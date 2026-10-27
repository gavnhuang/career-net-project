frozen_fixture <- function() {
  dir <- tempfile("frozen_")
  dir.create(dir)
  paths <- file.path(dir, c("frame_questions.csv", "pilot.rds"))
  writeLines("a,b\n1,2", paths[1])
  saveRDS(list(x = 1), paths[2])
  cfg <- list(frozen = TRUE, frozen_checksums = file_checksums(paths))
  list(cfg = cfg, paths = paths)
}

test_that("verify_frozen passes on unchanged files and stops on a changed or missing file", {
  fx <- frozen_fixture()
  expect_true(all(verify_frozen(fx$cfg)$ok))
  expect_equal(fx$cfg$frozen_checksums[[fx$paths[1]]], digest::digest(file = fx$paths[1], algo = "md5"))

  writeLines("a,b\n1,3", fx$paths[1])
  expect_error(verify_frozen(fx$cfg), "Frozen files differ.*frame_questions.csv")
  fx2 <- frozen_fixture()
  file.remove(fx2$paths[2])
  expect_error(verify_frozen(fx2$cfg), "pilot.rds \\(expected [0-9a-f]+, got MISSING\\)")
  expect_null(verify_frozen(list(frozen = FALSE)))
})

test_that("01 and 03 refuse to run while frozen", {
  expect_error(assert_not_frozen(list(frozen = TRUE), "01_build_frame.R"), "frozen is true")
  expect_true(assert_not_frozen(list(frozen = FALSE), "01_build_frame.R"))
})

test_that("the freeze block lists every frame and reserved-set file", {
  paths <- frozen_file_paths(CFG)
  expect_length(paths, 2 * (2 + length(CFG$reserved_sets) + 1))
  expect_true(all(c("study/data/01_frame/frame_questions.csv", "study/data/01_frame/frame_answers.csv",
                    "study/data/02_reserved/frame_remaining.csv", "study/data/02_reserved/pilot.csv") %in% paths))
  block <- frozen_config_block(list(`a/b.csv` = "abc"), "2026-10-27T00:00:00")
  expect_equal(yaml::yaml.load(paste(block, collapse = "\n"))$frozen_checksums$`a/b.csv`, "abc")
})

test_that("the shipped frozen config matches the files on disk", {
  skip_if_not(isTRUE(CFG$frozen), "frame not frozen yet")
  withr::with_dir(ROOT, expect_true(all(verify_frozen(CFG)$ok)))
  status <- withr::with_dir(ROOT, system2("Rscript", "study/scripts/01_build_frame.R", stdout = FALSE, stderr = FALSE))
  expect_false(status == 0L)
  withr::with_dir(ROOT, expect_true(all(verify_frozen(CFG)$ok)))
})
