test_that("the guard is in dry-run mode unless posted AND an OSF url is given", {
  expect_true(sample_output_plan(CFG)$dry_run)              # the shipped config
  cases <- list(list(FALSE, ""), list(TRUE, ""), list(TRUE, "   "), list(FALSE, "https://osf.io/abcde"))
  for (cs in cases) {
    cfg <- modifyList(CFG, list(preregistration_posted = cs[[1]], osf_url = cs[[2]]))
    plan <- sample_output_plan(cfg)
    expect_true(plan$dry_run)
    expect_equal(plan$dir, file.path(CFG$paths$sample_dir, "_dry_run"))
    expect_equal(plan$tag, "_DRY_RUN")
    expect_equal(plan$draw_stage, "study_draw_DRY_RUN")
  }
  real <- sample_output_plan(modifyList(CFG, list(preregistration_posted = TRUE, osf_url = "https://osf.io/abcde")))
  expect_false(real$dry_run)
  expect_equal(real$dir, CFG$paths$sample_dir)
})

test_that("the shipped config has the guard off", {
  raw <- yaml::read_yaml(root_path("study/config/study_config.yml"))
  expect_false(raw$preregistration_posted)
  expect_equal(raw$osf_url, "")
})

test_that("04 run with the shipped guard writes only DRY_RUN files under _dry_run/", {
  skip_if_no_data()
  skip_if_not(file.exists(root_path(file.path(CFG$paths$reserved_dir, "frame_remaining.rds"))), "run 01 and 03 first")
  tmp <- tempfile("guard_")
  dir.create(tmp)
  cfg <- yaml::read_yaml(root_path("study/config/study_config.yml"))
  cfg$paths$sample_dir <- file.path(tmp, "03_sample")
  cfg$paths$reports_dir <- file.path(tmp, "reports")
  cfg$paths$logs_dir <- file.path(tmp, "logs")
  cfg$inclusion_reps <- 300
  cfg_path <- file.path(tmp, "config.yml")
  yaml::write_yaml(cfg, cfg_path)

  status <- withr::with_dir(ROOT, system2("Rscript", c("study/scripts/04_draw_study_sample.R", shQuote(cfg_path)),
                                          stdout = FALSE, stderr = FALSE))
  expect_equal(status, 0L)
  written <- list.files(tmp, recursive = TRUE)
  written <- written[written != "config.yml"]
  expect_true(length(written) >= 6)
  expect_true(all(str_detect(basename(written), "DRY_RUN")))
  sample_files <- list.files(cfg$paths$sample_dir, recursive = TRUE, include.dirs = FALSE)
  expect_true(all(str_starts(sample_files, "_dry_run/")))
  expect_true(file.exists(file.path(cfg$paths$sample_dir, "_dry_run", "sample_for_generation_DRY_RUN.csv")))
  report <- readLines(list.files(cfg$paths$reports_dir, full.names = TRUE)[1])
  expect_true(any(str_detect(report, "DRY RUN. NOT THE STUDY SAMPLE")))
})
