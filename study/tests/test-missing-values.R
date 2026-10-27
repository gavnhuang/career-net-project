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

test_that("unclear_goal is missing for 694 of the 707 step-c questions on v1.1 and v1.0", {
  skip_if_no_data()
  # unclear_goal is no longer a filter (D87), but both missing-value styles must still read as missing.
  step_d <- function(raw) {
    e <- eligibility_attrition(raw, CFG$filters)
    dplyr::n_distinct(raw$question_id[e$masks$c & is_missing(raw$unclear_goal)])
  }
  v11 <- real_raw()
  v10 <- read_careernet(root_path(CFG$inputs$previous))
  expect_equal(step_d(v11), 694L)
  expect_equal(step_d(v10), 694L)

  # Also on un-normalized text, where v1.1 has "" and v1.0 has "NA".
  raw_text <- function(p) readr::read_csv(p, col_types = readr::cols(.default = "c"), na = character(), progress = FALSE)
  r11 <- raw_text(root_path(CFG$inputs$primary))
  r10 <- raw_text(root_path(CFG$inputs$previous))
  expect_equal(step_d(r11), 694L)
  expect_equal(step_d(r10), 694L)
  # The naive test this guards against:
  expect_equal(sum(r11$unclear_goal == "NA"), 0L)
})
