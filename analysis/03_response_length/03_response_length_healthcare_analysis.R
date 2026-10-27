source("analysis/00_data_helpers.R")
source("analysis/03_response_length/00_response_length_helpers.R")

health <- load_domain("Healthcare")

run_response_length_analysis(
  data = health,
  analysis_name = "Healthcare Dataset:",
  plot_file = "plots/response_length/healthcare.pdf",
  output_folder = "outputs/response_length/healthcare"
)