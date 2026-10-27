# ============================================================
# SCENARIO INTENT ANALYSIS — SHARED HELPERS
# ============================================================

source("analysis/00_data_helpers.R")

library(tidyverse)
library(tidytext)
library(stringr)

load_all_data <- load_all_domains

parse_quality_scores <- function(data) {
  data %>%
    mutate(
      completeness_num = as.numeric(str_extract(completeness, "^[1-4]")),
      coherency_num    = as.numeric(str_extract(coherency,    "^[1-4]")),
      correctness_num  = as.numeric(str_extract(correctness,  "^[1-4]"))
    ) %>%
    filter(
      !is.na(completeness_num),
      !is.na(coherency_num),
      !is.na(correctness_num)
    ) %>%
    mutate(
      composite_quality = (completeness_num + coherency_num + correctness_num) / 3
    )
}

# Extracts the first (primary) label from a semicolon-separated ScenarioLabels string.
# Returns NA when input is NA.
extract_primary_label <- function(x) {
  map_chr(str_split(x, ";"), ~ trimws(.x[[1]]))
}

INTENT_COLS <- c(
  "explore_options",
  "take_action",
  "understanding_purpose",
  "validation_support",
  "find_resources",
  "navigate_constraints",
  "compare_options",
  "unclear_goal"
)

INTENT_LABELS <- c(
  explore_options       = "Explore Options",
  take_action           = "Take Action",
  understanding_purpose = "Understanding Purpose",
  validation_support    = "Validation / Support",
  find_resources        = "Find Resources",
  navigate_constraints  = "Navigate Constraints",
  compare_options       = "Compare Options",
  unclear_goal          = "Unclear Goal"
)

# These two intent columns have only one possible sub-value so sub-intent
# breakdown is not meaningful for them.
SINGLE_VALUE_INTENTS <- c("understanding_purpose", "unclear_goal")

scenario_intent_theme <- function() {
  theme_minimal(base_size = 11) +
    theme(
      plot.title    = element_text(face = "bold", size = 13),
      plot.subtitle = element_text(size = 10, color = "gray40"),
      plot.caption  = element_text(size = 8,  color = "gray50"),
      axis.text     = element_text(size = 9)
    )
}
