# Step 5: apply the screening (exclusion rules 2-4) and seeded replacement. One round per call.
# Replays every completed sheet from round 1 (see replay_screening()). If the latest round
# excluded anything, writes the next round's sheet; once a round has no exclusions, writes the
# screened sample. Dry-run inputs give dry-run outputs (same guard as 04).
source("study/scripts/_common.R")
run <- start_run("05")
cfg <- run$cfg

plan <- sample_output_plan(cfg)
run_id <- paste0(run$run_id, if (plan$dry_run) "-DRY_RUN")
in_dir <- function(name, ext) file.path(plan$dir, paste0(name, plan$tag, ".", ext))

sample_path <- in_dir("study_sample", "rds")
queues_path <- in_dir("replacement_queues", "rds")
probs_path <- in_dir("inclusion_probs", "rds")
if (!file.exists(sample_path)) stop("No study sample in ", plan$dir, "; run 04 first", call. = FALSE)
fq_path <- file.path(cfg$paths$frame_dir, "frame_questions.rds")
fa_path <- file.path(cfg$paths$frame_dir, "frame_answers.rds")
fr_path <- file.path(cfg$paths$reserved_dir, "frame_remaining.rds")
set_paths <- stats::setNames(file.path(cfg$paths$reserved_dir, paste0(purrr::map_chr(cfg$reserved_sets, "name"), ".rds")),
                             purrr::map_chr(cfg$reserved_sets, "name"))

sample <- readRDS(sample_path)
queues <- readRDS(queues_path)
probs <- readRDS(probs_path)
fa <- readRDS(fa_path)
fr <- readRDS(fr_path)
reserved_ids <- unlist(purrr::map(set_paths, ~ readRDS(.x)$question_id), use.names = FALSE)
anchor_ids <- read_ids(cfg$inputs$anchor_exclusions)

sheet_paths <- find_screening_sheets(plan$dir, plan$tag)
if (!length(sheet_paths)) stop("No screening sheet in ", plan$dir, "; run 04 first", call. = FALSE)
sheets <- purrr::map(sheet_paths, read_screening_sheet)
res <- replay_screening(sample[c("question_id", "draw_order", "selection_stage", "floor_label")], sheets, queues, fr,
                        cfg$guaranteed_labels, cfg$floor)
k <- res$rounds
n_ex_last <- sum(res$log$round == k)

if (!res$finished) {
  next_sheet <- make_screening_sheet(fr[match(res$next_ids, fr$question_id), ])
  next_path <- screening_sheet_path(plan$dir, k + 1, plan$tag)
  readr::write_csv(next_sheet, next_path, na = "")
  outputs <- c(next_sheet = next_path)
  status <- glue("Round {k}: {n_ex_last} exclusion(s), each replaced. Wrote the round {k + 1} sheet ",
                 "({nrow(next_sheet)} question(s)) to {next_path}. Fill it in and run 05 again.")
  screened <- NULL
} else {
  final_path <- in_dir("study_sample_screened", "rds")
  if (!plan$dry_run && file.exists(final_path)) stop("A screened study sample already exists. Refusing to overwrite it.", call. = FALSE)
  answers <- pick_human_answer(fa, derive_seed(cfg$master_seed, "human_answer"))
  selection <- res$selection |>
    mutate(set = "study", planned_version = NA_character_,
           inclusion_prob = probs$inclusion_prob[match(question_id, probs$question_id)],
           weight = inclusion_weights(inclusion_prob))
  screened <- assemble_sample(selection, fr, answers, sample$seed[1], run_id, cfg$frame_version, cfg$target_words_tolerance)
  screened <- screened |>
    mutate(screening_round = res$selection$screening_round, replaced_question_id = res$selection$replaced_question_id,
           .after = frame_version)
  checks <- check_sample(screened, fr, fa, anchor_ids, reserved_ids, cfg$guaranteed_labels, cfg$floor, cfg$study_n)
  checks <- bind_rows(checks, tibble(check = "no excluded question remains", passed = !any(screened$question_id %in% res$log$question_id),
                                     detail = ""))
  stop_on_failed_checks(checks)
  outputs <- c(
    write_outputs(screened, plan$dir, paste0("study_sample_screened", plan$tag)),
    write_outputs(res$log, plan$dir, paste0("exclusions_log", plan$tag), rds = FALSE),
    write_outputs(screened[GENERATION_COLUMNS], plan$dir, paste0("sample_for_generation_screened", plan$tag), rds = FALSE)
  )
  status <- glue("Round {k} had no exclusions: screening is complete after {k} round(s) and {nrow(res$log)} replacement(s). ",
                 "Wrote the screened sample to {plan$dir}.")
}

banner <- if (plan$dry_run) c("> **DRY RUN. NOT THE STUDY SAMPLE.** Screening of a dry-run draw.", "") else character()
report_path <- file.path(cfg$paths$reports_dir, glue("05_apply_screening{plan$tag}_{run_id}.md"))
writeLines(c(
  glue("# Screening and replacement, round {k}{if (plan$dry_run) ' (DRY RUN)' else ''}"), "", banner,
  glue("Run `{run_id}` · sheets read: {paste(basename(sheet_paths), collapse = ', ')}"), "",
  status, "",
  "## Rules applied to drawn questions (question text only)", "",
  paste0("- **", names(SCREENING_RULES), "**: ", SCREENING_RULES), "",
  "Replacement: in draw order, an excluded question whose removal drops a guaranteed label below the floor is replaced ",
  "from that label's queue (rarest label first); any other from the general queue. Questions already selected or excluded are skipped.", "",
  "## Exclusions so far", "",
  md_table(res$log), "",
  if (!is.null(screened)) c(
    "## Screened sample", "",
    md_table(count(screened, screening_round, selection_stage)), "",
    "### Scenario label coverage (frame = frame_remaining)", "",
    md_table(coverage_table(fr, screened, cfg$scenario_labels, cfg$guaranteed_labels, cfg$floor)), "",
    "### Checks", "", md_table(mutate(checks, passed = ifelse(passed, "PASS", "FAIL"))), "",
    "**Inclusion probabilities are those of the unscreened procedure (from 04). Screening and replacement are not reflected in them; ",
    "weights are 1 / inclusion_prob renormalized to mean 1 over the screened sample.**", "")
), report_path)

write_run_log(file.path(cfg$paths$logs_dir, glue("{run_id}.yml")), run_id, "05_apply_screening.R",
              seeds = list(seed_base = plan$seed_base, seed_base_rule = as.character(plan$seed_rule)),
              config = cfg,
              input_files = c(config = run$config_path, study_sample = sample_path, replacement_queues = queues_path,
                              inclusion_probs = probs_path, frame_remaining = fr_path, frame_answers = fa_path,
                              stats::setNames(sheet_paths, basename(sheet_paths))),
              frame_version = cfg$frame_version, outputs = c(outputs, report = report_path),
              extra = list(dry_run = plan$dry_run, round = k, finished = res$finished,
                           exclusions = purrr::transpose(as.list(res$log))))

message(status, " Report: ", report_path)
