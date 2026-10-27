source("analysis/00_data_helpers.R")
source("analysis/02_question_length/00_question_length_helpers.R")

general <- load_domain("General")

run_question_length_analysis(
  data          = general,
  analysis_name = "General Dataset:",
  plot_file     = "plots/question_length/general.pdf",
  output_folder = "outputs/question_length/general"
)
