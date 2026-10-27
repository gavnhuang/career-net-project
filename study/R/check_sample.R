# Integrity checks. Each returns a tibble(check, passed, detail); callers stop on any FALSE.

check_sample <- function(sample, frame_questions, frame_answers, anchor_ids = character(),
                         reserved_ids = character(), guaranteed_labels = character(), floor = NULL,
                         n = NULL, check_floor_block = FALSE) {
  label_n <- purrr::map_int(label_column_names(guaranteed_labels), ~ sum(sample[[.x]]))
  below <- guaranteed_labels[label_n < (floor %||% 0)]
  pair_ok <- paste(sample$question_id, sample$answer_id) %in% paste(frame_answers$question_id, frame_answers$answer_id)
  checks <- list(
    c("n is exact", is.null(n) || nrow(sample) == n, glue::glue("{nrow(sample)} rows, expected {n %||% 'any'}")),
    c("no duplicate question_ids", !anyDuplicated(sample$question_id), ""),
    c("all questions are in the frame", all(sample$question_id %in% frame_questions$question_id), ""),
    c("no anchor check questions", !any(sample$question_id %in% anchor_ids),
      paste(intersect(sample$question_id, anchor_ids), collapse = ", ")),
    c("no reserved questions", !any(sample$question_id %in% reserved_ids),
      paste(intersect(sample$question_id, reserved_ids), collapse = ", ")),
    c("human answer is an eligible answer to its question", all(pair_ok), ""),
    c("no private id columns", !any(PRIVATE_COLUMNS %in% names(sample)), ""),
    c("inclusion_prob in (0, 1]", all(sample$inclusion_prob > 0 & sample$inclusion_prob <= 1), "")
  )
  if (!is.null(floor)) {
    checks <- c(checks, list(c(glue::glue("every guaranteed label has >= {floor} questions"), length(below) == 0,
                               paste(below, collapse = "; "))))
  }
  if (!is.null(floor) && "floor_block" %in% names(sample)) {
    n_block <- tryCatch(floor_block_size(sample), error = function(e) conditionMessage(e))
    prefix_ok <- is.numeric(n_block)
    block <- sample[!is.na(sample$floor_block) & sample$floor_block, ]
    block_below <- guaranteed_labels[purrr::map_int(label_column_names(guaranteed_labels), ~ sum(block[[.x]])) < floor]
    checks <- c(checks, list(
      c("floor-stage questions come first in draw order", prefix_ok, if (prefix_ok) glue::glue("floor block = first {n_block}") else n_block)))
    # Only for the unscreened draw: screening checks the floor across the whole sample.
    if (check_floor_block) {
      checks <- c(checks, list(c(glue::glue("the floor block alone gives every guaranteed label >= {floor} questions"),
                                 length(block_below) == 0, paste(block_below, collapse = "; "))))
    }
  }
  tibble::tibble(check = purrr::map_chr(checks, 1), passed = as.logical(purrr::map_chr(checks, 2)),
                 detail = purrr::map_chr(checks, 3))
}

check_reserved_sets <- function(sets, sets_spec, frame_questions, anchor_ids = character()) {
  sizes_ok <- purrr::map_lgl(sets_spec, function(s) {
    x <- sets[sets$set == s$name, ]
    nrow(x) == s$size && sum(x$planned_version == "human") == s$n_human && sum(x$planned_version == "ai") == s$n_ai
  })
  tibble::tibble(
    check = c("set sizes and planned_version splits match config", "reserved sets do not overlap",
              "all reserved questions are in the frame", "no anchor check questions"),
    passed = c(all(sizes_ok), !anyDuplicated(sets$question_id),
               all(sets$question_id %in% frame_questions$question_id), !any(sets$question_id %in% anchor_ids)),
    detail = c(paste(purrr::map_chr(sets_spec, "name")[!sizes_ok], collapse = ", "), "", "", "")
  )
}

stop_on_failed_checks <- function(checks) {
  if (!all(checks$passed)) {
    stop("Check(s) failed:\n", paste0("  - ", checks$check[!checks$passed], ": ", checks$detail[!checks$passed],
                                      collapse = "\n"), call. = FALSE)
  }
  invisible(TRUE)
}
