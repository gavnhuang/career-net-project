# Study sample (DRY RUN): n = 100, floor = 3

> **DRY RUN. NOT THE STUDY SAMPLE.** The OSF pre-registration is not marked as posted
> (`preregistration_posted` / `osf_url` in the config). This draw uses a separate dry-run seed,
> so it does not preview the real sample. Do not use these questions for anything.

Run `20261027-145450-04-DRY_RUN` · frame v1.1

- Seed base: 20261027 = master_seed (dry run; the DOI seed is never used)
- Draw seed: 146283223 = derive_seed(seed base, "study_draw_DRY_RUN")
- Inclusion reps and replacement queues derive from the same seed base.
- Frame frozen: yes (14 checksums verified)

## Counts at each stage

| stage | questions |
|---|---|
| Frame (01) | 694 |
| Reserved sets (03) | 57 |
| frame_remaining (sampling frame) | 637 |
| Selected at the floor stage (draw order 1 to the floor block size) | 18 |
| Selected by random fill | 82 |
| Study sample | 100 |

## Using the first k (D88)

**Floor-stage questions in this draw: 18** (draw order 1-18).

The study uses the first k questions in draw order, where k (expected 90) is set after the pilot and the rater headcount. 
Because floor-stage questions come first, every guaranteed label keeps its floor for any k >= the number of floor-stage questions. 
`select_first_k(sample, k)` refuses k < 18. Screening replacements keep the excluded question's position.

## Floor stage

Labels are processed rarest first (count in frame_remaining).

| order | label | available_in_frame_remaining | floor_slots_this_draw |
|---|---|---|---|
| 1 | First Job Navigation | 28 | 3 |
| 2 | Skill Development | 41 | 3 |
| 3 | Networking and Mentorship | 54 | 3 |
| 4 | Resume/CV/LinkedIn Optimization and Personal Branding | 62 | 3 |
| 5 | Work-Life Balance and Personal Values Alignment | 68 | 3 |
| 6 | Job Search Strategies and Infrastructure | 74 | 0 |
| 7 | College Queries | 96 | 1 |
| 8 | Career Decision-Making, Transitioning, and Exploration Resources | 210 | 2 |
| 9 | Industry-Specific Knowledge and Trends | 267 | 0 |

Floor slots used across 10,000 simulated draws: mean 18.15, SD 1.69, range 12-24. This draw: 18.

## Scenario label coverage

frame = frame_remaining. A question counts toward every label it carries.

| label | guaranteed | frame_n | frame_share | sample_n | sample_share | expected_if_srs | floor_check |
|---|---|---|---|---|---|---|---|
| Industry-Specific Knowledge and Trends | yes | 267 | 41.9% | 37 | 37.0% | 41.9 | PASS |
| Career Decision-Making, Transitioning, and Exploration Resources | yes | 210 | 33.0% | 31 | 31.0% | 33.0 | PASS |
| College Queries | yes | 96 | 15.1% | 20 | 20.0% | 15.1 | PASS |
| Job Search Strategies and Infrastructure | yes | 74 | 11.6% | 10 | 10.0% | 11.6 | PASS |
| Work-Life Balance and Personal Values Alignment | yes | 68 | 10.7% | 9 | 9.0% | 10.7 | PASS |
| Resume/CV/LinkedIn Optimization and Personal Branding | yes | 62 | 9.7% | 8 | 8.0% | 9.7 | PASS |
| Networking and Mentorship | yes | 54 | 8.5% | 12 | 12.0% | 8.5 | PASS |
| Skill Development | yes | 41 | 6.4% | 8 | 8.0% | 6.4 | PASS |
| First Job Navigation | yes | 28 | 4.4% | 8 | 8.0% | 4.4 | PASS |
| Freelancing/Self-Employment/Entrepreneurship |  | 15 | 2.4% | 0 | 0.0% | 2.4 | n/a |
| Interview Preparation |  | 14 | 2.2% | 2 | 2.0% | 2.2 | n/a |
| Non-Degree Certifications/Credentials |  | 13 | 2.0% | 2 | 2.0% | 2.0 | n/a |
| Workplace Dynamics |  | 13 | 2.0% | 3 | 3.0% | 2.0 | n/a |
| International Careers |  | 8 | 1.3% | 2 | 2.0% | 1.3 | n/a |
| Barriers, Equity, and Resource Considerations |  | 5 | 0.8% | 0 | 0.0% | 0.8 | n/a |
| Job Offers and Negotiations |  | 1 | 0.2% | 0 | 0.0% | 0.2 | n/a |
| Career Advancement |  | 1 | 0.2% | 0 | 0.0% | 0.2 | n/a |
| Mid-Career Pivots |  | 0 | 0.0% | 0 | 0.0% | 0.0 | n/a |

Labels present in the sample: 13 of 18 (9 of 9 guaranteed, 4 not guaranteed).

Guaranteed labels are those with at least 30 eligible questions (10 x floor) in the frame. Not guaranteed (frame questions): Freelancing/Self-Employment/Entrepreneurship (15), Interview Preparation (15), Workplace Dynamics (15), Non-Degree Certifications/Credentials (14), International Careers (8), Barriers, Equity, and Resource Considerations (6), Job Offers and Negotiations (1), Career Advancement (1), Mid-Career Pivots (0).

## Inclusion probabilities and weights

Estimated from 10,000 re-runs of the draw (derive_seed(20261027, "inclusion_rep_<r>") for r = 1..10000). weight = 1 / inclusion_prob, normalized to mean 1 over the sample.

| quantity | min | median | max |
|---|---|---|---|
| inclusion_prob, frame_remaining | 0.1224 | 0.1481 | 0.2718 |
| inclusion_prob, sample | 0.1269 | 0.1552 | 0.2718 |
| weight, sample | 0.5785 | 1.0131 | 1.2390 |

Simple random sampling would give every question 0.1570. Questions never selected in any simulated draw: 0.

## Checks

| check | passed | detail |
|---|---|---|
| n is exact | PASS | 100 rows, expected 100 |
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

Display length: median 121 words (range 41-565); targets for generation are display length ± 20%. Questions with one eligible answer: 36; with several: 64.

- Opening salutation removed: 35 of 100
- Closing sign-off, signature or pleasantry removed: 19 of 100
- List markers removed (items kept on their own lines): 8 of 100
- Any display edit: 45 of 100
- has_list (raw text has a list): 8 of 100
- Question body empty after hashtag removal (title only): 8

## Screening

`screening_sheet_round1_DRY_RUN.csv` lists the 100 drawn questions (question text only, in question_id order). Fill rule2-rule4, excluded, screener and notes, then run `05_apply_screening.R`. Replacement queues: general (537 questions) and one per guaranteed label.

## Goals (question level)

A question counts once under every goal column that is not missing.

| goal | frame_n | frame_share | sample_n | sample_share |
|---|---|---|---|---|
| explore_options | 349 | 54.8% | 48 | 48.0% |
| take_action | 286 | 44.9% | 55 | 55.0% |
| validation_support | 218 | 34.2% | 31 | 31.0% |
| find_resources | 138 | 21.7% | 23 | 23.0% |
| understanding_purpose | 81 | 12.7% | 14 | 14.0% |
| compare_options | 49 | 7.7% | 9 | 9.0% |
| navigate_constraints | 17 | 2.7% | 1 | 1.0% |
| unclear_goal | 11 | 1.7% | 0 | 0.0% |

## CareerNet ratings of human answers

Frame = every eligible answer; sample = the chosen human answer per question.

### correctness

| correctness | frame_n | frame_share | sample_n | sample_share |
|---|---|---|---|---|
| 4 - Fully Correct | 832 | 71.2% | 74 | 74.0% |
| 3 - Mostly Correct | 288 | 24.6% | 20 | 20.0% |
| 2 - Mostly Incorrect | 49 | 4.2% | 6 | 6.0% |

Mean correctness_num: frame 3.67, sample 3.68

### completeness

| completeness | frame_n | frame_share | sample_n | sample_share |
|---|---|---|---|---|
| 4 - Fully Complete | 335 | 28.7% | 32 | 32.0% |
| 3 - Mostly Complete | 392 | 33.5% | 35 | 35.0% |
| 2 - Somewhat Incomplete | 376 | 32.2% | 27 | 27.0% |
| 1 - Very Incomplete | 66 | 5.6% | 6 | 6.0% |

Mean completeness_num: frame 2.85, sample 2.93

### coherency

| coherency | frame_n | frame_share | sample_n | sample_share |
|---|---|---|---|---|
| 4 - Fully Coherent | 709 | 60.7% | 70 | 70.0% |
| 3 - Mostly Coherent | 386 | 33.0% | 21 | 21.0% |
| 2 - Mostly Incoherent | 72 | 6.2% | 9 | 9.0% |
| 1 - Completely Incoherent | 2 | 0.2% | 0 | 0.0% |

Mean coherency_num: frame 3.54, sample 3.61

## Occupation: SOC major groups (descriptive only)

Share with no career mentioned: frame 55.3%, sample 56.0%

A question counts once under every major group it lists. Flags are shown as [flag] rows.

| soc_major_group | frame_n | frame_share | sample_n | sample_share |
|---|---|---|---|---|
| [flag] no_career_mentioned | 352 | 55.3% | 56 | 56.0% |
| Healthcare Practitioners and Technical Occupations | 52 | 8.2% | 2 | 2.0% |
| Arts, Design, Entertainment, Sports, and Media Occupations | 46 | 7.2% | 5 | 5.0% |
| Life, Physical, and Social Science Occupations | 44 | 6.9% | 4 | 4.0% |
| Business and Financial Operations Occupations | 41 | 6.4% | 5 | 5.0% |
| Management Occupations | 40 | 6.3% | 3 | 3.0% |
| Computer and Mathematical Occupations | 39 | 6.1% | 11 | 11.0% |
| Architecture and Engineering Occupations | 33 | 5.2% | 10 | 10.0% |
| Educational Instruction and Library Occupations | 16 | 2.5% | 2 | 2.0% |
| Sales and Related Occupations | 11 | 1.7% | 4 | 4.0% |
| Community and Social Service Occupations | 9 | 1.4% | 1 | 1.0% |
| Office and Administrative Support Occupations | 9 | 1.4% | 3 | 3.0% |
| Legal Occupations | 8 | 1.3% | 1 | 1.0% |
| Personal Care and Service Occupations | 7 | 1.1% | 1 | 1.0% |
| Production Occupations | 7 | 1.1% | 0 | 0.0% |
| Construction and Extraction Occupations | 6 | 0.9% | 1 | 1.0% |
| Food Preparation and Serving Related Occupations | 6 | 0.9% | 1 | 1.0% |
| Healthcare Support Occupations | 5 | 0.8% | 0 | 0.0% |
| Installation, Maintenance, and Repair Occupations | 4 | 0.6% | 2 | 2.0% |
| [flag] not_aligned | 3 | 0.5% | 0 | 0.0% |
| Military Specific Occupations | 3 | 0.5% | 0 | 0.0% |
| Protective Service Occupations | 3 | 0.5% | 1 | 1.0% |
| Transportation and Material Moving Occupations | 1 | 0.2% | 1 | 1.0% |

## careernet_reasoning_label (descriptive only)

Assigned by a fine-tuned GPT-4.1-mini (limited reliability). Frame = every eligible answer; sample = chosen human answers. An answer counts once under every category it carries.

| reasoning_category | frame_n | frame_share | sample_n | sample_share |
|---|---|---|---|---|
| No reasoning - explanation only | 460 | 39.3% | 40 | 40.0% |
| Predictive Causal Reasoning/Interventional Reasoning | 355 | 30.4% | 29 | 29.0% |
| Analogy about next steps | 274 | 23.4% | 30 | 30.0% |
| Necessary Conditions | 198 | 16.9% | 16 | 16.0% |
| Associational/Normative reasoning | 160 | 13.7% | 14 | 14.0% |
| Inductive Reasoning | 41 | 3.5% | 3 | 3.0% |
| Counterfactual Reasoning | 23 | 2.0% | 0 | 0.0% |
| Analogy about current circumstances | 21 | 1.8% | 2 | 2.0% |

