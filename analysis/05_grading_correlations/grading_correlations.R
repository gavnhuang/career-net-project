library(tidyverse)
library(stringr)

all_data <- bind_rows(
  read_csv("data/general.csv",    show_col_types = FALSE) %>% mutate(domain = "General"),
  read_csv("data/health.csv",     show_col_types = FALSE) %>% mutate(domain = "Healthcare"),
  read_csv("data/technology.csv", show_col_types = FALSE) %>% mutate(domain = "Technology")
) %>%
  mutate(
    Correctness  = as.numeric(str_extract(correctness,  "^[1-4]")),
    Completeness = as.numeric(str_extract(completeness, "^[1-4]")),
    Coherency    = as.numeric(str_extract(coherency,    "^[1-4]"))
  ) %>%
  filter(!is.na(Correctness), !is.na(Completeness), !is.na(Coherency))

pairs <- list(
  c("Correctness",  "Completeness"),
  c("Correctness",  "Coherency"),
  c("Completeness", "Coherency")
)

domain_colors <- c(General = "#2C7BB6", Healthcare = "#1A9641", Technology = "#E66101")

# ── 1. tile heatmaps (combined) — stats in caption ───────────────────────────

pair_tile <- function(data, x_var, y_var, subtitle = NULL) {
  x_sym <- sym(x_var)
  y_sym <- sym(y_var)

  r_p <- round(cor(data[[x_var]], data[[y_var]], method = "pearson"),  3)
  r_s <- round(cor(data[[x_var]], data[[y_var]], method = "spearman"), 3)

  tile_data <- data %>%
    count(!!x_sym, !!y_sym) %>%
    mutate(pct = n / sum(n) * 100)

  ggplot(tile_data, aes(x = factor(!!x_sym), y = factor(!!y_sym))) +
    geom_tile(aes(fill = pct), colour = "white", linewidth = 0.8) +
    geom_text(aes(label = paste0(round(pct, 1), "%\n(n=", scales::comma(n), ")")),
              size = 3, colour = "white", fontface = "bold") +
    scale_fill_gradient(low = "#d9f0d3", high = "#1A6E2E", name = "% of\nResponses") +
    labs(
      title    = paste(x_var, "vs", y_var, "- Score Agreement"),
      subtitle = subtitle %||% paste0("All domains combined | n = ",
                                      scales::comma(nrow(data))),
      x        = paste(x_var, "(1 = Low, 4 = High)"),
      y        = paste(y_var, "(1 = Low, 4 = High)"),
      caption  = paste0("Pearson r = ", r_p, "   |   Spearman rho = ", r_s)
    ) +
    theme_minimal(base_size = 12) +
    theme(
      plot.title    = element_text(face = "bold", size = 13),
      plot.subtitle = element_text(size = 9, colour = "gray40"),
      plot.caption  = element_text(size = 9, colour = "gray40", hjust = 0.5,
                                   face = "italic", margin = margin(t = 6)),
      legend.position = "right"
    )
}

# ── 2. tile heatmaps (faceted by domain) — stats in subtitle ─────────────────

pair_tile_facet <- function(data, x_var, y_var) {
  x_sym <- sym(x_var)
  y_sym <- sym(y_var)

  cor_str <- data %>%
    group_by(domain) %>%
    summarise(
      r  = round(cor(!!x_sym, !!y_sym, method = "pearson"),  3),
      rs = round(cor(!!x_sym, !!y_sym, method = "spearman"), 3),
      .groups = "drop"
    ) %>%
    mutate(s = paste0(domain, ": r=", r, ", rho=", rs)) %>%
    pull(s) %>%
    paste(collapse = "   |   ")

  tile_data <- data %>%
    count(domain, !!x_sym, !!y_sym) %>%
    group_by(domain) %>%
    mutate(pct = n / sum(n) * 100) %>%
    ungroup()

  ggplot(tile_data, aes(x = factor(!!x_sym), y = factor(!!y_sym))) +
    geom_tile(aes(fill = pct), colour = "white", linewidth = 0.7) +
    geom_text(aes(label = paste0(round(pct, 1), "%")),
              size = 2.8, colour = "white", fontface = "bold") +
    scale_fill_gradient(low = "#d9f0d3", high = "#1A6E2E",
                        name = "% within\ndomain") +
    facet_wrap(~domain) +
    labs(
      title    = paste(x_var, "vs", y_var, "by Domain"),
      subtitle = paste0("n = ", scales::comma(nrow(data)), " total\n", cor_str),
      x        = paste(x_var, "(1-4)"),
      y        = paste(y_var, "(1-4)")
    ) +
    theme_minimal(base_size = 11) +
    theme(
      plot.title    = element_text(face = "bold", size = 13),
      plot.subtitle = element_text(size = 8, colour = "gray40"),
      strip.text    = element_text(face = "bold"),
      legend.position = "right"
    )
}

# ── 3. correlation matrix heatmap ─────────────────────────────────────────────

cor_matrix <- function(data, subtitle = NULL) {
  metrics <- c("Correctness", "Completeness", "Coherency")

  cor_df <- expand.grid(x = metrics, y = metrics, stringsAsFactors = FALSE) %>%
    rowwise() %>%
    mutate(
      pearson  = cor(data[[x]], data[[y]], method = "pearson"),
      spearman = cor(data[[x]], data[[y]], method = "spearman")
    ) %>%
    ungroup() %>%
    mutate(
      x = factor(x, levels = metrics),
      y = factor(y, levels = rev(metrics))
    )

  ggplot(cor_df, aes(x = x, y = y, fill = pearson)) +
    geom_tile(colour = "white", linewidth = 1.5) +
    geom_text(aes(label = paste0("r = ", round(pearson, 3),
                                 "\nrho = ", round(spearman, 3))),
              size = 4, fontface = "bold") +
    scale_fill_gradient2(
      low = "#D73027", mid = "white", high = "#1A9641",
      midpoint = 0, limits = c(-1, 1), name = "Pearson r"
    ) +
    labs(
      title    = "Correlation Matrix - Grading Dimensions",
      subtitle = subtitle %||% paste0("All domains | n = ",
                                      scales::comma(nrow(data))),
      x = NULL, y = NULL
    ) +
    theme_minimal(base_size = 13) +
    theme(
      plot.title      = element_text(face = "bold", size = 14),
      plot.subtitle   = element_text(size = 10, colour = "gray40"),
      axis.text       = element_text(face = "bold", size = 12),
      legend.position = "right"
    )
}

# ── render all pages ──────────────────────────────────────────────────────────

dir.create("plots/grading_correlations", recursive = TRUE, showWarnings = FALSE)
pdf("plots/grading_correlations/grading_correlations.pdf", width = 8, height = 6)

for (p in pairs) print(pair_tile(all_data, p[1], p[2]))
for (p in pairs) print(pair_tile_facet(all_data, p[1], p[2]))
print(cor_matrix(all_data))
for (dom in c("General", "Healthcare", "Technology")) {
  d <- filter(all_data, domain == dom)
  print(cor_matrix(d, subtitle = paste0(dom, " domain | n = ",
                                        scales::comma(nrow(d)))))
}

invisible(dev.off())

# ── console summary ───────────────────────────────────────────────────────────

cat("\n====================================================\n")
cat("GRADING DIMENSION CORRELATIONS\n")
cat("====================================================\n\n")

pairs_list <- list(
  c("Correctness", "Completeness"),
  c("Correctness", "Coherency"),
  c("Completeness", "Coherency")
)

cat("-- All Domains Combined ------------------------------------\n")
for (p in pairs_list) {
  r  <- round(cor(all_data[[p[1]]], all_data[[p[2]]], method = "pearson"),  3)
  rh <- round(cor(all_data[[p[1]]], all_data[[p[2]]], method = "spearman"), 3)
  cat(sprintf("  %-14s vs %-14s  Pearson r = %s   Spearman rho = %s\n",
              p[1], p[2], r, rh))
}

cat("\n-- By Domain -----------------------------------------------\n")
for (dom in c("General", "Healthcare", "Technology")) {
  cat(sprintf("\n  %s:\n", dom))
  d <- filter(all_data, domain == dom)
  for (p in pairs_list) {
    r  <- round(cor(d[[p[1]]], d[[p[2]]], method = "pearson"),  3)
    rh <- round(cor(d[[p[1]]], d[[p[2]]], method = "spearman"), 3)
    cat(sprintf("    %-14s vs %-14s  r = %s   rho = %s\n",
                p[1], p[2], r, rh))
  }
}
cat("\n")
