# Study draw with a coverage floor:
#  1. Go through the guaranteed labels from rarest to most common (count in `frame`,
#     ties in config order). If fewer than `floor` selected questions carry the label,
#     draw the shortfall at random from unselected questions carrying it.
#  2. Fill the remaining slots by simple random sampling from all unselected questions.
# A multi-label question counts toward every label it carries.

# Everything the draw needs that does not depend on the seed. Fails loudly when a
# guaranteed label cannot meet the floor.
prepare_floor_design <- function(frame, guaranteed_labels, floor, n) {
  frame <- frame[order(id_key(frame$question_id), method = "radix"), ]
  if (anyDuplicated(frame$question_id)) stop("Duplicate question_ids in the frame", call. = FALSE)
  cols <- label_column_names(guaranteed_labels)
  missing <- setdiff(cols, names(frame))
  if (length(missing)) stop("Frame lacks label column(s): ", paste(missing, collapse = ", "), call. = FALSE)

  member <- as.matrix(frame[cols]) == 1L
  colnames(member) <- guaranteed_labels
  available <- colSums(member)
  short <- available < floor
  if (any(short)) {
    stop("Guaranteed label(s) cannot meet the floor of ", floor, ": ",
         paste0(guaranteed_labels[short], " (", available[short], " available)", collapse = "; "), call. = FALSE)
  }
  if (n > nrow(frame)) stop("n = ", n, " exceeds the frame size ", nrow(frame), call. = FALSE)

  list(ids = frame$question_id, member = member, floor = floor, n = n,
       label_order = order(available, seq_along(available)), available = available)
}

# One draw from a prepared design under the current RNG state. Returns row indices
# into design$ids, in selection order, with their stage and floor label.
floor_draw_core <- function(design) {
  m <- design$member
  selected <- logical(length(design$ids))
  idx <- integer(0)
  floor_label <- character(0)
  for (j in design$label_order) {
    shortfall <- design$floor - sum(selected & m[, j])
    if (shortfall > 0) {
      candidates <- which(m[, j] & !selected)
      pick <- sample_k(candidates, shortfall)
      selected[pick] <- TRUE
      idx <- c(idx, pick)
      floor_label <- c(floor_label, rep(colnames(m)[j], shortfall))
    }
  }
  n_floor <- length(idx)
  if (n_floor > design$n) stop("The floor needs ", n_floor, " slots but n = ", design$n, call. = FALSE)
  rest <- which(!selected)
  fill <- sample_k(rest, design$n - n_floor)
  list(idx = c(idx, fill),
       selection_stage = c(rep("floor", n_floor), rep("random_fill", length(fill))),
       floor_label = c(floor_label, rep(NA_character_, length(fill))))
}

draw_coverage_floor <- function(frame, guaranteed_labels, floor, n, seed) {
  design <- prepare_floor_design(frame, guaranteed_labels, floor, n)
  res <- with_seed(seed, floor_draw_core(design))
  tibble::tibble(question_id = design$ids[res$idx], draw_order = seq_along(res$idx),
                 selection_stage = res$selection_stage, floor_label = res$floor_label)
}
