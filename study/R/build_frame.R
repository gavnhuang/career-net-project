# Eligibility filters (answer level), attrition, and the question/answer frame.

ATTRITION_RULES <- c(
  all = "All questions in the release",
  a = "Answer posted in {answer_min_year} or later",
  b = "Answer {answer_min_words}-{answer_max_words} words",
  c = "Question (title + body) {question_min_words}+ words",
  d = "unclear_goal missing",
  e = "Anchor check questions removed",
  f = "Manual exclusions (study/config/exclusions.csv) removed"
)

# Cumulative answer-level masks and the unique question count after each step.
# Works on raw or normalized input: missing is tested with is_missing().
eligibility_attrition <- function(raw, filters, anchor_ids = character(), exclusion_ids = character()) {
  answer_dt <- parse_careernet_date(normalize_missing(raw$answer_added_at), "answer_added_at")
  answer_words <- count_words(normalize_missing(raw$answer_body))
  question_words <- count_words(paste(coalesce(normalize_missing(raw$question_title), ""),
                                      coalesce(normalize_missing(raw$question_body), "")))
  min_dt <- lubridate::make_datetime(filters$answer_min_year, 1, 1, tz = "UTC")

  keep <- list(all = rep(TRUE, nrow(raw)))
  keep$a <- keep$all & !is.na(answer_dt) & answer_dt >= min_dt
  keep$b <- keep$a & answer_words >= filters$answer_min_words & answer_words <= filters$answer_max_words
  keep$c <- keep$b & question_words >= filters$question_min_words
  keep$d <- keep$c & is_missing(raw$unclear_goal)
  keep$e <- keep$d & !(raw$question_id %in% anchor_ids)
  keep$f <- keep$e & !(raw$question_id %in% exclusion_ids)

  attrition <- tibble::tibble(
    step = names(keep),
    rule = vapply(ATTRITION_RULES[names(keep)], function(r) as.character(glue::glue_data(filters, r)), character(1), USE.NAMES = FALSE),
    n_questions = unname(purrr::map_int(keep, ~ dplyr::n_distinct(raw$question_id[.x]))),
    n_answers = unname(purrr::map_int(keep, sum))
  )
  list(keep = keep$f, attrition = attrition, answer_dt = answer_dt,
       answer_words = answer_words, question_words = question_words)
}

# Stops unless steps all, a, ..., e reproduce `expected` exactly.
check_attrition <- function(attrition, expected) {
  steps <- c("all", "a", "b", "c", "d", "e")
  if (length(expected) != length(steps)) stop("expected_attrition needs ", length(steps), " numbers", call. = FALSE)
  got <- attrition$n_questions[match(steps, attrition$step)]
  if (!identical(as.integer(got), as.integer(expected))) {
    stop("Attrition does not reproduce.\n",
         paste0("  ", steps, ": expected ", expected, ", got ", got, collapse = "\n"), call. = FALSE)
  }
  invisible(TRUE)
}

# raw: output of read_careernet(). Returns list(frame_questions, frame_answers, attrition).
build_frame <- function(raw, filters, anchor_ids, exclusion_ids, all_labels, guaranteed_labels,
                        expected_attrition = NULL) {
  elig <- eligibility_attrition(raw, filters, anchor_ids, exclusion_ids)
  attrition <- elig$attrition
  if (!is.null(expected_attrition)) {
    check_attrition(attrition, expected_attrition)
    attrition$expected <- c(expected_attrition, NA_integer_)
  }

  d <- raw[elig$keep, ]
  d$.answer_dt <- elig$answer_dt[elig$keep]
  d$.answer_words <- elig$answer_words[elig$keep]
  d$.question_words <- elig$question_words[elig$keep]
  d <- d[order(id_key(d$question_id), id_key(d$answer_id), method = "radix"), ]

  question_level <- c("question_title", "question_body", "question_added_at", "question_score", "question_views",
                      "question_tagnames", "asker_location", "ScenarioLabels", GOAL_COLUMNS, "unclear_goal", "soc_code")

  varying <- d |>
    dplyr::group_by(question_id) |>
    dplyr::summarise(dplyr::across(dplyr::all_of(question_level), dplyr::n_distinct)) |>
    dplyr::select(-question_id) |>
    purrr::map_lgl(~ any(.x > 1))
  if (any(varying)) stop("Question-level column(s) vary within a question: ",
                         paste(names(varying)[varying], collapse = ", "), call. = FALSE)

  extras <- setdiff(names(raw), CAREERNET_COLUMNS)

  frame_answers <- tibble::tibble(
    question_id = d$question_id,
    answer_id = d$answer_id,
    answer_body_raw = d$answer_body,
    answer_text_clean = clean_text(d$answer_body),
    answer_word_count = d$.answer_words,
    answer_added_at = d$.answer_dt,
    answer_score = to_integer(d$answer_score, "answer_score"),
    answerer_location = d$answerer_location,
    careernet_correctness = d$correctness,
    careernet_completeness = d$completeness,
    careernet_coherency = d$coherency,
    careernet_correctness_num = rating_num(d$correctness, "correctness"),
    careernet_completeness_num = rating_num(d$completeness, "completeness"),
    careernet_coherency_num = rating_num(d$coherency, "coherency"),
    Split = d$Split,
    careernet_reasoning_label = d$reasoning_label,
    n_reasoning_labels = lengths(parse_reasoning(d$reasoning_label))
  )
  clash <- intersect(extras, names(frame_answers))
  if (length(clash)) stop("New input column(s) clash with output names: ", paste(clash, collapse = ", "), call. = FALSE)
  frame_answers <- dplyr::bind_cols(frame_answers, d[extras])

  q <- d[!duplicated(d$question_id), ]
  labels <- parse_scenario_labels(q$ScenarioLabels)
  indicators <- scenario_label_indicators(labels, all_labels)
  frame_questions <- dplyr::bind_cols(
    tibble::tibble(
      question_id = q$question_id,
      question_title = q$question_title,
      question_body_raw = q$question_body,
      question_text_clean = clean_text(q$question_body),
      question_word_count = q$.question_words,
      question_added_at = parse_careernet_date(q$question_added_at, "question_added_at"),
      question_score = to_integer(q$question_score, "question_score"),
      question_views = to_integer(q$question_views, "question_views"),
      question_tagnames = q$question_tagnames,
      asker_location = q$asker_location,
      scenario_labels = q$ScenarioLabels,
      n_labels = lengths(labels)
    ),
    indicators,
    tibble::tibble(n_guaranteed_labels = purrr::map_int(labels, ~ sum(.x %in% guaranteed_labels))),
    q[c(GOAL_COLUMNS, "unclear_goal")],
    tibble::tibble(soc_code_raw = q$soc_code),
    parse_soc(q$soc_code),
    tibble::tibble(n_eligible_answers = as.integer(table(d$question_id)[q$question_id]))
  )

  list(frame_questions = frame_questions, frame_answers = frame_answers, attrition = attrition)
}

# "4 - Fully Correct" -> 4L
rating_num <- function(x, name) {
  y <- to_integer(str_extract(x, "^[1-4](?= - )"), name)
  bad <- !is.na(x) & is.na(y)
  if (any(bad)) stop(name, ": unrecognized rating '", x[bad][1], "'", call. = FALSE)
  y
}
