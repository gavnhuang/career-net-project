test_that("attrition reproduces 3000/2396/2352/2314/2250/2214 exactly", {
  skip_if_no_data()
  att <- real_frame()$attrition
  expect_equal(att$step, c("all", "a", "b", "c", "d", "e", "f"))
  expect_equal(att$n_questions[1:6], c(3000L, 2396L, 2352L, 2314L, 2250L, 2214L))
  expect_equal(nrow(real_frame()$frame_questions), 2214L)
})

test_that("a wrong expected attrition fails loudly", {
  skip_if_no_data()
  att <- real_frame()$attrition
  expect_error(check_attrition(att, c(3000, 2396, 2352, 2314, 2250, 2213)), "does not reproduce")
})

test_that("manual exclusions lower the final count", {
  skip_if_no_data()
  ids <- head(real_frame()$frame_questions$question_id, 2)
  att <- eligibility_attrition(real_raw(), CFG$filters, anchor_ids(), ids)$attrition
  expect_equal(att$n_questions[att$step == "f"], 2212L)
})

test_that("the frame is one row per question and every answer is eligible", {
  skip_if_no_data()
  fr <- real_frame()
  fq <- fr$frame_questions
  fa <- fr$frame_answers
  expect_false(anyDuplicated(fq$question_id) > 0)
  expect_true(all(fa$question_id %in% fq$question_id))
  expect_true(all(fa$answer_word_count >= 40 & fa$answer_word_count <= 600))
  expect_true(all(fa$answer_added_at >= as.POSIXct("2021-01-01", tz = "UTC")))
  expect_true(all(fq$question_word_count >= 10))
  expect_true(all(is.na(fq$unclear_goal)))
  expect_false(any(fq$question_id %in% anchor_ids()))
  expect_equal(sum(fq$n_eligible_answers), nrow(fa))
  expect_false(any(PRIVATE_COLUMNS %in% c(names(fq), names(fa))))
  expect_true(all(fa$careernet_correctness_num %in% 1:4))
})

test_that("extra input columns pass through to the answer frame", {
  skip_if_no_data()
  raw <- real_raw()
  raw$future_column <- paste0("v", seq_len(nrow(raw)))
  fr <- build_frame(raw, CFG$filters, anchor_ids(), character(), CFG$scenario_labels, CFG$guaranteed_labels)
  expect_true("future_column" %in% names(fr$frame_answers))
  expect_equal(fr$frame_answers$future_column, raw$future_column[match(fr$frame_answers$answer_id, raw$answer_id)])
})
