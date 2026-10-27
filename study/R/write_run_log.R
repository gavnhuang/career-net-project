# One YAML log per run: what ran, with which seeds, config, inputs and software.

LOGGED_PACKAGES <- c("readr", "dplyr", "tidyr", "stringr", "purrr", "lubridate", "yaml", "xml2", "digest",
                     "glue", "testthat")

git_info <- function() {
  commit <- tryCatch(system2("git", c("rev-parse", "HEAD"), stdout = TRUE, stderr = FALSE), error = function(e) NA_character_)
  status <- tryCatch(system2("git", c("status", "--porcelain"), stdout = TRUE, stderr = FALSE), error = function(e) character())
  list(commit = if (length(commit)) commit[1] else NA_character_, uncommitted_changes = length(status) > 0)
}

file_md5 <- function(paths) {
  purrr::map(paths, function(p) if (file.exists(p)) digest::digest(file = p, algo = "md5") else "MISSING")
}

write_run_log <- function(path, run_id, script, seeds, config, input_files, frame_version, outputs,
                          git = git_info(), extra = list()) {
  pkgs <- purrr::map(stats::setNames(LOGGED_PACKAGES, LOGGED_PACKAGES), function(p) {
    if (requireNamespace(p, quietly = TRUE)) as.character(utils::packageVersion(p)) else "not installed"
  })
  log <- c(list(
    run_id = run_id,
    script = script,
    timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
    frame_version = frame_version,
    seeds = seeds,
    rng_kind = as.list(RNGkind()),
    input_md5 = file_md5(input_files),
    outputs = as.list(unname(outputs)),
    r_version = R.version.string,
    platform = R.version$platform,
    packages = pkgs,
    git = git
  ), extra, list(config = config))
  yaml::write_yaml(log, path)
  invisible(path)
}
