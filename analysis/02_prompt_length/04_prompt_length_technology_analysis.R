source("analysis/02_prompt_length/00_prompt_length_helpers.R")

technology <- read_csv("data/technology.csv", show_col_types = FALSE) %>%
  mutate(domain = "Technology")

run_prompt_length_analysis(
  data          = technology,
  analysis_name = "Technology Dataset:",
  plot_file     = "plots/prompt_length/technology.pdf",
  output_folder = "outputs/prompt_length/technology"
)
