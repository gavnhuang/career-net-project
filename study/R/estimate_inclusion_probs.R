# Monte Carlo inclusion probabilities for the coverage-floor design: re-run the full
# draw R times, rep r seeded with derive_seed(master_seed, "<stage>_<r>").

estimate_inclusion_probs <- function(frame, guaranteed_labels, floor, n, reps, master_seed,
                                     stage = "inclusion_rep") {
  design <- prepare_floor_design(frame, guaranteed_labels, floor, n)
  hits <- integer(length(design$ids))
  floor_slots <- integer(reps)
  with_seed(derive_seed(master_seed, stage), {
    for (r in seq_len(reps)) {
      set.seed(derive_seed(master_seed, paste0(stage, "_", r)))
      res <- floor_draw_core(design)
      hits[res$idx] <- hits[res$idx] + 1L
      floor_slots[r] <- sum(res$selection_stage == "floor")
    }
  })
  list(probs = tibble::tibble(question_id = design$ids, n_selected = hits, inclusion_prob = hits / reps),
       floor_slots = floor_slots, reps = reps,
       seed_rule = glue::glue("derive_seed({master_seed}, \"{stage}_<r>\") for r = 1..{reps}"))
}

# weight = 1 / inclusion_prob, normalized to mean 1 over the units given.
inclusion_weights <- function(inclusion_prob) {
  if (any(is.na(inclusion_prob) | inclusion_prob <= 0)) {
    stop("A selected question has an estimated inclusion probability of 0; increase inclusion_reps", call. = FALSE)
  }
  w <- 1 / inclusion_prob
  w / mean(w)
}
