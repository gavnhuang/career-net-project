# Freeze the frame: checksum the frame and reserved-set files and write them into the config
# (replacing the line "frozen: false"). Refuses if already frozen. Run after 01-03.
source("study/scripts/_common.R")
run <- start_run("freeze")
cfg <- run$cfg
if (isTRUE(cfg$frozen)) stop("Already frozen. Unfreezing requires setting frozen: false by hand.", call. = FALSE)

checksums <- file_checksums(frozen_file_paths(cfg))
lines <- readLines(run$config_path)
at <- which(lines == "frozen: false")
if (length(at) != 1) stop("Expected exactly one line 'frozen: false' in ", run$config_path, call. = FALSE)
frozen_at <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
writeLines(c(lines[seq_len(at - 1)], frozen_config_block(checksums, frozen_at), lines[-seq_len(at)]), run$config_path)

cfg2 <- load_config(run$config_path)
verify_frozen(cfg2)

write_run_log(file.path(cfg$paths$logs_dir, glue("{run$run_id}.yml")), run$run_id, "freeze_frame.R",
              seeds = list(master_seed = cfg$master_seed), config = cfg2,
              input_files = c(config = run$config_path, stats::setNames(names(checksums), names(checksums))),
              frame_version = cfg$frame_version, outputs = c(config = run$config_path),
              extra = list(frozen_at = frozen_at, frozen_checksums = checksums))
message("Frozen ", length(checksums), " files at ", frozen_at, ". Checksums written to ", run$config_path)
