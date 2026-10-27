# Step 3b (D96): screen the reserved sets with exclusion rules 2-4 and replace excluded items.
# One round per call. Round 1 is pre-filled from config/reserved_confirmed_exclusions.csv (matched
# by set and title); later rounds are filled in by the screener. While a round has exclusions, 03b
# writes the next round's sheet. Once a round has none, it rewrites the reserved-set files and
# frame_remaining and writes reserved_exclusions_log.csv; then run freeze_frame.R.
# Only sets without screened: false are screened (spare is not; D97). Needs the frame unfrozen
# (unfreeze_frame.R). Excluded items leave the frame for good: they are neither reserved nor in
# frame_remaining.
source("study/scripts/_common.R")
run <- start_run("03b")
cfg <- run$cfg
assert_not_frozen(cfg, "03b_screen_reserved.R")

dir <- cfg$paths$reserved_dir
log_path <- file.path(dir, "reserved_exclusions_log.csv")
if (file.exists(log_path)) stop("Reserved-set screening is already finished (", log_path, " exists).", call. = FALSE)

screened_sets <- purrr::keep(cfg$reserved_sets, ~ !isFALSE(.x$screened))
set_order <- purrr::map_chr(screened_sets, "name")
set_paths <- stats::setNames(file.path(dir, paste0(set_order, ".rds")), set_order)
fq_path <- file.path(cfg$paths$frame_dir, "frame_questions.rds")
fa_path <- file.path(cfg$paths$frame_dir, "frame_answers.rds")
fr_path <- file.path(dir, "frame_remaining.rds")
fq <- readRDS(fq_path)
fa <- readRDS(fa_path)
fr <- readRDS(fr_path)
set_rows <- purrr::map_dfr(set_paths, readRDS)
if (any(set_rows$selection_stage != "reserve")) {
  stop("The screened set files already contain replacements; restore them by re-running 03 (unfrozen) before 03b", call. = FALSE)
}
sets <- transmute(set_rows, set, position = as.integer(draw_order), question_id, planned_version)
anchor_ids <- read_ids(cfg$inputs$anchor_exclusions)

# The replacement queue is fixed in round 1 and reused, so later calls replay the same order.
queue_seed <- derive_seed(cfg$master_seed, "reserve_replacement")
queue_path <- file.path(dir, "reserve_replacement_queue.csv")
queue <- make_reserve_queue(fr, queue_seed)
if (file.exists(queue_path)) {
  saved <- readr::read_csv(queue_path, col_types = "ic")
  if (!identical(saved$question_id, queue$question_id)) stop("The saved reserve replacement queue does not match frame_remaining", call. = FALSE)
} else {
  readr::write_csv(queue, queue_path)
}

# Round 1, pre-filled.
confirmed <- readr::read_csv(cfg$inputs$reserved_confirmed_exclusions, col_types = readr::cols(.default = "c"))
round1_path <- reserved_sheet_path(dir, 1)
blank1 <- make_reserved_sheet(sets, fq, set_order)
matches <- match_confirmed_exclusions(blank1, confirmed)
if (!file.exists(round1_path)) readr::write_csv(prefill_reserved_sheet(blank1, matches), round1_path, na = "")

message("Confirmed exclusions matched (round 1):")
print(as.data.frame(transmute(matches, set, position, question_id, rule, matched_title)), right = FALSE)

sheet_paths <- find_reserved_sheets(dir)
sheets <- purrr::map(sheet_paths, ~ readr::read_csv(.x, col_types = readr::cols(.default = "c"), na = character(), progress = FALSE))
res <- replay_reserved_screening(sets, sheets, queue, set_order)
k <- res$rounds
title_of <- function(ids) fq$question_title[match(ids, fq$question_id)]
log_tab <- mutate(res$log, question_title = title_of(question_id), replaced_by_title = title_of(replaced_by))

if (!res$finished) {
  next_sheet <- make_reserved_sheet(res$next_items, fq, set_order)
  next_path <- reserved_sheet_path(dir, k + 1)
  readr::write_csv(next_sheet, next_path, na = "")
  outputs <- c(queue = queue_path, round1 = round1_path, next_sheet = next_path)
  status <- glue("Round {k}: {sum(res$log$round == k)} exclusion(s), each replaced. Wrote the round {k + 1} sheet ",
                 "({nrow(next_sheet)} item(s)) to {next_path}. Fill rule2-rule4, excluded and notes, then run 03b again.")
  message("Round ", k + 1, " items to screen:")
  print(as.data.frame(transmute(next_sheet, set, position, question_id, planned_version, question_title)), right = FALSE)
} else {
  answers <- pick_human_answer(fa, derive_seed(cfg$master_seed, "human_answer"))
  repl <- res$current[!is.na(res$current$replaced_question_id), ]
  selection <- transmute(repl, question_id, set, draw_order = position, selection_stage = "reserve_replacement",
                         floor_label = NA_character_,
                         inclusion_prob = purrr::map_dbl(set, function(s) purrr::keep(cfg$reserved_sets, ~ .x$name == s)[[1]]$size) / nrow(fq),
                         weight = 1, planned_version)
  new_rows <- assemble_sample(selection, fq, answers, queue_seed, run$run_id, cfg$frame_version, cfg$target_words_tolerance)
  key <- function(d) paste(d$set, d$draw_order)
  rows <- bind_rows(set_rows[!key(set_rows) %in% key(new_rows), ], new_rows)
  rows <- rows[order(match(rows$set, set_order), rows$draw_order), ]
  stopifnot(identical(paste(rows$set, rows$question_id), paste(res$current$set, res$current$question_id)))

  outputs <- c(queue = queue_path)
  all_rows <- bind_rows(purrr::map(setdiff(purrr::map_chr(cfg$reserved_sets, "name"), set_order),
                                   ~ readRDS(file.path(dir, paste0(.x, ".rds")))), rows)
  stop_on_failed_checks(check_reserved_sets(all_rows, cfg$reserved_sets, fq, anchor_ids))
  for (s in screened_sets) stop_on_failed_checks(check_sample(rows[rows$set == s$name, ], fq, fa, anchor_ids, n = s$size))
  # Excluded items may be original reserved items or earlier replacements (taken from
  # frame_remaining); either way they leave the frame.
  excluded_ids <- res$log$question_id
  remaining <- fr[!fr$question_id %in% c(rows$question_id, excluded_ids), ]
  parts <- c(remaining$question_id, all_rows$question_id, excluded_ids)
  if (!setequal(parts, fq$question_id) || anyDuplicated(parts)) {
    stop("frame_remaining + reserved sets + excluded items do not partition the frame", call. = FALSE)
  }
  # All checks passed: write.
  for (s in screened_sets) outputs <- c(outputs, write_outputs(rows[rows$set == s$name, ], dir, s$name))
  outputs <- c(outputs, write_outputs(remaining, dir, "frame_remaining"))
  readr::write_csv(log_tab, log_path, na = "")
  outputs <- c(outputs, log = log_path)
  status <- glue("Round {k} had no exclusions: reserved-set screening is complete after {k} round(s); ",
                 "{nrow(res$log)} item(s) excluded and replaced. Updated the reserved sets and frame_remaining ",
                 "({nrow(remaining)} questions). Run freeze_frame.R next.")
}

report_path <- file.path(cfg$paths$reports_dir, glue("03b_screen_reserved_{run$run_id}.md"))
writeLines(c(
  glue("# Reserved-set screening (D96), round {k}"), "", glue("Run `{run$run_id}` · sheets read: {paste(basename(sheet_paths), collapse = ', ')}"), "",
  status, "",
  glue("Sets screened: {paste(set_order, collapse = ', ')}. Not screened: ",
       "{paste(setdiff(purrr::map_chr(cfg$reserved_sets, 'name'), set_order), collapse = ', ')}."), "",
  "## Rules (question text only)", "",
  paste0("- **", names(SCREENING_RULES), "**: ", SCREENING_RULES), "",
  glue("Replacement: the next question in a seeded random ordering of frame_remaining (derive_seed({cfg$master_seed}, \"reserve_replacement\") = {queue_seed}), "),
  "skipping questions already used or excluded. The replacement keeps the set, position and planned_version; its human answer is the usual seeded pick.", "",
  "## Confirmed exclusions pre-filled in round 1", "",
  md_table(transmute(matches, set, position, question_id, rule, given_title, matched_title)), "",
  "## Exclusions and replacements so far", "",
  md_table(transmute(log_tab, set, position, round, question_id, question_title, rules_triggered, replaced_by, replaced_by_title)), ""
), report_path)

write_run_log(file.path(cfg$paths$logs_dir, glue("{run$run_id}.yml")), run$run_id, "03b_screen_reserved.R",
              seeds = list(master_seed = cfg$master_seed, reserve_replacement = queue_seed,
                           human_answer = derive_seed(cfg$master_seed, "human_answer")),
              config = cfg,
              input_files = c(config = run$config_path, confirmed = cfg$inputs$reserved_confirmed_exclusions,
                              frame_questions = fq_path, frame_answers = fa_path, frame_remaining = fr_path, set_paths,
                              stats::setNames(sheet_paths, basename(sheet_paths))),
              frame_version = cfg$frame_version, outputs = c(outputs, report = report_path),
              extra = list(round = k, finished = res$finished, exclusions = purrr::transpose(as.list(res$log))))
message(status, " Report: ", report_path)
