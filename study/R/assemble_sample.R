# Build the output rows (study sample or a reserved set), one per question, in the
# documented column order. Extra input columns are appended unchanged.

DRAW_COLUMNS <- c("question_id", "set", "draw_order", "selection_stage", "floor_label", "inclusion_prob",
                  "weight", "planned_version", "seed", "run_id", "frame_version")

# selection: question_id, set, draw_order, selection_stage, floor_label, inclusion_prob, weight,
#            planned_version (NA for the study sample)
# chosen_answers: output of pick_human_answer()
assemble_sample <- function(selection, frame_questions, chosen_answers, seed, run_id, frame_version,
                            tolerance) {
  qi <- match(selection$question_id, frame_questions$question_id)
  ai <- match(selection$question_id, chosen_answers$question_id)
  if (anyNA(qi) || anyNA(ai)) stop("Selected question(s) missing from the frame or answers", call. = FALSE)

  draw <- selection
  if (!"planned_version" %in% names(draw)) draw$planned_version <- NA_character_
  draw$floor_label <- as.character(draw$floor_label)
  draw$seed <- as.integer(seed)
  draw$run_id <- run_id
  draw$frame_version <- frame_version
  draw <- draw[DRAW_COLUMNS]

  q <- dplyr::select(frame_questions[qi, ], -question_id, -n_eligible_answers)
  a <- dplyr::select(chosen_answers[ai, ], -question_id)
  label_cols <- grep("^label_", names(q), value = TRUE)
  answer_cols <- c("answer_id", "answer_body_raw", "answer_text_clean", "answer_word_count", "answer_added_at",
                   "answer_score", "answerer_location", "careernet_correctness", "careernet_completeness",
                   "careernet_coherency", "careernet_correctness_num", "careernet_completeness_num",
                   "careernet_coherency_num", "Split", "n_eligible_answers")
  reasoning_cols <- c("careernet_reasoning_label", "n_reasoning_labels")
  extras <- setdiff(names(a), c(answer_cols, reasoning_cols))

  target <- a$answer_word_count
  targets <- tibble::tibble(
    target_words = target,
    target_min_words = as.integer(floor(target * (1 - tolerance) + 0.5)),
    target_max_words = as.integer(floor(target * (1 + tolerance) + 0.5))
  )

  out <- dplyr::bind_cols(
    draw,
    q[c("question_title", "question_body_raw", "question_text_clean", "question_word_count", "question_added_at",
        "question_score", "question_views", "question_tagnames", "asker_location",
        "scenario_labels", "n_labels", label_cols, "n_guaranteed_labels",
        GOAL_COLUMNS, "unclear_goal",
        "soc_code_raw", "soc_flag", "soc_major_groups", "n_soc_major_groups", "soc_detailed_codes")],
    a[c(answer_cols, reasoning_cols)],
    targets,
    a[extras]
  )
  if (any(PRIVATE_COLUMNS %in% names(out))) stop("Private id columns leaked into the output", call. = FALSE)
  out
}

GENERATION_COLUMNS <- c("question_id", "question_title", "question_text_clean", "target_words",
                        "target_min_words", "target_max_words")
