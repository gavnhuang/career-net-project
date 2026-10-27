study_draw <- function(n, seed = derive_seed(CFG$master_seed, "study_draw_DRY_RUN")) {
  draw_coverage_floor(real_remaining(), CFG$guaranteed_labels, CFG$floor, n, seed)
}

test_that("reserved sets have the configured sizes and splits, and do not overlap", {
  skip_if_no_data()
  res <- real_reserved()
  checks <- check_reserved_sets(res$sets, CFG$reserved_sets, real_frame()$frame_questions, anchor_ids())
  expect_true(all(checks$passed))
  expect_equal(nrow(res$sets), 57L)
  expect_equal(length(res$remaining), 681L - 57L)
  expect_length(intersect(res$remaining, res$sets$question_id), 0)
})

for (n in c(90, 100)) {
  test_that(glue("the study draw at n = {n} is exact, meets the floor and avoids anchors and reserved ids"), {
    skip_if_no_data()
    draw <- study_draw(n)
    expect_equal(nrow(draw), n)
    expect_false(anyDuplicated(draw$question_id) > 0)
    expect_false(any(draw$question_id %in% anchor_ids()))
    expect_false(any(draw$question_id %in% real_reserved()$sets$question_id))
    fr <- real_remaining()
    sel <- fr[match(draw$question_id, fr$question_id), ]
    per_label <- map_int(label_column_names(CFG$guaranteed_labels), ~ sum(sel[[.x]]))
    expect_true(all(per_label >= CFG$floor))
    expect_true(all(draw$selection_stage[draw$selection_stage == "floor"] == "floor"))
    expect_true(all(is.na(draw$floor_label) == (draw$selection_stage == "random_fill")))

    fa <- real_frame()$frame_answers
    answers <- pick_human_answer(fa, derive_seed(CFG$master_seed, "human_answer"))
    selection <- mutate(draw, set = "study", inclusion_prob = 0.05, weight = 1)
    out <- assemble_sample(selection, fr, answers, 1L, "test", "v1.1", CFG$target_words_tolerance)
    checks <- check_sample(out, fr, fa, anchor_ids(), real_reserved()$sets$question_id, CFG$guaranteed_labels,
                           CFG$floor, n)
    expect_true(all(checks$passed))
  })
}

test_that("the same seed gives identical output and a different seed a different one", {
  skip_if_no_data()
  expect_identical(study_draw(90, 11), study_draw(90, 11))
  expect_false(identical(study_draw(90, 11)$question_id, study_draw(90, 12)$question_id))

  ids <- real_frame()$frame_questions$question_id
  expect_identical(reserve_sets(ids, CFG$reserved_sets, 5), reserve_sets(ids, CFG$reserved_sets, 5))
  expect_false(identical(reserve_sets(ids, CFG$reserved_sets, 5)$sets, reserve_sets(ids, CFG$reserved_sets, 6)$sets))

  fa <- real_frame()$frame_answers
  expect_identical(pick_human_answer(fa, 3), pick_human_answer(fa, 3))
  expect_false(identical(pick_human_answer(fa, 3)$answer_id, pick_human_answer(fa, 4)$answer_id))

  # Input row order does not matter: everything starts from canonical id order.
  expect_identical(pick_human_answer(fa[rev(seq_len(nrow(fa))), ], 3)$answer_id, pick_human_answer(fa, 3)$answer_id)
  fr <- real_remaining()
  expect_identical(draw_coverage_floor(fr[sample(nrow(fr)), ], CFG$guaranteed_labels, 3, 90, 11), study_draw(90, 11))
})

test_that("sampling functions leave the global RNG state alone", {
  set.seed(1)
  before <- .Random.seed
  draw_coverage_floor(synthetic_frame(c(A = 5, B = 8)), c("A", "B"), 3, 10, 99)
  expect_identical(.Random.seed, before)
})

test_that("a guaranteed label that cannot meet the floor fails loudly", {
  tiny <- synthetic_frame(c(A = 10, B = 2))
  expect_error(draw_coverage_floor(tiny, c("A", "B"), floor = 3, n = 10, seed = 1), "cannot meet the floor.*B \\(2 available\\)")
  expect_error(estimate_inclusion_probs(tiny, c("A", "B"), 3, 10, 5, 1), "cannot meet the floor")
})

test_that("a floor that needs more slots than n fails loudly", {
  tiny <- synthetic_frame(c(A = 5, B = 5, C = 5))
  expect_error(draw_coverage_floor(tiny, c("A", "B", "C"), floor = 3, n = 6, seed = 1), "needs 9 slots")
})

test_that("rarest labels are processed first and multi-label questions count toward every label", {
  fr <- tibble::tibble(question_id = as.character(1:6),
                       label_a = c(1L, 1L, 1L, 0L, 0L, 0L),
                       label_b = c(1L, 1L, 1L, 1L, 1L, 1L))
  draw <- draw_coverage_floor(fr, c("A", "B"), floor = 3, n = 4, seed = 1)
  # A (rarest) takes all three of its questions; they also carry B, so B needs no floor slots.
  expect_equal(draw$floor_label[1:3], rep("A", 3))
  expect_equal(sum(draw$selection_stage == "floor"), 3)
})

test_that("estimated inclusion probabilities sum to n and favour rare labels", {
  tiny <- synthetic_frame(c(A = 4, B = 30), extra = 66)
  est <- estimate_inclusion_probs(tiny, c("A", "B"), floor = 3, n = 10, reps = 400, master_seed = 7)
  expect_equal(sum(est$probs$inclusion_prob), 10)
  a_ids <- tiny$question_id[tiny$label_a == 1]
  expect_true(all(est$probs$inclusion_prob[est$probs$question_id %in% a_ids] > 0.7))
  expect_equal(length(est$floor_slots), 400)
  w <- inclusion_weights(c(0.5, 0.25, 0.1))
  expect_equal(mean(w), 1)
  expect_error(inclusion_weights(c(0.5, 0)), "increase inclusion_reps")
})
