source("analysis/00_data_helpers.R")
source("analysis/02_question_length/00_question_length_helpers.R")

all_data <- load_all_domains()

run_question_length_analysis(
  data          = all_data,
  analysis_name = "All CareerNet Domains:",
  plot_file     = "plots/question_length/all.pdf",
  output_folder = "outputs/question_length/all"
)
