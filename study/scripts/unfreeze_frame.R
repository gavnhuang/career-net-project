# Unfreeze the frame for a documented, approved reason: replaces the frozen block in the config
# with "frozen: false" and logs the decision, the approval and the checksums it removed.
# After registration this is a deviation and must be reported as one.
# Usage: Rscript study/scripts/unfreeze_frame.R [config] --decision=D87 --approval="who approved, and why"
source("study/scripts/_common.R")
run <- start_run("unfreeze")
cfg <- run$cfg
decision <- cli_option("decision")
approval <- cli_option("approval")
if (is.null(decision) || !nzchar(decision) || is.null(approval) || !nzchar(approval)) {
  stop("Give --decision=<id> and --approval=\"<who approved, and why>\"", call. = FALSE)
}
if (!isTRUE(cfg$frozen)) stop("The frame is not frozen.", call. = FALSE)
if (isTRUE(cfg$preregistration_posted)) {
  message("WARNING: the pre-registration is marked as posted; unfreezing now is a deviation.")
}

lines <- readLines(run$config_path)
start <- which(lines == "frozen: true")
if (length(start) != 1) stop("Expected exactly one line 'frozen: true' in ", run$config_path, call. = FALSE)
end <- start
while (end < length(lines) && grepl("^(frozen_at:|frozen_checksums:|  \")", lines[end + 1])) end <- end + 1
writeLines(c(lines[seq_len(start - 1)], "frozen: false", lines[-seq_len(end)]), run$config_path)

cfg2 <- load_config(run$config_path)
if (isTRUE(cfg2$frozen) || length(cfg2$frozen_checksums)) stop("Unfreezing did not take effect", call. = FALSE)

write_run_log(file.path(cfg$paths$logs_dir, glue("{run$run_id}.yml")), run$run_id, "unfreeze_frame.R",
              seeds = list(master_seed = cfg$master_seed), config = cfg2,
              input_files = c(config = run$config_path), frame_version = cfg$frame_version,
              outputs = c(config = run$config_path),
              extra = list(unfreeze = list(decision = decision, approval = approval, approved = TRUE,
                                           preregistration_posted = isTRUE(cfg$preregistration_posted),
                                           previous_frozen_at = cfg$frozen_at,
                                           previous_frozen_checksums = cfg$frozen_checksums)))
message("Unfrozen under ", decision, ". Logged in ", file.path(cfg$paths$logs_dir, glue("{run$run_id}.yml")))
