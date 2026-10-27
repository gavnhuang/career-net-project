# Report tables: label coverage and descriptive distributions, frame vs sample.

# frame_q / sample_q: one row per question with label_* columns.
coverage_table <- function(frame_q, sample_q = NULL, all_labels, guaranteed_labels = character(), floor = NULL) {
  cols <- label_column_names(all_labels)
  tab <- tibble::tibble(
    label = all_labels,
    guaranteed = ifelse(all_labels %in% guaranteed_labels, "yes", ""),
    frame_n = purrr::map_int(cols, ~ sum(frame_q[[.x]])),
    frame_share = fmt_pct(frame_n / nrow(frame_q))
  )
  if (!is.null(sample_q)) {
    tab$sample_n <- purrr::map_int(cols, ~ sum(sample_q[[.x]]))
    tab$sample_share <- fmt_pct(tab$sample_n / nrow(sample_q))
    tab$expected_if_srs <- sprintf("%.1f", tab$frame_n / nrow(frame_q) * nrow(sample_q))
    if (!is.null(floor)) {
      tab$floor_check <- ifelse(all_labels %in% guaranteed_labels, ifelse(tab$sample_n >= floor, "PASS", "FAIL"), "n/a")
    }
  }
  dplyr::arrange(tab, dplyr::desc(frame_n))
}

# Units carrying each value. values: list with one character vector per unit.
share_table <- function(frame_values, sample_values = NULL, value_name = "value") {
  count <- function(v, lv) purrr::map_int(lv, function(l) sum(purrr::map_lgl(v, ~ l %in% .x)))
  lv <- sort(unique(c(unlist(frame_values), unlist(sample_values))))
  tab <- tibble::tibble(value = lv, frame_n = count(frame_values, lv))
  tab$frame_share <- fmt_pct(tab$frame_n / length(frame_values))
  if (!is.null(sample_values)) {
    tab$sample_n <- count(sample_values, lv)
    tab$sample_share <- fmt_pct(tab$sample_n / length(sample_values))
  }
  tab <- dplyr::arrange(tab, dplyr::desc(frame_n))
  names(tab)[1] <- value_name
  tab
}

goal_values <- function(q) {
  present <- as.data.frame(lapply(q[c(GOAL_COLUMNS, "unclear_goal")], function(x) !is.na(x)))
  purrr::map(seq_len(nrow(q)), function(i) {
    v <- names(present)[unlist(present[i, ])]
    if (length(v)) v else "(no goal)"
  })
}

occupation_values <- function(q) {
  purrr::map(seq_len(nrow(q)), function(i) {
    v <- if (!is.na(q$soc_major_groups[i])) str_split_1(q$soc_major_groups[i], fixed("; ")) else character()
    flag <- q$soc_flag[i]
    if (!is.na(flag)) v <- c(v, paste0("[flag] ", str_split_1(flag, fixed("; "))))
    if (length(v)) v else "(soc_code missing)"
  })
}

# Markdown sections for goals, CareerNet ratings, occupation and reasoning labels.
# frame_q: frame questions; frame_a: the frame's eligible answers; sample: optional sample rows.
distribution_sections <- function(frame_q, frame_a, sample = NULL, sample_name = "sample") {
  rename_sample <- function(tab) {
    names(tab) <- str_replace(names(tab), "^sample_", paste0(sample_name, "_"))
    tab
  }
  single <- function(x) as.list(dplyr::coalesce(x, "(missing)"))
  out <- c("## Goals (question level)", "",
           "A question counts once under every goal column that is not missing.", "",
           md_table(rename_sample(share_table(goal_values(frame_q), if (!is.null(sample)) goal_values(sample), "goal"))), "")

  out <- c(out, "## CareerNet ratings of human answers", "",
           "Frame = every eligible answer; sample = the chosen human answer per question.", "")
  for (dim in c("correctness", "completeness", "coherency")) {
    col <- paste0("careernet_", dim)
    tab <- share_table(single(frame_a[[col]]), if (!is.null(sample)) single(sample[[col]]), dim)
    tab <- dplyr::arrange(tab, dplyr::desc(.data[[dim]]))
    means <- glue::glue("Mean {dim}_num: frame {sprintf('%.2f', mean(frame_a[[paste0(col, '_num')]], na.rm = TRUE))}",
                        if (!is.null(sample)) glue::glue(", {sample_name} {sprintf('%.2f', mean(sample[[paste0(col, '_num')]], na.rm = TRUE))}") else "")
    out <- c(out, glue::glue("### {dim}"), "", md_table(rename_sample(tab)), "", means, "")
  }

  occ_f <- occupation_values(frame_q)
  occ_s <- if (!is.null(sample)) occupation_values(sample)
  no_career <- function(v) mean(purrr::map_lgl(v, ~ "[flag] no_career_mentioned" %in% .x))
  out <- c(out, "## Occupation: SOC major groups (descriptive only)", "",
           glue::glue("Share with no career mentioned: frame {fmt_pct(no_career(occ_f))}",
                      if (!is.null(sample)) glue::glue(", {sample_name} {fmt_pct(no_career(occ_s))}") else ""), "",
           "A question counts once under every major group it lists. Flags are shown as [flag] rows.", "",
           md_table(rename_sample(share_table(occ_f, occ_s, "soc_major_group"))), "")

  rs <- function(x) purrr::map(parse_reasoning(x), ~ if (length(.x)) .x else "(missing)")
  out <- c(out, "## careernet_reasoning_label (descriptive only)", "",
           "Assigned by a fine-tuned GPT-4.1-mini (limited reliability). Frame = every eligible answer; sample = chosen human answers. An answer counts once under every category it carries.", "",
           md_table(rename_sample(share_table(rs(frame_a$careernet_reasoning_label),
                                              if (!is.null(sample)) rs(sample$careernet_reasoning_label),
                                              "reasoning_category"))), "")
  out
}
