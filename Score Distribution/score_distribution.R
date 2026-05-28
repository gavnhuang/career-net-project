library(tidyverse)
library(stringr)

all_data <- bind_rows(
  read_csv("data/general.csv",    show_col_types = FALSE) %>% mutate(domain = "General"),
  read_csv("data/health.csv",     show_col_types = FALSE) %>% mutate(domain = "Healthcare"),
  read_csv("data/technology.csv", show_col_types = FALSE) %>% mutate(domain = "Technology")
) %>%
  mutate(
    completeness_num = as.numeric(str_extract(completeness, "^[1-4]")),
    coherency_num    = as.numeric(str_extract(coherency,    "^[1-4]")),
    correctness_num  = as.numeric(str_extract(correctness,  "^[1-4]"))
  ) %>%
  filter(
    !is.na(completeness_num),
    !is.na(coherency_num),
    !is.na(correctness_num)
  )

dist_data <- all_data %>%
  pivot_longer(
    cols      = c(completeness_num, coherency_num, correctness_num),
    names_to  = "dimension",
    values_to = "rating"
  ) %>%
  mutate(dimension = recode(dimension,
    completeness_num = "Completeness",
    coherency_num    = "Coherency",
    correctness_num  = "Correctness"
  )) %>%
  count(dimension, rating) %>%
  group_by(dimension) %>%
  mutate(pct = n / sum(n) * 100) %>%
  ungroup()

p <- dist_data %>%
  ggplot(aes(x = factor(rating), y = pct, fill = dimension)) +
  geom_col(position = "dodge", width = 0.7) +
  geom_text(
    aes(label = paste0(round(pct, 1), "%")),
    position = position_dodge(width = 0.7),
    vjust = -0.4, size = 3.2
  ) +
  scale_fill_manual(values = c(
    Completeness = "#E66101",
    Coherency    = "#2C7BB6",
    Correctness  = "#1A9641"
  )) +
  scale_y_continuous(limits = c(0, 75), labels = function(x) paste0(x, "%")) +
  labs(
    title    = "Distribution of Scores Across Quality Dimensions",
    subtitle = paste0("All domains combined | n = ", scales::comma(nrow(all_data)), " responses"),
    x        = "Rating  (1 = Low, 4 = High)",
    y        = "% of Responses",
    fill     = NULL
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title      = element_text(face = "bold", size = 14),
    plot.subtitle   = element_text(size = 10, color = "gray40"),
    legend.position = "top"
  )

composite_data <- all_data %>%
  mutate(composite_quality = (completeness_num + coherency_num + correctness_num) / 3)

mean_composite <- mean(composite_data$composite_quality)

p2 <- composite_data %>%
  ggplot(aes(x = composite_quality)) +
  geom_histogram(binwidth = 1/3, fill = "#2C7BB6", color = "white", boundary = 1) +
  geom_vline(xintercept = mean_composite, color = "#E66101", linewidth = 1.2, linetype = "dashed") +
  annotate(
    "text",
    x     = mean_composite + 0.08,
    y     = Inf,
    label = paste0("Mean = ", round(mean_composite, 2)),
    vjust = 1.6, hjust = 0,
    color = "#E66101", size = 3.8, fontface = "bold"
  ) +
  scale_x_continuous(breaks = seq(1, 4, by = 1/3), labels = function(x) round(x, 2)) +
  scale_y_continuous(labels = scales::comma) +
  labs(
    title    = "Distribution of Composite Quality Scores",
    subtitle = paste0(
      "All three dimensions averaged | n = ", scales::comma(nrow(composite_data)), " responses | ",
      "Dashed line = mean"
    ),
    x = "Composite Quality Score  (1 = Low, 4 = High)",
    y = "Number of Responses"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title    = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(size = 10, color = "gray40"),
    axis.text.x   = element_text(angle = 45, hjust = 1)
  )

p3 <- composite_data %>%
  ggplot(aes(x = composite_quality, y = "")) +
  geom_jitter(width = 0.04, height = 0.4, alpha = 0.07, color = "#2C7BB6", size = 0.7) +
  geom_vline(xintercept = mean_composite, color = "#E66101", linewidth = 1.2, linetype = "dashed") +
  annotate(
    "text",
    x     = mean_composite + 0.06,
    y     = Inf,
    label = paste0("Mean = ", round(mean_composite, 2)),
    vjust = 1.6, hjust = 0,
    color = "#E66101", size = 3.8, fontface = "bold"
  ) +
  scale_x_continuous(breaks = seq(1, 4, by = 1/3), labels = function(x) round(x, 2)) +
  labs(
    title    = "Every Composite Quality Score — Individual Points",
    subtitle = paste0(
      "Each dot = one response | n = ", scales::comma(nrow(composite_data)),
      " | Points jittered vertically to reduce overlap | Dashed line = mean"
    ),
    x = "Composite Quality Score  (1 = Low, 4 = High)",
    y = NULL
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title    = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(size = 10, color = "gray40"),
    axis.text.x   = element_text(angle = 45, hjust = 1),
    axis.text.y   = element_blank(),
    axis.ticks.y  = element_blank(),
    panel.grid.major.y = element_blank(),
    panel.grid.minor.y = element_blank()
  )

dir.create("plots/score_distribution", recursive = TRUE, showWarnings = FALSE)
pdf("plots/score_distribution/score_distribution.pdf", width = 10, height = 6)
print(p)
print(p2)
print(p3)
invisible(dev.off())

cat("\n====================================================\n")
cat("SCORE DISTRIBUTION\n")
cat("====================================================\n\n")
print(dist_data %>%
  mutate(pct = round(pct, 1)) %>%
  pivot_wider(names_from = dimension, values_from = c(n, pct)) %>%
  arrange(rating), n = Inf)
