# Eligibility filters (answer level), attrition, and the question/answer frame.

ATTRITION_RULES <- c(
  all = "All questions in the release",
  a = "Answer posted on or after {answer_date_min} and before {answer_date_max_exclusive} (UTC)",
  b = "Answer {answer_min_words}-{answer_max_words} words",
  c = "Question (title + body) {question_min_words}+ words",
  d = "unclear_goal missing",
  e = "Exclusion rule 1: platform-written prompts removed",
  f = "Anchor check questions removed",
  g = "Manual exclusions (study/config/exclusions.csv) removed"
)
ATTRITION_CHECKED_STEPS <- c("all", "a", "b", "c", "d", "e", "f")

# Exclusion rule 1: TRUE where title + body (HTML stripped) matches the platform-prompt pattern.
is_platform_prompt <- function(title, body, pattern) {
  text <- paste(str_replace_all(coalesce(title, ""), "<[^>]*>", " "), str_replace_all(coalesce(body, ""), "<[^>]*>", " "))
  str_detect(text, regex(pattern, ignore_case = TRUE))
}

answer_date_window <- function(filters) {
  c(min = as.POSIXct(filters$answer_date_min, tz = "UTC"),
    max_exclusive = as.POSIXct(filters$answer_date_max_exclusive, tz = "UTC"))
}

# Cumulative answer-level masks and the unique question count after each step.
# Works on raw or normalized input: missing is tested with is_missing().
eligibility_attrition <- function(raw, filters, anchor_ids = character(), exclusion_ids = character()) {
  answer_dt <- parse_careernet_date(normalize_missing(raw$answer_added_at), "answer_added_at")
  answer_words <- count_words(normalize_missing(raw$answer_body))
  question_words <- count_words(paste(coalesce(normalize_missing(raw$question_title), ""),
                                      coalesce(normalize_missing(raw$question_body), "")))
  platform_prompt <- is_platform_prompt(normalize_missing(raw$question_title), normalize_missing(raw$question_body),
                                        filters$platform_prompt_pattern)
  window <- answer_date_window(filters)

  keep <- list(all = rep(TRUE, nrow(raw)))
  keep$a <- keep$all & !is.na(answer_dt) & answer_dt >= window[["min"]] & answer_dt < window[["max_exclusive"]]
  keep$b <- keep$a & answer_words >= filters$answer_min_words & answer_words <= filters$answer_max_words
  keep$c <- keep$b & question_words >= filters$question_min_words
  keep$d <- keep$c & is_missing(raw$unclear_goal)
  keep$e <- keep$d & !platform_prompt
  keep$f <- keep$e & !(raw$question_id %in% anchor_ids)
  keep$g <- keep$f & !(raw$question_id %in% exclusion_ids)

  attrition <- tibble::tibble(
    step = names(keep),
    rule = vapply(ATTRITION_RULES[names(keep)], function(r) as.character(glue::glue_data(filters, r)), character(1), USE.NAMES = FALSE),
    n_questions = unname(purrr::map_int(keep, ~ dplyr::n_distinct(raw$question_id[.x]))),
    n_answers = unname(purrr::map_int(keep, sum))
  )
  list(keep = keep$g, masks = keep, attrition = attrition, answer_dt = answer_dt, answer_words = answer_words,
       question_words = question_words, platform_prompt = platform_prompt)
}

# Stops unless steps all, a, ..., f reproduce the expected question and answer counts exactly.
check_attrition <- function(attrition, expected) {
  steps <- ATTRITION_CHECKED_STEPS
  for (what in c("questions", "answers")) {
    exp <- expected[[what]]
    if (length(exp) != length(steps)) stop("expected_attrition$", what, " needs ", length(steps), " numbers", call. = FALSE)
    got <- attrition[[paste0("n_", what)]][match(steps, attrition$step)]
    if (!identical(as.integer(got), as.integer(exp))) {
      stop("Attrition (", what, ") does not reproduce.\n",
           paste0("  ", steps, ": expected ", exp, ", got ", got, collapse = "\n"), call. = FALSE)
    }
  }
  invisible(TRUE)
}

# raw: output of read_careernet(). Returns list(frame_questions, frame_answers, attrition).
build_frame <- function(raw, filters, anchor_ids, exclusion_ids, all_labels, guaranteed_labels,
                        expected_attrition = NULL, closing_pleasantries = character()) {
  elig <- eligibility_attrition(raw, filters, anchor_ids, exclusion_ids)
  attrition <- elig$attrition
  if (!is.null(expected_attrition)) {
    check_attrition(attrition, expected_attrition)
    attrition$expected_questions <- c(expected_attrition$questions, NA_integer_)
    attrition$expected_answers <- c(expected_attrition$answers, NA_integer_)
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

  answer_clean <- clean_text(d$answer_body)
  answer_display <- display_answer_text(answer_clean, closing_pleasantries)
  frame_answers <- tibble::tibble(
    question_id = d$question_id,
    answer_id = d$answer_id,
    answer_body_raw = d$answer_body,
    answer_text_clean = answer_clean,
    answer_text_display = answer_display$text,
    answer_word_count = d$.answer_words,
    answer_word_count_display = count_words(answer_display$text),
    has_list = has_list(d$answer_body, answer_clean),
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
  question_clean <- clean_text(q$question_body)
  question_display <- display_question_text(question_clean)
  labels <- parse_scenario_labels(q$ScenarioLabels)
  indicators <- scenario_label_indicators(labels, all_labels)
  frame_questions <- dplyr::bind_cols(
    tibble::tibble(
      question_id = q$question_id,
      question_title = q$question_title,
      question_body_raw = q$question_body,
      question_text_clean = question_clean,
      question_text_display = question_display$text,
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

  display_edits <- dplyr::bind_rows(
    tibble::tibble(answer_id = d$answer_id, part = "opening", removed_text = answer_display$opening_removed),
    tibble::tibble(answer_id = d$answer_id, part = "closing", removed_text = answer_display$closing_removed),
    tibble::tibble(answer_id = d$answer_id, part = "list_marker", removed_text = answer_display$list_markers_removed)
  ) |>
    dplyr::filter(!is.na(removed_text)) |>
    dplyr::arrange(id_key(answer_id), part)
  question_display_edits <- tibble::tibble(question_id = q$question_id, part = "hashtags",
                                           removed_text = question_display$hashtags_removed) |>
    dplyr::filter(!is.na(removed_text))

  list(frame_questions = frame_questions, frame_answers = frame_answers, attrition = attrition,
       display_edits = display_edits, question_display_edits = question_display_edits)
}

# "4 - Fully Correct" -> 4L
rating_num <- function(x, name) {
  y <- to_integer(str_extract(x, "^[1-4](?= - )"), name)
  bad <- !is.na(x) & is.na(y)
  if (any(bad)) stop(name, ": unrecognized rating '", x[bad][1], "'", call. = FALSE)
  y
}
