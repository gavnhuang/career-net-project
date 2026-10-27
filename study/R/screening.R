# Screening of drawn questions (exclusion rules 2-4) and seeded replacement.
#
# 04 fixes, at draw time, one random ordering of all unselected frame questions (the general
# queue) and one per guaranteed label (questions carrying it). 05 replays every completed
# screening sheet from round 1, so the result depends only on the draw, the queues and the
# sheets: there is no hidden state between calls.

SCREENING_RULES <- c(rule2 = "Asks about the responder's own career or experience, not for advice to the asker",
                     rule3 = "Needs knowledge of a specific non-US education or labor system",
                     rule4 = "Asks for review of a pasted personal document, or bundles more than three questions")
SCREENING_COLUMNS <- c("question_id", "question_title", "question_text_display", "rule2", "rule3", "rule4",
                       "excluded", "screener", "notes")

# Long table: queue ("general" or a label), label (NA for general), position, question_id.
make_replacement_queues <- function(frame, selected_ids, guaranteed_labels, seed_base) {
  frame <- frame[order(id_key(frame$question_id), method = "radix"), ]
  pool <- frame[!frame$question_id %in% selected_ids, ]
  shuffle <- function(ids, stage) with_seed(derive_seed(seed_base, stage), sample_k(ids, length(ids)))

  general <- shuffle(pool$question_id, "replacement_queue_general")
  per_label <- purrr::map(guaranteed_labels, function(l) {
    ids <- pool$question_id[pool[[label_column_names(l)]] == 1L]
    tibble::tibble(queue = l, label = l, position = seq_along(ids),
                   question_id = shuffle(ids, paste0("replacement_queue_", snake_case(l))))
  })
  dplyr::bind_rows(tibble::tibble(queue = "general", label = NA_character_, position = seq_along(general),
                                  question_id = general),
                   per_label)
}

# A blank sheet for the screener: question text only, never answer information.
# Rows are in question_id order so the sheet does not reveal how each question was selected.
make_screening_sheet <- function(questions) {
  q <- questions[order(id_key(questions$question_id), method = "radix"), ]
  tibble::tibble(question_id = q$question_id, question_title = q$question_title,
                 question_text_display = q$question_text_display,
                 rule2 = NA, rule3 = NA, rule4 = NA, excluded = NA,
                 screener = NA_character_, notes = NA_character_)
}

read_screening_sheet <- function(path) {
  readr::read_csv(path, col_types = readr::cols(.default = readr::col_character()), na = character(),
                  progress = FALSE)
}

parse_flag <- function(x) {
  x <- toupper(str_trim(coalesce(x, "")))
  ifelse(x == "TRUE", TRUE, ifelse(x == "FALSE", FALSE, NA))
}

# Stops with every problem listed. Returns the sheet with logical rule/excluded columns.
validate_screening_sheet <- function(sheet, expected_ids, round) {
  problems <- character()
  missing_cols <- setdiff(SCREENING_COLUMNS, names(sheet))
  if (length(missing_cols)) stop("Round ", round, " sheet is missing column(s): ", paste(missing_cols, collapse = ", "), call. = FALSE)
  if (anyDuplicated(sheet$question_id)) problems <- c(problems, "duplicated question_id(s)")
  if (!setequal(sheet$question_id, expected_ids)) {
    problems <- c(problems, glue::glue("question_ids do not match the draw (unexpected: {paste(setdiff(sheet$question_id, expected_ids), collapse = ', ')}; ",
                                       "missing: {paste(setdiff(expected_ids, sheet$question_id), collapse = ', ')})"))
  }
  flags <- purrr::map(sheet[c("rule2", "rule3", "rule4", "excluded")], parse_flag)
  for (col in names(flags)) {
    bad <- sheet$question_id[is.na(flags[[col]])]
    if (length(bad)) problems <- c(problems, glue::glue("{col} is not TRUE/FALSE for {paste(bad, collapse = ', ')}"))
  }
  no_screener <- sheet$question_id[is_missing(str_trim(coalesce(sheet$screener, "")))]
  if (length(no_screener)) problems <- c(problems, glue::glue("screener is empty for {paste(no_screener, collapse = ', ')}"))
  if (!any(purrr::map_lgl(flags, anyNA))) {
    mismatch <- sheet$question_id[flags$excluded != (flags$rule2 | flags$rule3 | flags$rule4)]
    if (length(mismatch)) problems <- c(problems, glue::glue("excluded != (rule2 | rule3 | rule4) for {paste(mismatch, collapse = ', ')}"))
  }
  if (length(problems)) {
    stop("Round ", round, " screening sheet is not valid:\n", paste0("  - ", problems, collapse = "\n"), call. = FALSE)
  }
  for (col in names(flags)) sheet[[col]] <- flags[[col]]
  sheet
}

# draw: question_id, draw_order, selection_stage, floor_label (the study draw, in draw order).
# sheets: completed, validated sheets for rounds 1..K. frame: frame_remaining with label columns.
# Returns the current selection, the exclusions log, whether screening is finished, and the
# question_ids for the next round's sheet.
replay_screening <- function(draw, sheets, queues, frame, guaranteed_labels, floor) {
  design <- prepare_floor_design(frame, guaranteed_labels, floor, nrow(draw))
  rarity <- guaranteed_labels[design$label_order]
  member <- design$member
  rownames(member) <- design$ids

  current <- draw[order(draw$draw_order), c("question_id", "draw_order", "selection_stage", "floor_label")]
  current$screening_round <- 1L
  current$replaced_question_id <- NA_character_
  excluded <- character()
  log <- list()
  expected <- current$question_id
  finished <- FALSE

  for (r in seq_along(sheets)) {
    if (finished) stop("Round ", r, " sheet exists, but round ", r - 1, " had no exclusions", call. = FALSE)
    sheet <- validate_screening_sheet(sheets[[r]], expected, r)
    ex <- sheet[sheet$excluded, ]
    ex <- ex[order(current$draw_order[match(ex$question_id, current$question_id)]), ]
    added <- character()
    for (i in seq_len(nrow(ex))) {
      q <- ex$question_id[i]
      current <- current[current$question_id != q, ]
      excluded <- c(excluded, q)
      counts <- colSums(member[current$question_id, , drop = FALSE])
      dropping <- intersect(rarity, guaranteed_labels[member[q, ] & counts < floor])
      queue_name <- if (length(dropping)) dropping[1] else "general"
      cand <- queues$question_id[queues$queue == queue_name]
      cand <- cand[!cand %in% c(current$question_id, excluded)]
      if (!length(cand)) stop("Replacement queue '", queue_name, "' is exhausted (round ", r, ")", call. = FALSE)
      repl <- cand[1]
      current <- dplyr::bind_rows(current, tibble::tibble(
        question_id = repl, draw_order = max(c(draw$draw_order, current$draw_order)) + 1L,
        selection_stage = "replacement", floor_label = if (queue_name == "general") NA_character_ else queue_name,
        screening_round = r + 1L, replaced_question_id = q))
      added <- c(added, repl)
      rules <- names(SCREENING_RULES)[unlist(ex[i, names(SCREENING_RULES)])]
      log[[length(log) + 1]] <- tibble::tibble(question_id = q, round = r, rules_triggered = paste(rules, collapse = "; "),
                                               notes = ex$notes[i], screener = ex$screener[i], replaced_by = repl,
                                               replacement_queue = queue_name)
    }
    if (!nrow(ex)) finished <- TRUE
    expected <- added
  }

  list(selection = current[order(current$draw_order), ],
       log = dplyr::bind_rows(log, tibble::tibble(question_id = character(), round = integer(), rules_triggered = character(),
                                                  notes = character(), screener = character(), replaced_by = character(),
                                                  replacement_queue = character())),
       finished = finished, rounds = length(sheets), next_ids = if (finished) character() else expected)
}

# Paths of existing sheets for rounds 1..K (must be consecutive).
screening_sheet_path <- function(dir, round, tag) file.path(dir, glue::glue("screening_sheet_round{round}{tag}.csv"))

find_screening_sheets <- function(dir, tag) {
  files <- list.files(dir, pattern = paste0("^screening_sheet_round[0-9]+", tag, "\\.csv$"))
  rounds <- sort(as.integer(str_extract(files, "(?<=round)[0-9]+")))
  if (length(rounds) && !identical(rounds, seq_along(rounds))) {
    stop("Screening sheets are not consecutive from round 1: ", paste(rounds, collapse = ", "), call. = FALSE)
  }
  screening_sheet_path(dir, seq_along(rounds), tag)
}
