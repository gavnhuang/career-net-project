test_that("attrition reproduces the expected question and answer counts exactly", {
  skip_if_no_data()
  att <- real_frame()$attrition
  expect_equal(att$step, c("all", "a", "b", "c", "d", "e", "f"))
  expect_equal(att$n_questions, c(3000L, 764L, 725L, 707L, 707L, 694L, 694L))
  expect_equal(att$n_answers, c(7984L, 1496L, 1338L, 1301L, 1301L, 1278L, 1278L))
  expect_equal(att$n_questions, att$expected_questions)
  expect_equal(nrow(real_frame()$frame_questions), 694L)
  expect_equal(nrow(real_frame()$frame_answers), 1278L)
})

test_that("a wrong expected attrition fails loudly", {
  skip_if_no_data()
  att <- real_frame()$attrition
  wrong_q <- modifyList(CFG$expected_attrition, list(questions = c(3000, 764, 725, 707, 707, 694, 693)))
  expect_error(check_attrition(att, wrong_q), "questions\\) does not reproduce")
  wrong_a <- modifyList(CFG$expected_attrition, list(answers = c(7984, 1496, 1338, 1301, 1301, 1278, 1277)))
  expect_error(check_attrition(att, wrong_a), "answers\\) does not reproduce")
  # The old D85/D86 counts (with the unclear_goal filter) no longer reproduce.
  old <- list(questions = c(3000, 764, 725, 707, 694, 694, 681), answers = c(7984, 1496, 1338, 1301, 1275, 1275, 1252))
  expect_error(check_attrition(att, old), "does not reproduce")
  expect_error(check_attrition(att, list(questions = 1:6, answers = 1:6)), "needs 7 numbers")
})

test_that("rule 1 matches exactly 79 questions in the full release and spares 'asked anonymously' notes", {
  skip_if_no_data()
  raw <- real_raw()
  hit <- is_platform_prompt(raw$question_title, raw$question_body, CFG$filters$platform_prompt_pattern)
  expect_equal(dplyr::n_distinct(raw$question_id[hit]), 79L)

  text <- paste(raw$question_title, raw$question_body)
  anon <- str_detect(text, regex("Note:\\s*this question was asked anonymously", ignore_case = TRUE))
  expect_gt(sum(anon), 0)
  expect_false(any(hit & anon))

  pat <- CFG$filters$platform_prompt_pattern
  expect_true(is_platform_prompt("Q", "<p>Note: We've seen a lot of interest in this career path</p>", pat))
  expect_true(is_platform_prompt("Q", "NOTE: given the growing interest in the field", pat))
  expect_true(is_platform_prompt("Q", "Note:   This question is part of our Professionals Series", pat))
  expect_true(is_platform_prompt("Q", "Note: this is part of the professionals series", pat))
  expect_false(is_platform_prompt("Q", "Note: this question was asked anonymously by a student", pat))
  expect_false(is_platform_prompt("Q", "I've seen a lot of interest in this career", pat))
})

test_that("the answer date window includes its start, excludes its end", {
  body <- paste(rep("word", 50), collapse = " ")
  raw <- tibble::tibble(
    question_id = as.character(1:5), answer_id = as.character(1:5),
    answer_added_at = c("December 31, 2020, 11:59 PM", "January 1, 2021, 12:00 AM", "February 28, 2023, 11:59 PM",
                        "March 1, 2023, 12:00 AM", "March 1, 2023, 12:01 AM"),
    answer_body = body, question_title = "A long enough question title here", question_body = "with more words in it",
    unclear_goal = NA_character_)
  elig <- eligibility_attrition(raw, CFG$filters)
  expect_equal(elig$masks$a, c(FALSE, TRUE, TRUE, FALSE, FALSE))
})

test_that("manual exclusions lower the final count, and 01 then fails the expected counts", {
  skip_if_no_data()
  ids <- head(real_frame()$frame_questions$question_id, 2)
  att <- eligibility_attrition(real_raw(), CFG$filters, anchor_ids(), ids)$attrition
  expect_equal(att$n_questions[att$step == "f"], 692L)
  expect_error(check_attrition(att, CFG$expected_attrition), "questions\\) does not reproduce")
})

test_that("Unclear Goal questions stay in the frame (D87) and unclear_goal is kept as a column", {
  skip_if_no_data()
  fq <- real_frame()$frame_questions
  expect_true("unclear_goal" %in% names(fq))
  expect_equal(sum(!is.na(fq$unclear_goal)), 13L)
  expect_false("unclear_goal missing" %in% real_frame()$attrition$rule)
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
  expect_true(all(fa$answer_added_at < as.POSIXct("2023-03-01", tz = "UTC")))
  expect_true(all(fq$question_word_count >= 10))
  expect_false(any(fq$question_id %in% anchor_ids()))
  expect_equal(sum(fq$n_eligible_answers), nrow(fa))
  expect_false(any(PRIVATE_COLUMNS %in% c(names(fq), names(fa))))
  expect_true(all(fa$careernet_correctness_num %in% 1:4))
})

test_that("the 9 guaranteed labels are exactly those with 30+ frame questions", {
  skip_if_no_data()
  fq <- real_frame()$frame_questions
  n <- purrr::map_int(label_column_names(CFG$scenario_labels), ~ sum(fq[[.x]]))
  expect_setequal(CFG$scenario_labels[n >= 10 * CFG$floor], CFG$guaranteed_labels)
  expect_length(CFG$guaranteed_labels, 9)
  expect_equal(n[CFG$scenario_labels == "First Job Navigation"], 30L)
  expect_true("First Job Navigation" %in% CFG$guaranteed_labels)
})

test_that("extra input columns pass through to the answer frame", {
  skip_if_no_data()
  raw <- real_raw()
  raw$future_column <- paste0("v", seq_len(nrow(raw)))
  fr <- build_frame(raw, CFG$filters, anchor_ids(), character(), CFG$scenario_labels, CFG$guaranteed_labels,
                    closing_pleasantries = CFG$closing_pleasantries)
  expect_true("future_column" %in% names(fr$frame_answers))
  expect_equal(fr$frame_answers$future_column, raw$future_column[match(fr$frame_answers$answer_id, raw$answer_id)])
})
