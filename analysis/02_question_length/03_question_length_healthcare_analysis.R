source("analysis/00_data_helpers.R")
source("analysis/02_question_length/00_question_length_helpers.R")

health <- load_domain("Healthcare")

run_question_length_analysis(
  data          = health,
  analysis_name = "Healthcare Dataset:",
  plot_file     = "plots/question_length/healthcare.pdf",
  output_folder = "outputs/question_length/healthcare"
)
