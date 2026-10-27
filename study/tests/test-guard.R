real_cfg <- function(doi = "10.17605/OSF.IO/ABC12") {
  modifyList(CFG, list(preregistration_posted = TRUE, osf_url = "https://osf.io/abc12", osf_doi = doi))
}

test_that("the guard is in dry-run mode unless posted AND an OSF url is given", {
  expect_true(sample_output_plan(CFG)$dry_run)              # the shipped config
  cases <- list(list(FALSE, ""), list(TRUE, ""), list(TRUE, "   "), list(FALSE, "https://osf.io/abcde"))
  for (cs in cases) {
    cfg <- modifyList(CFG, list(preregistration_posted = cs[[1]], osf_url = cs[[2]], osf_doi = "10.17605/OSF.IO/ABC12"))
    plan <- sample_output_plan(cfg)
    expect_true(plan$dry_run)
    expect_equal(plan$dir, file.path(CFG$paths$sample_dir, "_dry_run"))
    expect_equal(plan$tag, "_DRY_RUN")
    expect_equal(plan$draw_stage, "study_draw_DRY_RUN")
  }
  real <- sample_output_plan(real_cfg())
  expect_false(real$dry_run)
  expect_equal(real$dir, CFG$paths$sample_dir)
  expect_equal(real$draw_stage, "study_draw")
})

test_that("the DOI is normalized, then hashed: first 7 hex digits of md5", {
  # Checked by hand: md5 -q -s "10.17605/osf.io/abcde" = c18e1d27...; 0xc18e1d2 = 202957266
  expect_equal(normalize_doi(" doi:10.17605/osf.io/abcde "), "10.17605/osf.io/abcde")
  expect_equal(normalize_doi("https://doi.org/10.17605/osf.io/abcde"), "10.17605/osf.io/abcde")
  expect_equal(normalize_doi("HTTP://DOI.ORG/10.17605/OSF.IO/ABCDE"), "10.17605/osf.io/abcde")
  expect_equal(normalize_doi("doi.org/10.17605/OSF.IO/ABCDE"), "10.17605/osf.io/abcde")
  variants <- c("10.17605/OSF.IO/ABCDE", "https://doi.org/10.17605/osf.io/abcde", " doi:10.17605/osf.io/abcde ")
  seeds <- purrr::map_int(variants, doi_seed)
  expect_true(all(seeds == 202957266L))
  expect_equal(doi_seed("10.17605/osf.io/abcde"), 202957266L)
  # The old ABC12 example, now normalized: md5 -q -s "10.17605/osf.io/abc12" -> 151634269
  expect_equal(sample_output_plan(real_cfg())$seed_base, 151634269L)
  plan <- sample_output_plan(real_cfg(" https://doi.org/10.17605/OSF.IO/ABCDE"))
  expect_equal(plan$seed_base, 202957266L)
  expect_equal(plan$doi_raw, " https://doi.org/10.17605/OSF.IO/ABCDE")
  expect_equal(plan$doi_normalized, "10.17605/osf.io/abcde")
  expect_error(doi_seed(""), "non-empty")
  expect_error(doi_seed("doi: "), "non-empty")
})

test_that("a real draw refuses to run without osf_doi", {
  expect_error(sample_output_plan(real_cfg("")), "osf_doi is empty")
  expect_error(sample_output_plan(real_cfg("   ")), "osf_doi is empty")
  expect_error(sample_output_plan(real_cfg(NULL)), "osf_doi is empty")
})

test_that("dry runs never use the DOI seed", {
  for (posted in c(TRUE, FALSE)) {
    cfg <- modifyList(CFG, list(preregistration_posted = posted, osf_url = if (posted) "" else "https://osf.io/x",
                                osf_doi = "10.17605/OSF.IO/ABC12"))
    plan <- sample_output_plan(cfg)
    expect_true(plan$dry_run)
    expect_equal(plan$seed_base, CFG$master_seed)
    expect_false(plan$seed_base == doi_seed("10.17605/OSF.IO/ABC12"))
  }
})

test_that("the shipped config has the guard off and no DOI", {
  raw <- yaml::read_yaml(root_path("study/config/study_config.yml"))
  expect_false(raw$preregistration_posted)
  expect_equal(raw$osf_url, "")
  expect_equal(raw$osf_doi, "")
})

test_that("04 run with the shipped guard writes only DRY_RUN files under _dry_run/", {
  skip_if_no_data()
  skip_if_not(file.exists(root_path(file.path(CFG$paths$reserved_dir, "frame_remaining.rds"))), "run 01 and 03 first")
  tmp <- tempfile("guard_")
  dir.create(tmp)
  cfg <- yaml::read_yaml(root_path("study/config/study_config.yml"))
  cfg$osf_doi <- "10.17605/OSF.IO/ABC12"   # present but must be ignored: the guard is off
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
  expect_true(length(written) >= 9)
  expect_true(all(str_detect(basename(written), "DRY_RUN")))
  sample_files <- list.files(cfg$paths$sample_dir, recursive = TRUE, include.dirs = FALSE)
  expect_true(all(str_starts(sample_files, "_dry_run/")))
  dry <- file.path(cfg$paths$sample_dir, "_dry_run")
  expect_true(file.exists(file.path(dry, "sample_for_generation_DRY_RUN.csv")))
  expect_true(file.exists(file.path(dry, "screening_sheet_round1_DRY_RUN.csv")))
  expect_true(file.exists(file.path(dry, "replacement_queues_DRY_RUN.rds")))
  report <- readLines(list.files(cfg$paths$reports_dir, full.names = TRUE)[1])
  expect_true(any(str_detect(report, "DRY RUN. NOT THE STUDY SAMPLE")))
  log <- yaml::read_yaml(list.files(cfg$paths$logs_dir, full.names = TRUE)[1])
  expect_equal(log$seeds$seed_base, CFG$master_seed)

  # The screening sheet carries question text only.
  sheet <- read_screening_sheet(file.path(dry, "screening_sheet_round1_DRY_RUN.csv"))
  expect_equal(names(sheet), SCREENING_COLUMNS)
  expect_false(any(str_detect(names(sheet), "answer|careernet|reasoning|target")))
  smp <- readRDS(file.path(dry, "study_sample_DRY_RUN.rds"))
  expect_setequal(sheet$question_id, smp$question_id)
  expect_false(any(sheet$question_text_display %in% smp$answer_text_display[nzchar(smp$answer_text_display)]))
})
