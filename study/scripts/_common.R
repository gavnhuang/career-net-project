# Sourced by every numbered script: packages, RNG, functions, config, run id.
# Usage: Rscript study/scripts/NN_name.R [path/to/config.yml]

if (!dir.exists("study/R")) stop("Run this script from the project root (04 R Project/)", call. = FALSE)

suppressPackageStartupMessages({
  library(readr); library(dplyr); library(tidyr); library(stringr); library(purrr)
  library(lubridate); library(yaml); library(xml2); library(digest); library(glue)
})
RNGkind("Mersenne-Twister", "Inversion", "Rejection")
for (f in sort(list.files("study/R", pattern = "\\.R$", full.names = TRUE))) source(f)

start_run <- function(script_no) {
  args <- commandArgs(trailingOnly = TRUE)
  args <- args[!startsWith(args, "--")]     # --name=value options are read by the script itself
  config_path <- if (length(args)) args[1] else "study/config/study_config.yml"
  cfg <- load_config(config_path)
  for (d in cfg$paths) dir.create(d, recursive = TRUE, showWarnings = FALSE)
  list(cfg = cfg, config_path = config_path,
       run_id = paste0(format(Sys.time(), "%Y%m%d-%H%M%S"), "-", script_no))
}

# Writes <dir>/<name>.csv (UTF-8, missing as "") and <dir>/<name>.rds; returns both paths.
write_outputs <- function(df, dir, name, rds = TRUE) {
  csv <- file.path(dir, paste0(name, ".csv"))
  readr::write_csv(df, csv, na = "")
  if (!rds) return(csv)
  rds_path <- file.path(dir, paste0(name, ".rds"))
  saveRDS(df, rds_path)
  c(csv, rds_path)
}

# Value of a --name=value command-line option, or NULL.
cli_option <- function(name) {
  args <- commandArgs(trailingOnly = TRUE)
  hit <- args[startsWith(args, paste0("--", name, "="))]
  if (length(hit)) sub(paste0("^--", name, "="), "", hit[1]) else NULL
}

read_ids <- function(path) {
  x <- readr::read_csv(path, col_types = readr::cols(.default = readr::col_character()), na = character(), progress = FALSE)
  if (!"question_id" %in% names(x)) stop(path, " has no question_id column", call. = FALSE)
  normalize_missing(x$question_id) |> stats::na.omit() |> as.character()
}
