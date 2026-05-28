# ============================================================
# SCENARIO INTENT ANALYSIS — 02: INTENT QUALITY
# ============================================================
# Do certain prompt intent types predict higher response quality?
# Three views: presence/absence gap, sub-intent breakdown, dimension heatmap.

source("Scenario Intent Analysis/00_scenario_intent_helpers.R")

dir.create("plots/scenario_intent",   recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/scenario_intent", recursive = TRUE, showWarnings = FALSE)

# ============================================================
# 1. LOAD AND PREPARE
# ============================================================

all_data <- load_all_data() %>%
  parse_quality_scores()

# ============================================================
# 2. INTENT PRESENCE VS ABSENCE
# ============================================================

intent_presence_summary <- map_dfr(INTENT_COLS, function(col) {
  all_data %>%
    mutate(
      status       = ifelse(!is.na(.data[[col]]), "Present", "Absent"),
      intent_label = INTENT_LABELS[[col]]
    ) %>%
    group_by(intent_label, status) %>%
    summarise(
      n              = n(),
      composite_mean = mean(composite_quality),
      composite_se   = sd(composite_quality) / sqrt(n()),
      .groups = "drop"
    )
})

# Order intent types by the gap: (quality when present) - (quality when absent).
# Intents where presence most improves quality appear at the top.
intent_order <- intent_presence_summary %>%
  select(intent_label, status, composite_mean) %>%
  pivot_wider(names_from = status, values_from = composite_mean) %>%
  mutate(gap = Present - Absent) %>%
  arrange(gap) %>%
  pull(intent_label)

# ============================================================
# 3. PLOT 1 — Dumbbell: quality gap when intent is present vs absent
# ============================================================

dumbbell_data <- intent_presence_summary %>%
  select(intent_label, status, composite_mean, n) %>%
  pivot_wider(
    names_from  = status,
    values_from = c(composite_mean, n)
  ) %>%
  mutate(
    intent_label = factor(intent_label, levels = intent_order),
    gap          = round(composite_mean_Present - composite_mean_Absent, 3)
  )

p1 <- dumbbell_data %>%
  ggplot(aes(y = intent_label)) +
  geom_segment(
    aes(x = composite_mean_Absent, xend = composite_mean_Present, yend = intent_label),
    color = "gray70", linewidth = 1.2
  ) +
  geom_point(aes(x = composite_mean_Absent),  color = "#E66101", size = 4, alpha = 0.9) +
  geom_point(aes(x = composite_mean_Present), color = "#2C7BB6", size = 4, alpha = 0.9) +
  geom_text(
    aes(x = pmax(composite_mean_Present, composite_mean_Absent) + 0.05,
        label = ifelse(gap > 0, paste0("+", gap), as.character(gap))),
    hjust = 0, size = 3, color = "gray40"
  ) +
  scale_x_continuous(limits = c(2.4, 4.2), breaks = seq(2.5, 4, 0.25)) +
  labs(
    title    = "Effect of Intent Type on Response Quality",
    subtitle = "Mean composite quality: intent present (blue) vs absent (orange) | Gap shown at right | 1–4 scale",
    x        = "Mean Composite Quality Score",
    y        = NULL
  ) +
  scenario_intent_theme()

# ============================================================
# 4. SUB-INTENT QUALITY BREAKDOWN
# ============================================================

# Explode the semicolon-delimited sub-intent strings into one row per sub-intent.
# A single response can contribute to multiple sub-intent groups.
multi_value_cols <- INTENT_COLS[!INTENT_COLS %in% SINGLE_VALUE_INTENTS]

sub_intent_summary <- map_dfr(multi_value_cols, function(col) {
  all_data %>%
    filter(!is.na(.data[[col]])) %>%
    mutate(sub_intent = .data[[col]]) %>%
    separate_longer_delim(sub_intent, delim = ";") %>%
    mutate(
      sub_intent   = trimws(sub_intent),
      intent_label = INTENT_LABELS[[col]]
    ) %>%
    filter(sub_intent != "") %>%
    group_by(intent_label, sub_intent) %>%
    summarise(
      n              = n(),
      composite_mean = mean(composite_quality),
      composite_se   = sd(composite_quality) / sqrt(n()),
      .groups = "drop"
    ) %>%
    filter(n >= 10)
})

# ============================================================
# 5. PLOT 2 — Sub-intent quality breakdown (faceted bars)
# ============================================================

p2 <- sub_intent_summary %>%
  mutate(sub_intent = reorder_within(sub_intent, composite_mean, intent_label)) %>%
  ggplot(aes(x = composite_mean, y = sub_intent)) +
  geom_col(fill = "#2C7BB6", alpha = 0.82) +
  geom_errorbarh(
    aes(
      xmin = composite_mean - 1.96 * composite_se,
      xmax = composite_mean + 1.96 * composite_se
    ),
    height = 0.3, color = "gray30", linewidth = 0.4
  ) +
  geom_text(
    aes(
      x     = composite_mean + 1.96 * composite_se + 0.04,
      label = paste0("n=", n)
    ),
    hjust = 0, size = 2.5, color = "gray50"
  ) +
  scale_y_reordered() +
  scale_x_continuous(limits = c(1, 4.5), breaks = 1:4) +
  facet_wrap(~ intent_label, scales = "free_y", ncol = 2) +
  labs(
    title    = "Quality by Sub-Intent Type",
    subtitle = "Mean composite quality (1–4 scale) | Error bars = 95% CI | Sub-intents with n ≥ 10\nNote: rows with multiple sub-intents contribute to each relevant group",
    x        = "Mean Composite Quality Score",
    y        = NULL
  ) +
  scenario_intent_theme() +
  theme(
    strip.text  = element_text(face = "bold", size = 9),
    axis.text.y = element_text(size = 8)
  )

# ============================================================
# 6. PLOT 3 — Intent × quality dimension heatmap (present rows only)
# ============================================================

intent_dim_summary <- map_dfr(INTENT_COLS, function(col) {
  all_data %>%
    filter(!is.na(.data[[col]])) %>%
    summarise(
      completeness_mean = mean(completeness_num),
      coherency_mean    = mean(coherency_num),
      correctness_mean  = mean(correctness_num),
      n                 = n()
    ) %>%
    mutate(intent_label = INTENT_LABELS[[col]])
}) %>%
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
    intent_label = factor(intent_label, levels = intent_order)
  )

p3 <- intent_dim_summary %>%
  ggplot(aes(x = dimension, y = intent_label, fill = mean_score)) +
  geom_tile(color = "white", linewidth = 0.8) +
  geom_text(aes(label = round(mean_score, 2)), size = 3.2, color = "gray20") +
  scale_fill_gradient(
    low  = "#FEE090",
    high = "#2C7BB6",
    name = "Mean Score"
  ) +
  labs(
    title    = "Quality Dimensions by Intent Type",
    subtitle = "Responses where intent is present | Mean score per dimension (1–4 scale)\nRows ordered by quality gap (present minus absent, low → high)",
    x        = NULL,
    y        = NULL
  ) +
  scenario_intent_theme() +
  theme(panel.grid = element_blank())

# ============================================================
# 7. SAVE
# ============================================================

pdf("plots/scenario_intent/02_intent_quality.pdf", width = 10, height = 7)
print(p1)
print(p3)
invisible(dev.off())

pdf("plots/scenario_intent/02_intent_quality_subintents.pdf", width = 12, height = 12)
print(p2)
invisible(dev.off())

write_csv(intent_presence_summary, "outputs/scenario_intent/02_intent_presence_summary.csv")
write_csv(sub_intent_summary,      "outputs/scenario_intent/02_sub_intent_summary.csv")

# ============================================================
# 8. CONSOLE OUTPUT
# ============================================================

cat("\n====================================================\n")
cat("INTENT QUALITY ANALYSIS COMPLETE\n")
cat("====================================================\n\n")

cat("Intent presence vs absence (sorted by quality gap):\n\n")

dumbbell_data %>%
  arrange(desc(gap)) %>%
  transmute(
    intent              = intent_label,
    n_present           = n_Present,
    quality_present     = round(composite_mean_Present, 3),
    quality_absent      = round(composite_mean_Absent,  3),
    gap                 = gap
  ) %>%
  print(n = Inf)

cat("\nSub-intent quality summary (sorted by intent category then quality):\n\n")

sub_intent_summary %>%
  arrange(intent_label, desc(composite_mean)) %>%
  transmute(
    intent     = intent_label,
    sub_intent = sub_intent,
    n          = n,
    composite  = round(composite_mean, 3)
  ) %>%
  print(n = Inf)
