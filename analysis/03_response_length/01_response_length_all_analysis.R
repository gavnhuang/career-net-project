source("analysis/04_response_length/00_response_length_helpers.R")

domain_files <- c(
  General    = "data/general.csv",
  Healthcare = "data/health.csv",
  Technology = "data/technology.csv"
)

all_data <- imap_dfr(domain_files, ~ read_csv(.x, show_col_types = FALSE) %>% mutate(domain = .y))

run_response_length_analysis(
  data = all_data,
  analysis_name = "All CareerNet Domains:",
  plot_file = "plots/response_length/all.pdf",
  output_folder = "outputs/response_length/all"
)