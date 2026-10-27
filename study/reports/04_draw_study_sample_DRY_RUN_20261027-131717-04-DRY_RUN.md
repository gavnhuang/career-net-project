# Study sample (DRY RUN): n = 90, floor = 3

> **DRY RUN. NOT THE STUDY SAMPLE.** The OSF pre-registration is not marked as posted
> (`preregistration_posted` / `osf_url` in the config). This draw uses a separate dry-run seed,
> so it does not preview the real sample. Do not use these questions for anything.

Run `20261027-131717-04-DRY_RUN` · frame v1.1

- Seed base: 20261027 = master_seed (dry run; the DOI seed is never used)
- Draw seed: 146283223 = derive_seed(seed base, "study_draw_DRY_RUN")
- Inclusion reps and replacement queues derive from the same seed base.

## Counts at each stage

| stage | questions |
|---|---|
| Frame (01) | 681 |
| Reserved sets (03) | 57 |
| frame_remaining (sampling frame) | 624 |
| Selected at the floor stage | 15 |
| Selected by random fill | 75 |
| Study sample | 90 |

## Floor stage

Labels are processed rarest first (count in frame_remaining).

| order | label | available_in_frame_remaining | floor_slots_this_draw |
|---|---|---|---|
| 1 | Skill Development | 37 | 3 |
| 2 | Networking and Mentorship | 51 | 3 |
| 3 | Resume/CV/LinkedIn Optimization and Personal Branding | 62 | 2 |
| 4 | Work-Life Balance and Personal Values Alignment | 66 | 3 |
| 5 | Job Search Strategies and Infrastructure | 77 | 2 |
| 6 | College Queries | 93 | 0 |
| 7 | Career Decision-Making, Transitioning, and Exploration Resources | 212 | 2 |
| 8 | Industry-Specific Knowledge and Trends | 260 | 0 |

Floor slots used across 10,000 simulated draws: mean 16.39, SD 1.53, range 11-21. This draw: 15.

## Scenario label coverage

frame = frame_remaining. A question counts toward every label it carries.

| label | guaranteed | frame_n | frame_share | sample_n | sample_share | expected_if_srs | floor_check |
|---|---|---|---|---|---|---|---|
| Industry-Specific Knowledge and Trends | yes | 260 | 41.7% | 36 | 40.0% | 37.5 | PASS |
| Career Decision-Making, Transitioning, and Exploration Resources | yes | 212 | 34.0% | 33 | 36.7% | 30.6 | PASS |
| College Queries | yes | 93 | 14.9% | 11 | 12.2% | 13.4 | PASS |
| Job Search Strategies and Infrastructure | yes | 77 | 12.3% | 14 | 15.6% | 11.1 | PASS |
| Work-Life Balance and Personal Values Alignment | yes | 66 | 10.6% | 9 | 10.0% | 9.5 | PASS |
| Resume/CV/LinkedIn Optimization and Personal Branding | yes | 62 | 9.9% | 13 | 14.4% | 8.9 | PASS |
| Networking and Mentorship | yes | 51 | 8.2% | 9 | 10.0% | 7.4 | PASS |
| Skill Development | yes | 37 | 5.9% | 5 | 5.6% | 5.3 | PASS |
| First Job Navigation |  | 27 | 4.3% | 2 | 2.2% | 3.9 | n/a |
| Non-Degree Certifications/Credentials |  | 14 | 2.2% | 0 | 0.0% | 2.0 | n/a |
| Workplace Dynamics |  | 13 | 2.1% | 0 | 0.0% | 1.9 | n/a |
| Freelancing/Self-Employment/Entrepreneurship |  | 12 | 1.9% | 0 | 0.0% | 1.7 | n/a |
| Interview Preparation |  | 11 | 1.8% | 1 | 1.1% | 1.6 | n/a |
| International Careers |  | 8 | 1.3% | 1 | 1.1% | 1.2 | n/a |
| Barriers, Equity, and Resource Considerations |  | 6 | 1.0% | 0 | 0.0% | 0.9 | n/a |
| Job Offers and Negotiations |  | 1 | 0.2% | 1 | 1.1% | 0.1 | n/a |
| Career Advancement |  | 1 | 0.2% | 0 | 0.0% | 0.1 | n/a |
| Mid-Career Pivots |  | 0 | 0.0% | 0 | 0.0% | 0.0 | n/a |

Labels present in the sample: 12 of 18 (8 of 8 guaranteed, 4 not guaranteed).

Guaranteed labels are those with at least 30 eligible questions (10 x floor) in the frame. Not guaranteed: First Job Navigation (29), Interview Preparation (15), Workplace Dynamics (15), Non-Degree Certifications/Credentials (14), Freelancing/Self-Employment/Entrepreneurship (12), International Careers (8), Barriers, Equity, and Resource Considerations (6), Job Offers and Negotiations (1), Career Advancement (1), Mid-Career Pivots (0). First Job Navigation has 29 eligible questions and is not guaranteed.

## Inclusion probabilities and weights

Estimated from 10,000 re-runs of the draw (derive_seed(20261027, "inclusion_rep_<r>") for r = 1..10000). weight = 1 / inclusion_prob, normalized to mean 1 over the sample.

| quantity | min | median | max |
|---|---|---|---|
| inclusion_prob, frame_remaining | 0.1130 | 0.1381 | 0.2400 |
| inclusion_prob, sample | 0.1137 | 0.1396 | 0.2290 |
| weight, sample | 0.6226 | 1.0213 | 1.2540 |

Simple random sampling would give every question 0.1442. Questions never selected in any simulated draw: 0.

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

## Human answers

Display length: median 111.5 words (range 39-540); targets for generation are display length ± 20%. Questions with one eligible answer: 38; with several: 52.

- Opening salutation removed: 37 of 90
- Closing sign-off or signature removed: 15 of 90
- Either: 41 of 90
- has_list: 11 of 90 (lists not changed; decision pending)
- Question body empty after hashtag removal (title only): 7

## Screening

`screening_sheet_round1_DRY_RUN.csv` lists the 90 drawn questions (question text only, in question_id order). Fill rule2-rule4, excluded, screener and notes, then run `05_apply_screening.R`. Replacement queues: general (534 questions) and one per guaranteed label.

## Goals (question level)

A question counts once under every goal column that is not missing.

| goal | frame_n | frame_share | sample_n | sample_share |
|---|---|---|---|---|
| explore_options | 347 | 55.6% | 50 | 55.6% |
| take_action | 281 | 45.0% | 30 | 33.3% |
| validation_support | 225 | 36.1% | 44 | 48.9% |
| find_resources | 136 | 21.8% | 23 | 25.6% |
| understanding_purpose | 83 | 13.3% | 13 | 14.4% |
| compare_options | 49 | 7.9% | 6 | 6.7% |
| navigate_constraints | 21 | 3.4% | 3 | 3.3% |

## CareerNet ratings of human answers

Frame = every eligible answer; sample = the chosen human answer per question.

### correctness

| correctness | frame_n | frame_share | sample_n | sample_share |
|---|---|---|---|---|
| 4 - Fully Correct | 796 | 69.5% | 67 | 74.4% |
| 3 - Mostly Correct | 296 | 25.9% | 18 | 20.0% |
| 2 - Mostly Incorrect | 52 | 4.5% | 5 | 5.6% |
| 1 - Completely Incorrect | 1 | 0.1% | 0 | 0.0% |

Mean correctness_num: frame 3.65, sample 3.69

### completeness

| completeness | frame_n | frame_share | sample_n | sample_share |
|---|---|---|---|---|
| 4 - Fully Complete | 326 | 28.5% | 22 | 24.4% |
| 3 - Mostly Complete | 379 | 33.1% | 34 | 37.8% |
| 2 - Somewhat Incomplete | 368 | 32.1% | 30 | 33.3% |
| 1 - Very Incomplete | 72 | 6.3% | 4 | 4.4% |

Mean completeness_num: frame 2.84, sample 2.82

### coherency

| coherency | frame_n | frame_share | sample_n | sample_share |
|---|---|---|---|---|
| 4 - Fully Coherent | 688 | 60.1% | 51 | 56.7% |
| 3 - Mostly Coherent | 381 | 33.3% | 35 | 38.9% |
| 2 - Mostly Incoherent | 74 | 6.5% | 4 | 4.4% |
| 1 - Completely Incoherent | 2 | 0.2% | 0 | 0.0% |

Mean coherency_num: frame 3.53, sample 3.52

## Occupation: SOC major groups (descriptive only)

Share with no career mentioned: frame 55.1%, sample 62.2%

A question counts once under every major group it lists. Flags are shown as [flag] rows.

| soc_major_group | frame_n | frame_share | sample_n | sample_share |
|---|---|---|---|---|
| [flag] no_career_mentioned | 344 | 55.1% | 56 | 62.2% |
| Healthcare Practitioners and Technical Occupations | 48 | 7.7% | 7 | 7.8% |
| Life, Physical, and Social Science Occupations | 46 | 7.4% | 6 | 6.7% |
| Arts, Design, Entertainment, Sports, and Media Occupations | 43 | 6.9% | 1 | 1.1% |
| Computer and Mathematical Occupations | 38 | 6.1% | 4 | 4.4% |
| Business and Financial Operations Occupations | 37 | 5.9% | 5 | 5.6% |
| Management Occupations | 36 | 5.8% | 4 | 4.4% |
| Architecture and Engineering Occupations | 33 | 5.3% | 6 | 6.7% |
| Educational Instruction and Library Occupations | 20 | 3.2% | 1 | 1.1% |
| Community and Social Service Occupations | 11 | 1.8% | 3 | 3.3% |
| Office and Administrative Support Occupations | 9 | 1.4% | 3 | 3.3% |
| Personal Care and Service Occupations | 8 | 1.3% | 2 | 2.2% |
| Sales and Related Occupations | 8 | 1.3% | 1 | 1.1% |
| Legal Occupations | 7 | 1.1% | 0 | 0.0% |
| Production Occupations | 7 | 1.1% | 1 | 1.1% |
| Construction and Extraction Occupations | 6 | 1.0% | 1 | 1.1% |
| Food Preparation and Serving Related Occupations | 6 | 1.0% | 1 | 1.1% |
| Healthcare Support Occupations | 6 | 1.0% | 2 | 2.2% |
| Installation, Maintenance, and Repair Occupations | 4 | 0.6% | 0 | 0.0% |
| [flag] not_aligned | 3 | 0.5% | 0 | 0.0% |
| Military Specific Occupations | 3 | 0.5% | 0 | 0.0% |
| Protective Service Occupations | 2 | 0.3% | 0 | 0.0% |
| Transportation and Material Moving Occupations | 1 | 0.2% | 0 | 0.0% |

## careernet_reasoning_label (descriptive only)

Assigned by a fine-tuned GPT-4.1-mini (limited reliability). Frame = every eligible answer; sample = chosen human answers. An answer counts once under every category it carries.

| reasoning_category | frame_n | frame_share | sample_n | sample_share |
|---|---|---|---|---|
| No reasoning - explanation only | 445 | 38.9% | 44 | 48.9% |
| Predictive Causal Reasoning/Interventional Reasoning | 345 | 30.1% | 26 | 28.9% |
| Analogy about next steps | 286 | 25.0% | 15 | 16.7% |
| Necessary Conditions | 184 | 16.1% | 13 | 14.4% |
| Associational/Normative reasoning | 153 | 13.4% | 7 | 7.8% |
| Inductive Reasoning | 38 | 3.3% | 2 | 2.2% |
| Analogy about current circumstances | 25 | 2.2% | 1 | 1.1% |
| Counterfactual Reasoning | 25 | 2.2% | 1 | 1.1% |

