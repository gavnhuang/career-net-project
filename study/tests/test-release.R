test_that("the release check passes on the real files", {
  skip_if_no_data()
  res <- check_release(real_raw(), read_careernet(root_path(CFG$inputs$previous)))
  expect_true(res$passed)
  expect_setequal(res$new_columns, c("soc_code", "reasoning_label"))
  expect_length(res$dropped_columns, 0)
})

test_that("the release check fails on a deliberately altered copy", {
  skip_if_no_data()
  old_path <- root_path(CFG$inputs$previous)
  old <- readr::read_csv(old_path, col_types = readr::cols(.default = "c"), na = character(), progress = FALSE)

  changed <- old
  changed$correctness[10] <- "1 - Completely Incorrect"
  changed_path <- tempfile(fileext = ".csv")
  readr::write_csv(changed, changed_path, na = "")
  res <- check_release(real_raw(), read_careernet(changed_path))
  expect_false(res$passed)
  expect_equal(res$column_diffs$n_differing[res$column_diffs$column == "correctness"], 1L)

  dropped_row <- old[-5, ]
  dropped_path <- tempfile(fileext = ".csv")
  readr::write_csv(dropped_row, dropped_path, na = "")
  res2 <- check_release(real_raw(), read_careernet(dropped_path))
  expect_false(res2$passed)
  expect_equal(res2$ids_only_new, old$answer_id[5])
})
