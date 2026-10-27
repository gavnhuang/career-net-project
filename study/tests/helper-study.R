# Loaded once by testthat before the test files. Run from the project root with:
#   Rscript study/scripts/run_tests.R

suppressPackageStartupMessages({
  library(readr); library(dplyr); library(tidyr); library(stringr); library(purrr)
  library(lubridate); library(yaml); library(xml2); library(digest); library(glue)
})

ROOT <- normalizePath(file.path(testthat::test_path(), "..", ".."))
for (f in sort(list.files(file.path(ROOT, "study/R"), pattern = "\\.R$", full.names = TRUE))) source(f)

root_path <- function(p) file.path(ROOT, p)
CFG <- load_config(root_path("study/config/study_config.yml"))

skip_if_no_data <- function() {
  testthat::skip_if_not(file.exists(root_path(CFG$inputs$primary)), "CareerNet v1.1 not available")
}

# Real-data fixtures, built once per test run.
.fixtures <- new.env()

real_raw <- function() {
  .fixtures$raw <- .fixtures$raw %||% read_careernet(root_path(CFG$inputs$primary), required = CAREERNET_COLUMNS)
  .fixtures$raw
}

anchor_ids <- function() {
  readr::read_csv(root_path(CFG$inputs$anchor_exclusions), col_types = readr::cols(.default = "c"))$question_id
}

real_frame <- function() {
  .fixtures$frame <- .fixtures$frame %||%
    build_frame(real_raw(), CFG$filters, anchor_ids(), character(), CFG$scenario_labels, CFG$guaranteed_labels,
                expected_attrition = CFG$expected_attrition, closing_pleasantries = CFG$closing_pleasantries)
  .fixtures$frame
}

real_reserved <- function() {
  .fixtures$reserved <- .fixtures$reserved %||%
    reserve_sets(real_frame()$frame_questions$question_id, CFG$reserved_sets, derive_seed(CFG$master_seed, "reserve_sets"))
  .fixtures$reserved
}

real_remaining <- function() {
  fq <- real_frame()$frame_questions
  fq[match(real_reserved()$remaining, fq$question_id), ]
}

# A tiny synthetic frame with the label columns the draw needs.
synthetic_frame <- function(n_per_label, labels = names(n_per_label), extra = 20) {
  rows <- purrr::imap(n_per_label, function(k, l) rep(l, k))
  labs <- c(unlist(rows, use.names = FALSE), rep(NA_character_, extra))
  ind <- scenario_label_indicators(parse_scenario_labels(labs), labels)
  dplyr::bind_cols(tibble::tibble(question_id = as.character(seq_along(labs))), ind)
}
