# CareerNet Response Quality Analysis

Exploratory analysis of a CareerNet dataset containing career-advice Q&A pairs, each human-rated on three quality dimensions. The goal is to understand what characteristics of questions and answers predict higher quality ratings.

## Dataset

~16,100 Q&A pairs drawn from three career domains:

| File | Domain | Answers | Unique questions |
|------|--------|---------|-----------------|
| `data/general.csv` | General career advice | 7,984 | 3,000 |
| `data/health.csv` | Healthcare careers | 4,069 | 1,500 |
| `data/technology.csv` | Technology careers | 4,077 | 1,500 |

Each question may have multiple answers (annotators rated each answer independently). Each file also includes a `Split` column marking rows as `Train` or `Test`. The current analyses use all rows — if a predictive model is built later, exploration should be repeated using only the `Train` rows.

Each row is one answer to a career question, rated by a human annotator on a 1–4 scale across three dimensions:

- **Completeness** — does the answer fully address the question?
- **Coherency** — is the answer well-structured and easy to follow?
- **Correctness** — is the information accurate?

A **composite quality score** (average of the three dimensions) is used throughout the analyses.

Additional columns capture the question's **scenario label** (e.g. job search, career change) and **intent flags** (e.g. `explore_options`, `take_action`, `find_resources`).

## Setup

Requires R 4.5+. Install dependencies once:

```r
install.packages(c("tidyverse", "tidytext", "stringr", "hexbin"))
```

Always run scripts from the **project root** (`Project/`) so relative paths to `data/`, `outputs/`, and `plots/` resolve correctly:

```bash
Rscript "analysis/03_response_length/01_response_length_all_analysis.R"
```

## Project Structure

```
analysis/          R scripts, grouped by analysis type
data/              Source CSV files (read-only)
outputs/           CSV summaries produced by the scripts
plots/             PDF plots produced by the scripts
```

## Analyses

### Getting oriented

#### Data Exploration · `analysis/00_data_exploration/`
The starting point. Two scripts for building intuition before formal analysis:

- **`First Impressions.R`** — prints the five lowest and five highest-rated responses (by completeness) from the General dataset so you can read concrete examples of what the rating scale means.
- **`Response Generator.R`** — interactive explorer: choose a domain and target scores for each dimension, then randomly sample matching Q&A pairs one at a time.

#### Score Distribution · `analysis/01_score_distribution/`
Distributions of completeness, coherency, correctness, and the composite score across the full dataset. Establishes the baseline shape of quality ratings.

Output: `plots/score_distribution/score_distribution.pdf`

---

### Question-side analyses
*What properties of the question predict answer quality?*

#### Question Length · `analysis/02_question_length/`
Does a longer question attract a better answer? Runs correlation and regression for all domains combined and for each domain separately. Outliers removed before modelling.

Outputs: `plots/question_length/`, `outputs/question_length/`

| Script | Scope |
|--------|-------|
| `01_question_length_all_analysis.R` | All domains |
| `02_question_length_general_analysis.R` | General |
| `03_question_length_healthcare_analysis.R` | Healthcare |
| `04_question_length_technology_analysis.R` | Technology |

---

### Answer-side analyses
*What properties of the answer predict its quality rating?*

#### Response Length · `analysis/03_response_length/`
Same structure as question length but applied to answers. Examines whether longer responses score higher and whether that pattern holds across domains.

Outputs: `plots/response_length/`, `outputs/response_length/`

| Script | Scope |
|--------|-------|
| `01_response_length_all_analysis.R` | All domains |
| `02_response_length_general_analysis.R` | General |
| `03_response_length_healthcare_analysis.R` | Healthcare |
| `04_response_length_technology_analysis.R` | Technology |

---

### Contextual factors
*Does the topic or intent of the question shape how well it gets answered?*

#### Scenario & Intent · `analysis/04_scenario_intent/`
Analyses scenario labels (e.g. job search, career change) and intent flags (e.g. `explore_options`, `take_action`) independently, then jointly, to see which question contexts systematically attract better answers.

| Script | Question answered |
|--------|------------------|
| `01_scenario_quality.R` | Which career scenarios get the highest-quality answers? |
| `02_intent_quality.R` | Which question intents predict better answers? |
| `03_scenario_intent_combined.R` | How do scenario and intent interact? |

Outputs: `plots/scenario_intent/`, `outputs/scenario_intent/`
