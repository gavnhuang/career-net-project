# Read and validate study/config/study_config.yml.

load_config <- function(path) {
  if (!file.exists(path)) stop("Config not found: ", path, call. = FALSE)
  cfg <- yaml::read_yaml(path)
  cfg$config_path <- path

  required <- c("preregistration_posted", "osf_url", "master_seed", "frame_version", "inputs", "paths",
                "filters", "expected_attrition", "reading_sample_n", "reserved_sets", "study_n", "floor",
                "inclusion_reps", "target_words_tolerance", "guaranteed_labels", "scenario_labels")
  missing <- setdiff(required, names(cfg))
  if (length(missing)) stop("Config is missing: ", paste(missing, collapse = ", "), call. = FALSE)

  if (!is.logical(cfg$preregistration_posted) || length(cfg$preregistration_posted) != 1 || is.na(cfg$preregistration_posted))
    stop("preregistration_posted must be true or false", call. = FALSE)
  cfg$osf_url <- cfg$osf_url %||% ""

  cfg$guaranteed_labels <- unlist(cfg$guaranteed_labels)
  cfg$scenario_labels <- unlist(cfg$scenario_labels)
  cfg$expected_attrition <- as.integer(unlist(cfg$expected_attrition))
  unknown <- setdiff(cfg$guaranteed_labels, cfg$scenario_labels)
  if (length(unknown)) stop("guaranteed_labels not in scenario_labels: ", paste(unknown, collapse = "; "), call. = FALSE)
  if (anyDuplicated(cfg$scenario_labels)) stop("scenario_labels has duplicates", call. = FALSE)
  if (anyDuplicated(snake_case(cfg$scenario_labels))) stop("scenario_labels collide after snake_case", call. = FALSE)

  for (s in cfg$reserved_sets) {
    if (s$size != s$n_human + s$n_ai) stop("Reserved set '", s$name, "': size != n_human + n_ai", call. = FALSE)
  }
  if (cfg$floor < 1) stop("floor must be >= 1", call. = FALSE)
  if (cfg$study_n < 1) stop("study_n must be >= 1", call. = FALSE)
  if (cfg$inclusion_reps < 1) stop("inclusion_reps must be >= 1", call. = FALSE)
  cfg
}

# The real study draw is allowed only once the OSF pre-registration is posted.
is_preregistered <- function(cfg) {
  isTRUE(cfg$preregistration_posted) && is.character(cfg$osf_url) && length(cfg$osf_url) == 1 &&
    !is.na(cfg$osf_url) && nzchar(str_trim(cfg$osf_url))
}

# Where and how 04 writes. Unless pre-registered: DRY-RUN, in <sample_dir>/_dry_run/,
# "DRY_RUN" in every filename, and a separate draw seed so a dry run never previews
# the real sample.
sample_output_plan <- function(cfg) {
  dry_run <- !is_preregistered(cfg)
  list(dry_run = dry_run,
       dir = if (dry_run) file.path(cfg$paths$sample_dir, "_dry_run") else cfg$paths$sample_dir,
       tag = if (dry_run) "_DRY_RUN" else "",
       draw_stage = if (dry_run) "study_draw_DRY_RUN" else "study_draw")
}
