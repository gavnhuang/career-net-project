# ============================================================
# SCENARIO INTENT ANALYSIS — 03: COMBINED HEATMAP
# ============================================================
# For each (scenario type × intent type) combination, what is the
# average quality of responses? This is the thesis centrepiece figure.

source("Scenario Intent Analysis/00_scenario_intent_helpers.R")

dir.create("plots/scenario_intent",   recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/scenario_intent", recursive = TRUE, showWarnings = FALSE)

# ============================================================
# 1. LOAD AND PREPARE
# ============================================================

all_data <- load_all_data() %>%
  parse_quality_scores() %>%
  mutate(primary_scenario = extract_primary_label(ScenarioLabels)) %>%
  filter(!is.na(primary_scenario))

# ============================================================
# 2. SELECT TOP SCENARIOS
# ============================================================

# Keep only scenarios with enough data to be interpretable.
top_scenarios <- all_data %>%
  count(primary_scenario, sort = TRUE) %>%
  filter(n >= 100) %>%
  pull(primary_scenario)

# ============================================================
# 3. COMPUTE SCENARIO × INTENT QUALITY
# ============================================================

# For each intent column, compute mean quality for rows that:
#   (a) belong to one of the top scenarios, AND
#   (b) have a non-NA value for that intent column.
combined_summary <- map_dfr(INTENT_COLS, function(col) {
  all_data %>%
    filter(primary_scenario %in% top_scenarios, !is.na(.data[[col]])) %>%
    group_by(primary_scenario) %>%
    summarise(
      n                 = n(),
      composite_mean    = mean(composite_quality),
      completeness_mean = mean(completeness_num),
      coherency_mean    = mean(coherency_num),
      correctness_mean  = mean(correctness_num),
      .groups = "drop"
    ) %>%
    mutate(intent_label = INTENT_LABELS[[col]])
})

# Fill in all (scenario × intent) combinations, including ones with no data.
combined_full <- expand_grid(
  primary_scenario = top_scenarios,
  intent_label     = unname(INTENT_LABELS)
) %>%
  left_join(combined_summary, by = c("primary_scenario", "intent_label")) %>%
  mutate(
    # Cells with fewer than 10 responses are greyed out and unlabelled.
    display_quality      = ifelse(is.na(n) | n < 10, NA_real_, composite_mean),
    display_completeness = ifelse(is.na(n) | n < 10, NA_real_, completeness_mean),
    display_coherency    = ifelse(is.na(n) | n < 10, NA_real_, coherency_mean),
    display_correctness  = ifelse(is.na(n) | n < 10, NA_real_, correctness_mean),
    cell_label           = case_when(
      is.na(n) | n < 10 ~ "",
      n >= 1000          ~ paste0(round(n / 1000, 1), "k"),
      TRUE               ~ as.character(n)
    ),
    score_label          = ifelse(is.na(display_quality),      "", as.character(round(display_quality,      2))),
    completeness_label   = ifelse(is.na(display_completeness), "", as.character(round(display_completeness, 2))),
    coherency_label      = ifelse(is.na(display_coherency),    "", as.character(round(display_coherency,    2))),
    correctness_label    = ifelse(is.na(display_correctness),  "", as.character(round(display_correctness,  2)))
  )

# ============================================================
# 4. AXIS ORDERING
# ============================================================

# Scenarios: ordered by overall composite quality (low → high on y-axis)
scenario_order <- all_data %>%
  filter(primary_scenario %in% top_scenarios) %>%
  group_by(primary_scenario) %>%
  summarise(composite_mean = mean(composite_quality), .groups = "drop") %>%
  arrange(composite_mean) %>%
  pull(primary_scenario)

# Intent types: ordered by mean quality when present (low → high on x-axis)
intent_order <- map_dfr(INTENT_COLS, function(col) {
  all_data %>%
    filter(!is.na(.data[[col]])) %>%
    summarise(composite_mean = mean(composite_quality)) %>%
    mutate(intent_label = INTENT_LABELS[[col]])
}) %>%
  arrange(composite_mean) %>%
  pull(intent_label)

combined_full <- combined_full %>%
  mutate(
    primary_scenario = factor(primary_scenario, levels = scenario_order),
    intent_label     = factor(intent_label,     levels = intent_order)
  )

# ============================================================
# 5. PLOT — Combined heatmap
# ============================================================

p_combined <- combined_full %>%
  ggplot(aes(x = intent_label, y = primary_scenario, fill = display_quality)) +
  geom_tile(color = "white", linewidth = 0.8) +
  geom_text(aes(label = cell_label), size = 2.8, color = "gray30") +
  scale_fill_gradient(
    low      = "#FEE090",
    high     = "#2C7BB6",
    name     = "Mean Quality\nScore",
    na.value = "gray92"
  ) +
  labs(
    title    = "Career Advice Quality by Scenario Type and Prompt Intent",
    subtitle = paste0(
      "Mean composite quality (1–4 scale) | n shown in each cell | ",
      "Gray = fewer than 10 responses\n",
      "Rows ordered by overall scenario quality (low → high) | ",
      "Columns ordered by intent quality when present (low → high)"
    ),
    x = "Prompt Intent Type",
    y = NULL
  ) +
  scenario_intent_theme() +
  theme(
    axis.text.x = element_text(angle = 35, hjust = 1, size = 9),
    panel.grid  = element_blank()
  )

p_combined_scores <- combined_full %>%
  ggplot(aes(x = intent_label, y = primary_scenario, fill = display_quality)) +
  geom_tile(color = "white", linewidth = 0.8) +
  geom_text(aes(label = score_label), size = 2.8, color = "gray30") +
  scale_fill_gradient(
    low      = "#FEE090",
    high     = "#2C7BB6",
    name     = "Mean Quality\nScore",
    na.value = "gray92"
  ) +
  labs(
    title    = "Career Advice Quality by Scenario Type and Prompt Intent",
    subtitle = paste0(
      "Mean composite quality (1–4 scale) | Score shown in each cell | ",
      "Gray = fewer than 10 responses\n",
      "Rows ordered by overall scenario quality (low → high) | ",
      "Columns ordered by intent quality when present (low → high)"
    ),
    x = "Prompt Intent Type",
    y = NULL
  ) +
  scenario_intent_theme() +
  theme(
    axis.text.x = element_text(angle = 35, hjust = 1, size = 9),
    panel.grid  = element_blank()
  )

make_dimension_heatmap <- function(data, fill_col, label_col, dimension_name) {
  data %>%
    ggplot(aes(x = intent_label, y = primary_scenario, fill = .data[[fill_col]])) +
    geom_tile(color = "white", linewidth = 0.8) +
    geom_text(aes(label = .data[[label_col]]), size = 2.8, color = "gray30") +
    scale_fill_gradient(
      low      = "#FEE090",
      high     = "#2C7BB6",
      name     = paste0("Mean\n", dimension_name),
      na.value = "gray92"
    ) +
    labs(
      title    = paste0(dimension_name, " Score by Scenario Type and Prompt Intent"),
      subtitle = paste0(
        "Mean ", tolower(dimension_name), " score (1–4 scale) | Score shown in each cell | ",
        "Gray = fewer than 10 responses\n",
        "Rows ordered by overall scenario quality (low → high) | ",
        "Columns ordered by intent quality when present (low → high)"
      ),
      x = "Prompt Intent Type",
      y = NULL
    ) +
    scenario_intent_theme() +
    theme(
      axis.text.x = element_text(angle = 35, hjust = 1, size = 9),
      panel.grid  = element_blank()
    )
}

p_completeness <- make_dimension_heatmap(combined_full, "display_completeness", "completeness_label", "Completeness")
p_coherency    <- make_dimension_heatmap(combined_full, "display_coherency",    "coherency_label",    "Coherency")
p_correctness  <- make_dimension_heatmap(combined_full, "display_correctness",  "correctness_label",  "Correctness")

# ============================================================
# 6. SAVE
# ============================================================

pdf("plots/scenario_intent/03_scenario_intent_heatmap.pdf", width = 12, height = 8)
print(p_combined)
print(p_combined_scores)
print(p_completeness)
print(p_coherency)
print(p_correctness)
invisible(dev.off())

write_csv(combined_full, "outputs/scenario_intent/03_scenario_intent_combined.csv")

# ============================================================
# 7. CONSOLE OUTPUT
# ============================================================

cat("\n====================================================\n")
cat("SCENARIO × INTENT COMBINED ANALYSIS COMPLETE\n")
cat("====================================================\n\n")

cat("Scenarios included (n >= 100):", length(top_scenarios), "\n")
cat(paste0(" - ", scenario_order, collapse = "\n"), "\n\n")

cat("Top 10 scenario × intent combinations by quality:\n\n")
combined_full %>%
  filter(!is.na(display_quality)) %>%
  arrange(desc(display_quality)) %>%
  transmute(
    scenario     = primary_scenario,
    intent       = intent_label,
    n            = n,
    mean_quality = round(composite_mean, 3)
  ) %>%
  slice_head(n = 10) %>%
  print()

cat("\nBottom 10 scenario × intent combinations by quality:\n\n")
combined_full %>%
  filter(!is.na(display_quality)) %>%
  arrange(display_quality) %>%
  transmute(
    scenario     = primary_scenario,
    intent       = intent_label,
    n            = n,
    mean_quality = round(composite_mean, 3)
  ) %>%
  slice_head(n = 10) %>%
  print()
