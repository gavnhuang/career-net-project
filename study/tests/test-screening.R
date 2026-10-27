# Synthetic setting: labels A (rare) and B; 40 questions.
screen_frame <- function() {
  tibble::tibble(question_id = as.character(1:40),
                 question_title = paste("Q", 1:40), question_text_display = paste("Text", 1:40),
                 label_a = as.integer(1:40 %in% c(1:3, 21:26)),
                 label_b = as.integer(1:40 %in% c(4:12, 27:35)))
}
screen_draw <- function(fr = screen_frame(), seed = 1) draw_coverage_floor(fr, c("A", "B"), floor = 3, n = 10, seed = seed)

filled_sheet <- function(ids, excluded = character(), rule = "rule2") {
  tibble::tibble(question_id = ids, question_title = "t", question_text_display = "x",
                 rule2 = ifelse(ids %in% excluded & rule == "rule2", "TRUE", "FALSE"),
                 rule3 = ifelse(ids %in% excluded & rule == "rule3", "TRUE", "FALSE"),
                 rule4 = ifelse(ids %in% excluded & rule == "rule4", "TRUE", "FALSE"),
                 excluded = ifelse(ids %in% excluded, "TRUE", "FALSE"), screener = "tester", notes = "")
}

test_that("queues hold every unselected question, in a seeded order", {
  fr <- screen_frame()
  d <- screen_draw(fr)
  q <- make_replacement_queues(fr, d$question_id, c("A", "B"), 7)
  general <- q$question_id[q$queue == "general"]
  expect_setequal(general, setdiff(fr$question_id, d$question_id))
  expect_setequal(q$question_id[q$queue == "A"], setdiff(fr$question_id[fr$label_a == 1], d$question_id))
  expect_identical(q, make_replacement_queues(fr, d$question_id, c("A", "B"), 7))
  expect_false(identical(q, make_replacement_queues(fr, d$question_id, c("A", "B"), 8)))
})

test_that("the screening sheet has question text only", {
  d <- screen_draw()
  smp <- dplyr::left_join(d, screen_frame(), by = "question_id")
  smp$answer_text_display <- "secret answer"
  smp$careernet_correctness <- "4 - Fully Correct"
  sheet <- make_screening_sheet(smp)
  expect_equal(names(sheet), SCREENING_COLUMNS)
  expect_false(any(str_detect(names(sheet), "answer|careernet")))
  expect_false(any(unlist(sheet) %in% c("secret answer", "4 - Fully Correct")))
})

test_that("a floor-protecting exclusion is replaced from that label's queue, any other from the general queue", {
  fr <- screen_frame()
  a_ids <- fr$question_id[fr$label_a == 1]
  neither <- fr$question_id[fr$label_a == 0 & fr$label_b == 0]
  seed <- purrr::detect(1:200, function(s) {
    d <- screen_draw(fr, s)
    sum(d$question_id %in% a_ids) == 3 && any(d$question_id %in% neither)
  })
  d <- screen_draw(fr, seed)
  q <- make_replacement_queues(fr, d$question_id, c("A", "B"), 7)
  a_in <- d$question_id[d$question_id %in% a_ids]
  expect_equal(length(a_in), 3)                      # A sits exactly at the floor
  other <- d$question_id[!d$question_id %in% fr$question_id[fr$label_a == 1 | fr$label_b == 1]][1]
  excluded <- c(a_in[1], other)
  res <- replay_screening(d, list(filled_sheet(d$question_id, excluded)), q, fr, c("A", "B"), 3)

  expect_false(res$finished)
  log <- res$log
  expect_equal(log$replacement_queue[log$question_id == a_in[1]], "A")
  expect_equal(log$replaced_by[log$question_id == a_in[1]], q$question_id[q$queue == "A"][1])
  expect_equal(log$replacement_queue[log$question_id == other], "general")
  sel <- res$selection
  # Replacements take the excluded question's position (and block); draw order stays 1..n.
  pos <- function(id, x) x$draw_order[match(id, x$question_id)]
  expect_equal(pos(log$replaced_by, sel), pos(log$question_id, d))
  expect_equal(sel$floor_block[match(log$replaced_by, sel$question_id)], d$floor_block[match(log$question_id, d$question_id)])
  expect_equal(sel$draw_order, 1:10)
  expect_equal(floor_block_size(sel), floor_block_size(d))
  expect_equal(nrow(sel), 10)
  expect_false(anyDuplicated(sel$question_id) > 0)
  expect_false(any(sel$question_id %in% excluded))
  expect_gte(sum(sel$question_id %in% fr$question_id[fr$label_a == 1]), 3)
  expect_setequal(res$next_ids, log$replaced_by)

  # Round 2: no exclusions -> finished; same inputs -> same result.
  res2 <- replay_screening(d, list(filled_sheet(d$question_id, excluded), filled_sheet(res$next_ids)), q, fr, c("A", "B"), 3)
  expect_true(res2$finished)
  expect_identical(res2$selection, replay_screening(d, list(filled_sheet(d$question_id, excluded), filled_sheet(res$next_ids)),
                                                    q, fr, c("A", "B"), 3)$selection)
})

test_that("several dropping labels: the rarest label's queue first, then a floor swap", {
  fr <- screen_frame()
  fr$label_b[1:3] <- 1L                                        # questions 1-3 carry A and B
  d <- tibble::tibble(question_id = as.character(c(1, 2, 3, 13:19)), draw_order = 1:10,
                      selection_stage = c(rep("floor", 3), rep("random_fill", 7)), floor_label = c(rep("A", 3), rep(NA, 7)))
  q <- make_replacement_queues(fr, d$question_id, c("A", "B"), 3)
  res <- replay_screening(d, list(filled_sheet(d$question_id, "1")), q, fr, c("A", "B"), 3)
  expect_equal(res$log$reason, c("excluded", "floor_swap"))
  expect_equal(res$log$replacement_queue, c("A", "B"))         # A (9 in frame) is rarer than B
  expect_equal(res$log$question_id[2], "19")                    # last outside the floor block
  sel <- res$selection
  expect_equal(sel$question_id, c(res$log$replaced_by[1], "2", "3", res$log$replaced_by[2], as.character(13:18)))
  expect_equal(sel$draw_order, 1:10)
  expect_equal(floor_block_size(sel), 4)                         # the swapped-in B question joins the block
  expect_equal(res$log$draw_order, c(1L, 10L))
})

test_that("an exclusion outside the floor block uses the general queue, even when it carries a guaranteed label", {
  fr <- screen_frame()
  d <- tibble::tibble(question_id = as.character(c(1, 2, 3, 4, 5, 6, 21, 13:15)), draw_order = 1:10,
                      selection_stage = c(rep("floor", 6), rep("random_fill", 4)),
                      floor_label = c(rep("A", 3), rep("B", 3), rep(NA, 4)))
  q <- make_replacement_queues(fr, d$question_id, c("A", "B"), 3)
  res <- replay_screening(d, list(filled_sheet(d$question_id, "21")), q, fr, c("A", "B"), 3)
  expect_equal(res$log$replacement_queue, "general")             # 21 carries A but sits at position 7
  expect_equal(res$selection$draw_order[res$selection$question_id == res$log$replaced_by], 7L)
  # In the block, the same label triggers that label's queue.
  res2 <- replay_screening(d, list(filled_sheet(d$question_id, "2")), q, fr, c("A", "B"), 3)
  expect_equal(res2$log$replacement_queue, "A")
  expect_equal(res2$selection$draw_order[res2$selection$question_id == res2$log$replaced_by], 2L)
})

# n = 90: one exclusion drops two guaranteed labels below the floor (within the floor block) at once.
two_label_setting <- function() {
  ids <- as.character(1:300)
  fr <- tibble::tibble(question_id = ids, question_title = "t", question_text_display = "x",
                       label_a = as.integer(ids %in% as.character(c(1:3, 4:10))),         # A: 10 in frame (rarest)
                       label_b = as.integer(ids %in% as.character(c(1:3, 101:140))))      # B: 43 in frame
  # The draw: 1-3 carry A and B (A and B sit exactly at the floor); 87 random-fill questions carry neither.
  d <- tibble::tibble(question_id = as.character(c(1:3, 151:237)), draw_order = 1:90,
                      selection_stage = c(rep("floor", 3), rep("random_fill", 87)),
                      floor_label = c(rep("A", 3), rep(NA, 87)))
  list(fr = fr, d = d, q = make_replacement_queues(fr, d$question_id, c("A", "B"), 42))
}

test_that("a two-label drop keeps n = 90, meets both floors and is reproducible", {
  st <- two_label_setting()
  run <- function() replay_screening(st$d, list(filled_sheet(st$d$question_id, "2", "rule3")), st$q, st$fr, c("A", "B"), 3)
  res <- run()
  sel <- res$selection
  expect_equal(nrow(sel), 90)
  expect_false(anyDuplicated(sel$question_id) > 0)
  in_sel <- st$fr[match(sel$question_id, st$fr$question_id), ]
  expect_gte(sum(in_sel$label_a), 3)
  expect_gte(sum(in_sel$label_b), 3)
  expect_equal(res$log$reason, c("excluded", "floor_swap"))
  expect_equal(res$log$replacement_queue, c("A", "B"))
  expect_equal(res$log$question_id[2], "237")                   # most recently drawn random_fill
  expect_true(res$log$replaced_by[1] %in% as.character(4:10))   # A-only replacement
  expect_true(res$log$replaced_by[2] %in% as.character(101:140))
  expect_false(any(sel$question_id %in% c("2", "237")))
  # The A replacement keeps position 2; the B question joins the floor block at position 4.
  expect_equal(sel$question_id[c(2, 4)], res$log$replaced_by)
  expect_equal(floor_block_size(sel), 4)
  expect_equal(sel$question_id[5:90], as.character(151:236))
  first4 <- st$fr[match(select_first_k(sel, 4)$question_id, st$fr$question_id), ]
  expect_gte(sum(first4$label_a), 3)
  expect_gte(sum(first4$label_b), 3)
  expect_setequal(res$next_ids, res$log$replaced_by)            # swapped-in questions are screened next round
  expect_identical(res, run())
  # Round 2 clear: finished with n = 90.
  res2 <- replay_screening(st$d, list(filled_sheet(st$d$question_id, "2", "rule3"), filled_sheet(res$next_ids)),
                           st$q, st$fr, c("A", "B"), 3)
  expect_true(res2$finished)
  expect_equal(nrow(res2$selection), 90)
})

test_that("the floor swap stops loudly only when nothing outside the floor block can be swapped out", {
  st <- two_label_setting()
  d <- st$d
  d$selection_stage[4:90] <- "floor"                             # the whole draw is the floor block
  expect_error(replay_screening(d, list(filled_sheet(d$question_id, "2")), st$q, st$fr, c("A", "B"), 3),
               "no question outside the floor block can be swapped out")
})

test_that("replacements never duplicate, and never use reserved or anchor items", {
  skip_if_no_data()
  fr <- real_remaining()
  d <- draw_coverage_floor(fr, CFG$guaranteed_labels, CFG$floor, 100, 11)
  q <- make_replacement_queues(fr, d$question_id, CFG$guaranteed_labels, 11)
  expect_false(any(q$question_id %in% c(real_reserved()$sets$question_id, anchor_ids(), d$question_id)))
  excluded <- d$question_id[c(1, 2, 3, 20, 50, 89, 100)]
  res <- replay_screening(d, list(filled_sheet(d$question_id, excluded, "rule4")), q, fr, CFG$guaranteed_labels, CFG$floor)
  sel <- res$selection
  expect_equal(nrow(sel), 100)
  expect_equal(sel$draw_order, 1:100)
  block <- fr[match(sel$question_id[sel$floor_block], fr$question_id), ]
  expect_true(all(purrr::map_int(label_column_names(CFG$guaranteed_labels), ~ sum(block[[.x]])) >= CFG$floor))
  if (!any(res$log$reason == "floor_swap")) {
    expect_equal(sel$draw_order[match(res$log$replaced_by, sel$question_id)], c(1, 2, 3, 20, 50, 89, 100))
  }
  expect_false(anyDuplicated(sel$question_id) > 0)
  expect_false(any(sel$question_id %in% c(excluded, real_reserved()$sets$question_id, anchor_ids())))
  per_label <- purrr::map_int(label_column_names(CFG$guaranteed_labels), ~ sum(fr[[.x]][match(sel$question_id, fr$question_id)]))
  expect_true(all(per_label >= CFG$floor))
  expect_identical(res, replay_screening(d, list(filled_sheet(d$question_id, excluded, "rule4")), q, fr,
                                         CFG$guaranteed_labels, CFG$floor))
  expect_false(any(sel$question_id %in% res$log$question_id))
})

test_that("invalid sheets fail loudly", {
  d <- screen_draw()
  ok <- filled_sheet(d$question_id)
  blank <- ok; blank$rule3[2] <- ""
  expect_error(validate_screening_sheet(blank, d$question_id, 1), "rule3 is not TRUE/FALSE")
  inconsistent <- ok; inconsistent$rule2[1] <- "TRUE"
  expect_error(validate_screening_sheet(inconsistent, d$question_id, 1), "excluded != \\(rule2 \\| rule3 \\| rule4\\)")
  wrong_ids <- ok; wrong_ids$question_id[1] <- "999"
  expect_error(validate_screening_sheet(wrong_ids, d$question_id, 1), "do not match the draw")
  no_screener <- ok; no_screener$screener[3] <- ""
  expect_error(validate_screening_sheet(no_screener, d$question_id, 1), "screener is empty")
  expect_silent(validate_screening_sheet(ok, d$question_id, 1))
})
