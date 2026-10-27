# Screening of drawn questions (exclusion rules 2-4) and seeded replacement.
#
# 04 fixes, at draw time, one random ordering of all unselected frame questions (the general
# queue) and one per guaranteed label (questions carrying it). 05 replays every completed
# screening sheet from round 1, so the result depends only on the draw, the queues and the
# sheets: there is no hidden state between calls.

SCREENING_RULES <- c(
  rule2 = "Asks about the responder's own career or experience rather than for advice to the asker (e.g. \"Why do you love your career?\", school interview assignments)",
  rule3 = "Needs knowledge of a specific non-US education or labor system to answer correctly",
  rule4 = "Asks for review of a pasted personal document (e.g. a resume), or bundles more than three separate questions"
)
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

# draw: question_id, draw_order, selection_stage, floor_block, floor_label (the study draw).
# sheets: completed sheets for rounds 1..K. frame: frame_remaining with label columns.
#
# The floor block is the floor-stage slots at the start of the draw order; the floor is checked
# within it, so the first k questions keep every floor for any k >= its size (D88). For each
# excluded question, in draw order:
#  1. Remove it. Its replacement takes the same position in draw order (and block). In the floor
#     block, if the removal drops guaranteed labels below the floor within the block, the
#     replacement is the next question in the rarest such label's queue; otherwise, and always
#     outside the block, the next in the general queue.
#  2. Floor swap: while a guaranteed label is still below the floor within the block (several
#     labels dropped at once), the last question in draw order outside the block (that this
#     round's sheet did not exclude) is swapped out, logged with reason "floor_swap", and the next
#     question in the short label's queue (rarest short label first) joins the end of the floor
#     block; the questions between move down one position. Stops only if nothing is outside the block.
# Queues skip questions already selected, excluded or swapped out. n never changes.
# Returns the current selection, the log, whether screening is finished, and the next round's ids.
replay_screening <- function(draw, sheets, queues, frame, guaranteed_labels, floor) {
  design <- prepare_floor_design(frame, guaranteed_labels, floor, nrow(draw))
  rarity <- guaranteed_labels[design$label_order]
  member <- design$member
  rownames(member) <- design$ids

  current <- draw[order(draw$draw_order), intersect(c("question_id", "draw_order", "selection_stage", "floor_block",
                                                      "floor_label"), names(draw))]
  if (!"floor_block" %in% names(current)) current$floor_block <- current$selection_stage == "floor"
  current <- current[c("question_id", "draw_order", "selection_stage", "floor_block", "floor_label")]
  floor_block_size(current)
  current$screening_round <- 1L
  current$replaced_question_id <- NA_character_
  gone <- character()                       # excluded or swapped out: never selected again
  log <- list()
  expected <- current$question_id
  finished <- FALSE

  block_counts <- function() colSums(member[current$question_id[current$floor_block], , drop = FALSE])
  next_in_queue <- function(queue_name, r) {
    cand <- queues$question_id[queues$queue == queue_name]
    cand <- cand[!cand %in% c(current$question_id, gone)]
    if (!length(cand)) stop("Replacement queue '", queue_name, "' is exhausted (round ", r, ")", call. = FALSE)
    cand[1]
  }
  add <- function(id, position, block, queue_name, replaced, r) {
    current <<- dplyr::bind_rows(current, tibble::tibble(
      question_id = id, draw_order = position, selection_stage = "replacement", floor_block = block,
      floor_label = if (queue_name == "general") NA_character_ else queue_name,
      screening_round = r + 1L, replaced_question_id = replaced))
    current <<- current[order(current$draw_order), ]
  }
  log_row <- function(id, position, r, reason, rules, notes, screener, repl, queue_name) {
    log[[length(log) + 1]] <<- tibble::tibble(question_id = id, draw_order = position, round = r, reason = reason,
                                              rules_triggered = rules, notes = notes, screener = screener,
                                              replaced_by = repl, replacement_queue = queue_name)
  }

  for (r in seq_along(sheets)) {
    if (finished) stop("Round ", r, " sheet exists, but round ", r - 1, " had no exclusions", call. = FALSE)
    sheet <- validate_screening_sheet(sheets[[r]], expected, r)
    ex <- sheet[sheet$excluded, ]
    ex <- ex[order(current$draw_order[match(ex$question_id, current$question_id)]), ]
    for (i in seq_len(nrow(ex))) {
      q <- ex$question_id[i]
      row <- current[current$question_id == q, ]
      current <- current[current$question_id != q, ]
      gone <- c(gone, q)
      dropping <- if (row$floor_block) intersect(rarity, guaranteed_labels[member[q, ] & block_counts() < floor]) else character()
      queue_name <- if (length(dropping)) dropping[1] else "general"
      repl <- next_in_queue(queue_name, r)
      add(repl, row$draw_order, row$floor_block, queue_name, q, r)
      rules <- names(SCREENING_RULES)[unlist(ex[i, names(SCREENING_RULES)])]
      log_row(q, row$draw_order, r, "excluded", paste(rules, collapse = "; "), ex$notes[i], ex$screener[i], repl, queue_name)

      repeat {
        short <- intersect(rarity, guaranteed_labels[block_counts() < floor])
        if (!length(short)) break
        lab <- short[1]
        pool <- current[!current$floor_block & !current$question_id %in% ex$question_id, ]
        if (!nrow(pool)) {
          stop("Guaranteed label '", lab, "' is below the floor after excluding ", q, " (round ", r,
               ") and no question outside the floor block can be swapped out", call. = FALSE)
        }
        out <- pool[which.max(pool$draw_order), ]
        current <- current[current$question_id != out$question_id, ]
        gone <- c(gone, out$question_id)
        n_block <- sum(current$floor_block)
        shift <- !current$floor_block & current$draw_order < out$draw_order
        current$draw_order[shift] <- current$draw_order[shift] + 1L
        in_q <- next_in_queue(lab, r)
        add(in_q, n_block + 1L, TRUE, lab, out$question_id, r)
        log_row(out$question_id, out$draw_order, r, "floor_swap", "", paste("displaced to keep n after excluding", q),
                NA_character_, in_q, lab)
      }
    }
    if (!nrow(ex)) finished <- TRUE
    expected <- current$question_id[current$screening_round == r + 1L]
  }
  floor_block_size(current)

  empty_log <- tibble::tibble(question_id = character(), draw_order = integer(), round = integer(), reason = character(),
                              rules_triggered = character(), notes = character(), screener = character(),
                              replaced_by = character(), replacement_queue = character())
  list(selection = current[order(current$draw_order), ],
       log = dplyr::bind_rows(empty_log, log),
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
