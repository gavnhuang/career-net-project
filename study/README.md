# study/ — the rating study pipeline

Everything that turns the CareerNet release into the materials raters see. Each stage reads the previous stage's output and never edits it.

| Folder | Holds |
|---|---|
| `config/` | `study_config.yml`: seed, sample size, filters, coverage floor, guaranteed labels, input paths |
| `R/` | Reusable functions (frame building, sampling, checks). No side effects |
| `scripts/` | Thin, numbered run scripts that call the functions and write outputs |
| `tests/` | testthat tests for the functions |
| `data/01_frame/` | The eligible question frame (one row per question) and its attrition table |
| `data/02_reserved/` | Pilot, warm-up, calibration and gold candidate sets, drawn before the study sample |
| `data/03_sample/` | The study sample. **Drawn only after the OSF pre-registration is posted (D20)** |
| `data/04_generated/` | LLM answers and raw API output |
| `data/05_assignments/` | Block plans per pool |
| `reports/` | Human-readable summaries of each run (label coverage, counts) |
| `logs/` | Run logs: date, seed, config, input file hash, R version, git commit |

## Rules
- Run everything from the `04 R Project` root.
- `../data/` and `03 CareerNet Data/` are read-only.
- **No participant data ever goes in this folder or anywhere on a personal device.** Ratings, rater IDs, intake, background and contact data live only in the restricted lab Microsoft 365 folders (IRB narrative 8.5.2). This folder holds study materials derived from the public dataset only.

## Question sampling: how to run

Each script takes an optional config path (default `study/config/study_config.yml`). Run them in order:

```bash
Rscript study/scripts/00_check_release.R      # v1.1 vs v1.0 equivalence; stops if content differs
Rscript study/scripts/01_build_frame.R        # eligibility frame + attrition; stops if counts don't reproduce
Rscript study/scripts/02_reading_sample.R     # 45 random frame questions to read; removes nothing
Rscript study/scripts/03_reserve_sets.R       # pilot, warm-up, calibration, gold candidate sets
Rscript study/scripts/04_draw_study_sample.R  # study draw (DRY RUN until the guard is set)
Rscript study/scripts/run_tests.R             # testthat suite (~20 s; needs the CareerNet files)
```

After a manual read of the reading sample, add question ids to `config/exclusions.csv` (`question_id,reason`), then rerun 01 onward. Step f of the attrition table will show the drop.

### Pre-registration guard

`04` runs in DRY-RUN mode unless `preregistration_posted: true` **and** `osf_url` is non-empty in the config. In dry-run mode it writes to `data/03_sample/_dry_run/`, every filename and the run id contain `DRY_RUN`, the report has a banner, and the draw uses a separate seed (`study_draw_DRY_RUN`), so a dry run never reveals the real sample. Only set the guard after the OSF pre-registration is posted. A real run refuses to overwrite an existing real sample.

### Outputs

| File | What it is |
|---|---|
| `data/01_frame/attrition.csv` | Unique questions and answers left after each filter (all, a–f), with the expected counts |
| `data/01_frame/frame_questions.{csv,rds}` | One row per eligible question: text (raw + clean), scenario label indicators, goals, SOC occupation, `n_eligible_answers` |
| `data/01_frame/frame_answers.{csv,rds}` | Every eligible answer: text (raw + clean), word count, CareerNet ratings (text + 1–4), `careernet_reasoning_label`. The CSV is >10 MB and not committed; rebuild it with 01 |
| `data/02_reserved/{pilot,warmups,calibration,gold_candidates}.{csv,rds}` | Reserved sets, same columns as the study sample, with `planned_version` (human/ai) |
| `data/02_reserved/frame_remaining.{csv,rds}` | Frame questions not reserved: the sampling frame for 04 |
| `data/03_sample/study_sample.{csv,rds}` | The study sample: one row per question with its chosen human answer, `inclusion_prob`, `weight` and generation targets |
| `data/03_sample/sample_for_generation.csv` | Input to LLM generation: `question_id`, `question_title`, `question_text_clean`, `target_words`, `target_min_words`, `target_max_words` |
| `data/03_sample/inclusion_probs.csv` | Estimated inclusion probability of every question in `frame_remaining` |
| `reports/release_check_<run_id>.md` | Release equivalence result, per column |
| `reports/reading_sample_<seed>.md` | The reading sample, formatted for reading |
| `reports/<script>_<run_id>.md` | Counts at each stage, scenario label coverage (with floor PASS/FAIL), goal / rating / occupation / reasoning distributions, frame vs sample |
| `logs/<run_id>.yml` | Timestamp, seeds, full config, md5 of every input file, R and package versions, git commit, output paths |

In dry-run mode the three `data/03_sample/` files sit in `_dry_run/` with `_DRY_RUN` in their names.

### Method in brief

- **Missing values.** v1.1 writes missing as `""`, v1.0 as `"NA"`; both, and NA, are treated as missing everywhere.
- **Word count.** Strip HTML tags, then split on whitespace. Question length is title + body.
- **Clean text.** HTML to plain text (entities decoded, paragraph breaks kept), URLs removed. Raw columns are kept.
- **Seeds.** One `master_seed`; each stage uses `derive_seed(master_seed, "<stage>")`, the first 7 hex digits of md5 (`reading_sample`, `reserve_sets`, `human_answer`, `study_draw`, `inclusion_rep_<r>`). RNG kind: Mersenne-Twister / Inversion / Rejection. Every draw starts from questions sorted by numeric id, so the input row order does not matter.
- **Human answer.** One eligible answer per question, drawn uniformly with the `human_answer` seed over the whole frame, so a question has the same answer whichever set it lands in.
- **Coverage floor.** Guaranteed labels (fixed list in the config) are processed rarest first. Each gets topped up to `floor` questions from those carrying it, then the remaining slots are filled by simple random sampling. `inclusion_prob` is estimated from `inclusion_reps` re-runs of the full draw; `weight = 1 / inclusion_prob`, normalized to mean 1 over the sample. Reserved sets are sequential simple random samples (`inclusion_prob = size / frame size`, `weight = 1`).
- **Not used in selection:** `soc_code` and `reasoning_label`. They are carried for description only.

### Reasoning labels

`careernet_reasoning_label` is CareerNet's label for the chosen human answer, assigned by a fine-tuned GPT-4.1-mini with limited reliability. It is carried for description only. Labeling both human and AI answers with the study's own reasoning scheme is an optional later stage. It would join on `answer_id` or `question_id`, and the `careernet_` prefix keeps the names from colliding.
