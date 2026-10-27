# Step 0: confirm the v1.1 release matches v1.0 on every shared column.
source("study/scripts/_common.R")
run <- start_run("00")
cfg <- run$cfg

new <- read_careernet(cfg$inputs$primary)
old <- read_careernet(cfg$inputs$previous)
res <- check_release(new, old)

report_path <- file.path(cfg$paths$reports_dir, glue("release_check_{run$run_id}.md"))
writeLines(render_release_report(res, cfg$frame_version, cfg$inputs$previous_version,
                                 cfg$inputs$primary, cfg$inputs$previous, run$run_id), report_path)

log_path <- file.path(cfg$paths$logs_dir, glue("{run$run_id}.yml"))
write_run_log(log_path, run$run_id, "00_check_release.R", seeds = list(master_seed = cfg$master_seed),
              config = cfg, input_files = c(config = run$config_path, primary = cfg$inputs$primary,
                                            previous = cfg$inputs$previous),
              frame_version = cfg$frame_version, outputs = c(report = report_path),
              extra = list(release_check_passed = res$passed, new_columns = res$new_columns))

message("Report: ", report_path)
if (!res$passed) stop("Release check FAILED: ", cfg$frame_version, " differs from ", cfg$inputs$previous_version,
                      ". See ", report_path, call. = FALSE)
message("Release check PASSED. New columns: ", paste(res$new_columns, collapse = ", "))
