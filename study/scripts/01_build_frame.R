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
  write_outputs(frame$attrition, cfg$paths$frame_dir, "attrition", rds = FALSE),
  write_outputs(frame$display_edits, cfg$paths$frame_dir, "display_edits", rds = FALSE),
  write_outputs(frame$question_display_edits, cfg$paths$frame_dir, "question_display_edits", rds = FALSE)
)

full_prompt <- is_platform_prompt(raw$question_title, raw$question_body, cfg$filters$platform_prompt_pattern)
fq <- frame$frame_questions
fa <- frame$frame_answers
label_n <- purrr::map_int(label_column_names(cfg$scenario_labels), ~ sum(fq[[.x]]))
rule_threshold <- (cfg$guaranteed_rule_multiplier %||% 10) * cfg$floor
by_rule <- cfg$scenario_labels[label_n >= rule_threshold]
n_open <- sum(frame$display_edits$part == "opening")
n_close <- sum(frame$display_edits$part == "closing")

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
  glue("Guaranteed-label rule: labels with at least {rule_threshold} eligible questions (10 x floor). ",
       "Labels meeting it now: {length(by_rule)}; config guaranteed_labels: {length(cfg$guaranteed_labels)}; ",
       "same set: {if (setequal(by_rule, cfg$guaranteed_labels)) 'yes' else '**NO**'}. ",
       "Largest label not guaranteed: {cfg$scenario_labels[!cfg$scenario_labels %in% cfg$guaranteed_labels][which.max(label_n[!cfg$scenario_labels %in% cfg$guaranteed_labels])]} ",
       "({max(label_n[!cfg$scenario_labels %in% cfg$guaranteed_labels])} questions)."), "",
  "## Exclusion rule 1: platform-written prompts", "",
  glue("Pattern (case-insensitive, title + body with HTML stripped): `{cfg$filters$platform_prompt_pattern}`"), "",
  glue("- Matches in the full release: {n_distinct(raw$question_id[full_prompt])} questions"),
  glue("- Removed at step e (still present after steps a-d): ",
       "{with(frame$attrition, n_questions[step == 'd'] - n_questions[step == 'e'])} questions. ",
       "The date window already removes all of them; the rule stays as a safeguard."), "",
  "## Display text", "",
  glue("- Answers with an opening salutation removed: {n_open} of {nrow(fa)}"),
  glue("- Answers with a closing sign-off or signature removed: {n_close} of {nrow(fa)}"),
  glue("- Answers with either: {n_distinct(frame$display_edits$answer_id)} of {nrow(fa)}"),
  glue("- Answers with a list (has_list): {sum(fa$has_list)} of {nrow(fa)} (lists are not changed)"),
  glue("- Questions with hashtags removed: {nrow(frame$question_display_edits)} of {nrow(fq)}; ",
       "{sum(fq$question_text_display == '' | is.na(fq$question_text_display))} have an empty body after removal (title only)"),
  "- Every removal is logged in `display_edits.csv` (answers) and `question_display_edits.csv` (questions).", "",
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
