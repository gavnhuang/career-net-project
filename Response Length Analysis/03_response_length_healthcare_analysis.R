source("Response Length Analysis/00_response_length_helpers.R")

health <- read_csv("data/health.csv", show_col_types = FALSE) %>%
  mutate(domain = "Healthcare")

run_response_length_analysis(
  data = health,
  analysis_name = "Healthcare Dataset:",
  plot_file = "plots/response_length/healthcare.pdf",
  output_folder = "outputs/response_length/healthcare"
)