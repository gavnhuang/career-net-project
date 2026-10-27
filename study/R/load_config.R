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
  cfg$osf_doi <- cfg$osf_doi %||% ""
  cfg$closing_pleasantries <- as.character(unlist(cfg$closing_pleasantries))
  cfg$frozen <- isTRUE(cfg$frozen)
  if (cfg$frozen && !length(cfg$frozen_checksums)) stop("frozen is true but frozen_checksums is missing", call. = FALSE)

  f <- cfg$filters
  needed <- c("answer_date_min", "answer_date_max_exclusive", "answer_min_words", "answer_max_words",
              "question_min_words", "platform_prompt_pattern")
  if (length(setdiff(needed, names(f)))) stop("filters is missing: ", paste(setdiff(needed, names(f)), collapse = ", "), call. = FALSE)
  for (d in c("answer_date_min", "answer_date_max_exclusive")) {
    if (is.na(as.Date(f[[d]], format = "%Y-%m-%d"))) stop("filters$", d, " must be YYYY-MM-DD", call. = FALSE)
  }
  if (as.Date(f$answer_date_min) >= as.Date(f$answer_date_max_exclusive)) stop("Empty answer date window", call. = FALSE)

  cfg$expected_attrition <- list(questions = as.integer(unlist(cfg$expected_attrition$questions)),
                                 answers = as.integer(unlist(cfg$expected_attrition$answers)))

  cfg$guaranteed_labels <- unlist(cfg$guaranteed_labels)
  cfg$scenario_labels <- unlist(cfg$scenario_labels)
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

# Where and how 04/05 write, and which master seed the draw stages use.
# Dry run (guard off): <sample_dir>/_dry_run/, "DRY_RUN" in every filename, master_seed with a
# separate draw stage name. The DOI-derived seed is never used.
# Real run (guard on): <sample_dir>/, seed_base = doi_seed(osf_doi); refuses if osf_doi is empty.
sample_output_plan <- function(cfg) {
  dry_run <- !is_preregistered(cfg)
  if (dry_run) {
    return(list(dry_run = TRUE, dir = file.path(cfg$paths$sample_dir, "_dry_run"), tag = "_DRY_RUN",
                draw_stage = "study_draw_DRY_RUN", seed_base = cfg$master_seed, doi_raw = NA_character_,
                doi_normalized = NA_character_,
                seed_rule = "master_seed (dry run; the DOI seed is never used)"))
  }
  doi <- cfg$osf_doi
  if (!is.character(doi) || length(doi) != 1 || is.na(doi) || !nzchar(str_trim(doi))) {
    stop("The guard is on but osf_doi is empty. The real draw's seed comes from the OSF DOI; ",
         "set osf_doi to the registered DOI first.", call. = FALSE)
  }
  list(dry_run = FALSE, dir = cfg$paths$sample_dir, tag = "", draw_stage = "study_draw",
       seed_base = doi_seed(doi), doi_raw = doi, doi_normalized = normalize_doi(doi),
       seed_rule = glue::glue("strtoi(substr(md5(\"{normalize_doi(doi)}\"), 1, 7), 16) [normalized from \"{doi}\"]"))
}
