source("analysis/00_data_helpers.R")
source("analysis/03_response_length/00_response_length_helpers.R")

general <- load_domain("General")

run_response_length_analysis(
  data = general,
  analysis_name = "General Dataset:",
  plot_file = "plots/response_length/general.pdf",
  output_folder = "outputs/response_length/general"
)