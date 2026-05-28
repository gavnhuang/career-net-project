# ============================================================
# CAREERNET DATA EXPLORATION
# ============================================================

# Purpose:
# Explore examples of low and high completeness responses
# from the General CareerNet dataset.

# IMPORTANT:
# This script assumes you opened the .Rproj file first.
# Your working directory should already be the main Project folder.

# ============================================================
# 1. LOAD LIBRARIES
# ============================================================

library(tidyverse)
library(tidytext)
library(stringr)

# ============================================================
# 2. LOAD DATASETS
# ============================================================

general <- read_csv(
  "data/general.csv",
  show_col_types = FALSE
)

health <- read_csv(
  "data/health.csv",
  show_col_types = FALSE
)

technology <- read_csv(
  "data/technology.csv",
  show_col_types = FALSE
)

# ============================================================
# 3. CLEAN TEXT
# ============================================================

general <- general %>%
  
  mutate(
    
    # Remove HTML formatting
    answer_body = str_remove_all(
      answer_body,
      "<.*?>"
    )
    
  )

# ============================================================
# 4. LOWEST COMPLETENESS RESPONSES
# ============================================================

lowest_responses <- general %>%
  
  arrange(completeness) %>%
  
  select(
    answer_body,
    completeness,
    coherency,
    correctness,
    question_title
  ) %>%
  
  slice(1:5)

cat("\n")
cat("====================================================\n")
cat("LOWEST COMPLETENESS RESPONSES\n")
cat("====================================================\n\n")

View(lowest_responses)

# Print first low-quality response fully

cat("FIRST LOWEST COMPLETENESS RESPONSE:\n\n")

lowest_responses %>%
  slice(1) %>%
  pull(answer_body) %>%
  cat()

# ============================================================
# 5. HIGHEST COMPLETENESS RESPONSES
# ============================================================

highest_responses <- general %>%
  
  arrange(desc(completeness)) %>%
  
  select(
    answer_body,
    completeness,
    coherency,
    correctness,
    question_title
  ) %>%
  
  slice(1:5)

cat("\n\n")
cat("====================================================\n")
cat("HIGHEST COMPLETENESS RESPONSES\n")
cat("====================================================\n\n")

View(highest_responses)

# Print first high-quality response fully

cat("FIRST HIGHEST COMPLETENESS RESPONSE:\n\n")

highest_responses %>%
  slice(1) %>%
  pull(answer_body) %>%
  cat()

# ============================================================
# 6. QUICK INTERPRETATION
# ============================================================

cat("\n\n")
cat("====================================================\n")
cat("INTERPRETATION GUIDE\n")
cat("====================================================\n\n")

cat(
  "Compare the low and high completeness responses.\n"
)

cat(
  "Look for differences in:\n\n"
)

cat(
  "- response length\n"
)

cat(
  "- level of detail\n"
)

cat(
  "- structure and organization\n"
)

cat(
  "- specificity\n"
)

cat(
  "- actionable advice\n"
)

cat(
  "- examples or explanations\n\n"
)

cat(
  "This helps build intuition for what the raters\n"
)

cat(
  "considered complete versus incomplete responses.\n"
)