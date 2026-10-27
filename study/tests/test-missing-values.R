test_that("'', 'NA' and NA all count as missing", {
  expect_equal(is_missing(c("", "NA", NA, "x", " ", "Unclear Goal")), c(TRUE, TRUE, TRUE, FALSE, FALSE, FALSE))
  expect_equal(normalize_missing(c("", "NA", NA, "a")), c(NA, NA, NA, "a"))
})

test_that("read_careernet normalizes both missing-value styles", {
  path <- tempfile(fileext = ".csv")
  writeLines(c("answer_id,unclear_goal,question_body", "1,,x", "2,NA,", "3,Unclear Goal,y"), path)
  d <- read_careernet(path, required = c("answer_id", "unclear_goal"))
  expect_equal(d$unclear_goal, c(NA, NA, "Unclear Goal"))
  expect_equal(d$question_body, c("x", NA, "y"))
})

test_that("eligibility returns 2,250 questions before the anchor exclusion on v1.1 and v1.0", {
  skip_if_no_data()
  step_d <- function(raw) {
    a <- eligibility_attrition(raw, CFG$filters)$attrition
    a$n_questions[a$step == "d"]
  }
  v11 <- real_raw()
  v10 <- read_careernet(root_path(CFG$inputs$previous))
  expect_equal(step_d(v11), 2250L)
  expect_equal(step_d(v10), 2250L)

  # Also on un-normalized text, where v1.1 has "" and v1.0 has "NA".
  raw_text <- function(p) readr::read_csv(p, col_types = readr::cols(.default = "c"), na = character(), progress = FALSE)
  r11 <- raw_text(root_path(CFG$inputs$primary))
  r10 <- raw_text(root_path(CFG$inputs$previous))
  expect_equal(step_d(r11), 2250L)
  expect_equal(step_d(r10), 2250L)
  # The naive test this guards against:
  expect_equal(sum(r11$unclear_goal == "NA"), 0L)
})
