# Step 1: eligibility frame (one row per question) and its eligible answers.
source("study/scripts/_common.R")
run <- start_run("01")
cfg <- run$cfg

raw <- read_careernet(cfg$inputs$primary, required = CAREERNET_COLUMNS)
anchor_ids <- read_ids(cfg$inputs$anchor_exclusions)
exclusion_ids <- read_ids(cfg$inputs$manual_exclusions)

frame <- build_frame(raw, cfg$filters, anchor_ids, exclusion_ids, cfg$scenario_labels, cfg$guaranteed_labels,
                     expected_attrition = cfg$expected_attrition)

outputs <- c(
  write_outputs(frame$frame_questions, cfg$paths$frame_dir, "frame_questions"),
  write_outputs(frame$frame_answers, cfg$paths$frame_dir, "frame_answers"),
  write_outputs(frame$attrition, cfg$paths$frame_dir, "attrition", rds = FALSE)
)

report_path <- file.path(cfg$paths$reports_dir, glue("01_build_frame_{run$run_id}.md"))
writeLines(c(
  glue("# Eligibility frame ({cfg$frame_version})"), "", glue("Run `{run$run_id}`"), "",
  "## Counts at each stage", "",
  "Filters are applied to answers, cumulatively; counts are unique questions (and answers) still eligible.", "",
  md_table(frame$attrition), "",
  glue("Anchor check ids: {length(anchor_ids)} ({sum(anchor_ids %in% raw$question_id)} found in the release). ",
       "Manual exclusions: {length(exclusion_ids)}."), "",
  glue("Frame: {nrow(frame$frame_questions)} questions, {nrow(frame$frame_answers)} eligible answers ",
       "(median {median(frame$frame_questions$n_eligible_answers)} per question)."), "",
  "## Scenario label coverage in the frame", "",
  md_table(coverage_table(frame$frame_questions, NULL, cfg$scenario_labels, cfg$guaranteed_labels)), "",
  distribution_sections(frame$frame_questions, frame$frame_answers)
), report_path)

write_run_log(file.path(cfg$paths$logs_dir, glue("{run$run_id}.yml")), run$run_id, "01_build_frame.R",
              seeds = list(master_seed = cfg$master_seed), config = cfg,
              input_files = c(config = run$config_path, primary = cfg$inputs$primary,
                              anchor_exclusions = cfg$inputs$anchor_exclusions,
                              manual_exclusions = cfg$inputs$manual_exclusions),
              frame_version = cfg$frame_version, outputs = c(outputs, report = report_path),
              extra = list(attrition = purrr::transpose(as.list(frame$attrition))))

message("Frame: ", nrow(frame$frame_questions), " questions. Report: ", report_path)
