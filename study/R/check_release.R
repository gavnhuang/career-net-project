# Compare two CareerNet releases (both already passed through read_careernet()).

check_release <- function(new, old, key = "answer_id") {
  new_columns <- setdiff(names(new), names(old))
  dropped_columns <- setdiff(names(old), names(new))
  shared <- setdiff(intersect(names(new), names(old)), key)

  only_new <- setdiff(new[[key]], old[[key]])
  only_old <- setdiff(old[[key]], new[[key]])
  dup_new <- sum(duplicated(new[[key]]))
  dup_old <- sum(duplicated(old[[key]]))

  m <- dplyr::inner_join(new[c(key, shared)], old[c(key, shared)], by = key, suffix = c(".new", ".old"))
  column_diffs <- purrr::map_dfr(shared, function(col) {
    a <- m[[paste0(col, ".new")]]
    b <- m[[paste0(col, ".old")]]
    same <- (is.na(a) & is.na(b)) | (!is.na(a) & !is.na(b) & a == b)
    tibble::tibble(column = col, n_differing = sum(!same),
                   example_ids = paste(head(m[[key]][!same], 3), collapse = ", "))
  })

  passed <- length(only_new) == 0 && length(only_old) == 0 && dup_new == 0 && dup_old == 0 &&
    length(dropped_columns) == 0 && all(column_diffs$n_differing == 0)

  list(passed = passed, n_rows_new = nrow(new), n_rows_old = nrow(old),
       new_columns = new_columns, dropped_columns = dropped_columns, shared_columns = shared,
       ids_only_new = only_new, ids_only_old = only_old, duplicated_new = dup_new, duplicated_old = dup_old,
       column_diffs = column_diffs)
}

render_release_report <- function(res, new_label, old_label, new_path, old_path, run_id) {
  verdict <- if (res$passed) "**PASS**: identical content on every shared column." else "**FAIL**: content differs. Do not build the frame until this is understood."
  diffs <- res$column_diffs
  c(
    glue::glue("# Release check: {new_label} vs {old_label}"), "",
    glue::glue("Run `{run_id}`"), "",
    glue::glue("- New: `{new_path}` ({format(res$n_rows_new, big.mark = ',')} rows)"),
    glue::glue("- Previous: `{old_path}` ({format(res$n_rows_old, big.mark = ',')} rows)"),
    "- Missing values normalized before comparing: \"\", \"NA\" and NA all count as missing.", "",
    "## Result", "", verdict, "",
    "| Check | Value |", "|---|---|",
    glue::glue("| answer_ids only in {new_label} | {length(res$ids_only_new)} |"),
    glue::glue("| answer_ids only in {old_label} | {length(res$ids_only_old)} |"),
    glue::glue("| duplicated answer_ids ({new_label} / {old_label}) | {res$duplicated_new} / {res$duplicated_old} |"),
    glue::glue("| shared columns compared | {length(res$shared_columns)} |"),
    glue::glue("| shared columns with any difference | {sum(diffs$n_differing > 0)} |"),
    glue::glue("| new columns in {new_label} | {if (length(res$new_columns)) paste(res$new_columns, collapse = ', ') else 'none'} |"),
    glue::glue("| columns dropped from {old_label} | {if (length(res$dropped_columns)) paste(res$dropped_columns, collapse = ', ') else 'none'} |"),
    "", "## Per-column comparison", "",
    md_table(dplyr::rename(diffs, `differing rows` = n_differing, `example answer_ids` = example_ids))
  )
}
