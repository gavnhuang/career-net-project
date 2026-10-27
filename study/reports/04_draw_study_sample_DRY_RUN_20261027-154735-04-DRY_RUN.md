# Study sample (DRY RUN): n = 90, floor = 3

> **DRY RUN. NOT THE STUDY SAMPLE.** The OSF pre-registration is not marked as posted
> (`preregistration_posted` / `osf_url` in the config). This draw uses a separate dry-run seed,
> so it does not preview the real sample. Do not use these questions for anything.

Run `20261027-154735-04-DRY_RUN` · frame v1.1

- Seed base: 20261027 = master_seed (dry run; the DOI seed is never used)
- Draw seed: 146283223 = derive_seed(seed base, "study_draw_DRY_RUN")
- Inclusion reps and replacement queues derive from the same seed base.
- Frame frozen: yes (15 checksums verified)

## Counts at each stage

| stage | questions |
|---|---|
| Frame (01) | 694 |
| Reserved sets (03, after 03b screening) | 57 |
| Reserved items screened out (03b) | 8 |
| frame_remaining (sampling frame) | 629 |
| Selected at the floor stage (draw order 1 to the floor block size) | 18 |
| Selected by random fill | 72 |
| Study sample | 90 |

**Floor block: 18 floor-stage questions** (draw order 1-18); they alone meet every floor. Screening replacements keep the excluded question's position.

## Floor stage

Labels are processed rarest first (count in frame_remaining).

| order | label | available_in_frame_remaining | floor_slots_this_draw |
|---|---|---|---|
| 1 | First Job Navigation | 28 | 3 |
| 2 | Skill Development | 41 | 3 |
| 3 | Networking and Mentorship | 53 | 3 |
| 4 | Resume/CV/LinkedIn Optimization and Personal Branding | 62 | 3 |
| 5 | Work-Life Balance and Personal Values Alignment | 68 | 3 |
| 6 | Job Search Strategies and Infrastructure | 73 | 0 |
| 7 | College Queries | 94 | 1 |
| 8 | Career Decision-Making, Transitioning, and Exploration Resources | 204 | 2 |
| 9 | Industry-Specific Knowledge and Trends | 266 | 0 |

Floor slots used across 10,000 simulated draws: mean 18.22, SD 1.68, range 12-24. This draw: 18.

## Scenario label coverage

frame = frame_remaining. A question counts toward every label it carries.

| label | guaranteed | frame_n | frame_share | sample_n | sample_share | expected_if_srs | floor_check |
|---|---|---|---|---|---|---|---|
| Industry-Specific Knowledge and Trends | yes | 266 | 42.3% | 30 | 33.3% | 38.1 | PASS |
| Career Decision-Making, Transitioning, and Exploration Resources | yes | 204 | 32.4% | 22 | 24.4% | 29.2 | PASS |
| College Queries | yes | 94 | 14.9% | 18 | 20.0% | 13.4 | PASS |
| Job Search Strategies and Infrastructure | yes | 73 | 11.6% | 14 | 15.6% | 10.4 | PASS |
| Work-Life Balance and Personal Values Alignment | yes | 68 | 10.8% | 14 | 15.6% | 9.7 | PASS |
| Resume/CV/LinkedIn Optimization and Personal Branding | yes | 62 | 9.9% | 8 | 8.9% | 8.9 | PASS |
| Networking and Mentorship | yes | 53 | 8.4% | 10 | 11.1% | 7.6 | PASS |
| Skill Development | yes | 41 | 6.5% | 7 | 7.8% | 5.9 | PASS |
| First Job Navigation | yes | 28 | 4.5% | 11 | 12.2% | 4.0 | PASS |
| Freelancing/Self-Employment/Entrepreneurship |  | 15 | 2.4% | 2 | 2.2% | 2.1 | n/a |
| Interview Preparation |  | 14 | 2.2% | 2 | 2.2% | 2.0 | n/a |
| Non-Degree Certifications/Credentials |  | 13 | 2.1% | 1 | 1.1% | 1.9 | n/a |
| Workplace Dynamics |  | 13 | 2.1% | 2 | 2.2% | 1.9 | n/a |
| International Careers |  | 8 | 1.3% | 1 | 1.1% | 1.1 | n/a |
| Barriers, Equity, and Resource Considerations |  | 5 | 0.8% | 1 | 1.1% | 0.7 | n/a |
| Job Offers and Negotiations |  | 1 | 0.2% | 0 | 0.0% | 0.1 | n/a |
| Career Advancement |  | 1 | 0.2% | 0 | 0.0% | 0.1 | n/a |
| Mid-Career Pivots |  | 0 | 0.0% | 0 | 0.0% | 0.0 | n/a |

Labels present in the sample: 15 of 18 (9 of 9 guaranteed, 6 not guaranteed).

Guaranteed labels are those with at least 30 eligible questions (10 x floor) in the frame. Not guaranteed (frame questions): Freelancing/Self-Employment/Entrepreneurship (15), Interview Preparation (15), Workplace Dynamics (15), Non-Degree Certifications/Credentials (14), International Careers (8), Barriers, Equity, and Resource Considerations (6), Job Offers and Negotiations (1), Career Advancement (1), Mid-Career Pivots (0).

## Inclusion probabilities and weights

Estimated from 10,000 re-runs of the draw (derive_seed(20261027, "inclusion_rep_<r>") for r = 1..10000). weight = 1 / inclusion_prob, normalized to mean 1 over the sample.

| quantity | min | median | max |
|---|---|---|---|
| inclusion_prob, frame_remaining | 0.1098 | 0.1347 | 0.2666 |
| inclusion_prob, sample | 0.1098 | 0.1473 | 0.2666 |
| weight, sample | 0.5545 | 1.0032 | 1.3463 |

Simple random sampling would give every question 0.1431. Questions never selected in any simulated draw: 0.

## Checks

| check | passed | detail |
|---|---|---|
| n is exact | PASS | 90 rows, expected 90 |
| no duplicate question_ids | PASS |  |
| all questions are in the frame | PASS |  |
| no anchor check questions | PASS |  |
| no reserved questions | PASS |  |
| human answer is an eligible answer to its question | PASS |  |
| no private id columns | PASS |  |
| inclusion_prob in (0, 1] | PASS |  |
| every guaranteed label has >= 3 questions | PASS |  |
| floor-stage questions come first in draw order | PASS | floor block = first 18 |
| the floor block alone gives every guaranteed label >= 3 questions | PASS |  |

## Human answers

Display length: median 122.5 words (range 46-576); targets for generation are display length ± 20%. Questions with one eligible answer: 31; with several: 59.

- Opening salutation removed: 35 of 90
- Closing sign-off, signature or pleasantry removed: 23 of 90
- List markers removed (items kept on their own lines): 7 of 90
- Any display edit: 47 of 90
- has_list (raw text has a list): 7 of 90
- Question body empty after hashtag removal (title only): 9

## Screening

`screening_sheet_round1_DRY_RUN.csv` lists the 90 drawn questions (question text only, in question_id order). Fill rule2-rule4, excluded, screener and notes, then run `05_apply_screening.R`. Replacement queues: general (539 questions) and one per guaranteed label.

## Goals (question level)

A question counts once under every goal column that is not missing.

| goal | frame_n | frame_share | sample_n | sample_share |
|---|---|---|---|---|
| explore_options | 347 | 55.2% | 54 | 60.0% |
| take_action | 282 | 44.8% | 36 | 40.0% |
| validation_support | 214 | 34.0% | 38 | 42.2% |
| find_resources | 138 | 21.9% | 23 | 25.6% |
| understanding_purpose | 79 | 12.6% | 14 | 15.6% |
| compare_options | 48 | 7.6% | 5 | 5.6% |
| navigate_constraints | 17 | 2.7% | 0 | 0.0% |
| unclear_goal | 11 | 1.7% | 0 | 0.0% |

## CareerNet ratings of human answers

Frame = every eligible answer; sample = the chosen human answer per question.

### correctness

| correctness | frame_n | frame_share | sample_n | sample_share |
|---|---|---|---|---|
| 4 - Fully Correct | 819 | 71.1% | 71 | 78.9% |
| 3 - Mostly Correct | 284 | 24.7% | 17 | 18.9% |
| 2 - Mostly Incorrect | 49 | 4.3% | 2 | 2.2% |

Mean correctness_num: frame 3.67, sample 3.77

### completeness

| completeness | frame_n | frame_share | sample_n | sample_share |
|---|---|---|---|---|
| 4 - Fully Complete | 332 | 28.8% | 29 | 32.2% |
| 3 - Mostly Complete | 385 | 33.4% | 33 | 36.7% |
| 2 - Somewhat Incomplete | 370 | 32.1% | 25 | 27.8% |
| 1 - Very Incomplete | 65 | 5.6% | 3 | 3.3% |

Mean completeness_num: frame 2.85, sample 2.98

### coherency

| coherency | frame_n | frame_share | sample_n | sample_share |
|---|---|---|---|---|
| 4 - Fully Coherent | 700 | 60.8% | 59 | 65.6% |
| 3 - Mostly Coherent | 378 | 32.8% | 28 | 31.1% |
| 2 - Mostly Incoherent | 72 | 6.2% | 3 | 3.3% |
| 1 - Completely Incoherent | 2 | 0.2% | 0 | 0.0% |

Mean coherency_num: frame 3.54, sample 3.62

## Occupation: SOC major groups (descriptive only)

Share with no career mentioned: frame 55.2%, sample 58.9%

A question counts once under every major group it lists. Flags are shown as [flag] rows.

| soc_major_group | frame_n | frame_share | sample_n | sample_share |
|---|---|---|---|---|
| [flag] no_career_mentioned | 347 | 55.2% | 53 | 58.9% |
| Healthcare Practitioners and Technical Occupations | 52 | 8.3% | 9 | 10.0% |
| Arts, Design, Entertainment, Sports, and Media Occupations | 45 | 7.2% | 3 | 3.3% |
| Life, Physical, and Social Science Occupations | 43 | 6.8% | 5 | 5.6% |
| Business and Financial Operations Occupations | 41 | 6.5% | 5 | 5.6% |
| Computer and Mathematical Occupations | 38 | 6.0% | 6 | 6.7% |
| Management Occupations | 38 | 6.0% | 6 | 6.7% |
| Architecture and Engineering Occupations | 33 | 5.2% | 4 | 4.4% |
| Educational Instruction and Library Occupations | 16 | 2.5% | 3 | 3.3% |
| Sales and Related Occupations | 11 | 1.7% | 0 | 0.0% |
| Community and Social Service Occupations | 9 | 1.4% | 1 | 1.1% |
| Office and Administrative Support Occupations | 9 | 1.4% | 3 | 3.3% |
| Legal Occupations | 8 | 1.3% | 0 | 0.0% |
| Personal Care and Service Occupations | 7 | 1.1% | 1 | 1.1% |
| Production Occupations | 7 | 1.1% | 1 | 1.1% |
| Construction and Extraction Occupations | 6 | 1.0% | 1 | 1.1% |
| Food Preparation and Serving Related Occupations | 6 | 1.0% | 2 | 2.2% |
| Healthcare Support Occupations | 5 | 0.8% | 0 | 0.0% |
| Installation, Maintenance, and Repair Occupations | 4 | 0.6% | 0 | 0.0% |
| [flag] not_aligned | 3 | 0.5% | 1 | 1.1% |
| Military Specific Occupations | 3 | 0.5% | 0 | 0.0% |
| Protective Service Occupations | 3 | 0.5% | 0 | 0.0% |
| Transportation and Material Moving Occupations | 1 | 0.2% | 0 | 0.0% |

## careernet_reasoning_label (descriptive only)

Assigned by a fine-tuned GPT-4.1-mini (limited reliability). Frame = every eligible answer; sample = chosen human answers. An answer counts once under every category it carries.

| reasoning_category | frame_n | frame_share | sample_n | sample_share |
|---|---|---|---|---|
| No reasoning - explanation only | 455 | 39.5% | 37 | 41.1% |
| Predictive Causal Reasoning/Interventional Reasoning | 349 | 30.3% | 27 | 30.0% |
| Analogy about next steps | 271 | 23.5% | 22 | 24.4% |
| Necessary Conditions | 197 | 17.1% | 19 | 21.1% |
| Associational/Normative reasoning | 159 | 13.8% | 9 | 10.0% |
| Inductive Reasoning | 39 | 3.4% | 5 | 5.6% |
| Counterfactual Reasoning | 23 | 2.0% | 1 | 1.1% |
| Analogy about current circumstances | 20 | 1.7% | 5 | 5.6% |

