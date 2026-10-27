# Step 4: study draw with a coverage floor, inclusion probabilities, one human answer per question,
# plus the round-1 screening sheet and the replacement queues for 05.
# Runs as a DRY RUN unless the config says the OSF pre-registration is posted (see sample_output_plan()).
# The real draw's seeds derive from the OSF DOI; dry runs use master_seed.
source("study/scripts/_common.R")
run <- start_run("04")
cfg <- run$cfg

plan <- sample_output_plan(cfg)
verify_frozen(cfg)
if (!plan$dry_run && !isTRUE(cfg$frozen)) stop("A real run needs the frozen frame (frozen: true with checksums).", call. = FALSE)
run_id <- paste0(run$run_id, if (plan$dry_run) "-DRY_RUN")
dir.create(plan$dir, recursive = TRUE, showWarnings = FALSE)
if (!plan$dry_run && file.exists(file.path(plan$dir, "study_sample.rds"))) {
  stop("A real study sample already exists in ", plan$dir, ". Refusing to overwrite it.", call. = FALSE)
}
if (plan$dry_run) {
  message("DRY RUN: pre-registration not marked as posted. Writing to ", plan$dir)
  # Screening files from an earlier dry draw no longer match this draw.
  stale <- list.files(plan$dir, pattern = "^(screening_sheet_round[0-9]+|study_sample_screened|exclusions_log|sample_for_generation_screened).*_DRY_RUN\\.(csv|rds)$",
                      full.names = TRUE)
  invisible(file.remove(stale))
}

fq_path <- file.path(cfg$paths$frame_dir, "frame_questions.rds")
fa_path <- file.path(cfg$paths$frame_dir, "frame_answers.rds")
fr_path <- file.path(cfg$paths$reserved_dir, "frame_remaining.rds")
set_paths <- stats::setNames(file.path(cfg$paths$reserved_dir, paste0(purrr::map_chr(cfg$reserved_sets, "name"), ".rds")),
                             purrr::map_chr(cfg$reserved_sets, "name"))
fq <- readRDS(fq_path)
fa <- readRDS(fa_path)
fr <- readRDS(fr_path)
reserved_ids <- unlist(purrr::map(set_paths, ~ readRDS(.x)$question_id), use.names = FALSE)
anchor_ids <- read_ids(cfg$inputs$anchor_exclusions)
# Reserved items excluded by screening (D96) leave the frame for good.
reserved_log_path <- file.path(cfg$paths$reserved_dir, "reserved_exclusions_log.csv")
reserved_excluded <- if (file.exists(reserved_log_path)) read_ids(reserved_log_path) else character()
parts <- c(fr$question_id, reserved_ids, reserved_excluded)
if (!setequal(parts, fq$question_id) || anyDuplicated(parts)) {
  stop("frame_remaining + reserved sets + screened-out reserved items do not partition the frame; rerun 01, 03 and 03b", call. = FALSE)
}

n <- cfg$study_n
draw_seed <- derive_seed(plan$seed_base, plan$draw_stage)
answer_seed <- derive_seed(cfg$master_seed, "human_answer")

draw <- draw_coverage_floor(fr, cfg$guaranteed_labels, cfg$floor, n, draw_seed)
incl <- estimate_inclusion_probs(fr, cfg$guaranteed_labels, cfg$floor, n, cfg$inclusion_reps, plan$seed_base)
answers <- pick_human_answer(fa, answer_seed)

selection <- draw |>
  mutate(set = "study", inclusion_prob = incl$probs$inclusion_prob[match(question_id, incl$probs$question_id)],
         weight = inclusion_weights(inclusion_prob), planned_version = NA_character_)
sample <- assemble_sample(selection, fr, answers, draw_seed, run_id, cfg$frame_version, cfg$target_words_tolerance)

checks <- check_sample(sample, fr, fa, anchor_ids, reserved_ids, cfg$guaranteed_labels, cfg$floor, n,
                       check_floor_block = TRUE)
stop_on_failed_checks(checks)
n_floor_block <- floor_block_size(sample)

queues <- make_replacement_queues(fr, sample$question_id, cfg$guaranteed_labels, plan$seed_base)
sheet <- make_screening_sheet(sample)
if (any(str_detect(names(sheet), "answer|careernet|reasoning"))) stop("Answer information in the screening sheet", call. = FALSE)

frame_probs <- incl$probs |> mutate(raw_weight = 1 / inclusion_prob, in_sample = question_id %in% sample$question_id)
outputs <- c(
  write_outputs(sample, plan$dir, paste0("study_sample", plan$tag)),
  write_outputs(sample[GENERATION_COLUMNS], plan$dir, paste0("sample_for_generation", plan$tag), rds = FALSE),
  write_outputs(frame_probs, plan$dir, paste0("inclusion_probs", plan$tag)),
  write_outputs(queues, plan$dir, paste0("replacement_queues", plan$tag)),
  write_outputs(sheet, plan$dir, paste0("screening_sheet_round1", plan$tag), rds = FALSE)
)

# ---- Report ------------------------------------------------------------------
avail <- prepare_floor_design(fr, cfg$guaranteed_labels, cfg$floor, n)
order_tab <- tibble(order = seq_along(avail$label_order), label = cfg$guaranteed_labels[avail$label_order],
                    available_in_frame_remaining = unname(avail$available[avail$label_order]),
                    floor_slots_this_draw = purrr::map_int(label, ~ sum(draw$floor_label %in% .x)))
fs <- incl$floor_slots
present <- cfg$scenario_labels[purrr::map_int(label_column_names(cfg$scenario_labels), ~ sum(sample[[.x]])) > 0]
labels_present <- length(present)
rule_threshold <- (cfg$guaranteed_rule_multiplier %||% 10) * cfg$floor
not_guaranteed <- tibble(label = setdiff(cfg$scenario_labels, cfg$guaranteed_labels)) |>
  mutate(n = purrr::map_int(label_column_names(label), ~ sum(fq[[.x]]))) |> arrange(desc(n))
sample_edits <- readr::read_csv(file.path(cfg$paths$frame_dir, "display_edits.csv"), col_types = "ccc") |>
  filter(answer_id %in% sample$answer_id)
banner <- if (plan$dry_run) c(
  "> **DRY RUN. NOT THE STUDY SAMPLE.** The OSF pre-registration is not marked as posted",
  "> (`preregistration_posted` / `osf_url` in the config). This draw uses a separate dry-run seed,",
  "> so it does not preview the real sample. Do not use these questions for anything.", "") else
  c(glue("Pre-registration: {cfg$osf_url}"), "")

report_path <- file.path(cfg$paths$reports_dir, glue("04_draw_study_sample{plan$tag}_{run_id}.md"))
writeLines(c(
  glue("# Study sample{if (plan$dry_run) ' (DRY RUN)' else ''}: n = {n}, floor = {cfg$floor}"), "", banner,
  glue("Run `{run_id}` · frame {cfg$frame_version}"), "",
  glue("- Seed base: {plan$seed_base} = {plan$seed_rule}"),
  glue("- Draw seed: {draw_seed} = derive_seed(seed base, \"{plan$draw_stage}\")"),
  "- Inclusion reps and replacement queues derive from the same seed base.",
  glue("- Frame frozen: {if (isTRUE(cfg$frozen)) paste0('yes (', length(unlist(cfg$frozen_checksums)), ' checksums verified)') else 'no'}"), "",
  "## Counts at each stage", "",
  md_table(tibble(stage = c("Frame (01)", "Reserved sets (03, after 03b screening)", "Reserved items screened out (03b)",
                            "frame_remaining (sampling frame)",
                            "Selected at the floor stage (draw order 1 to the floor block size)",
                            "Selected by random fill", "Study sample"),
                  questions = c(nrow(fq), length(reserved_ids), length(reserved_excluded), nrow(fr), sum(draw$selection_stage == "floor"),
                                sum(draw$selection_stage == "random_fill"), nrow(sample)))), "",
  glue("**Floor block: {n_floor_block} floor-stage questions** (draw order 1-{n_floor_block}); they alone meet every floor. ",
       "Screening replacements keep the excluded question's position."), "",
  "## Floor stage", "",
  "Labels are processed rarest first (count in frame_remaining).", "",
  md_table(order_tab), "",
  glue("Floor slots used across {format(incl$reps, big.mark = ',')} simulated draws: mean {sprintf('%.2f', mean(fs))}, ",
       "SD {sprintf('%.2f', sd(fs))}, range {min(fs)}-{max(fs)}. This draw: {sum(draw$selection_stage == 'floor')}."), "",
  "## Scenario label coverage", "",
  "frame = frame_remaining. A question counts toward every label it carries.", "",
  md_table(coverage_table(fr, sample, cfg$scenario_labels, cfg$guaranteed_labels, cfg$floor)), "",
  glue("Labels present in the sample: {labels_present} of {length(cfg$scenario_labels)} ",
       "({sum(cfg$guaranteed_labels %in% present)} of {length(cfg$guaranteed_labels)} guaranteed, ",
       "{labels_present - sum(cfg$guaranteed_labels %in% present)} not guaranteed)."), "",
  glue("Guaranteed labels are those with at least {rule_threshold} eligible questions (10 x floor) in the frame. ",
       "Not guaranteed (frame questions): {paste0(not_guaranteed$label, ' (', not_guaranteed$n, ')', collapse = ', ')}."), "",
  "## Inclusion probabilities and weights", "",
  glue("Estimated from {format(incl$reps, big.mark = ',')} re-runs of the draw ({incl$seed_rule}). ",
       "weight = 1 / inclusion_prob, normalized to mean 1 over the sample."), "",
  md_table(tibble(quantity = c("inclusion_prob, frame_remaining", "inclusion_prob, sample", "weight, sample"),
                  min = sprintf("%.4f", c(min(frame_probs$inclusion_prob), min(sample$inclusion_prob), min(sample$weight))),
                  median = sprintf("%.4f", c(median(frame_probs$inclusion_prob), median(sample$inclusion_prob), median(sample$weight))),
                  max = sprintf("%.4f", c(max(frame_probs$inclusion_prob), max(sample$inclusion_prob), max(sample$weight))))), "",
  glue("Simple random sampling would give every question {sprintf('%.4f', n / nrow(fr))}. ",
       "Questions never selected in any simulated draw: {sum(frame_probs$n_selected == 0)}."), "",
  "## Checks", "", md_table(mutate(checks, passed = ifelse(passed, "PASS", "FAIL"))), "",
  "## Human answers", "",
  glue("Display length: median {median(sample$answer_word_count_display)} words (range {min(sample$answer_word_count_display)}-{max(sample$answer_word_count_display)}); ",
       "targets for generation are display length ± {cfg$target_words_tolerance * 100}%. ",
       "Questions with one eligible answer: {sum(sample$n_eligible_answers == 1)}; with several: {sum(sample$n_eligible_answers > 1)}."), "",
  glue("- Opening salutation removed: {sum(sample_edits$part == 'opening')} of {nrow(sample)}"),
  glue("- Closing sign-off, signature or pleasantry removed: {sum(sample_edits$part == 'closing')} of {nrow(sample)}"),
  glue("- List markers removed (items kept on their own lines): {sum(sample_edits$part == 'list_marker')} of {nrow(sample)}"),
  glue("- Any display edit: {n_distinct(sample_edits$answer_id)} of {nrow(sample)}"),
  glue("- has_list (raw text has a list): {sum(sample$has_list)} of {nrow(sample)}"),
  glue("- Question body empty after hashtag removal (title only): {sum(sample$question_text_display == '' | is.na(sample$question_text_display))}"), "",
  "## Screening", "",
  glue("`screening_sheet_round1{plan$tag}.csv` lists the {nrow(sheet)} drawn questions (question text only, in question_id order). ",
       "Fill rule2-rule4, excluded, screener and notes, then run `05_apply_screening.R`. ",
       "Replacement queues: general ({sum(queues$queue == 'general')} questions) and one per guaranteed label."), "",
  distribution_sections(fr, fa[fa$question_id %in% fr$question_id, ], sample)
), report_path)

write_run_log(file.path(cfg$paths$logs_dir, glue("{run_id}.yml")), run_id, "04_draw_study_sample.R",
              seeds = list(master_seed = cfg$master_seed, seed_base = plan$seed_base, seed_base_rule = as.character(plan$seed_rule),
                           osf_doi_raw = plan$doi_raw, osf_doi_normalized = plan$doi_normalized, study_draw = draw_seed, study_draw_stage = plan$draw_stage,
                           human_answer = answer_seed, inclusion_reps = as.character(incl$seed_rule),
                           replacement_queues = "derive_seed(seed_base, \"replacement_queue_general\" | \"replacement_queue_<label>\")"),
              config = cfg,
              input_files = c(config = run$config_path, frame_questions = fq_path, frame_answers = fa_path,
                              frame_remaining = fr_path, set_paths, anchor_exclusions = cfg$inputs$anchor_exclusions),
              frame_version = cfg$frame_version, outputs = c(outputs, report = report_path),
              extra = list(dry_run = plan$dry_run, floor_slots_mean = mean(fs), n_floor_block = n_floor_block,
                           question_ids = sample$question_id))

message(if (plan$dry_run) "DRY RUN " else "", "study sample: ", nrow(sample), " questions; floor-stage questions: ",
        n_floor_block, " (mean across simulated draws ", sprintf("%.2f", mean(fs)), "). Report: ", report_path)
