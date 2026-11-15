# ============================================================
# PILOT HELPERS
# ============================================================
# Paths, loaders, constants, agreement functions, and plot theme for
# the pilot rating study. Source from the project root.
# Inputs are read-only; nothing here writes to data/ or study/data/.

library(tidyverse)

# ── Paths ────────────────────────────────────────────────────────────────────

PILOT_DIR <- "../07 Study Materials/06 Pilot/03 Analysis"
PLOT_DIR  <- "plots/pilot"
OUT_DIR   <- "outputs/pilot"
dir.create(PLOT_DIR, recursive = TRUE, showWarnings = FALSE)
dir.create(OUT_DIR,  recursive = TRUE, showWarnings = FALSE)

# ── Constants ────────────────────────────────────────────────────────────────

DIMS   <- c("Completeness", "Correctness", "Coherency", "Actionability", "Supportiveness")
RATERS <- c("P01", "P02", "P05")

SOURCE_LABELS <- c(human = "Human", ai = "AI")
SOURCE_COLORS <- c(Human = "#0072B2", AI = "#D55E00")   # Okabe-Ito blue / vermillion (colorblind-safe)

GOLD_ITEMS  <- c(1, 3, 5, 6, 7, 8, 10, 13, 17, 20)
CALIB_ITEMS <- c(2, 4, 9, 11, 12, 14, 15, 16, 18, 19)
SET_LEVELS  <- c("Gold", "Calibration")

fct_source <- function(x) factor(SOURCE_LABELS[x], levels = unname(SOURCE_LABELS))
fct_dim    <- function(x) factor(x, levels = DIMS)
item_set   <- function(item) factor(if_else(item %in% GOLD_ITEMS, "Gold", "Calibration"), levels = SET_LEVELS)
# Short topic for each answer's question (from the question titles), for readable axis labels
ITEM_TOPICS <- c(
  `1` = "Finding career guidance",    `2` = "Choosing a major",
  `3` = "Making a career decision",   `4` = "CS graduate resume",
  `5` = "What goes on a resume",      `6` = "Value of a college minor",
  `7` = "Which biology major",        `8` = "Skills for architects",
  `9` = "Choosing a career path",     `10` = "Studying abroad",
  `11` = "Preparing for a first job", `12` = "Finding your passion",
  `13` = "Marine biology connections", `14` = "Welding job or degree",
  `15` = "No career seems to fit",    `16` = "Re-entering engineering",
  `17` = "Where to find support",     `18` = "Narrowing a job search",
  `19` = "Which career is right",     `20` = "Finding life goals"
)
item_label <- function(item, source) paste0(ITEM_TOPICS[as.character(item)], " (", SOURCE_LABELS[source], ")")

# ── Loaders ──────────────────────────────────────────────────────────────────

read_pilot <- function(file) read_csv(file.path(PILOT_DIR, file), show_col_types = FALSE)

# rater, item, dim, raw, score (NA = UJ), uj, source
load_pilot_ratings <- function() read_pilot("pilot_ratings_long.csv") %>% mutate(uj = as.logical(uj))

# rater, item, submit, min (+ source from the ratings file)
load_pilot_timing <- function(ratings) {
  read_pilot("pilot_timing_long.csv") %>%
    left_join(distinct(ratings, item, source), by = "item")
}

# rater, item, guess, source, call, correct (1/0/NA)
load_pilot_guesses <- function() read_pilot("pilot_person_or_ai_long.csv")

# Siya's codes only (Draft 3, master coder), in the same shape as the rater file
load_siya <- function() {
  read_pilot("coder_scores_long.csv") %>%
    filter(coder == "Siya") %>%
    transmute(rater = "Siya", item, dim, score, uj = as.logical(uj), source)
}

# ── Agreement helpers ────────────────────────────────────────────────────────

# Wide matrix items x scorers for one dimension (NA = UJ)
score_matrix <- function(long, d, who) {
  long %>%
    filter(dim == d, rater %in% who) %>%
    select(item, rater, score) %>%
    pivot_wider(names_from = rater, values_from = score) %>%
    arrange(item) %>%
    select(all_of(who)) %>%
    as.matrix()
}

# Multi-rater Gwet AC1 (Gwet 2008), categories fixed at 1-4, missing dropped.
# pa uses items with >= 2 ratings; pi_k uses items with >= 1 rating.
gwet_ac1 <- function(m, cats = 1:4) {
  r_ik <- t(apply(m, 1, function(x) tabulate(match(x, cats), nbins = length(cats))))
  r_i  <- rowSums(r_ik)
  two  <- r_i >= 2
  pa   <- mean(rowSums(r_ik[two, , drop = FALSE] * (r_ik[two, , drop = FALSE] - 1)) /
                 (r_i[two] * (r_i[two] - 1)))
  pik  <- colMeans(r_ik[r_i >= 1, , drop = FALSE] / r_i[r_i >= 1])
  pe   <- sum(pik * (1 - pik)) / (length(cats) - 1)
  (pa - pe) / (1 - pe)
}

# Quadratic-weighted kappa with categories fixed at 1-4 (cross-check on irr::kappa2)
qwk_fixed <- function(x, y, lev = 1:4) {
  o <- table(factor(x, lev), factor(y, lev)) / length(x)
  e <- outer(rowSums(o), colSums(o))
  w <- outer(lev, lev, function(i, j) (i - j)^2)
  1 - sum(w * o) / sum(w * e)
}

# ── Theme and saving ─────────────────────────────────────────────────────────

theme_pilot <- function(base_size = 12) {
  theme_minimal(base_size = base_size) +
    theme(
      plot.title         = element_text(face = "bold", size = rel(1.1), margin = margin(b = 4)),
      plot.subtitle      = element_text(colour = "grey30", size = rel(0.9), margin = margin(b = 10)),
      plot.caption       = element_text(colour = "grey35", hjust = 0, size = rel(0.8), lineheight = 1.15,
                                        margin = margin(t = 10)),
      plot.title.position   = "plot",
      plot.caption.position = "plot",
      panel.grid.minor   = element_blank(),
      panel.grid.major   = element_line(colour = "grey92"),
      strip.text         = element_text(face = "bold", hjust = 0),
      legend.position    = "top",
      legend.justification = "left",
      legend.title       = element_blank(),
      plot.background    = element_rect(fill = "white", colour = NA),
      plot.margin        = margin(12, 16, 10, 12)
    )
}

# PNG via ragg (300 dpi); PDF via base pdf() because Cairo needs XQuartz here.
# WinAnsi encoding covers × and en dash; avoid the Unicode minus sign in labels.
save_fig <- function(plot, name, width, height) {
  ggsave(file.path(PLOT_DIR, paste0(name, ".png")), plot, width = width, height = height,
         dpi = 300, bg = "white", device = ragg::agg_png)
  ggsave(file.path(PLOT_DIR, paste0(name, ".pdf")), plot, width = width, height = height,
         device = grDevices::pdf, encoding = "WinAnsi.enc")
  message("Saved ", name)
}
