# Screening of the reserved sets with exclusion rules 2-4 (D96) and seeded replacement.
#
# One queue: a seeded random ordering of frame_remaining (derive_seed(master_seed,
# "reserve_replacement")), fixed in round 1. Each excluded item is replaced by the next queue
# question not already used or excluded; the replacement keeps the set, position and
# planned_version. 03b replays every completed sheet from round 1, like 05.

RESERVED_SCREENING_COLUMNS <- c("set", "position", "question_id", "question_title", "question_text_display",
                                "planned_version", "rule2", "rule3", "rule4", "excluded", "notes")

reserved_key <- function(set, position, question_id) paste(set, position, question_id, sep = "|")

# rows: set, position, question_id, planned_version; questions: frame questions (title, display text).
# Never carries answer information.
make_reserved_sheet <- function(rows, questions, set_order) {
  rows <- rows[order(match(rows$set, set_order), rows$position), ]
  q <- questions[match(rows$question_id, questions$question_id), ]
  tibble::tibble(set = rows$set, position = as.integer(rows$position), question_id = rows$question_id,
                 question_title = q$question_title, question_text_display = q$question_text_display,
                 planned_version = rows$planned_version,
                 rule2 = NA_character_, rule3 = NA_character_, rule4 = NA_character_, excluded = NA_character_,
                 notes = NA_character_)
}

normalize_title <- function(x) str_squish(tolower(coalesce(x, "")))

# confirmed: set, title, rule (rule2/rule3/rule4), match ("exact", or "prefix" for a title given
# with a trailing ellipsis), note. Each row must match exactly one item of its set.
match_confirmed_exclusions <- function(sheet, confirmed) {
  bad_rule <- setdiff(confirmed$rule, names(SCREENING_RULES))
  if (length(bad_rule)) stop("Unknown rule(s) in confirmed exclusions: ", paste(bad_rule, collapse = ", "), call. = FALSE)
  purrr::pmap_dfr(confirmed, function(set, title, rule, match, note) {
    cand <- sheet[sheet$set == set, ]
    want <- normalize_title(str_remove(title, "(…|\\.\\.\\.)\\s*$"))
    have <- normalize_title(cand$question_title)
    hit <- switch(match, exact = have == want, prefix = startsWith(have, want),
                  stop("match must be exact or prefix, not '", match, "'", call. = FALSE))
    if (sum(hit) != 1) {
      stop("Confirmed exclusion \"", title, "\" matches ", sum(hit), " item(s) in set ", set, " (needs exactly 1)", call. = FALSE)
    }
    tibble::tibble(set = set, position = cand$position[hit], question_id = cand$question_id[hit],
                   given_title = title, matched_title = cand$question_title[hit], rule = rule, note = note)
  })
}

# Round 1: the matched items excluded with their rule, every other item excluded = FALSE.
prefill_reserved_sheet <- function(sheet, matches) {
  for (col in c(names(SCREENING_RULES), "excluded")) sheet[[col]] <- "FALSE"
  sheet$notes <- ""
  i <- match(reserved_key(matches$set, matches$position, matches$question_id),
             reserved_key(sheet$set, sheet$position, sheet$question_id))
  if (anyNA(i) || anyDuplicated(i)) stop("Confirmed exclusions do not map one-to-one onto the sheet", call. = FALSE)
  for (k in seq_along(i)) {
    sheet[[matches$rule[k]]][i[k]] <- "TRUE"
    sheet$excluded[i[k]] <- "TRUE"
    sheet$notes[i[k]] <- matches$note[k]
  }
  sheet
}

# Stops with every problem listed. expected: set, position, question_id of the items in this round.
validate_reserved_sheet <- function(sheet, expected, round) {
  missing_cols <- setdiff(RESERVED_SCREENING_COLUMNS, names(sheet))
  if (length(missing_cols)) stop("Reserved round ", round, " sheet is missing column(s): ", paste(missing_cols, collapse = ", "), call. = FALSE)
  problems <- character()
  got <- reserved_key(sheet$set, sheet$position, sheet$question_id)
  want <- reserved_key(expected$set, expected$position, expected$question_id)
  if (anyDuplicated(got)) problems <- c(problems, "duplicated rows")
  if (!setequal(got, want)) {
    problems <- c(problems, glue::glue("items do not match (unexpected: {paste(setdiff(got, want), collapse = ', ')}; ",
                                       "missing: {paste(setdiff(want, got), collapse = ', ')})"))
  }
  flags <- purrr::map(sheet[c(names(SCREENING_RULES), "excluded")], parse_flag)
  for (col in names(flags)) {
    bad <- got[is.na(flags[[col]])]
    if (length(bad)) problems <- c(problems, glue::glue("{col} is not TRUE/FALSE for {paste(bad, collapse = ', ')}"))
  }
  if (!any(purrr::map_lgl(flags, anyNA))) {
    mismatch <- got[flags$excluded != (flags$rule2 | flags$rule3 | flags$rule4)]
    if (length(mismatch)) problems <- c(problems, glue::glue("excluded != (rule2 | rule3 | rule4) for {paste(mismatch, collapse = ', ')}"))
  }
  if (length(problems)) stop("Reserved round ", round, " sheet is not valid:\n", paste0("  - ", problems, collapse = "\n"), call. = FALSE)
  for (col in names(flags)) sheet[[col]] <- flags[[col]]
  sheet$position <- as.integer(sheet$position)     # sheets are read as text; order numerically
  sheet
}

make_reserve_queue <- function(frame_remaining, seed) {
  ids <- frame_remaining$question_id[order(id_key(frame_remaining$question_id), method = "radix")]
  tibble::tibble(position = seq_along(ids), question_id = with_seed(seed, sample_k(ids, length(ids))))
}

# sets: set, position, question_id, planned_version (the reserved sets as drawn by 03).
# Returns the current items, the log, whether screening is finished and the next round's items.
replay_reserved_screening <- function(sets, sheets, queue, set_order) {
  current <- sets[c("set", "position", "question_id", "planned_version")]
  current$screening_round <- 1L
  current$replaced_question_id <- NA_character_
  gone <- character()
  log <- list()
  expected <- current
  finished <- FALSE
  for (r in seq_along(sheets)) {
    if (finished) stop("Reserved round ", r, " sheet exists, but round ", r - 1, " had no exclusions", call. = FALSE)
    sheet <- validate_reserved_sheet(sheets[[r]], expected, r)
    ex <- sheet[sheet$excluded, ]
    ex <- ex[order(match(ex$set, set_order), ex$position), ]
    for (i in seq_len(nrow(ex))) {
      q <- ex$question_id[i]
      row <- current[current$set == ex$set[i] & current$position == ex$position[i], ]
      current <- current[!(current$set == ex$set[i] & current$position == ex$position[i]), ]
      gone <- c(gone, q)
      cand <- queue$question_id[!queue$question_id %in% c(current$question_id, gone)]
      if (!length(cand)) stop("The reserve replacement queue is exhausted (round ", r, ")", call. = FALSE)
      current <- dplyr::bind_rows(current, tibble::tibble(set = row$set, position = row$position, question_id = cand[1],
                                                          planned_version = row$planned_version,
                                                          screening_round = r + 1L, replaced_question_id = q))
      rules <- names(SCREENING_RULES)[unlist(ex[i, names(SCREENING_RULES)])]
      log[[length(log) + 1]] <- tibble::tibble(set = row$set, position = row$position, question_id = q, round = r,
                                               rules_triggered = paste(rules, collapse = "; "), notes = ex$notes[i],
                                               replaced_by = cand[1])
    }
    if (!nrow(ex)) finished <- TRUE
    expected <- current[current$screening_round == r + 1L, ]
  }
  empty_log <- tibble::tibble(set = character(), position = integer(), question_id = character(), round = integer(),
                              rules_triggered = character(), notes = character(), replaced_by = character())
  current <- current[order(match(current$set, set_order), current$position), ]
  list(current = current, log = dplyr::bind_rows(empty_log, log), finished = finished, rounds = length(sheets),
       next_items = if (finished) current[0, ] else expected)
}

reserved_sheet_path <- function(dir, round) file.path(dir, glue::glue("reserved_screening_round{round}.csv"))

find_reserved_sheets <- function(dir) {
  files <- list.files(dir, pattern = "^reserved_screening_round[0-9]+\\.csv$")
  rounds <- sort(as.integer(str_extract(files, "(?<=round)[0-9]+")))
  if (length(rounds) && !identical(rounds, seq_along(rounds))) {
    stop("Reserved screening sheets are not consecutive from round 1: ", paste(rounds, collapse = ", "), call. = FALSE)
  }
  reserved_sheet_path(dir, seq_along(rounds))
}
