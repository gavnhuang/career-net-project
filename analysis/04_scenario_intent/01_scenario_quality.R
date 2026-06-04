# ============================================================
# SCENARIO INTENT ANALYSIS — 01: SCENARIO QUALITY
# ============================================================
# Which career scenario types receive the highest-rated responses?

source("analysis/04_scenario_intent/00_scenario_intent_helpers.R")

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
# 2. SUMMARISE BY SCENARIO
# ============================================================

scenario_summary <- all_data %>%
  group_by(primary_scenario) %>%
  summarise(
    n                 = n(),
    composite_mean    = mean(composite_quality),
    composite_se      = sd(composite_quality) / sqrt(n()),
    completeness_mean = mean(completeness_num),
    coherency_mean    = mean(coherency_num),
    correctness_mean  = mean(correctness_num),
    .groups = "drop"
  ) %>%
  filter(n >= 30) %>%
  arrange(composite_mean)

# Factor levels lock in the sort order for both plots below
scenario_levels <- scenario_summary$primary_scenario

# ============================================================
# 3. PLOT 1 — Composite quality by scenario (horizontal bars)
# ============================================================

p1 <- scenario_summary %>%
  mutate(primary_scenario = factor(primary_scenario, levels = scenario_levels)) %>%
  ggplot(aes(x = composite_mean, y = primary_scenario)) +
  geom_col(fill = "#2C7BB6", alpha = 0.85) +
  geom_errorbarh(
    aes(
      xmin = composite_mean - 1.96 * composite_se,
      xmax = composite_mean + 1.96 * composite_se
    ),
    height = 0.35, color = "gray30", linewidth = 0.5
  ) +
  geom_text(
    aes(
      x     = composite_mean + 1.96 * composite_se + 0.05,
      label = paste0("n=", n)
    ),
    hjust = 0, size = 2.8, color = "gray50"
  ) +
  scale_x_continuous(limits = c(1, 4.5), breaks = 1:4) +
  labs(
    title    = "Mean Quality Score by Career Scenario Type",
    subtitle = "Composite of correctness, completeness, and coherency (1–4 scale)\nError bars = 95% CI | Scenarios with n ≥ 30 only",
    x        = "Mean Composite Quality Score",
    y        = NULL
  ) +
  scenario_intent_theme()

# ============================================================
# 4. PLOT 2 — Quality dimensions heatmap by scenario
# ============================================================

scenario_long <- scenario_summary %>%
  pivot_longer(
    cols      = c(completeness_mean, coherency_mean, correctness_mean),
    names_to  = "dimension",
    values_to = "mean_score"
  ) %>%
  mutate(
    dimension = recode(dimension,
      completeness_mean = "Completeness",
      coherency_mean    = "Coherency",
      correctness_mean  = "Correctness"
    ),
    primary_scenario = factor(primary_scenario, levels = scenario_levels)
  )

p2 <- scenario_long %>%
  ggplot(aes(x = dimension, y = primary_scenario, fill = mean_score)) +
  geom_tile(color = "white", linewidth = 0.8) +
  geom_text(aes(label = round(mean_score, 2)), size = 3, color = "gray20") +
  scale_fill_gradient(
    low  = "#FEE090",
    high = "#2C7BB6",
    name = "Mean Score"
  ) +
  labs(
    title    = "Quality Dimensions by Career Scenario Type",
    subtitle = "Mean score per dimension (1–4 scale) | Rows ordered by composite quality (low → high)",
    x        = NULL,
    y        = NULL
  ) +
  scenario_intent_theme() +
  theme(panel.grid = element_blank())

# ============================================================
# 5. PLOT 3 — Zoomed dot plot for at-a-glance comparison
# ============================================================

overall_mean <- weighted.mean(scenario_summary$composite_mean, scenario_summary$n)

x_lo <- min(scenario_summary$composite_mean) - 0.05
x_hi <- max(scenario_summary$composite_mean) + 0.12

p3 <- scenario_summary %>%
  mutate(primary_scenario = factor(primary_scenario, levels = scenario_levels)) %>%
  ggplot(aes(x = composite_mean, y = primary_scenario)) +
  geom_vline(
    xintercept = overall_mean,
    linetype   = "dashed",
    color      = "gray60",
    linewidth  = 0.6
  ) +
  geom_segment(
    aes(x = overall_mean, xend = composite_mean, yend = primary_scenario),
    color     = "gray75",
    linewidth = 0.8
  ) +
  geom_point(aes(color = composite_mean), size = 4) +
  geom_text(
    aes(label = sprintf("%.3f", composite_mean)),
    hjust = -0.4,
    size  = 3,
    color = "gray20"
  ) +
  scale_color_gradient(low = "#FEE090", high = "#2C7BB6", guide = "none") +
  scale_x_continuous(
    breaks = seq(round(x_lo, 1), round(x_hi, 1), 0.05)
  ) +
  coord_cartesian(xlim = c(x_lo, x_hi)) +
  labs(
    title    = "Mean Composite Quality Score by Scenario",
    subtitle = "Ranked low → high | Dashed line = weighted overall mean | 1–4 scale",
    x        = "Mean Composite Quality Score",
    y        = NULL
  ) +
  scenario_intent_theme()

# ============================================================
# 6. SAVE
# ============================================================

pdf("plots/scenario_intent/01_scenario_quality.pdf", width = 10, height = 7)
print(p1)
print(p2)
print(p3)
invisible(dev.off())

write_csv(scenario_summary, "outputs/scenario_intent/01_scenario_quality_summary.csv")

# ============================================================
# 7. CONSOLE OUTPUT
# ============================================================

cat("\n====================================================\n")
cat("SCENARIO QUALITY ANALYSIS COMPLETE\n")
cat("====================================================\n\n")
cat("Scenarios analyzed (n >= 30):", nrow(scenario_summary), "\n\n")
cat("Ranked by composite quality (highest to lowest):\n\n")

scenario_summary %>%
  arrange(desc(composite_mean)) %>%
  transmute(
    scenario       = primary_scenario,
    n              = n,
    composite      = round(composite_mean, 3),
    completeness   = round(completeness_mean, 3),
    coherency      = round(coherency_mean, 3),
    correctness    = round(correctness_mean, 3)
  ) %>%
  print(n = Inf)
