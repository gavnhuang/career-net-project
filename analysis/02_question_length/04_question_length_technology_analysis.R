source("analysis/02_question_length/00_question_length_helpers.R")

technology <- read_csv("data/technology.csv", show_col_types = FALSE) %>%
  mutate(domain = "Technology")

run_question_length_analysis(
  data          = technology,
  analysis_name = "Technology Dataset:",
  plot_file     = "plots/question_length/technology.pdf",
  output_folder = "outputs/question_length/technology"
)
