# reasoning_label: per-answer, ";"-separated, from 9 categories. Descriptive only.

REASONING_CATEGORIES <- c(
  "Inductive Reasoning", "Diagnostic/Explanatory Causal Reasoning", "Analogy about current circumstances",
  "Analogy about next steps", "Predictive Causal Reasoning/Interventional Reasoning",
  "Associational/Normative reasoning", "Necessary Conditions", "Counterfactual Reasoning",
  "No reasoning - explanation only"
)

parse_reasoning <- function(x) {
  out <- purrr::map(x, function(s) {
    if (is_missing(s)) return(character())
    v <- str_trim(str_split_1(s, fixed(";")))
    unique(v[v != ""])
  })
  unknown <- setdiff(unique(unlist(out)), REASONING_CATEGORIES)
  if (length(unknown)) warning("Unknown reasoning label(s): ", paste(unknown, collapse = "; "), call. = FALSE)
  out
}
