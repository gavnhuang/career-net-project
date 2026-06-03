library(tidyverse)
library(stringr)

clean_careernet_data <- function(data) {
  data %>%
    mutate(
      question_clean  = str_remove_all(coalesce(question_body, ""), "<.*?>"),
      question_length = str_count(question_clean, "\\S+"),

      completeness_num = as.numeric(str_extract(completeness, "^[1-4]")),
      coherency_num    = as.numeric(str_extract(coherency,    "^[1-4]")),
      correctness_num  = as.numeric(str_extract(correctness,  "^[1-4]"))
    ) %>%
    filter(
      !is.na(question_length),
      !is.na(completeness_num),
      !is.na(coherency_num),
      !is.na(correctness_num)
    )
}

remove_length_outliers <- function(data) {
  q1        <- quantile(data$question_length, 0.25)
  q3        <- quantile(data$question_length, 0.75)
  iqr_value <- IQR(data$question_length)

  data %>%
    filter(
      question_length >= q1 - 1.5 * iqr_value,
      question_length <= q3 + 1.5 * iqr_value
    )
}

get_correlation <- function(x, y, label) {
  test <- cor.test(x, y)
  tibble(
    outcome       = label,
    correlation_r = round(unname(test$estimate), 3),
    p_value       = ifelse(test$p.value < .001, "< .001", as.character(round(test$p.value, 3))),
    strength      = case_when(
      abs(unname(test$estimate)) < .10 ~ "Very weak",
      abs(unname(test$estimate)) < .30 ~ "Weak",
      abs(unname(test$estimate)) < .50 ~ "Moderate",
      TRUE                             ~ "Strong"
    )
  )
}

get_regression <- function(outcome_col, data, label) {
  model         <- lm(reformulate("question_length", outcome_col), data = data)
  model_summary <- summary(model)
  tibble(
    outcome             = label,
    slope_per_word      = round(coef(model)[2], 5),
    slope_per_100_words = round(coef(model)[2] * 100, 3),
    r_squared           = round(model_summary$r.squared, 3),
    p_value             = ifelse(
      coef(model_summary)[2, 4] < .001, "< .001",
      as.character(round(coef(model_summary)[2, 4], 3))
    )
  )
}

make_stats_label <- function(correlation_summary, regression_summary, outcome_name) {
  cor_row <- correlation_summary %>% filter(outcome == outcome_name)
  reg_row <- regression_summary  %>% filter(outcome == outcome_name)
  paste0(
    "r = ", cor_row$correlation_r,
    "\np = ", cor_row$p_value,
    "\nR² = ", reg_row$r_squared,
    "\nSlope per 100 words = ", reg_row$slope_per_100_words
  )
}

make_question_length_plot <- function(data, y_variable, title, y_label, stats_label) {
  ggplot(data, aes(x = question_length, y = .data[[y_variable]])) +
    geom_point(alpha = 0.15) +
    geom_smooth(method = "lm", se = TRUE) +
    labs(
      title    = title,
      subtitle = "Blue line = regression trend line | Shaded band = uncertainty",
      x        = "Question Length in Words",
      y        = y_label,
      caption  = stats_label
    ) +
    theme(legend.position = "none")
}

run_question_length_analysis <- function(data, analysis_name, plot_file, output_folder) {

  dir.create(dirname(plot_file), recursive = TRUE, showWarnings = FALSE)
  dir.create(output_folder,      recursive = TRUE, showWarnings = FALSE)

  clean_data  <- clean_careernet_data(data)
  no_outliers <- remove_length_outliers(clean_data)

  outcomes <- c(
    Completeness = "completeness_num",
    Coherency    = "coherency_num",
    Correctness  = "correctness_num"
  )
  outcome_labels <- setNames(names(outcomes), unname(outcomes))

  rating_summary <- no_outliers %>%
    pivot_longer(
      cols      = all_of(unname(outcomes)),
      names_to  = "outcome",
      values_to = "rating"
    ) %>%
    mutate(outcome = unname(outcome_labels[outcome])) %>%
    group_by(outcome, rating) %>%
    summarise(
      mean_words   = round(mean(question_length), 1),
      median_words = round(median(question_length), 1),
      responses    = n(),
      .groups = "drop"
    )

  correlation_summary <- imap_dfr(outcomes, function(col, label) {
    get_correlation(no_outliers$question_length, no_outliers[[col]], label)
  })

  regression_summary <- imap_dfr(outcomes, function(col, label) {
    get_regression(col, no_outliers, label)
  })

  plots <- imap(outcomes, function(col, label) {
    make_question_length_plot(
      no_outliers,
      col,
      paste(analysis_name, "Question Length vs", label),
      paste(label, "Rating"),
      make_stats_label(correlation_summary, regression_summary, label)
    )
  })

  pdf(plot_file, width = 8, height = 5)
  walk(plots, print)
  invisible(dev.off())

  write_csv(no_outliers,          file.path(output_folder, "clean_data_no_outliers.csv"))
  write_csv(rating_summary,       file.path(output_folder, "rating_length_summary.csv"))
  write_csv(correlation_summary,  file.path(output_folder, "correlation_summary.csv"))
  write_csv(regression_summary,   file.path(output_folder, "regression_summary.csv"))

  cat("\n====================================================\n")
  cat(analysis_name, "ANALYSIS COMPLETE\n")
  cat("====================================================\n\n")

  cat("Original responses:", nrow(clean_data), "\n")
  cat("Responses after removing outliers:", nrow(no_outliers), "\n\n")

  cat("Average Question Length by Rating:\n")
  print(rating_summary)

  cat("\nCorrelation Results:\n")
  print(correlation_summary)

  cat("\nRegression Results:\n")
  print(regression_summary)
}
