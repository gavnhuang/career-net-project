# TEST ONLY: shows that 05 replaces excluded questions correctly. Not a screening record.
# Copies the dry-run draw into <out_dir>, fills the round-1 sheet with a FAKE pattern, runs 05,
# marks round 2 all clear, runs 05 again. Nothing is written to study/data.
# Patterns:
#   floor     (default) the first three questions, in draw order, carrying the rarest guaranteed
#             label in the sample, so later exclusions push that label to the floor
#   two_label the smallest set found (searching label pairs) whose exclusion drops two guaranteed
#             labels below the floor at once, so the floor swap runs
# Usage (from the project root): Rscript study/scripts/demo_05_screening_TEST.R <out_dir> [floor|two_label]
source("study/scripts/_common.R")
args <- commandArgs(trailingOnly = TRUE)
if (!length(args) %in% 1:2) stop("Usage: Rscript study/scripts/demo_05_screening_TEST.R <out_dir> [floor|two_label]", call. = FALSE)
out_dir <- normalizePath(args[1], mustWork = FALSE)
pattern <- if (length(args) == 2) args[2] else "floor"
if (!pattern %in% c("floor", "two_label")) stop("pattern must be floor or two_label", call. = FALSE)
if (startsWith(out_dir, normalizePath("study"))) stop("out_dir must be outside study/", call. = FALSE)

cfg <- load_config("study/config/study_config.yml")
if (is_preregistered(cfg)) stop("This demo only runs on a dry-run draw", call. = FALSE)
src <- sample_output_plan(cfg)

test_cfg <- yaml::read_yaml("study/config/study_config.yml")
test_cfg$paths$sample_dir <- file.path(out_dir, "03_sample")
test_cfg$paths$reports_dir <- file.path(out_dir, "reports")
test_cfg$paths$logs_dir <- file.path(out_dir, "logs")
dir.create(file.path(out_dir, "03_sample", "_dry_run"), recursive = TRUE, showWarnings = FALSE)
cfg_path <- file.path(out_dir, "TEST_config.yml")
yaml::write_yaml(test_cfg, cfg_path)
invisible(file.copy(list.files(src$dir, pattern = "_DRY_RUN\\.(csv|rds)$", full.names = TRUE),
          file.path(out_dir, "03_sample", "_dry_run"), overwrite = TRUE))
dry_dir <- file.path(out_dir, "03_sample", "_dry_run")
invisible(file.remove(list.files(dry_dir, pattern = "^screening_sheet_round([2-9]|[0-9]{2,})|screened|exclusions_log", full.names = TRUE)))

sample <- readRDS(file.path(dry_dir, "study_sample_DRY_RUN.rds"))
cols <- label_column_names(cfg$guaranteed_labels)
counts <- colSums(as.matrix(sample[cols]))
fr <- readRDS(file.path(cfg$paths$reserved_dir, "frame_remaining.rds"))
queues <- readRDS(file.path(dry_dir, "replacement_queues_DRY_RUN.rds"))
draw <- sample[c("question_id", "draw_order", "selection_stage", "floor_label")]
sheet_with <- function(ex) {
  s <- make_screening_sheet(sample)
  s$rule2 <- ifelse(s$question_id %in% ex, "TRUE", "FALSE"); s$rule3 <- "FALSE"; s$rule4 <- "FALSE"
  s$excluded <- s$rule2; s$screener <- "TEST-PATTERN"; s$notes <- ""
  s
}
if (pattern == "floor") {
  rarest <- cols[which.min(counts)]
  fake <- sample$question_id[order(sample$draw_order)][sample[[rarest]][order(sample$draw_order)] == 1L][1:3]
  cat("FAKE pattern: exclude the first 3 of", counts[[rarest]], "questions carrying", rarest, "\n")
} else {
  # For a question q carrying two guaranteed labels: keep just enough other carriers that each label
  # sits exactly at the floor when q is processed, exclude every other carrier drawn before q, then q.
  fake <- NULL
  for (i in seq_along(cols)) for (j in seq_along(cols)) if (i < j) {
    pair <- cols[c(i, j)]
    both <- sample$question_id[sample[[pair[1]]] == 1L & sample[[pair[2]]] == 1L]
    for (q in both) {
      qo <- sample$draw_order[sample$question_id == q]
      carriers <- sample[(sample[[pair[1]]] == 1L | sample[[pair[2]]] == 1L) & sample$question_id != q, ]
      kept <- colSums(as.matrix(carriers[carriers$draw_order > qo, pair]))
      before <- carriers[carriers$draw_order < qo, ]
      before <- before[order(-before$draw_order), ]
      ex <- character()
      for (k in seq_len(nrow(before))) {
        has <- unlist(before[k, pair]) == 1L
        if (all(kept[has] + 1 <= cfg$floor - 1)) kept[has] <- kept[has] + 1 else ex <- c(ex, before$question_id[k])
      }
      if (any(kept != cfg$floor - 1)) next
      ex <- c(ex, q)
      res <- tryCatch(replay_screening(draw, list(sheet_with(ex)), queues, fr, cfg$guaranteed_labels, cfg$floor),
                      error = function(e) NULL)
      if (!is.null(res) && any(res$log$reason == "floor_swap") && (is.null(fake) || length(ex) < length(fake))) fake <- ex
    }
  }
  if (is.null(fake)) stop("No single-round exclusion pattern in this dry-run draw produces a two-label drop (too many later-drawn carriers); see the synthetic test in test-screening.R", call. = FALSE)
  cat("FAKE pattern: exclude", length(fake), "questions so that the last one drops two guaranteed labels at once\n")
}

fill <- function(path, excluded_ids, rule_of) {
  s <- read_screening_sheet(path)
  for (r in c("rule2", "rule3", "rule4")) s[[r]] <- ifelse(s$question_id %in% excluded_ids & rule_of[s$question_id] == r, "TRUE", "FALSE")
  s$rule2[is.na(s$rule2)] <- "FALSE"; s$rule3[is.na(s$rule3)] <- "FALSE"; s$rule4[is.na(s$rule4)] <- "FALSE"
  s$excluded <- ifelse(s$question_id %in% excluded_ids, "TRUE", "FALSE")
  s$screener <- "TEST-PATTERN"
  s$notes <- ifelse(s$question_id %in% excluded_ids, "FAKE TEST PATTERN - not a real screening decision", "")
  readr::write_csv(s, path, na = "")
}
run05 <- function() {
  status <- system2("Rscript", c("study/scripts/05_apply_screening.R", shQuote(cfg_path)), stdout = TRUE, stderr = TRUE)
  cat(grep("Round|screening is complete|Error", status, value = TRUE), sep = "\n")
}

fill(screening_sheet_path(dry_dir, 1, "_DRY_RUN"), fake, stats::setNames(rep_len(c("rule2", "rule3", "rule4"), length(fake)), fake))
run05()
fill(screening_sheet_path(dry_dir, 2, "_DRY_RUN"), character(), character())
run05()

log <- readr::read_csv(file.path(dry_dir, "exclusions_log_DRY_RUN.csv"), col_types = readr::cols(.default = "c"))
screened <- readRDS(file.path(dry_dir, "study_sample_screened_DRY_RUN.rds"))
label_of <- function(id) paste(cfg$guaranteed_labels[unlist(fr[fr$question_id == id, cols]) == 1L], collapse = "; ")
cat("\nTEST exclusions (fake pattern):\n")
print(tibble::tibble(removed = log$question_id, reason = log$reason, labels = purrr::map_chr(log$question_id, label_of),
  rule = log$rules_triggered, queue = log$replacement_queue, replaced_by = log$replaced_by,
  replacement_labels = purrr::map_chr(log$replaced_by, label_of)), width = Inf)
cat("\nScreened sample:", nrow(screened), "rows; guaranteed label counts:\n")
print(colSums(as.matrix(screened[cols])))
cat("Outputs (TEST, not kept):", dry_dir, "\n")
