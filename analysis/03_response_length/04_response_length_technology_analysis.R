source("analysis/04_response_length/00_response_length_helpers.R")

technology <- read_csv("data/technology.csv", show_col_types = FALSE) %>%
  mutate(domain = "Technology")

run_response_length_analysis(
  data = technology,
  analysis_name = "Technology Dataset:",
  plot_file = "plots/response_length/technology.pdf",
  output_folder = "outputs/response_length/technology"
)