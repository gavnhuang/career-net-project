reserve_fixture <- function() {
  fq <- tibble::tibble(question_id = as.character(1:30), question_title = paste("Question", 1:30),
                       question_text_display = paste("Body", 1:30))
  fq$question_title[2] <- "What sections of my resume need improvement or could use a bit more detail to help?"
  fq$question_title[5] <- "Career choice?"
  sets <- tibble::tibble(set = rep(c("warmups", "calibration"), c(3, 4)), position = c(1:3, 1:4),
                         question_id = as.character(1:7), planned_version = rep(c("human", "ai"), length.out = 7))
  list(fq = fq, sets = sets, fr = fq[8:30, ], order = c("warmups", "calibration"))
}
confirmed_fixture <- tibble::tibble(
  set = c("warmups", "calibration"),
  title = c("What sections of my resume need improvement or could use a bit more detail…", "career choice?"),
  rule = c("rule4", "rule2"), match = c("prefix", "exact"), note = c("pasted resume", "own career"))

fill_reserved <- function(sheet, excluded = character()) {
  for (col in c("rule2", "rule3", "rule4")) sheet[[col]] <- "FALSE"
  sheet$rule2[sheet$question_id %in% excluded] <- "TRUE"
  sheet$excluded <- ifelse(sheet$question_id %in% excluded, "TRUE", "FALSE")
  sheet$notes <- ""
  sheet
}

test_that("confirmed exclusions match by set and title (exact, or prefix for an ellipsis) and fail loudly otherwise", {
  fx <- reserve_fixture()
  sheet <- make_reserved_sheet(fx$sets, fx$fq, fx$order)
  expect_equal(names(sheet), RESERVED_SCREENING_COLUMNS)
  expect_false(any(str_detect(names(sheet), "answer|careernet|reasoning")))
  m <- match_confirmed_exclusions(sheet, confirmed_fixture)
  expect_equal(m$question_id, c("2", "5"))
  expect_equal(m$position, c(2L, 2L))
  wrong_set <- confirmed_fixture; wrong_set$set[2] <- "warmups"
  expect_error(match_confirmed_exclusions(sheet, wrong_set), "matches 0 item\\(s\\) in set warmups")
  no_prefix <- confirmed_fixture; no_prefix$match[1] <- "exact"
  expect_error(match_confirmed_exclusions(sheet, no_prefix), "matches 0")
  bad_rule <- confirmed_fixture; bad_rule$rule[1] <- "rule9"
  expect_error(match_confirmed_exclusions(sheet, bad_rule), "Unknown rule")

  pre <- prefill_reserved_sheet(sheet, m)
  expect_equal(pre$excluded, ifelse(pre$question_id %in% c("2", "5"), "TRUE", "FALSE"))
  expect_equal(pre$rule4[pre$question_id == "2"], "TRUE")
  expect_equal(pre$rule2[pre$question_id == "5"], "TRUE")
  expect_equal(pre$notes[pre$question_id == "5"], "own career")
  expect_silent(validate_reserved_sheet(pre, fx$sets, 1))
})

test_that("replacements come from the seeded queue in order and keep set, position and planned_version", {
  fx <- reserve_fixture()
  queue <- make_reserve_queue(fx$fr, 42)
  expect_setequal(queue$question_id, fx$fr$question_id)
  expect_identical(queue, make_reserve_queue(fx$fr[nrow(fx$fr):1, ], 42))
  s1 <- fill_reserved(make_reserved_sheet(fx$sets, fx$fq, fx$order), c("2", "5"))
  res <- replay_reserved_screening(fx$sets, list(s1), queue, fx$order)
  expect_false(res$finished)
  expect_equal(res$log$question_id, c("2", "5"))                 # set order, then position
  expect_equal(res$log$replaced_by, queue$question_id[1:2])
  nx <- res$next_items
  expect_equal(nx$set, c("warmups", "calibration"))
  expect_equal(nx$position, c(2L, 2L))
  expect_equal(nx$planned_version, fx$sets$planned_version[match(c("2", "5"), fx$sets$question_id)])

  # Round 2: exclude one replacement -> the next queue item, skipping used ones.
  s2 <- fill_reserved(make_reserved_sheet(nx, fx$fq, fx$order), queue$question_id[1])
  res2 <- replay_reserved_screening(fx$sets, list(s1, s2), queue, fx$order)
  expect_equal(res2$log$replaced_by[3], queue$question_id[3])
  s3 <- fill_reserved(make_reserved_sheet(res2$next_items, fx$fq, fx$order))
  res3 <- replay_reserved_screening(fx$sets, list(s1, s2, s3), queue, fx$order)
  expect_true(res3$finished)
  expect_equal(nrow(res3$current), 7)
  expect_false(any(res3$current$question_id %in% res3$log$question_id))
  expect_identical(res3, replay_reserved_screening(fx$sets, list(s1, s2, s3), queue, fx$order))
})

test_that("invalid reserved sheets fail loudly", {
  fx <- reserve_fixture()
  ok <- fill_reserved(make_reserved_sheet(fx$sets, fx$fq, fx$order))
  blank <- ok; blank$rule3[1] <- ""
  expect_error(validate_reserved_sheet(blank, fx$sets, 1), "rule3 is not TRUE/FALSE")
  inconsistent <- ok; inconsistent$rule2[1] <- "TRUE"
  expect_error(validate_reserved_sheet(inconsistent, fx$sets, 1), "excluded != ")
  moved <- ok; moved$position[1] <- 9L
  expect_error(validate_reserved_sheet(moved, fx$sets, 1), "items do not match")
})

test_that("the 7 confirmed exclusions match the screened reserved sets", {
  skip_if_no_data()
  set_order <- purrr::map_chr(purrr::keep(CFG$reserved_sets, ~ !isFALSE(.x$screened)), "name")
  expect_equal(set_order, c("warmups", "calibration", "gold_candidates"))   # spare is not screened (D97)
  # The round-1 sheet holds the sets as drawn by 03 (the set files are rewritten once screening ends).
  round1 <- root_path(reserved_sheet_path(CFG$paths$reserved_dir, 1))
  skip_if_not(file.exists(round1), "03b has not run")
  sheet <- readr::read_csv(round1, col_types = readr::cols(.default = "c"), na = character())
  sheet$position <- as.integer(sheet$position)
  expect_equal(nrow(sheet), 41)
  confirmed <- readr::read_csv(root_path(CFG$inputs$reserved_confirmed_exclusions), col_types = readr::cols(.default = "c"))
  m <- match_confirmed_exclusions(sheet, confirmed)
  expect_setequal(m$question_id, sheet$question_id[sheet$excluded == "TRUE"])
  expect_equal(nrow(m), 7)
  expect_equal(as.vector(table(factor(m$set, set_order))), c(0L, 4L, 3L))
})

test_that("excluded items are processed by numeric position, also when the sheet is read as text", {
  fq <- tibble::tibble(question_id = as.character(1:40), question_title = paste("Q", 1:40), question_text_display = "x")
  sets <- tibble::tibble(set = "calibration", position = 1:13, question_id = as.character(1:13), planned_version = "human")
  queue <- make_reserve_queue(fq[14:40, ], 5)
  sheet <- fill_reserved(make_reserved_sheet(sets, fq, "calibration"), c("7", "11"))
  sheet[] <- lapply(sheet, as.character)                         # as read_csv(col_types = "c") gives it
  res <- replay_reserved_screening(sets, list(sheet), queue, "calibration")
  expect_equal(res$log$position, c(7L, 11L))
  expect_equal(res$log$replaced_by, queue$question_id[1:2])
})
