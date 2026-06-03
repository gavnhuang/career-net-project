source("analysis/02_question_length/00_question_length_helpers.R")

health <- read_csv("data/health.csv", show_col_types = FALSE) %>%
  mutate(domain = "Healthcare")

run_question_length_analysis(
  data          = health,
  analysis_name = "Healthcare Dataset:",
  plot_file     = "plots/question_length/healthcare.pdf",
  output_folder = "outputs/question_length/healthcare"
)
