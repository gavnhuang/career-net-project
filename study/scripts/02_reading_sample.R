# Step 2: a random reading sample of frame questions, for writing exclusion rules. Removes nothing.
source("study/scripts/_common.R")
run <- start_run("02")
cfg <- run$cfg

fq_path <- file.path(cfg$paths$frame_dir, "frame_questions.rds")
fa_path <- file.path(cfg$paths$frame_dir, "frame_answers.rds")
fq <- readRDS(fq_path)
fa <- readRDS(fa_path)

seed <- derive_seed(cfg$master_seed, "reading_sample")
answer_seed <- derive_seed(cfg$master_seed, "human_answer")
n <- min(cfg$reading_sample_n, nrow(fq))
ids <- with_seed(seed, sample_k(canonical_ids(fq$question_id), n))
answers <- pick_human_answer(fa, answer_seed)

quote_block <- function(x) paste0("> ", str_replace_all(coalesce(x, "(empty)"), "\n", "\n> "))

items <- purrr::imap(ids, function(id, i) {
  q <- fq[fq$question_id == id, ]
  a <- answers[answers$question_id == id, ]
  occupation <- c(if (!is.na(q$soc_major_groups)) paste("Major group(s):", q$soc_major_groups),
                  if (!is.na(q$soc_detailed_codes)) paste("Detailed:", q$soc_detailed_codes),
                  if (!is.na(q$soc_flag)) paste("Flag:", q$soc_flag))
  goals <- unlist(q[GOAL_COLUMNS])
  goals <- goals[!is.na(goals)]
  c(glue("## {i}. {q$question_title}"), "",
    glue("question_id {id} · {q$question_word_count} words · {format(q$question_added_at, '%Y-%m-%d')} · ",
         "{q$n_eligible_answers} eligible answer(s)"), "",
    glue("- **Scenario labels:** {coalesce(q$scenario_labels, '(none)')}"),
    glue("- **Goals:** {if (length(goals)) paste(paste0(names(goals), ': ', goals), collapse = ' | ') else '(none)'}"),
    glue("- **Occupation:** {if (length(occupation)) paste(occupation, collapse = ' · ') else '(none)'}"), "",
    "**Question**", "", quote_block(if (nzchar(coalesce(q$question_text_display, ""))) q$question_text_display else "(body empty after hashtag removal)"), "",
    glue("**Answer** (answer_id {a$answer_id} · {a$answer_word_count_display} display words{if (a$has_list) ' · has list' else ''} · {format(a$answer_added_at, '%Y-%m-%d')} · ",
         "{a$careernet_correctness}, {a$careernet_completeness}, {a$careernet_coherency})"), "",
    quote_block(a$answer_text_display), "", "---", "")
})

report_path <- file.path(cfg$paths$reports_dir, glue("reading_sample_{seed}.md"))
writeLines(c(
  glue("# Reading sample: {n} frame questions"), "",
  glue("Run `{run$run_id}` · seed {seed} (derive_seed(master_seed, \"reading_sample\")) · frame {cfg$frame_version}, ",
       "{nrow(fq)} questions"), "",
  "Random frame questions, each with one eligible human answer (the same answer the study would use). ",
  "Read these to write exclusion rules for `study/config/exclusions.csv`. This step removes nothing.", "",
  "Text shown is the display text: URLs, hashtags, answer salutations and sign-offs removed.", "", "---", "",
  unlist(items)
), report_path)

write_run_log(file.path(cfg$paths$logs_dir, glue("{run$run_id}.yml")), run$run_id, "02_reading_sample.R",
              seeds = list(master_seed = cfg$master_seed, reading_sample = seed, human_answer = answer_seed),
              config = cfg, input_files = c(config = run$config_path, frame_questions = fq_path, frame_answers = fa_path),
              frame_version = cfg$frame_version, outputs = c(report = report_path),
              extra = list(question_ids = ids))

message("Reading sample: ", report_path)
