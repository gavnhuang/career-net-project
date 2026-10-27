source("analysis/00_data_helpers.R")
source("analysis/03_response_length/00_response_length_helpers.R")

all_data <- load_all_domains()

run_response_length_analysis(
  data = all_data,
  analysis_name = "All CareerNet Domains:",
  plot_file = "plots/response_length/all.pdf",
  output_folder = "outputs/response_length/all"
)