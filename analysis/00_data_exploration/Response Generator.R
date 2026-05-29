# ============================================================
# CAREERNET INTERACTIVE RANDOM RESPONSE EXPLORER
# ============================================================

# Purpose:
# Randomly explore CareerNet responses by selected ratings.
# This helps build intuition for what high-quality and low-quality
# responses look like.

# IMPORTANT:
# This script assumes you opened the .Rproj file first.
# Your working directory should be the main Project folder.

# ============================================================
# 1. LOAD LIBRARIES
# ============================================================

library(tidyverse)

# ============================================================
# 2. LOAD DATASETS
# ============================================================

general <- read_csv("data/general.csv", show_col_types = FALSE)
health <- read_csv("data/health.csv", show_col_types = FALSE)
technology <- read_csv("data/technology.csv", show_col_types = FALSE)

# ============================================================
# 3. HELPER FUNCTIONS
# ============================================================

clean_html <- function(data) {
  data %>%
    mutate(
      answer_body   = str_remove_all(answer_body,   "<.*?>"),
      question_body = str_remove_all(question_body, "<.*?>"),
      question_title = str_remove_all(question_title, "<.*?>")
    )
}

select_dataset <- function() {
  cat("\nChoose which dataset you want to explore:\n")
  cat("1 = General\n")
  cat("2 = Healthcare\n")
  cat("3 = Technology\n")
  cat("4 = All datasets combined\n\n")

  choice <- readline(prompt = "Enter choice (1-4): ")
  while (!trimws(choice) %in% c("1", "2", "3", "4")) {
    cat("\nInvalid choice. Please enter 1, 2, 3, or 4.\n")
    choice <- readline(prompt = "Enter choice (1-4): ")
  }

  switch(trimws(choice),
    "1" = list(
      data = general %>% mutate(domain = "General"),
      name = "General"
    ),
    "2" = list(
      data = health %>% mutate(domain = "Healthcare"),
      name = "Healthcare"
    ),
    "3" = list(
      data = technology %>% mutate(domain = "Technology"),
      name = "Technology"
    ),
    "4" = list(
      data = bind_rows(
        general    %>% mutate(domain = "General"),
        health     %>% mutate(domain = "Healthcare"),
        technology %>% mutate(domain = "Technology")
      ),
      name = "All Datasets Combined"
    )
  )
}

ask_score <- function(rating_name) {
  cat("\nChoose target", rating_name, "score:\n")
  cat("1 = Lowest rating\n")
  cat("2 = Somewhat low\n")
  cat("3 = Mostly good\n")
  cat("4 = Highest rating\n")
  cat("0 = Ignore this rating\n\n")

  score <- readline(prompt = paste("Enter score for", rating_name, "(0-4): "))
  while (!trimws(score) %in% c("0", "1", "2", "3", "4")) {
    cat("\nInvalid choice. Please enter 0, 1, 2, 3, or 4.\n")
    score <- readline(prompt = paste("Enter score for", rating_name, "(0-4): "))
  }

  if (trimws(score) == "0") NA else trimws(score)
}

ask_all_scores <- function() {
  list(
    completeness = ask_score("completeness"),
    coherency    = ask_score("coherency"),
    correctness  = ask_score("correctness")
  )
}

filter_responses <- function(data, scores) {
  filtered <- data

  if (!is.na(scores$completeness))
    filtered <- filtered %>% filter(str_starts(completeness, scores$completeness))

  if (!is.na(scores$coherency))
    filtered <- filtered %>% filter(str_starts(coherency, scores$coherency))

  if (!is.na(scores$correctness))
    filtered <- filtered %>% filter(str_starts(correctness, scores$correctness))

  filtered
}

print_random_response <- function(filtered_responses, scores, dataset_name) {
  random_response <- filtered_responses %>% slice_sample(n = 1)

  divider_thick <- strrep("=", 70)
  divider_thin  <- strrep("-", 60)

  cat("\n", divider_thick, "\n", sep = "")
  cat("CAREERNET RANDOM RESPONSE EXPLORER\n")
  cat(divider_thick, "\n\n", sep = "")

  cat("DATASET\n")
  cat(divider_thin, "\n\n", sep = "")
  cat(dataset_name, "\n")
  if ("domain" %in% names(random_response))
    cat("Domain:", random_response$domain, "\n")

  cat("\nFILTERS USED\n")
  cat(divider_thin, "\n\n", sep = "")
  cat("Completeness filter: ", ifelse(is.na(scores$completeness), "Ignored", scores$completeness), "\n")
  cat("Coherency filter:    ", ifelse(is.na(scores$coherency),    "Ignored", scores$coherency),    "\n")
  cat("Correctness filter:  ", ifelse(is.na(scores$correctness),  "Ignored", scores$correctness),  "\n")
  cat("Matching responses:  ", nrow(filtered_responses), "\n")

  cat("\nQUESTION TITLE\n")
  cat(divider_thin, "\n\n", sep = "")
  cat(random_response$question_title)

  cat("\n\nQUESTION BODY\n")
  cat(divider_thin, "\n\n", sep = "")
  cat(random_response$question_body)

  cat("\n\nANSWER\n")
  cat(divider_thin, "\n\n", sep = "")
  cat(random_response$answer_body)

  cat("\n\nRATINGS\n")
  cat(divider_thin, "\n\n", sep = "")
  cat("Completeness: ", random_response$completeness, "\n")
  cat("Coherency:    ", random_response$coherency,    "\n")
  cat("Correctness:  ", random_response$correctness,  "\n")

  cat("\n", divider_thick, "\n", sep = "")
}

# ============================================================
# 4. MAIN INTERACTIVE LOOP
# ============================================================

cat("\n")
cat(strrep("=", 52), "\n", sep = "")
cat("CAREERNET RANDOM RESPONSE EXPLORER\n")
cat(strrep("=", 52), "\n\n", sep = "")

dataset      <- select_dataset()
selected_data_clean <- clean_html(dataset$data)
scores       <- ask_all_scores()
filtered_responses  <- filter_responses(selected_data_clean, scores)

repeat {
  if (nrow(filtered_responses) == 0) {
    cat("\nNo responses matched your selected filters.\n")
    cat("Try choosing different ratings or using 0 to ignore a rating.\n")
  } else {
    print_random_response(filtered_responses, scores, dataset$name)
  }

  cat("\nWhat would you like to do next?\n")
  cat("1 = Generate another response with the same ratings\n")
  cat("2 = Choose different ratings\n")
  cat("3 = Choose a different dataset\n")
  cat("4 = Quit explorer\n\n")

  choice <- readline(prompt = "Enter choice (1-4): ")
  while (!trimws(choice) %in% c("1", "2", "3", "4")) {
    cat("\nInvalid choice. Please enter 1, 2, 3, or 4.\n")
    choice <- readline(prompt = "Enter choice (1-4): ")
  }

  if (trimws(choice) == "1") next

  if (trimws(choice) == "2") {
    scores             <- ask_all_scores()
    filtered_responses <- filter_responses(selected_data_clean, scores)
  }

  if (trimws(choice) == "3") {
    dataset             <- select_dataset()
    selected_data_clean <- clean_html(dataset$data)
    scores              <- ask_all_scores()
    filtered_responses  <- filter_responses(selected_data_clean, scores)
  }

  if (trimws(choice) == "4") {
    cat("\nExplorer closed.\n")
    break
  }
}
