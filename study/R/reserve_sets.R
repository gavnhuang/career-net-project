# Sequential simple random samples: each set is drawn from what the earlier sets left.
# planned_version is assigned at random within each set.
# sets: list of list(name, size, n_human, n_ai), in draw order.

reserve_sets <- function(question_ids, sets, seed) {
  remaining <- canonical_ids(question_ids)
  drawn <- with_seed(seed, {
    out <- vector("list", length(sets))
    for (i in seq_along(sets)) {
      s <- sets[[i]]
      if (s$size > length(remaining)) stop("Not enough questions left for reserved set '", s$name, "'", call. = FALSE)
      pick <- sample_k(remaining, s$size)
      versions <- rep(c("human", "ai"), c(s$n_human, s$n_ai))
      out[[i]] <- tibble::tibble(question_id = pick, set = s$name, draw_order = seq_len(s$size),
                                 planned_version = sample_k(versions, length(versions)))
      remaining <- setdiff(remaining, pick)
    }
    out
  })
  list(sets = dplyr::bind_rows(drawn), remaining = remaining)
}
