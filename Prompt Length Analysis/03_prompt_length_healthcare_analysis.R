source("Prompt Length Analysis/00_prompt_length_helpers.R")

health <- read_csv("data/health.csv", show_col_types = FALSE) %>%
  mutate(domain = "Healthcare")

run_prompt_length_analysis(
  data          = health,
  analysis_name = "Healthcare Dataset:",
  plot_file     = "plots/prompt_length/healthcare.pdf",
  output_folder = "outputs/prompt_length/healthcare"
)
