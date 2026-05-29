# CareerNet Response Quality Analysis

Exploratory analysis of a CareerNet dataset containing career-advice Q&A pairs, each human-rated on three quality dimensions. The goal is to understand what characteristics of questions and answers predict higher quality ratings.

## Dataset

~144,000 Q&A pairs drawn from three career domains:

| File | Domain | Records |
|------|--------|---------|
| `data/general.csv` | General career advice | ~81,600 |
| `data/health.csv` | Healthcare careers | ~31,600 |
| `data/technology.csv` | Technology careers | ~30,800 |

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
Rscript "analysis/04_response_length/01_response_length_all_analysis.R"
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
The starting point. Displays the lowest and highest-rated responses side by side to build intuition for what separates a poor answer from an excellent one before any formal analysis.

#### Score Distribution · `analysis/01_score_distribution/`
Distributions of completeness, coherency, correctness, and the composite score across the full dataset. Establishes the baseline shape of quality ratings.

Output: `plots/score_distribution/score_distribution.pdf`

---

### Question-side analyses
*What properties of the question predict answer quality?*

#### Prompt Length · `analysis/02_prompt_length/`
Does a longer question attract a better answer? Runs correlation and regression for all domains combined and for each domain separately. Outliers removed before modelling.

Outputs: `plots/prompt_length/`, `outputs/prompt_length/`

| Script | Scope |
|--------|-------|
| `01_prompt_length_all_analysis.R` | All domains |
| `02_prompt_length_general_analysis.R` | General |
| `03_prompt_length_healthcare_analysis.R` | Healthcare |
| `04_prompt_length_technology_analysis.R` | Technology |

#### Prompt Text · `analysis/03_prompt_text/`
What words and phrases appear in high-quality vs. low-quality questions? Uses TF-IDF and log-odds ratio to surface the language that distinguishes each group. Two threshold variants: composite > 3.0 and composite > 3.5.

Outputs: `plots/prompt_text/`, `outputs/prompt_text/`

---

### Answer-side analyses
*What properties of the answer predict its quality rating?*

#### Response Length · `analysis/04_response_length/`
Same structure as prompt length but applied to answers. Examines whether longer responses score higher and whether that pattern holds across domains.

Outputs: `plots/response_length/`, `outputs/response_length/`

| Script | Scope |
|--------|-------|
| `01_response_length_all_analysis.R` | All domains |
| `02_response_length_general_analysis.R` | General |
| `03_response_length_healthcare_analysis.R` | Healthcare |
| `04_response_length_technology_analysis.R` | Technology |

#### Response Text · `analysis/05_response_text/`
Mirror of the prompt text analysis applied to answer content. Identifies words and phrases that characterise high-scoring vs. low-scoring answers. Two threshold variants: composite > 3.0 and composite > 3.5.

Outputs: `plots/response_text/`, `outputs/response_text/`

---

### Contextual factors
*Does the topic or intent of the question shape how well it gets answered?*

#### Scenario & Intent · `analysis/06_scenario_intent/`
Analyses scenario labels (e.g. job search, career change) and intent flags (e.g. `explore_options`, `take_action`) independently, then jointly, to see which question contexts systematically attract better answers.

| Script | Question answered |
|--------|------------------|
| `01_scenario_quality.R` | Which career scenarios get the highest-quality answers? |
| `02_intent_quality.R` | Which prompt intents predict better answers? |
| `03_scenario_intent_combined.R` | How do scenario and intent interact? |

Outputs: `plots/scenario_intent/`, `outputs/scenario_intent/`
