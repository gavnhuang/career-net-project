# Study sample (DRY RUN): n = 90, floor = 3

> **DRY RUN. NOT THE STUDY SAMPLE.** The OSF pre-registration is not marked as posted
> (`preregistration_posted` / `osf_url` in the config). This draw uses a separate dry-run seed,
> so it does not preview the real sample. Do not use these questions for anything.

Run `20261027-124028-04-DRY_RUN` · draw seed 146283223 (derive_seed(master_seed, "study_draw_DRY_RUN")) · frame v1.1

## Counts at each stage

| stage | questions |
|---|---|
| Frame (01) | 2,214 |
| Reserved sets (03) | 57 |
| frame_remaining (sampling frame) | 2,157 |
| Selected at the floor stage | 22 |
| Selected by random fill | 68 |
| Study sample | 90 |

## Floor stage

Labels are processed rarest first (count in frame_remaining).

| order | label | available_in_frame_remaining | floor_slots_this_draw |
|---|---|---|---|
| 1 | Workplace Dynamics | 31 | 3 |
| 2 | Non-Degree Certifications/Credentials | 37 | 3 |
| 3 | Interview Preparation | 41 | 2 |
| 4 | Freelancing/Self-Employment/Entrepreneurship | 58 | 3 |
| 5 | First Job Navigation | 100 | 2 |
| 6 | Networking and Mentorship | 125 | 1 |
| 7 | Resume/CV/LinkedIn Optimization and Personal Branding | 157 | 0 |
| 8 | Skill Development | 202 | 2 |
| 9 | Job Search Strategies and Infrastructure | 235 | 3 |
| 10 | Work-Life Balance and Personal Values Alignment | 241 | 2 |
| 11 | College Queries | 381 | 1 |
| 12 | Career Decision-Making, Transitioning, and Exploration Resources | 718 | 0 |
| 13 | Industry-Specific Knowledge and Trends | 1,090 | 0 |

Floor slots used across 10,000 simulated draws: mean 24.33, SD 2.10, range 15-32. This draw: 22.

## Scenario label coverage

frame = frame_remaining. A question counts toward every label it carries.

| label | guaranteed | frame_n | frame_share | sample_n | sample_share | expected_if_srs | floor_check |
|---|---|---|---|---|---|---|---|
| Industry-Specific Knowledge and Trends | yes | 1,090 | 50.5% | 50 | 55.6% | 45.5 | PASS |
| Career Decision-Making, Transitioning, and Exploration Resources | yes | 718 | 33.3% | 28 | 31.1% | 30.0 | PASS |
| College Queries | yes | 381 | 17.7% | 13 | 14.4% | 15.9 | PASS |
| Work-Life Balance and Personal Values Alignment | yes | 241 | 11.2% | 13 | 14.4% | 10.1 | PASS |
| Job Search Strategies and Infrastructure | yes | 235 | 10.9% | 9 | 10.0% | 9.8 | PASS |
| Skill Development | yes | 202 | 9.4% | 10 | 11.1% | 8.4 | PASS |
| Resume/CV/LinkedIn Optimization and Personal Branding | yes | 157 | 7.3% | 8 | 8.9% | 6.6 | PASS |
| Networking and Mentorship | yes | 125 | 5.8% | 7 | 7.8% | 5.2 | PASS |
| First Job Navigation | yes | 100 | 4.6% | 8 | 8.9% | 4.2 | PASS |
| Freelancing/Self-Employment/Entrepreneurship | yes | 58 | 2.7% | 3 | 3.3% | 2.4 | PASS |
| Interview Preparation | yes | 41 | 1.9% | 4 | 4.4% | 1.7 | PASS |
| Non-Degree Certifications/Credentials | yes | 37 | 1.7% | 6 | 6.7% | 1.5 | PASS |
| Workplace Dynamics | yes | 31 | 1.4% | 6 | 6.7% | 1.3 | PASS |
| International Careers |  | 24 | 1.1% | 2 | 2.2% | 1.0 | n/a |
| Barriers, Equity, and Resource Considerations |  | 19 | 0.9% | 2 | 2.2% | 0.8 | n/a |
| Job Offers and Negotiations |  | 5 | 0.2% | 0 | 0.0% | 0.2 | n/a |
| Career Advancement |  | 4 | 0.2% | 0 | 0.0% | 0.2 | n/a |
| Mid-Career Pivots |  | 1 | 0.0% | 1 | 1.1% | 0.0 | n/a |

## Inclusion probabilities and weights

Estimated from 10,000 re-runs of the draw (derive_seed(master_seed, "inclusion_rep_<r>") for r = 1..10000). weight = 1 / inclusion_prob, normalized to mean 1 over the sample.

| quantity | min | median | max |
|---|---|---|---|
| inclusion_prob, frame_remaining | 0.0254 | 0.0345 | 0.2035 |
| inclusion_prob, sample | 0.0281 | 0.0371 | 0.2035 |
| weight, sample | 0.2046 | 1.1225 | 1.4819 |

Simple random sampling would give every question 0.0417. Questions never selected in any simulated draw: 0.

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

Answer length: median 150 words (range 44-583). Questions with one eligible answer: 18; with several: 72.

## Goals (question level)

A question counts once under every goal column that is not missing.

| goal | frame_n | frame_share | sample_n | sample_share |
|---|---|---|---|---|
| explore_options | 1,248 | 57.9% | 42 | 46.7% |
| take_action | 970 | 45.0% | 42 | 46.7% |
| validation_support | 620 | 28.7% | 27 | 30.0% |
| find_resources | 422 | 19.6% | 21 | 23.3% |
| understanding_purpose | 282 | 13.1% | 16 | 17.8% |
| compare_options | 174 | 8.1% | 5 | 5.6% |
| navigate_constraints | 60 | 2.8% | 6 | 6.7% |

## CareerNet ratings of human answers

Frame = every eligible answer; sample = the chosen human answer per question.

### correctness

| correctness | frame_n | frame_share | sample_n | sample_share |
|---|---|---|---|---|
| 4 - Fully Correct | 3,632 | 76.3% | 64 | 71.1% |
| 3 - Mostly Correct | 1,000 | 21.0% | 20 | 22.2% |
| 2 - Mostly Incorrect | 125 | 2.6% | 6 | 6.7% |
| 1 - Completely Incorrect | 6 | 0.1% | 0 | 0.0% |

Mean correctness_num: frame 3.73, sample 3.64

### completeness

| completeness | frame_n | frame_share | sample_n | sample_share |
|---|---|---|---|---|
| 4 - Fully Complete | 1,858 | 39.0% | 36 | 40.0% |
| 3 - Mostly Complete | 1,381 | 29.0% | 26 | 28.9% |
| 2 - Somewhat Incomplete | 1,297 | 27.2% | 22 | 24.4% |
| 1 - Very Incomplete | 227 | 4.8% | 6 | 6.7% |

Mean completeness_num: frame 3.02, sample 3.02

### coherency

| coherency | frame_n | frame_share | sample_n | sample_share |
|---|---|---|---|---|
| 4 - Fully Coherent | 3,492 | 73.3% | 63 | 70.0% |
| 3 - Mostly Coherent | 1,093 | 22.9% | 22 | 24.4% |
| 2 - Mostly Incoherent | 174 | 3.7% | 5 | 5.6% |
| 1 - Completely Incoherent | 4 | 0.1% | 0 | 0.0% |

Mean coherency_num: frame 3.69, sample 3.64

## Occupation: SOC major groups (descriptive only)

Share with no career mentioned: frame 46.7%, sample 35.6%

A question counts once under every major group it lists. Flags are shown as [flag] rows.

| soc_major_group | frame_n | frame_share | sample_n | sample_share |
|---|---|---|---|---|
| [flag] no_career_mentioned | 1,007 | 46.7% | 32 | 35.6% |
| Healthcare Practitioners and Technical Occupations | 207 | 9.6% | 8 | 8.9% |
| Arts, Design, Entertainment, Sports, and Media Occupations | 172 | 8.0% | 7 | 7.8% |
| Life, Physical, and Social Science Occupations | 158 | 7.3% | 7 | 7.8% |
| Computer and Mathematical Occupations | 141 | 6.5% | 8 | 8.9% |
| Business and Financial Operations Occupations | 130 | 6.0% | 9 | 10.0% |
| Educational Instruction and Library Occupations | 128 | 5.9% | 4 | 4.4% |
| Management Occupations | 126 | 5.8% | 6 | 6.7% |
| Architecture and Engineering Occupations | 113 | 5.2% | 6 | 6.7% |
| Community and Social Service Occupations | 67 | 3.1% | 8 | 8.9% |
| Personal Care and Service Occupations | 38 | 1.8% | 0 | 0.0% |
| Office and Administrative Support Occupations | 32 | 1.5% | 3 | 3.3% |
| Sales and Related Occupations | 32 | 1.5% | 1 | 1.1% |
| Legal Occupations | 31 | 1.4% | 0 | 0.0% |
| Protective Service Occupations | 30 | 1.4% | 1 | 1.1% |
| Food Preparation and Serving Related Occupations | 28 | 1.3% | 1 | 1.1% |
| Healthcare Support Occupations | 26 | 1.2% | 3 | 3.3% |
| Construction and Extraction Occupations | 21 | 1.0% | 1 | 1.1% |
| Production Occupations | 18 | 0.8% | 1 | 1.1% |
| Installation, Maintenance, and Repair Occupations | 14 | 0.6% | 2 | 2.2% |
| Military Specific Occupations | 9 | 0.4% | 1 | 1.1% |
| Transportation and Material Moving Occupations | 9 | 0.4% | 1 | 1.1% |
| [flag] not_aligned | 8 | 0.4% | 1 | 1.1% |
| Farming, Fishing, and Forestry Occupations | 4 | 0.2% | 0 | 0.0% |
| Building and Grounds Cleaning and Maintenance Occupations | 1 | 0.0% | 0 | 0.0% |

## careernet_reasoning_label (descriptive only)

Assigned by a fine-tuned GPT-4.1-mini (limited reliability). Frame = every eligible answer; sample = chosen human answers. An answer counts once under every category it carries.

| reasoning_category | frame_n | frame_share | sample_n | sample_share |
|---|---|---|---|---|
| Predictive Causal Reasoning/Interventional Reasoning | 2,183 | 45.8% | 40 | 44.4% |
| No reasoning - explanation only | 1,426 | 29.9% | 26 | 28.9% |
| Necessary Conditions | 1,019 | 21.4% | 21 | 23.3% |
| Analogy about next steps | 945 | 19.8% | 19 | 21.1% |
| Associational/Normative reasoning | 602 | 12.6% | 13 | 14.4% |
| Inductive Reasoning | 190 | 4.0% | 6 | 6.7% |
| Counterfactual Reasoning | 154 | 3.2% | 2 | 2.2% |
| Analogy about current circumstances | 84 | 1.8% | 3 | 3.3% |

