# ============================================================
# PILOT ANALYSIS: 4 FIGURES + 1 SUMMARY TABLE
# ============================================================
# 3 lab raters (P01, P02, P05) and Siya (master coder) scored 20 answers
# (10 human, 10 AI) on five 1-4 dimensions, all with rubric Draft 3.
#
# Run from the project root:
#   Rscript "analysis/06_pilot/pilot_figures.R"
#
# Figures -> plots/pilot/ (PNG 300 dpi + PDF); table -> outputs/pilot/pilot_summary.csv

source("analysis/06_pilot/00_pilot_helpers.R")
library(irr)

# ── Load ─────────────────────────────────────────────────────────────────────

ratings <- load_pilot_ratings()                 # 3 raters
siya    <- load_siya()
scorers <- bind_rows(ratings %>% select(rater, item, dim, score, uj, source), siya)
timing  <- load_pilot_timing(ratings)
guesses <- load_pilot_guesses()

# ============================================================
# NUMBERS
# ============================================================

# ── Time ─────────────────────────────────────────────────────────────────────
time_rater  <- timing %>% group_by(rater)  %>% summarise(m = mean(min), .groups = "drop")
time_source <- timing %>% group_by(source) %>% summarise(m = mean(min), .groups = "drop")
time_item   <- timing %>% group_by(item, source) %>% summarise(m = mean(min), .groups = "drop")

# ── AI vs human (item-level means, UJ excluded) ──────────────────────────────
item_means <- scorers %>%
  mutate(group = if_else(rater == "Siya", "siya", "pilot")) %>%
  group_by(group, item, source, dim) %>%
  summarise(score = mean(score, na.rm = TRUE), .groups = "drop") %>%
  filter(!is.nan(score))

avh <- item_means %>%
  group_by(group, dim) %>%
  summarise(human_mean = mean(score[source == "human"]),
            ai_mean    = mean(score[source == "ai"]), .groups = "drop") %>%
  mutate(diff_ai_minus_human = ai_mean - human_mean)

# ── Reliability ──────────────────────────────────────────────────────────────
exact_with_siya <- ratings %>%
  select(rater, item, dim, score) %>%
  inner_join(siya %>% select(item, dim, siya = score), by = c("item", "dim")) %>%
  filter(!is.na(score), !is.na(siya))

# Pairwise agreement among all 4 scorers (3 raters + Siya), one row per dimension x pair
SCORERS4 <- c(RATERS, "Siya")
pairs4 <- combn(SCORERS4, 2, simplify = FALSE)
pairwise4 <- map_dfr(DIMS, function(d) {
  m <- score_matrix(scorers, d, SCORERS4)
  map_dfr(pairs4, function(pr) {
    ok <- !is.na(m[, pr[1]]) & !is.na(m[, pr[2]])
    tibble(dim = d, pair = paste(pr, collapse = "_"),
           n_exact = sum(m[ok, pr[1]] == m[ok, pr[2]]), n = sum(ok))
  })
})
pairwise4_all <- pairwise4 %>% group_by(pair) %>%
  summarise(exact = sum(n_exact) / sum(n), .groups = "drop")

rel <- map_dfr(DIMS, function(d) {
  m3 <- score_matrix(scorers, d, RATERS)
  m4 <- score_matrix(scorers, d, c(RATERS, "Siya"))
  ews <- exact_with_siya %>% filter(dim == d) %>% group_by(rater) %>%
    summarise(p = mean(score == siya), .groups = "drop")
  tibble(
    dim             = d,
    alpha_3raters   = kripp.alpha(t(m3), method = "ordinal")$value,
    alpha_4scorers  = kripp.alpha(t(m4), method = "ordinal")$value,
    icc21_3raters   = icc(m3, model = "twoway", type = "agreement", unit = "single")$value,
    ac1_3raters     = gwet_ac1(m3),
    # all 4 scorers treated as equals
    icc21_4scorers  = icc(m4, model = "twoway", type = "agreement", unit = "single")$value,
    icc24_4scorers  = icc(m4, model = "twoway", type = "agreement", unit = "average")$value,
    ac1_4scorers    = gwet_ac1(m4),
    pct_all4_agree  = mean(apply(m4[complete.cases(m4), , drop = FALSE], 1, function(r) n_distinct(r) == 1)),
    pairwise_exact_4scorers   = mean(combn(SCORERS4, 2, function(pr) {
      ok <- !is.na(m4[, pr[1]]) & !is.na(m4[, pr[2]]); mean(m4[ok, pr[1]] == m4[ok, pr[2]]) })),
    pairwise_within1_4scorers = mean(combn(SCORERS4, 2, function(pr) {
      ok <- !is.na(m4[, pr[1]]) & !is.na(m4[, pr[2]]); mean(abs(m4[ok, pr[1]] - m4[ok, pr[2]]) <= 1) })),
    share_4s_3raters = mean(!is.na(m3) & m3 == 4),        # denominator: all 60 ratings incl. UJ
    exact_with_siya_mean = mean(ews$p),
    exact_with_siya_P01  = ews$p[ews$rater == "P01"],
    exact_with_siya_P02  = ews$p[ews$rater == "P02"],
    exact_with_siya_P05  = ews$p[ews$rater == "P05"]
  )
})

ews_overall <- exact_with_siya %>% group_by(rater) %>% summarise(p = mean(score == siya), .groups = "drop")

# ── Person or AI ─────────────────────────────────────────────────────────────
calls <- guesses %>% filter(!is.na(correct))
poa <- bind_rows(
  calls %>% group_by(who = rater) %>% summarise(correct = sum(correct), calls = n(), .groups = "drop"),
  calls %>% summarise(who = "All", correct = sum(correct), calls = n())
)

# ============================================================
# FIGURE 1 — Time per answer
# ============================================================

lvl1 <- time_item %>% arrange(m) %>% mutate(lab = item_label(item, source)) %>% pull(lab)
f1_pts  <- timing    %>% mutate(lab = factor(item_label(item, source), lvl1), Source = fct_source(source))
f1_mean <- time_item %>% mutate(lab = factor(item_label(item, source), lvl1), Source = fct_source(source))
overall_min <- mean(timing$min)
rater_note  <- paste(sprintf("%s %.1f", time_rater$rater, time_rater$m), collapse = ", ")

p1 <- ggplot(f1_pts, aes(x = min, y = lab, colour = Source, shape = Source)) +
  geom_vline(xintercept = 5, linetype = "dashed", colour = "grey40", linewidth = 0.5) +
  annotate("text", x = 5, y = 20.75, label = "Time planned in training", hjust = 1.04, vjust = 0,
           size = 3.6, colour = "grey25") +
  geom_point(size = 1.8, alpha = 0.5) +
  geom_point(data = f1_mean, aes(x = m), size = 3.6) +
  scale_colour_manual(values = SOURCE_COLORS, labels = c(Human = "Human-written", AI = "AI-generated")) +
  scale_shape_manual(values = c(Human = 16, AI = 17), labels = c(Human = "Human-written", AI = "AI-generated")) +
  scale_x_continuous(breaks = 0:6, limits = c(0, 6), expand = expansion(mult = c(0.01, 0.01))) +
  scale_y_discrete(expand = expansion(add = c(0.6, 1.4))) +
  coord_cartesian(clip = "off") +
  labs(title = sprintf("Raters took about %.0f minutes per answer, well under the planned 5", overall_min),
       subtitle = "3 pilot raters, 20 answers",
       caption = sprintf("Small points = one rater; large points = average for that answer.\nAverage per rater: %s minutes.",
                         rater_note),
       x = "Minutes spent on each answer", y = NULL) +
  theme_pilot() +
  theme(panel.grid.major.y = element_line(colour = "grey95"))

save_fig(p1, "01_time_per_answer", width = 9, height = 7)

# ============================================================
# FIGURE 2 — Score distributions (pilot raters + Siya pooled)
# ============================================================

lev2 <- c("1", "2", "3", "4", "UJ")
dist <- scorers %>%
  mutate(level = factor(if_else(uj, "UJ", as.character(score)), lev2),
         Source = fct_source(source), dim = fct_dim(dim)) %>%
  count(dim, Source, level) %>%
  group_by(dim, Source) %>%
  mutate(pct = n / sum(n)) %>%
  arrange(level, .by_group = TRUE) %>%
  mutate(xmid = cumsum(pct) - pct / 2) %>%
  ungroup()

pooled_means <- scorers %>%
  mutate(Source = fct_source(source), dim = fct_dim(dim)) %>%
  group_by(dim, Source) %>%
  summarise(m = mean(score, na.rm = TRUE), .groups = "drop")
src_lab <- c(Human = "Human", AI = "AI")

p2 <- ggplot(dist, aes(y = fct_rev(Source), x = pct)) +
  geom_col(aes(fill = level), position = position_stack(reverse = TRUE), width = 0.72,
           colour = "white", linewidth = 0.4) +
  geom_tile(data = filter(dist, level == "UJ"), aes(x = xmid, width = pct), height = 0.7,
            fill = "white", colour = "grey35", linewidth = 0.4, linetype = "dashed") +
  # share of 4s: the one number per bar that carries the point
  geom_text(data = filter(dist, level == "4"), aes(x = xmid, label = scales::percent(pct, accuracy = 1)),
            colour = "white", size = 3.5) +
  # source label in its color, left of each bar
  geom_text(data = pooled_means, aes(x = -0.015, label = src_lab[as.character(Source)], colour = Source),
            hjust = 1, size = 3.8, fontface = "bold") +
  geom_text(data = pooled_means, aes(x = 1.02, label = sprintf("mean %.2f", m), colour = Source),
            hjust = 0, size = 3.6, fontface = "bold") +
  facet_grid(dim ~ ., switch = "y") +
  scale_fill_manual(values = c(`1` = "#e6e6e6", `2` = "#b3b3b3", `3` = "#737373", `4` = "#262626", UJ = "white"),
                    labels = c(`1` = "1", `2` = "2", `3` = "3", `4` = "4", UJ = "Unable to judge"),
                    name = "Score") +
  scale_colour_manual(values = SOURCE_COLORS, guide = "none") +
  scale_x_continuous(labels = scales::percent, breaks = seq(0, 1, 0.25), limits = c(-0.1, 1.17),
                     expand = c(0, 0)) +
  guides(fill = guide_legend(override.aes = list(colour = "grey35"), nrow = 1)) +
  labs(title = "AI answers scored higher, and most scores were 4s",
       subtitle = "3 pilot raters and Siya, 20 answers (10 human, 10 AI)",
       caption = "Each bar = 40 scores (4 scorers × 10 answers). Percent = share of 4s. Means leave out 'Unable to judge'.",
       x = "Share of scores", y = NULL) +
  theme_pilot() +
  theme(strip.placement = "outside", strip.text.y.left = element_text(angle = 0, hjust = 1, face = "bold"),
        axis.text.y = element_blank(), panel.grid.major.y = element_blank(),
        panel.spacing.y = unit(0.7, "lines"), legend.title = element_text(face = "bold"))

save_fig(p2, "02_score_distributions", width = 9.5, height = 6.2)

# ============================================================
# FIGURE 3 — Agreement by dimension
# ============================================================

measure_levels <- c("Krippendorff's alpha", "Gwet's AC1", "Share of exact matches")
f3 <- rel %>%
  transmute(dim = fct_rev(fct_dim(dim)),
            `1` = alpha_4scorers, `2` = ac1_4scorers, `3` = pairwise_exact_4scorers) %>%
  pivot_longer(-dim, names_to = "k", values_to = "value") %>%
  mutate(measure = factor(measure_levels[as.integer(k)], measure_levels))
f3_ref <- tibble(measure = factor(measure_levels[1], measure_levels), x = 0.67)

p3 <- ggplot(f3, aes(x = value, y = dim)) +
  geom_vline(xintercept = 0, colour = "grey60", linewidth = 0.4) +
  geom_vline(data = f3_ref, aes(xintercept = x), linetype = "dashed", colour = "grey35") +
  geom_segment(aes(x = 0, xend = value, yend = dim), colour = "grey75", linewidth = 0.8) +
  geom_point(size = 3.6, colour = "black") +
  geom_label(aes(label = sub("^(-?)0\\.", "\\1.", sprintf("%.2f", value))), nudge_y = 0.33, size = 3.5,
             fill = "white", label.size = 0, label.padding = unit(0.08, "lines")) +
  facet_wrap(~measure, nrow = 1) +
  scale_x_continuous(limits = c(-0.2, 1), breaks = c(0, 0.5, 1), labels = c("0", ".5", "1")) +
  scale_y_discrete(expand = expansion(add = c(0.5, 0.7))) +
  labs(title = "Raters agreed least on supportiveness",
       subtitle = "3 pilot raters and Siya, 20 answers",
       caption = paste0("Alpha and AC1 are agreement corrected for chance (0 = chance, 1 = perfect); dashed line = .67, a common minimum for alpha.\n",
                        "Correctness looks low on alpha because nearly every score was 4, which leaves little to disagree about."),
       x = "Agreement (higher = more agreement)", y = NULL) +
  theme_pilot() +
  theme(panel.grid.major.y = element_blank(), panel.spacing.x = unit(1.4, "lines"))

save_fig(p3, "03_agreement_by_dimension", width = 10, height = 5)

# ============================================================
# FIGURE 4 — Item agreement map (gold vs calibration)
# ============================================================

heat <- scorers %>%
  group_by(item, source, dim) %>%
  summarise(range = max(score, na.rm = TRUE) - min(score, na.rm = TRUE),
            n_uj = sum(uj), .groups = "drop") %>%
  mutate(set = item_set(item), dim = fct_dim(dim))

row_order <- heat %>%
  group_by(item, source, set) %>%
  summarise(total = sum(range), .groups = "drop") %>%
  arrange(set, desc(total), item) %>%
  mutate(lab = item_label(item, source))

set_names_plain <- c(Gold = "Gold items", Calibration = "Calibration items")
heat <- heat %>%
  left_join(row_order %>% select(item, lab), by = "item") %>%
  mutate(lab = factor(lab, rev(row_order$lab)),
         range_f = factor(range, 0:3),
         set = factor(set_names_plain[as.character(set)], set_names_plain))

p4 <- ggplot(heat, aes(x = dim, y = lab)) +
  geom_tile(aes(fill = range_f), colour = "white", linewidth = 0.8) +
  geom_tile(data = filter(heat, n_uj > 0), fill = NA, colour = "black", linewidth = 0.7,
            width = 0.94, height = 0.86) +
  facet_grid(set ~ ., scales = "free_y", space = "free_y") +
  scale_fill_manual(values = c(`0` = "#f4f4f4", `1` = "#c4c4c4", `2` = "#7a7a7a", `3` = "#2e2e2e"),
                    labels = c(`0` = "0 (all agree)", `1` = "1 point", `2` = "2 points", `3` = "3 points"),
                    name = "Gap between highest and lowest score", drop = FALSE) +
  scale_x_discrete(position = "top") +
  labs(title = "Raters disagreed most on a few human-written calibration answers",
       subtitle = "3 pilot raters and Siya, 20 answers; rows sorted by total disagreement",
       caption = "Outlined cells include an 'Unable to judge' score, which is left out of the gap.",
       x = NULL, y = NULL) +
  guides(fill = guide_legend(title.position = "top", nrow = 1)) +
  theme_pilot() +
  theme(panel.grid = element_blank(), strip.text.y = element_text(angle = 0),
        legend.title = element_text(size = rel(0.9)))

save_fig(p4, "04_item_agreement_map", width = 9.5, height = 8.2)

# ============================================================
# TABLE — outputs/pilot/pilot_summary.csv (long)
# ============================================================

row <- function(section, measure, dimension, value) tibble(section, measure, dimension, value = as.numeric(value))

summary_tbl <- bind_rows(
  # time
  row("time", "mean_minutes_overall",   "All", mean(timing$min)),
  row("time", "median_minutes_overall", "All", median(timing$min)),
  row("time", paste0("mean_minutes_", time_rater$rater), "All", time_rater$m),
  row("time", paste0("mean_minutes_", time_source$source), "All", time_source$m),
  # ai vs human
  avh %>% pivot_longer(c(human_mean, ai_mean, diff_ai_minus_human), names_to = "m", values_to = "value") %>%
    transmute(section = "ai_vs_human", measure = paste0(if_else(group == "pilot", "pilot_raters_", "siya_"), m),
              dimension = dim, value),
  # reliability
  rel %>% pivot_longer(-dim, names_to = "measure", values_to = "value") %>%
    transmute(section = "reliability", measure, dimension = dim, value),
  row("reliability", paste0("exact_with_siya_", ews_overall$rater), "All", ews_overall$p),
  row("reliability", paste0("pairwise_exact_", pairwise4_all$pair), "All", pairwise4_all$exact),
  # person or ai
  row("person_or_ai", paste0("correct_calls_", poa$who), "All", poa$correct),
  row("person_or_ai", paste0("calls_made_",    poa$who), "All", poa$calls),
  row("person_or_ai", paste0("pct_correct_",   poa$who), "All", poa$correct / poa$calls)
) %>%
  mutate(dimension = factor(dimension, c(DIMS, "All", sort(unique(setdiff(dimension, c(DIMS, "All")))))),
         value = round(value, 3)) %>%
  arrange(factor(section, c("time", "ai_vs_human", "reliability", "person_or_ai")),
          measure, dimension) %>%
  mutate(dimension = as.character(dimension))

# The saved table is the record of the numbers: never overwrite it from here.
# Write it only if it is missing; otherwise confirm the recomputed numbers match it.
tbl_path <- file.path(OUT_DIR, "pilot_summary.csv")
if (!file.exists(tbl_path)) {
  write_csv(summary_tbl, tbl_path)
  message("Saved pilot_summary.csv (", nrow(summary_tbl), " rows)")
} else {
  saved <- read_csv(tbl_path, show_col_types = FALSE)
  same <- isTRUE(all.equal(as.data.frame(saved), as.data.frame(summary_tbl), check.attributes = FALSE))
  message("pilot_summary.csv left untouched; recomputed numbers ", if (same) "match it" else "DIFFER from it")
}

# ============================================================
# CHECKS against the Python run (flag |diff| > 0.01)
# ============================================================

ck <- function(what, ours, py, tol = 0.01) {
  tibble(check = what, r = round(ours, 3), python = py, flag = if_else(abs(ours - py) > tol, "DIFF", ""))
}
get_rel <- function(col) set_names(rel[[col]], rel$dim)
pa <- avh %>% filter(group == "pilot")

checks <- bind_rows(
  ck("time overall", mean(timing$min), 2.02),
  ck("time P01", time_rater$m[1], 1.22), ck("time P02", time_rater$m[2], 1.87), ck("time P05", time_rater$m[3], 2.97),
  ck("time human", time_source$m[time_source$source == "human"], 2.35),
  ck("time AI",    time_source$m[time_source$source == "ai"], 1.70),
  map2_dfr(DIMS, list(c(3.40, 3.87), c(3.67, 3.97), c(3.60, 3.90), c(3.27, 3.67), c(2.53, 2.87)),
           ~ bind_rows(ck(paste("pilot human", .x), pa$human_mean[pa$dim == .x], .y[1]),
                       ck(paste("pilot AI",    .x), pa$ai_mean[pa$dim == .x],    .y[2]))),
  ck(paste("alpha3", DIMS), get_rel("alpha_3raters"),  c(.40, -.08, .06, .69, .47)),
  ck(paste("alpha4", DIMS), get_rel("alpha_4scorers"), c(.43, -.09, .21, .72, .55)),
  ck(paste("AC1",    DIMS), get_rel("ac1_3raters"),    c(.61, .81, .62, .68, .40)),
  ck(paste("exact w/ Siya", ews_overall$rater), ews_overall$p, c(.71, .63, .76)),
  ck("person/AI correct", poa$correct[poa$who == "All"], 44, 0),
  ck("person/AI calls",   poa$calls[poa$who == "All"],   53, 0)

)
cat("\n==== Checks ====\n"); print(checks, n = Inf)

cat("\n==== Reliability, all 4 scorers ====\n")
print(rel %>% select(dim, alpha_4scorers, icc21_4scorers, icc24_4scorers, ac1_4scorers,
                     pct_all4_agree, pairwise_exact_4scorers, pairwise_within1_4scorers) %>%
        mutate(across(where(is.double), ~ round(.x, 2))), width = 200)
cat("\nPairwise exact agreement, all dimensions pooled:\n")
print(pairwise4_all %>% mutate(exact = round(exact, 2)))
