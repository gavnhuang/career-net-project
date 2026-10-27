# Read a CareerNet release as all-character columns with missing values normalized.

CAREERNET_COLUMNS <- c(
  "answer_id", "answer_body", "answer_added_at", "answer_score", "answerer_id", "answerer_location",
  "question_id", "question_title", "question_body", "question_added_at", "question_score",
  "asker_author_id", "asker_location", "question_tagnames", "question_views", "ScenarioLabels",
  "correctness", "completeness", "coherency",
  "explore_options", "take_action", "understanding_purpose", "validation_support", "find_resources",
  "navigate_constraints", "compare_options", "unclear_goal", "Split", "soc_code", "reasoning_label"
)

GOAL_COLUMNS <- c("explore_options", "take_action", "understanding_purpose", "validation_support",
                  "find_resources", "navigate_constraints", "compare_options")

# Never written to any output.
PRIVATE_COLUMNS <- c("answerer_id", "asker_author_id")

read_careernet <- function(path, required = setdiff(CAREERNET_COLUMNS, c("soc_code", "reasoning_label"))) {
  raw <- readr::read_csv(path, col_types = readr::cols(.default = readr::col_character()),
                         na = character(), trim_ws = FALSE, progress = FALSE)
  if (nrow(readr::problems(raw))) stop("Parsing problems in ", path, call. = FALSE)
  missing <- setdiff(required, names(raw))
  if (length(missing)) stop(path, " is missing column(s): ", paste(missing, collapse = ", "), call. = FALSE)
  raw <- dplyr::mutate(raw, dplyr::across(dplyr::everything(), normalize_missing))
  if (anyNA(raw$answer_id) || anyDuplicated(raw$answer_id)) stop(path, ": answer_id is missing or duplicated", call. = FALSE)
  raw
}
