source("analysis/00_data_helpers.R")
source("analysis/03_response_length/00_response_length_helpers.R")

technology <- load_domain("Technology")

run_response_length_analysis(
  data = technology,
  analysis_name = "Technology Dataset:",
  plot_file = "plots/response_length/technology.pdf",
  output_folder = "outputs/response_length/technology"
)