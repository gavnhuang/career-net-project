# Run the study test suite. From the project root: Rscript study/scripts/run_tests.R
if (!dir.exists("study/tests")) stop("Run this script from the project root (04 R Project/)", call. = FALSE)
res <- testthat::test_dir("study/tests", reporter = "summary", stop_on_failure = TRUE)
