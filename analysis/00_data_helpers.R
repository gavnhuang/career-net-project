# ============================================================
# SHARED DATA LOADING
# ============================================================
# Every analysis script loads CareerNet data through this file.
# To switch all analyses to a different dataset release, change
# DATA_VERSION below.
#
# v1.0 — original release (28 columns)
# v1.1 — public release; identical to v1.0 plus two columns:
#          soc_code        — semicolon-separated O*NET/SOC occupation
#                            hierarchy for careers mentioned in the question
#          reasoning_label — semicolon-separated reasoning type(s) in the answer

library(tidyverse)

DATA_VERSION <- "v1.1"

DATA_FILES <- list(
  v1.0 = c(
    General    = "data/v1.0/general.csv",
    Healthcare = "data/v1.0/health.csv",
    Technology = "data/v1.0/technology.csv"
  ),
  v1.1 = c(
    General    = "data/v1.1/general_public_v1.1.csv",
    Healthcare = "data/v1.1/health_public_v1.1.csv",
    Technology = "data/v1.1/technology_public_v1.1.csv"
  )
)

domain_files <- DATA_FILES[[DATA_VERSION]]

# Loads one domain ("General", "Healthcare", or "Technology") and tags it.
load_domain <- function(domain) {
  read_csv(domain_files[[domain]], show_col_types = FALSE) %>%
    mutate(domain = domain)
}

# Loads all three domains stacked into one data frame with a `domain` column.
load_all_domains <- function() {
  imap_dfr(domain_files, ~ read_csv(.x, show_col_types = FALSE) %>% mutate(domain = .y))
}
