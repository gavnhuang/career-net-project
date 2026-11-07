# study/ — the rating study pipeline

Everything that turns the CareerNet release into the materials raters see. Each stage reads the previous stage's output and never edits it.

| Folder | Holds |
|---|---|
| `config/` | `study_config.yml`: seed, sample size, filters, coverage floor, guaranteed labels, input paths, frozen checksums |
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

Each script takes an optional config path (default `study/config/study_config.yml`). Run them in order from the project root:

```bash
Rscript study/scripts/00_check_release.R      # v1.1 vs v1.0 equivalence; stops if content differs
Rscript study/scripts/01_build_frame.R        # eligibility frame, attrition, display text; stops if counts don't reproduce
Rscript study/scripts/02_reading_sample.R     # 45 random frame questions to read; removes nothing
Rscript study/scripts/03_reserve_sets.R       # spare, warm-up, calibration, gold candidate sets
Rscript study/scripts/03b_screen_reserved.R   # screen the reserved sets with rules 2-4; one round per call (D96)
Rscript study/scripts/freeze_frame.R          # checksum the frame and reserved sets into the config (once)
Rscript study/scripts/unfreeze_frame.R --decision=<id> --approval="..."   # only for an approved, logged change
Rscript study/scripts/04_draw_study_sample.R  # study draw + screening sheet + replacement queues (DRY RUN until the guard is set)
Rscript study/scripts/05_apply_screening.R    # one screening round per call (see Screening below)
Rscript study/scripts/06_prereg_export.R      # reports/prereg_sampling_appendix.md for the OSF registration
Rscript study/scripts/run_tests.R             # testthat suite (~40 s; needs the CareerNet files)
```

`study/scripts/demo_05_screening_TEST.R <out_dir> [floor|two_label]` is a test only: it copies the dry-run draw to a folder outside `study/`, fills the sheet with a fake pattern and runs 05 twice to show replacement working. Its output is not a screening record.

**The frame is frozen** (`frozen: true` in the config). 01, 03 and 03b refuse to run, and 02 still works. 04, 05 and 06 verify the checksums first and stop if any frozen file differs; a real (non-dry) 04/05 also requires the frame to be frozen.

### The frame (01)

Filters are applied to answers, cumulatively; a question stays if at least one answer survives. Counts are unique questions / answers and must reproduce exactly (01 stops otherwise):

| Step | Rule | Questions | Answers |
|---|---|---|---|
| all | the v1.1 general release | 3,000 | 7,984 |
| a | answer posted on or after 2021-01-01 and before 2023-03-01 (UTC) | 764 | 1,496 |
| b | answer 40–600 words (raw text, HTML stripped) | 725 | 1,338 |
| c | question title + body 10+ words | 707 | 1,301 |
| d | exclusion rule 1: platform-written prompts | 707 | 1,301 |
| e | the 36 anchor check questions | 694 | 1,278 |
| f | manual exclusions in `config/exclusions.csv` | 694 | 1,278 |

Why:
- **a. Date window.** Human answers posted from spring 2023 on show signs of AI-assisted writing and a style shift, so the human side is limited to pre-LLM forum advice (2021-01-01 up to, not including, 2023-03-01). Both dates are in the config.
- **No `unclear_goal` filter (D87).** Questions CareerNet flags "Unclear Goal" stay in the frame (13 of 694); `unclear_goal` is kept as a descriptive column.
- **d. Rule 1 (automatic).** Some "questions" were written by CareerVillage to solicit content, not by a real asker. A question is removed when its title + body (HTML stripped) matches the case-insensitive `platform_prompt_pattern` in the config. It matches 79 questions in the full release; the date window already removes all of them, so step d removes none now and stays as a safeguard. Notes like "this question was asked anonymously by a student" are real students and do not match.
- **Guaranteed labels.** The 9 labels with 30+ eligible questions (10 × the floor) in this frame, fixed by name in the config; 01 stops if the rule no longer gives exactly this set. First Job Navigation has exactly 30 (28 after the reserved sets).

**There are no manual frame exclusions.** `config/exclusions.csv` stays empty (headers only): the reading sample was used to write the exclusion rules, rule 1 is applied to the frame automatically, and rules 2–4 are applied by screening the drawn sample (05).

### Reserved sets (03, 03b)

03 draws four sets by seeded sequential simple random sampling: spare (16), warmups (6), calibration (15), gold_candidates (20).

- **spare (D97).** The first set, drawn as "pilot", is renamed `spare`. It is not used and not screened (`screened: false` in the config). **The lab pilot runs on the 20 gold candidates.** The rename did not change any id, planned version or human answer (the set name is not part of the seed).
- **Screening (D96).** `03b_screen_reserved.R` screens warmups, calibration and gold_candidates with the same rules 2–4 as the study sample, from question text only. Round 1 (`reserved_screening_round1.csv`) is pre-filled from `config/reserved_confirmed_exclusions.csv` (items already confirmed, matched by set and title, exact or by prefix for a title given with "…"); every other item is `excluded = FALSE`. Each excluded item is replaced by the next question in a seeded ordering of `frame_remaining` (`derive_seed(master_seed, "reserve_replacement")`, saved as `reserve_replacement_queue.csv`), skipping questions already used or excluded. The replacement keeps the set, position and `planned_version`, and gets the usual seeded human answer. Replacements go in the next round's sheet; fill `rule2`–`rule4`, `excluded` and `notes`, and run 03b again. 03b replays every sheet from round 1.
- When a round has no exclusions, 03b rewrites the screened set files and `frame_remaining` (without the replacements) and writes `reserved_exclusions_log.csv`. **Excluded items leave the frame for good**: they are neither reserved nor in `frame_remaining`, and 04 counts them when it checks that the frame is partitioned. Then run `freeze_frame.R`.

### Freezing the frame

After 01–03b, `freeze_frame.R` writes `frozen: true`, `frozen_at` and the md5 of 15 files into the config: `frame_questions` and `frame_answers` (csv and rds), every reserved-set file plus `frame_remaining` (csv and rds; 04/05 read the rds), and `reserved_exclusions_log.csv`. It refuses if already frozen and never edits anything else in the config. While frozen:
- 01, 03 and 03b stop before writing anything.
- 04, 05 and 06 verify every checksum at the start and stop if a file is missing or differs.
- Unfreezing goes through `unfreeze_frame.R --decision=<id> --approval="<who, why>"`. It sets `frozen: false` and writes a run log (`logs/<run_id>-unfreeze.yml`) with the decision, the approval and the checksums it removed. After registration, an unfreeze is a deviation.

The frame was unfrozen once, before registration, under D87 (approved 2026-10-27; drop the `unclear_goal` filter, draw 100). The earlier outputs are in `data/_superseded/2026-10-27_pre-D87/`, and the frame was rebuilt and re-frozen with new checksums. It was unfrozen again under D96 (approved 2026-10-27, before registration) to screen the reserved sets, rename pilot to spare (D97) and draw exactly 90 (D95); the reserved files before that are in `data/_superseded/2026-10-27_pre-D96/`, along with an aborted round 1 that still included the pilot set.

### Study draw: n = 90 (D95)

04 draws exactly `study_n` = 90 questions; inclusion probabilities are for n = 90. (D88, "draw 100 and use the first k", was dropped under D95.)

- Draw order lists every floor-stage question (`selection_stage = floor`) before any random-fill question. These first slots are the **floor block** (`floor_block = TRUE`); they alone meet every guaranteed label's floor. 04 reports their number.
- Screening replacements keep the excluded question's position in draw order. Screening checks the floor across the whole sample (see Screening); after screening, the floor block alone need not meet every floor.

### Pre-registration guard and seeds

04 and 05 run in DRY-RUN mode unless `preregistration_posted: true` **and** `osf_url` is non-empty. In dry-run mode they write to `data/03_sample/_dry_run/`, every filename and run id contains `DRY_RUN`, and reports carry a banner. A real run refuses to overwrite an existing real sample or screened sample.

- `master_seed` (20261027) drives the frame, reading sample, reserved sets, the human-answer pick and every dry run.
- **The real study draw's seed comes from the OSF DOI.** `study_master_seed = strtoi(substr(md5(normalized DOI), 1, 7), 16)`. The DOI in `osf_doi` is normalized first: whitespace trimmed, lowercased, and a leading `https://doi.org/`, `http://doi.org/`, `doi.org/` or `doi:` removed, so `10.17605/OSF.IO/ABCDE`, `https://doi.org/10.17605/osf.io/abcde` and ` doi:10.17605/osf.io/abcde ` give the same seed. The md5 is of the text, not of a serialized R object. The draw, the inclusion-probability reps and the replacement queues all derive from it with `derive_seed(study_master_seed, "<stage>")` (`study_draw`, `inclusion_rep_<r>`, `replacement_queue_general`, `replacement_queue_<label>`). A real run refuses to start if `osf_doi` is empty. Dry runs never use the DOI seed (they use `master_seed` and the draw stage `study_draw_DRY_RUN`). The run log records the raw and normalized DOI, the rule and the resulting number.
- `derive_seed(x, stage)` = first 7 hex digits of md5("<x>:<stage>"). RNG kind: Mersenne-Twister / Inversion / Rejection. Every draw starts from questions sorted by numeric id.

### Screening (exclusion rules 2–4) and replacement

Rules 2–4 need human judgment, so they are applied only to drawn questions, using question text only:

- **Rule 2:** asks about the responder's own career or experience rather than for advice to the asker (e.g. "Why do you love your career?", school interview assignments).
- **Rule 3:** needs knowledge of a specific non-US education or labor system to answer correctly.
- **Rule 4:** asks for review of a pasted personal document (e.g. a resume), or bundles more than three separate questions.

Workflow:
1. 04 writes `screening_sheet_round1.csv`: question_id, title and display text of each drawn question (in question_id order, so it does not reveal how each was selected), plus empty `rule2`, `rule3`, `rule4`, `excluded`, `screener`, `notes`. **It contains no answer text, ratings or other answer information.** 04 also fixes the replacement queues (`replacement_queues.csv/.rds`): a seeded random order of every unselected frame question, plus one per guaranteed label.
2. The screener (the student researcher, or whoever the protocol names) fills every row: `TRUE`/`FALSE` for each rule, `excluded` = TRUE exactly when any rule is TRUE, their name or initials in `screener`, and optional `notes`. Screen from the sheet only; do not look up the answers.
3. Run `05_apply_screening.R`. It validates the sheet (every row filled, `excluded == rule2 | rule3 | rule4`, ids match the draw) and replaces each excluded question, in draw order:
   - The floor is checked **across the whole sample**. If removing it drops one or more guaranteed labels below the floor, the replacement is the next question in the **rarest** such label's queue (rarest = fewest questions in the sampling frame). Otherwise it is the next question in the general queue.
   - **Two labels at once:** if a guaranteed label is still below the floor after that, the most recently drawn `random_fill` question whose removal would drop no guaranteed label below the floor (and that this round's sheet did not exclude) is swapped out for the next question in that label's queue, rarest short label first, repeated until every label meets the floor. Each swapped-out question is logged with reason `floor_swap` (it was not excluded by a rule; it was displaced to keep n = 90), and swapped-in questions are screened in the next round. 05 stops with an error only if no eligible `random_fill` question exists.
   - **Every replacement (and swapped-in question) takes the position in draw order of the question it replaces**, so draw order stays 1–90.
   - Queues skip questions already selected, excluded or swapped out.
4. If anything was excluded, 05 writes `screening_sheet_round2.csv` with the replacements. Fill it in and run 05 again. Repeat until a round has no exclusions; 05 runs one round per call and says what it did.
5. Then 05 writes `study_sample_screened.csv/.rds` (the study sample columns plus `screening_round` and `replaced_question_id`), `exclusions_log.csv` (question_id, draw_order, round, reason = excluded/floor_swap, rules triggered, notes, screener, replaced_by, queue) and `sample_for_generation_screened.csv`. **Generate LLM answers from the screened file.**

05 replays every sheet from round 1 on each call, so the result depends only on the draw, the queues and the sheets. Do not edit an earlier round's sheet after the next round exists. Inclusion probabilities stay those of the unscreened procedure; screening is not reflected in them (stated in the 05 report).

### Display text

Raters and the generation step see display text. The raw and clean columns are kept.

- `*_text_clean`: HTML to plain text (entities decoded, paragraph breaks kept), URLs removed.
- `answer_text_display` = `answer_text_clean` with only these removed, in this order:
  1. **Opening salutation**: a first line or leading phrase like "Hi,", "Hello Shawn,", "Hey there!", "Hi Claire -", "Dear student,", "Greetings,".
  2. **Closing sign-off, signature or pleasantry**: final lines that are only a valediction and/or a name ("Best,", "Best wishes.", "Sincerely, Maria", "Cheers!", "- John", a lone "Gloria"), or only closing pleasantries from `closing_pleasantries` in the config ("Hope this helps!", "I hope this helps.", "Good luck!", "Best of luck to you!", "All the best!", "Wishing you the best!", combinations like "Hope this helps! Good luck!", optionally followed by a name). Such a phrase is never removed inside a longer sentence ("Good luck with your interviews next week, and…") or anywhere but the last line. A lone last line starting with a common sentence word ("Then Y.") is not taken for a name.
  3. **List markers**: a line starting with "-", "*", "•", "–" or a one- or two-digit number with "." or ")" loses that marker and the space after it; each item stays on its own line with identical words. HTML `<li>` items become their own lines without markers. Lines like "2.5 years" or "-getting started" are untouched.

  Nothing else changes: no rewording, no typo fixes, and "Great question" openers, personal experience and in-sentence courtesies stay. Every removal is logged in `data/01_frame/display_edits.csv` (answer_id, part = opening/closing/list_marker, removed_text).
- `answer_word_count_display` counts display words (after all three steps). `target_words` and `target_min_words` / `target_max_words` (±20%) use it. Filter b still uses the raw word count.
- `has_list`: TRUE if the raw HTML has `<ul>`, `<ol>` or `<li>`, or the clean (pre-display) text has lines starting with "-", "*", "•" or "1.". It describes the original answer; the display text no longer has markers.
- `question_text_display` = `question_text_clean` with CareerVillage hashtags (`#word`, `#word-word`) removed and whitespace tidied, logged in `data/01_frame/question_display_edits.csv`. Some bodies are only hashtags and become empty; the title carries the question. `sample_for_generation*.csv` uses `question_title` + `question_text_display`.

### Outputs

| File | What it is |
|---|---|
| `data/01_frame/attrition.csv` | Questions and answers left after each step (all, a–g), with the expected counts |
| `data/01_frame/frame_questions.{csv,rds}` | One row per eligible question: raw/clean/display text, scenario label indicators, goals, SOC occupation, `n_eligible_answers` |
| `data/01_frame/frame_answers.{csv,rds}` | Every eligible answer: raw/clean/display text, word counts, `has_list`, CareerNet ratings, `careernet_reasoning_label` |
| `data/01_frame/display_edits.csv`, `question_display_edits.csv` | Every salutation, sign-off and hashtag removal |
| `data/02_reserved/{spare,warmups,calibration,gold_candidates}.{csv,rds}` | Reserved sets (16/6/15/20), study-sample columns plus `planned_version`; replacements from 03b have `selection_stage = reserve_replacement` |
| `data/02_reserved/reserved_screening_round<k>.csv`, `reserve_replacement_queue.csv`, `reserved_exclusions_log.csv` | Reserved-set screening sheets (question text only), the seeded replacement queue, and every exclusion with its replacement (03b) |
| `data/02_reserved/frame_remaining.{csv,rds}` | Frame questions not reserved: the sampling frame for 04 |
| `data/03_sample/study_sample.{csv,rds}` | The unscreened draw (n = 90), one row per question in draw order with `floor_block`, its human answer, `inclusion_prob`, `weight` and generation targets |
| `data/03_sample/screening_sheet_round<k>.csv` | Screening sheets (question text only) |
| `data/03_sample/replacement_queues.{csv,rds}` | The seeded replacement queues fixed at draw time |
| `data/03_sample/inclusion_probs.{csv,rds}` | Estimated inclusion probability of every question in `frame_remaining` |
| `data/03_sample/study_sample_screened.{csv,rds}`, `exclusions_log.csv` | The final screened sample and the exclusion log (05) |
| `data/03_sample/sample_for_generation_screened.csv` | **Input to LLM generation**: `question_id`, `question_title`, `question_text_display`, `target_words`, `target_min_words`, `target_max_words` (04 also writes an unscreened `sample_for_generation.csv`; do not generate from it) |
| `data/_superseded/2026-10-27_pre-D85/` | Outputs of the first design (2021+ answers, 13 guaranteed labels), kept for the record |
| `data/_superseded/2026-10-27_pre-D86/` | Outputs before the final display-cleaning rules (pleasantries, list markers); same frame and reserved-set ids |
| `data/_superseded/2026-10-27_pre-D96/` | Reserved sets before D96/D97 (with the set named pilot, unscreened) and the aborted round 1 that included it |
| `data/_superseded/2026-10-27_pre-D87/` | Outputs with the `unclear_goal` filter (681-question frame, 8 guaranteed labels, n = 90), the appendix generated from them, and the reading sample |
| `reports/prereg_sampling_appendix.md` | Plain-language sampling appendix for the OSF registration (06): rules, counts, seeds, checksums, commit; no question or answer text, no ids |
| `reports/release_check_<run_id>.md`, `reading_sample_<seed>.md`, `<script>_<run_id>.md` | Run reports: counts at each stage, label coverage with floor PASS/FAIL, distributions, display edits, screening rounds |
| `logs/<run_id>.yml` | Timestamp, seeds and seed rules, full config, md5 of every input, R and package versions, git commit, output paths |

In dry-run mode the `data/03_sample/` files sit in `_dry_run/` with `_DRY_RUN` in their names. Only the 13 MB `frame_answers.csv` of the pre-D85 frame is not committed.

### Method in brief

- **Missing values.** v1.1 writes missing as `""`, v1.0 as `"NA"`; both, and NA, count as missing everywhere.
- **Human answer.** One eligible answer per question, drawn uniformly with the `human_answer` stage of `master_seed` over the whole frame, so a question has the same answer whichever set it lands in.
- **Coverage floor.** Guaranteed labels are processed rarest first; each is topped up to `floor` (3) questions from those carrying it (the floor block, first in draw order), then remaining slots are filled by simple random sampling, in the order drawn. `inclusion_prob` is estimated from `inclusion_reps` (10,000) re-runs of the full draw; `weight = 1 / inclusion_prob`, normalized to mean 1 over the sample. Reserved sets are sequential simple random samples (`inclusion_prob = size / frame size`, `weight = 1`).
- **Not used in selection:** `soc_code` and `reasoning_label`.

### Reasoning labels

`careernet_reasoning_label` is CareerNet's label for the chosen human answer, assigned by a fine-tuned GPT-4.1-mini with limited reliability. It is carried for description only. Labeling both human and AI answers with the study's own reasoning scheme is an optional later stage. It would join on `answer_id` or `question_id`, and the `careernet_` prefix keeps the names from colliding.

## AI answer generation (07, B02)

Decisions D100–D103 (vault `04 Decisions`). Settings live in `config/study_config.yml` under `generation`, and the prompt in `config/generation_prompt.txt`.

```bash
Rscript study/scripts/07_generate_answers.R --set gold_candidates --preview   # what the model will be sent; no API calls
Rscript study/scripts/07_generate_answers.R --set gold_candidates --limit 3   # test run
Rscript study/scripts/07_generate_answers.R --set gold_candidates             # full set (warmups, calibration, or study_sample after the OSF draw)
Rscript study/scripts/freeze_generation.R                                     # after the pilot: locks the prompt (md5) and settings
```

- **Model:** `gpt-6-luna`, reasoning `none`, other settings at their defaults. Needs `OPENAI_API_KEY` in `~/.Renviron`, never in this repo.
- **Length:** the prompt asks for `round(target × 0.83)` words, "and no more than" the top of the ±20% window. Acceptance is checked against the real target. Up to 5 tries. If none fit, the closest-length attempt that passes the format checks is kept and flagged `closest_length`. No question is dropped (D101).
- **Display:** URLs are stripped and typography normalized (`normalize_typography()`: straight quotes and apostrophes, dashes become " - "). The raw model text is kept in `response_text_raw`. Word counts are taken before normalization. The same function is applied to human answers when surveys are built (B16).
- **Outputs:** `data/04_generated/<set>/answers_<run>.csv` (one row per question), `raw_<run>.jsonl` (every attempt, with the full API response), `reports/07_generate_<set>_<run>.md`, and `logs/<run>.yml`. Earlier runs are never overwritten.
- **Pilot answers:** `gold_candidates` run `20261101-180642-07` (commit 9548670).

## Pilot materials

`data/05_assignments/pilot_items_key.csv` maps the 20 shuffled pilot items (order seed 20261101) to question_id, version (human/AI), answer_id or AI run, and word counts. **This is the unblinding key**: it stays here and is never sent to coders or pilot raters. The blind materials built from it are in `07 Study Materials/06 Pilot/`.

**Warm-ups (D116):** after `Rscript study/scripts/07_generate_answers.R --set warmups`, run `python3 study/scripts/make_warmup_sheet.py` from `04 R Project`. It writes the blind scoring sheet to `07 Study Materials/02 Training/Warm-ups/` and the key to `data/05_assignments/warmup_items_key.csv` (never shared). Order seed 20261107; items 1–3 are the pilot training's practice items.
Needs openpyxl; on Gavin's Mac run it with /opt/anaconda3/bin/python3 (the default python3 lacks it).
