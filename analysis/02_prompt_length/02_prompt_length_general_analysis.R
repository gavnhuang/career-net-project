source("analysis/02_prompt_length/00_prompt_length_helpers.R")

general <- read_csv("data/general.csv", show_col_types = FALSE) %>%
  mutate(domain = "General")

run_prompt_length_analysis(
  data          = general,
  analysis_name = "General Dataset:",
  plot_file     = "plots/prompt_length/general.pdf",
  output_folder = "outputs/prompt_length/general"
)
