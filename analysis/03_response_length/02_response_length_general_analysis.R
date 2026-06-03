source("analysis/04_response_length/00_response_length_helpers.R")

general <- read_csv("data/general.csv", show_col_types = FALSE) %>%
  mutate(domain = "General")

run_response_length_analysis(
  data = general,
  analysis_name = "General Dataset:",
  plot_file = "plots/response_length/general.pdf",
  output_folder = "outputs/response_length/general"
)