# ScenarioLabels: label names contain commas, so split ONLY on ";".

parse_scenario_labels <- function(x) {
  purrr::map(x, function(s) {
    if (is_missing(s)) return(character())
    v <- str_trim(str_split_1(s, fixed(";")))
    unique(v[v != ""])
  })
}

label_column_names <- function(labels) paste0("label_", snake_case(labels))

# One 0/1 integer column per label in `all_labels`. Unknown labels are an error.
scenario_label_indicators <- function(labels_list, all_labels) {
  unknown <- setdiff(unique(unlist(labels_list)), all_labels)
  if (length(unknown)) stop("Unknown scenario label(s): ", paste(unknown, collapse = "; "), call. = FALSE)
  cols <- purrr::map(all_labels, function(l) as.integer(purrr::map_lgl(labels_list, ~ l %in% .x)))
  names(cols) <- label_column_names(all_labels)
  tibble::as_tibble(cols)
}
