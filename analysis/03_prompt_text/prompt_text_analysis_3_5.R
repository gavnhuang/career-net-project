library(tidyverse)
library(tidytext)
library(stringr)

# ============================================================
# 1. LOAD AND PREPARE
# ============================================================

all_data <- bind_rows(
  read_csv("data/general.csv",    show_col_types = FALSE) %>% mutate(domain = "General"),
  read_csv("data/health.csv",     show_col_types = FALSE) %>% mutate(domain = "Healthcare"),
  read_csv("data/technology.csv", show_col_types = FALSE) %>% mutate(domain = "Technology")
) %>%
  mutate(
    completeness_num  = as.numeric(str_extract(completeness, "^[1-4]")),
    coherency_num     = as.numeric(str_extract(coherency,    "^[1-4]")),
    correctness_num   = as.numeric(str_extract(correctness,  "^[1-4]")),
    composite_quality = (completeness_num + coherency_num + correctness_num) / 3,
    prompt_text       = paste(
      str_remove_all(coalesce(question_title, ""), "<.*?>"),
      str_remove_all(coalesce(question_body,  ""), "<.*?>")
    )
  ) %>%
  filter(
    !is.na(completeness_num), !is.na(coherency_num), !is.na(correctness_num),
    str_trim(prompt_text) != ""
  ) %>%
  mutate(quality_group = ifelse(composite_quality > 3.5, "> 3.5", "<= 3.5"))

n_high <- sum(all_data$quality_group == "> 3.5")
n_low  <- sum(all_data$quality_group == "<= 3.5")

# ============================================================
# 2. SINGLE WORDS
# ============================================================

tokens <- all_data %>%
  select(quality_group, prompt_text) %>%
  unnest_tokens(word, prompt_text) %>%
  anti_join(stop_words, by = "word") %>%
  filter(str_detect(word, "^[a-z]{3,}$"))

word_freq <- tokens %>%
  count(quality_group, word) %>%
  group_by(quality_group) %>%
  mutate(pct = n / sum(n) * 100) %>%
  ungroup()

word_tfidf <- word_freq %>%
  bind_tf_idf(word, quality_group, n) %>%
  group_by(quality_group) %>%
  slice_max(tf_idf, n = 20, with_ties = FALSE) %>%
  ungroup()

# ============================================================
# 3. BIGRAMS (two-word phrases)
# ============================================================

bigrams <- all_data %>%
  select(quality_group, prompt_text) %>%
  unnest_tokens(bigram, prompt_text, token = "ngrams", n = 2) %>%
  separate(bigram, into = c("w1", "w2"), sep = " ") %>%
  filter(
    !w1 %in% stop_words$word,
    !w2 %in% stop_words$word,
    str_detect(w1, "^[a-z]{2,}$"),
    str_detect(w2, "^[a-z]{2,}$")
  ) %>%
  unite(bigram, w1, w2, sep = " ")

bigram_tfidf <- bigrams %>%
  count(quality_group, bigram) %>%
  filter(n >= 5) %>%
  bind_tf_idf(bigram, quality_group, n) %>%
  group_by(quality_group) %>%
  slice_max(tf_idf, n = 15, with_ties = FALSE) %>%
  ungroup()

# ============================================================
# 4. LOG ODDS RATIO
# ============================================================

word_log_odds <- word_freq %>%
  select(quality_group, word, n) %>%
  pivot_wider(names_from = quality_group, values_from = n, values_fill = 0) %>%
  filter(`> 3.5` + `<= 3.5` >= 10) %>%
  mutate(
    p_high   = (`> 3.5`  + 0.5) / (n_high + 0.5),
    p_low    = (`<= 3.5` + 0.5) / (n_low  + 0.5),
    log_odds = log(p_high / p_low)
  ) %>%
  slice_max(abs(log_odds), n = 30)

bigram_log_odds <- bigrams %>%
  count(quality_group, bigram) %>%
  filter(n >= 5) %>%
  pivot_wider(names_from = quality_group, values_from = n, values_fill = 0) %>%
  filter(`> 3.5` + `<= 3.5` >= 5) %>%
  mutate(
    p_high   = (`> 3.5`  + 0.5) / (n_high + 0.5),
    p_low    = (`<= 3.5` + 0.5) / (n_low  + 0.5),
    log_odds = log(p_high / p_low)
  ) %>%
  slice_max(abs(log_odds), n = 24)

# ============================================================
# 5. PLOTS
# ============================================================

theme_text <- theme_minimal(base_size = 11) +
  theme(
    plot.title      = element_text(face = "bold", size = 13),
    plot.subtitle   = element_text(size = 10, color = "gray40"),
    legend.position = "none"
  )

group_colors <- c("> 3.5" = "#2C7BB6", "<= 3.5" = "#E66101")

p1 <- word_freq %>%
  group_by(quality_group) %>%
  slice_max(pct, n = 20, with_ties = FALSE) %>%
  ungroup() %>%
  mutate(word = reorder_within(word, pct, quality_group)) %>%
  ggplot(aes(x = pct, y = word, fill = quality_group)) +
  geom_col() +
  scale_y_reordered() +
  scale_fill_manual(values = group_colors) +
  facet_wrap(~ quality_group, scales = "free_y") +
  labs(
    title    = "Most Common Words by Prompt Quality Group",
    subtitle = paste0(
      "Top 20 words by frequency | Stop words removed | ",
      "> 3.5 n = ", scales::comma(n_high), " | <= 3.5 n = ", scales::comma(n_low)
    ),
    x = "% of all words in group",
    y = NULL
  ) +
  theme_text

p2 <- word_tfidf %>%
  mutate(word = reorder_within(word, tf_idf, quality_group)) %>%
  ggplot(aes(x = tf_idf, y = word, fill = quality_group)) +
  geom_col() +
  scale_y_reordered() +
  scale_fill_manual(values = group_colors) +
  facet_wrap(~ quality_group, scales = "free_y") +
  labs(
    title    = "Most Distinctive Words by Prompt Quality Group",
    subtitle = "TF-IDF score: words proportionally more common in one group than the other",
    x        = "TF-IDF score",
    y        = NULL
  ) +
  theme_text

p3 <- bigram_tfidf %>%
  mutate(bigram = reorder_within(bigram, tf_idf, quality_group)) %>%
  ggplot(aes(x = tf_idf, y = bigram, fill = quality_group)) +
  geom_col() +
  scale_y_reordered() +
  scale_fill_manual(values = group_colors) +
  facet_wrap(~ quality_group, scales = "free_y") +
  labs(
    title    = "Most Distinctive Two-Word Phrases by Prompt Quality Group",
    subtitle = "TF-IDF score | Phrases appearing fewer than 5 times excluded",
    x        = "TF-IDF score",
    y        = NULL
  ) +
  theme_text

p6 <- word_tfidf %>%
  mutate(word = reorder_within(word, n, quality_group)) %>%
  ggplot(aes(x = n, y = word, fill = quality_group)) +
  geom_col(show.legend = FALSE) +
  geom_text(aes(label = scales::comma(n)), hjust = -0.1, size = 2.8) +
  scale_y_reordered() +
  scale_x_continuous(expand = expansion(mult = c(0, 0.2)), labels = scales::comma) +
  scale_fill_manual(values = group_colors) +
  facet_wrap(~ quality_group, scales = "free_y") +
  labs(
    title    = "Frequency of most distinctive words",
    subtitle = "Same words as page 2 — showing raw count instead of TF-IDF score",
    x        = "Number of times word appears",
    y        = NULL
  ) +
  theme_text

bigram_counts <- bigrams %>%
  count(quality_group, bigram)

p7 <- bigram_tfidf %>%
  mutate(bigram = reorder_within(bigram, n, quality_group)) %>%
  ggplot(aes(x = n, y = bigram, fill = quality_group)) +
  geom_col(show.legend = FALSE) +
  geom_text(aes(label = scales::comma(n)), hjust = -0.1, size = 2.8) +
  scale_y_reordered() +
  scale_x_continuous(expand = expansion(mult = c(0, 0.2)), labels = scales::comma) +
  scale_fill_manual(values = group_colors) +
  facet_wrap(~ quality_group, scales = "free_y") +
  labs(
    title    = "Frequency of most distinctive two-word phrases",
    subtitle = "Same phrases as page 3 — showing raw count instead of TF-IDF score",
    x        = "Number of times phrase appears",
    y        = NULL
  ) +
  theme_text

# ============================================================
# 6. SAVE
# ============================================================

dir.create("plots/prompt_text",   recursive = TRUE, showWarnings = FALSE)
dir.create("outputs/prompt_text", recursive = TRUE, showWarnings = FALSE)

pdf("plots/prompt_text/prompt_text_analysis_3_5.pdf", width = 12, height = 8)
print(p1)
print(p2)
print(p3)
print(p6)
print(p7)
invisible(dev.off())

write_csv(word_tfidf,   "outputs/prompt_text/distinctive_words_3_5.csv")
write_csv(bigram_tfidf, "outputs/prompt_text/distinctive_bigrams_3_5.csv")

# ============================================================
# 7. CONSOLE OUTPUT
# ============================================================

cat("\n====================================================\n")
cat("PROMPT TEXT ANALYSIS (> 3.5 vs <= 3.5) COMPLETE\n")
cat("====================================================\n\n")
cat("Composite > 3.5: ", scales::comma(n_high), "\n")
cat("Composite <= 3.5:", scales::comma(n_low),  "\n\n")

cat("Most distinctive words — > 3.5 prompts:\n")
word_tfidf %>%
  filter(quality_group == "> 3.5") %>%
  arrange(desc(tf_idf)) %>%
  transmute(word, n, pct = round(pct, 3), tf_idf = round(tf_idf, 5)) %>%
  print(n = 20)

cat("\nMost distinctive words — <= 3.5 prompts:\n")
word_tfidf %>%
  filter(quality_group == "<= 3.5") %>%
  arrange(desc(tf_idf)) %>%
  transmute(word, n, pct = round(pct, 3), tf_idf = round(tf_idf, 5)) %>%
  print(n = 20)

cat("\nMost distinctive phrases — > 3.5 prompts:\n")
bigram_tfidf %>%
  filter(quality_group == "> 3.5") %>%
  arrange(desc(tf_idf)) %>%
  transmute(bigram, n, tf_idf = round(tf_idf, 5)) %>%
  print(n = 15)

cat("\nMost distinctive phrases — <= 3.5 prompts:\n")
bigram_tfidf %>%
  filter(quality_group == "<= 3.5") %>%
  arrange(desc(tf_idf)) %>%
  transmute(bigram, n, tf_idf = round(tf_idf, 5)) %>%
  print(n = 15)
