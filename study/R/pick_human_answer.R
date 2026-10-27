# One human answer per question, chosen uniformly at random from its eligible answers.
# Runs over the whole answer frame in canonical order, so a question gets the same
# answer whichever set it lands in.

pick_human_answer <- function(frame_answers, seed) {
  fa <- frame_answers[order(id_key(frame_answers$question_id), id_key(frame_answers$answer_id), method = "radix"), ]
  qids <- unique(fa$question_id)
  idx_by_q <- split(seq_len(nrow(fa)), factor(fa$question_id, levels = qids))
  chosen <- with_seed(seed, vapply(idx_by_q, function(i) sample_k(i, 1L), integer(1)))
  out <- fa[chosen, ]
  out$n_eligible_answers <- lengths(idx_by_q)
  out
}
