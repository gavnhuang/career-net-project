# Career Net Project

## Project Overview
R-based data analysis project exploring CareerNet dataset responses across three domains: General, Healthcare, and Technology.

## Working Directory
Always run R scripts from the project root (`Project/`), not from subdirectories. Scripts use relative paths based on that root.

## Project Structure
```
Project/
├── data/
│   ├── general.csv
│   ├── health.csv
│   └── technology.csv
├── analysis/
│   ├── 00_data_exploration/
│   ├── 01_score_distribution/
│   ├── 02_question_length/
│   ├── 03_response_length/
│   └── 04_scenario_intent/
├── outputs/
└── plots/
```

## Running R Scripts
Run scripts from the project root so relative paths resolve correctly:

```bash
# Run a specific script
Rscript "analysis/03_response_length/01_response_length_all_analysis.R"

# Run all response length analyses
Rscript "analysis/03_response_length/01_response_length_all_analysis.R"
Rscript "analysis/03_response_length/02_response_length_general_analysis.R"
Rscript "analysis/03_response_length/03_response_length_healthcare_analysis.R"
Rscript "analysis/03_response_length/04_response_length_technology_analysis.R"

# Interactive R session
R --no-save --no-restore
```

## R Environment
- R version: 4.5.1
- Key packages: tidyverse, tidytext, stringr
- Install missing packages with: `install.packages(c("tidyverse", "tidytext", "stringr", "hexbin"))`

## Conventions
- Helper/shared functions go in `00_*_helpers.R` files and are sourced by other scripts
- Plots saved to `plots/`, tabular outputs saved to `outputs/`
- Data files in `data/` are read-only source files — do not modify them
