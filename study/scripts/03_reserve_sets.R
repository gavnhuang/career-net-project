# Step 3: reserve pilot, warm-up, calibration and gold candidate sets before any study draw.
source("study/scripts/_common.R")
run <- start_run("03")
cfg <- run$cfg
assert_not_frozen(cfg, "03_reserve_sets.R")

fq_path <- file.path(cfg$paths$frame_dir, "frame_questions.rds")
fa_path <- file.path(cfg$paths$frame_dir, "frame_answers.rds")
fq <- readRDS(fq_path)
fa <- readRDS(fa_path)
anchor_ids <- read_ids(cfg$inputs$anchor_exclusions)

seed <- derive_seed(cfg$master_seed, "reserve_sets")
answer_seed <- derive_seed(cfg$master_seed, "human_answer")
reserved <- reserve_sets(fq$question_id, cfg$reserved_sets, seed)
answers <- pick_human_answer(fa, answer_seed)

stop_on_failed_checks(check_reserved_sets(reserved$sets, cfg$reserved_sets, fq, anchor_ids))

# Sequential SRS: P(question in set k) = size_k / N for every frame question.
selection <- reserved$sets |>
  mutate(selection_stage = "reserve", floor_label = NA_character_,
         inclusion_prob = purrr::map_dbl(set, function(s) purrr::keep(cfg$reserved_sets, ~ .x$name == s)[[1]]$size) / nrow(fq),
         weight = 1)
rows <- assemble_sample(selection, fq, answers, seed, run$run_id, cfg$frame_version, cfg$target_words_tolerance)

outputs <- character()
for (s in cfg$reserved_sets) {
  set_rows <- rows[rows$set == s$name, ]
  stop_on_failed_checks(check_sample(set_rows, fq, fa, anchor_ids, n = s$size))
  outputs <- c(outputs, write_outputs(set_rows, cfg$paths$reserved_dir, s$name))
}
remaining <- fq[match(reserved$remaining, fq$question_id), ]
outputs <- c(outputs, write_outputs(remaining, cfg$paths$reserved_dir, "frame_remaining"))

set_counts <- rows |> count(set, planned_version) |> tidyr::pivot_wider(names_from = planned_version, values_from = n) |>
  mutate(set = factor(set, purrr::map_chr(cfg$reserved_sets, "name"))) |> arrange(set) |>
  transmute(set, human, ai, total = human + ai, inclusion_prob = sprintf("%.4f", purrr::map_dbl(cfg$reserved_sets, "size") / nrow(fq)))

cov <- coverage_table(fq, NULL, cfg$scenario_labels, cfg$guaranteed_labels)
for (s in cfg$reserved_sets) {
  cov[[s$name]] <- purrr::map_int(label_column_names(cov$label), ~ sum(rows[[.x]][rows$set == s$name]))
}

report_path <- file.path(cfg$paths$reports_dir, glue("03_reserve_sets_{run$run_id}.md"))
writeLines(c(
  glue("# Reserved sets ({cfg$frame_version})"), "", glue("Run `{run$run_id}` · seed {seed} (derive_seed(master_seed, \"reserve_sets\"))"), "",
  "## Counts at each stage", "",
  glue("- Frame: {nrow(fq)} questions"),
  purrr::map_chr(cfg$reserved_sets, ~ glue("- {.x$name}: {.x$size} drawn by simple random sampling")),
  glue("- frame_remaining: {nrow(remaining)} questions (input to the study draw)"), "",
  md_table(set_counts), "",
  "## Scenario label coverage by set (descriptive; no floor applies to reserved sets)", "",
  md_table(cov), "",
  "## Distributions: frame vs all reserved questions", "",
  distribution_sections(fq, fa, rows, sample_name = "reserved")
), report_path)

write_run_log(file.path(cfg$paths$logs_dir, glue("{run$run_id}.yml")), run$run_id, "03_reserve_sets.R",
              seeds = list(master_seed = cfg$master_seed, reserve_sets = seed, human_answer = answer_seed),
              config = cfg, input_files = c(config = run$config_path, frame_questions = fq_path, frame_answers = fa_path,
                                            anchor_exclusions = cfg$inputs$anchor_exclusions),
              frame_version = cfg$frame_version, outputs = c(outputs, report = report_path))

message("Reserved ", nrow(rows), " questions; ", nrow(remaining), " remain. Report: ", report_path)
