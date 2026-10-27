source("analysis/00_data_helpers.R")
source("analysis/02_question_length/00_question_length_helpers.R")

technology <- load_domain("Technology")

run_question_length_analysis(
  data          = technology,
  analysis_name = "Technology Dataset:",
  plot_file     = "plots/question_length/technology.pdf",
  output_folder = "outputs/question_length/technology"
)
