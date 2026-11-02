# Generate AI answers for one question set (B02).
#
# From the project root (04 R Project/):
#   Rscript study/scripts/07_generate_answers.R --set gold_candidates
#   Rscript study/scripts/07_generate_answers.R --set gold_candidates --limit 3
#   Rscript study/scripts/07_generate_answers.R --set gold_candidates --preview
#   Rscript study/scripts/07_generate_answers.R --input path/to/file.csv --name my_set
#   Rscript study/scripts/07_generate_answers.R --set gold_candidates --resume 20261102-101500-07
#
# --set     a reserved set in study/data/02_reserved (warmups, calibration, gold_candidates, spare)
#           or "study_sample" for study/data/03_sample/study_sample.csv (after the OSF draw)
# --input   any CSV with question_id, question_title, question_text_display, target_words
# --limit   only the first N questions (for a test run)
# --preview no API calls: writes the exact instructions and input for each question so they can be read
# --resume  continue a stopped run; questions already in that run's answers file are skipped
#
# Needs OPENAI_API_KEY in ~/.Renviron (never in this repository).
# Writes to study/data/04_generated/<set>/: answers_<run>.csv, raw_<run>.jsonl (every attempt,
# including rejected ones and the full API response), and a report in study/reports/.
# Never overwrites an earlier run.

source("study/scripts/_common.R")
run <- start_run("07")
cfg <- run$cfg
g <- generation_settings(cfg)
verify_generation_frozen(g)

set_name <- cli_option("set")
input_path <- cli_option("input")
limit <- cli_option("limit")
resume <- cli_option("resume")
preview <- "--preview" %in% commandArgs(trailingOnly = TRUE)

if (!is.null(set_name)) {
  input_path <- if (identical(set_name, "study_sample")) file.path(cfg$paths$sample_dir, "study_sample.csv")
                else file.path(cfg$paths$reserved_dir, paste0(set_name, ".csv"))
} else if (!is.null(input_path)) {
  set_name <- cli_option("name") %||% tools::file_path_sans_ext(basename(input_path))
} else stop("Give --set <name> or --input <file.csv>", call. = FALSE)
if (!file.exists(input_path)) stop("Input not found: ", input_path, call. = FALSE)
if (identical(set_name, "study_sample") && !is_preregistered(cfg)) {
  stop("The study sample is generated only after the OSF registration is posted.", call. = FALSE)
}

qs <- readr::read_csv(input_path, col_types = readr::cols(.default = "c"), na = character(), progress = FALSE)
need <- c("question_id", "question_title", "question_text_display", "target_words")
miss <- setdiff(need, names(qs))
if (length(miss)) stop("Input is missing column(s): ", paste(miss, collapse = ", "), call. = FALSE)
if (anyNA(suppressWarnings(as.integer(qs$target_words)))) stop("target_words must be whole numbers", call. = FALSE)
if (!is.null(limit)) qs <- utils::head(qs, as.integer(limit))

out_dir <- file.path(g$output_dir, set_name)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
run_id <- resume %||% run$run_id
answers_csv <- file.path(out_dir, paste0("answers_", run_id, ".csv"))
raw_jsonl <- file.path(out_dir, paste0("raw_", run_id, ".jsonl"))
if (is.null(resume) && (file.exists(answers_csv) || file.exists(raw_jsonl))) stop("Output for run ", run_id, " already exists", call. = FALSE)
if (!is.null(resume) && !file.exists(answers_csv)) stop("Nothing to resume: ", answers_csv, " not found", call. = FALSE)

# ---- Preview: no API calls ---------------------------------------------------
if (preview) {
  prev <- file.path(out_dir, paste0("preview_", run$run_id, ".md"))
  txt <- c(paste0("# Generation preview: ", set_name), "",
           paste0("Model `", g$model, "`, reasoning `", g$reasoning_effort, "`, prompt md5 `", g$prompt_md5,
                  "`, length request factor ", g$length_request_factor), "")
  for (i in seq_len(nrow(qs))) {
    q <- qs[i, ]
    n <- request_lengths(q$target_words, g$length_request_factor, g$length_tolerance)
    b <- length_bounds(as.integer(q$target_words), g$length_tolerance)
    txt <- c(txt, paste0("## ", q$question_id, " (target ", q$target_words, " words, window ", b[["min"]], "-", b[["max"]],
                         "; asks for ", n[["request"]], ", at most ", n[["max"]], ")"), "",
             "**Instructions**", "", build_instructions(g$prompt_template, q$target_words, g$length_request_factor, g$length_tolerance), "",
             "**Input**", "", build_input(q$question_title, q$question_text_display), "")
  }
  writeLines(txt, prev, useBytes = TRUE)
  message("Preview written: ", prev, " (", nrow(qs), " questions, no API calls)")
  quit(save = "no")
}

if (!nzchar(Sys.getenv("OPENAI_API_KEY"))) {
  stop("OPENAI_API_KEY is not set. Add a line OPENAI_API_KEY=sk-... to ~/.Renviron and restart R.", call. = FALSE)
}

done <- read_done_ids(answers_csv)
todo <- qs[!qs$question_id %in% done, ]
message(set_name, ": ", nrow(todo), " to generate (", length(done), " already done), model ", g$model)

for (i in seq_len(nrow(todo))) {
  q <- todo[i, ]
  r <- generate_one(q, g)
  append_jsonl(r$attempts, raw_jsonl)
  readr::write_csv(r$row, answers_csv, append = file.exists(answers_csv), na = "")
  message(sprintf("  [%d/%d] %s: %s after %d attempt(s)%s", i, nrow(todo), q$question_id, r$row$status,
                  r$row$attempts, if (r$row$status != "failed") paste0(", ", r$row$word_count, " words") else ""))
  Sys.sleep(g$pause_seconds)
}

# ---- Report ------------------------------------------------------------------
ans <- readr::read_csv(answers_csv, col_types = readr::cols(.default = "c"), progress = FALSE)
reasons <- unlist(strsplit(ans$rejection_reasons, ";"))
reasons <- reasons[reasons != "ok"]
report <- file.path(cfg$paths$reports_dir, paste0("07_generate_", set_name, "_", run_id, ".md"))
writeLines(c(
  paste0("# AI answer generation: ", set_name), "",
  paste0("- Run: `", run_id, "`"),
  paste0("- Model requested: `", g$model, "`; returned: `", paste(unique(stats::na.omit(ans$model_returned)), collapse = ", "), "`"),
  paste0("- Reasoning effort: `", g$reasoning_effort, "`"),
  paste0("- Length request factor (D103): ", g$length_request_factor),
  paste0("- Prompt: `", g$prompt_file, "` (md5 `", g$prompt_md5, "`); frozen: ", g$generation_frozen),
  paste0("- Questions: ", nrow(ans), "; within the length window ", sum(ans$status == "accepted"),
         "; closest-length kept (D101) ", sum(ans$status == "closest_length"), "; failed ", sum(ans$status == "failed")),
  paste0("- Accepted on first try: ", sum(ans$status == "accepted" & ans$attempts == "1")),
  paste0("- URLs removed from: ", sum(ans$urls_removed %in% "TRUE"), " answers"),
  paste0("- Typography normalized (D102) in: ", sum(ans$typography_changed %in% "TRUE"), " answers"), "",
  "## Rejected attempts by reason", "",
  if (length(reasons)) paste0("- ", names(table(reasons)), ": ", as.integer(table(reasons))) else "- none", "",
  "## Kept at the closest length (D101: outside the length window after every try)", "",
  if (any(ans$status == "closest_length")) paste0("- ", ans$question_id[ans$status == "closest_length"], ": ",
    ans$word_count[ans$status == "closest_length"], " words (window ", ans$target_min_words[ans$status == "closest_length"],
    "-", ans$target_max_words[ans$status == "closest_length"], ")") else "- none", "",
  "## Failed (no attempt passed the format checks; decide by hand and log it)", "",
  if (any(ans$status == "failed")) paste0("- ", ans$question_id[ans$status == "failed"]) else "- none"
), report)

write_run_log(file.path(cfg$paths$logs_dir, paste0(run_id, ".yml")), run_id, "07_generate_answers.R",
              seeds = list(note = "no randomness in this script; the API is not seeded"), config = cfg[c("generation")],
              input_files = c(input_path, g$prompt_file), frame_version = cfg$frame_version,
              outputs = c(answers_csv, raw_jsonl, report),
              extra = list(set = set_name, model = g$model, prompt_md5 = g$prompt_md5))
message("Done. Answers: ", answers_csv, "\nReport: ", report)
