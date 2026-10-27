# Frozen frame: once the frame and reserved sets are final, their files are checksummed in the
# config. 01 and 03 refuse to run; 04, 05 and 06 verify every checksum before doing anything.
# Unfreezing goes through scripts/unfreeze_frame.R, which logs the decision and approval.

# The files that define the frame and the reserved sets (csv and rds; 04/05 read the rds).
frozen_file_paths <- function(cfg) {
  sets <- c(purrr::map_chr(cfg$reserved_sets, "name"), "frame_remaining")
  c(file.path(cfg$paths$frame_dir, paste0(rep(c("frame_questions", "frame_answers"), each = 2), c(".csv", ".rds"))),
    file.path(cfg$paths$reserved_dir, paste0(rep(sets, each = 2), c(".csv", ".rds"))))
}

file_checksums <- function(paths) {
  missing <- paths[!file.exists(paths)]
  if (length(missing)) stop("Cannot checksum missing file(s): ", paste(missing, collapse = ", "), call. = FALSE)
  stats::setNames(as.list(purrr::map_chr(paths, ~ digest::digest(file = .x, algo = "md5"))), paths)
}

# Returns tibble(path, expected, actual, ok); stops if any file is missing or differs.
verify_frozen <- function(cfg) {
  if (!isTRUE(cfg$frozen)) return(invisible(NULL))
  expected <- unlist(cfg$frozen_checksums)
  if (!length(expected)) stop("frozen is true but frozen_checksums is empty", call. = FALSE)
  actual <- purrr::map_chr(names(expected), ~ if (file.exists(.x)) digest::digest(file = .x, algo = "md5") else "MISSING")
  res <- tibble::tibble(path = names(expected), expected = unname(expected), actual = actual, ok = expected == actual)
  if (!all(res$ok)) {
    stop("Frozen files differ from their checksums:\n",
         paste0("  - ", res$path[!res$ok], " (expected ", res$expected[!res$ok], ", got ", res$actual[!res$ok], ")",
                collapse = "\n"),
         "\nThe frame is frozen; restore the files rather than rebuilding them.", call. = FALSE)
  }
  invisible(res)
}

assert_not_frozen <- function(cfg, script) {
  if (isTRUE(cfg$frozen)) {
    stop(script, " would overwrite the frozen frame / reserved sets. frozen is true in the config; ",
         "unfreezing requires an approved, logged decision (study/scripts/unfreeze_frame.R).", call. = FALSE)
  }
  invisible(TRUE)
}

# The YAML block freeze_frame.R writes in place of the line "frozen: false".
frozen_config_block <- function(checksums, frozen_at) {
  c("frozen: true", paste0("frozen_at: \"", frozen_at, "\""), "frozen_checksums:",
    paste0("  \"", names(checksums), "\": \"", unlist(checksums), "\""))
}
