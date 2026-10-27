test_that("an opening salutation and a closing sign-off are removed, nothing else", {
  out <- display_answer_text(c(
    "Hello Shawn,\n\nBased on your interests, a career as a portfolio manager could fit.\n\nBest wishes.",
    "Hi there! Great question. Start with an internship.",
    "Hey there!\nTalk to a nurse.\n\nSincerely, Maria",
    "Dear student,\nTalk to a nurse.\n\nCheers!",
    "Greetings,\n\nTalk to a nurse.\n\n- John",
    "Hi Claire - A minor can help.",
    "Talk to a nurse.\n\nGood luck! Jane",
    "Talk to a nurse.\n\nBest,\nJane Doe"
  ))
  expect_equal(out$text[1], "Based on your interests, a career as a portfolio manager could fit.")
  expect_equal(out$opening_removed[1], "Hello Shawn,")
  expect_equal(out$closing_removed[1], "Best wishes.")
  expect_equal(out$text[2], "Great question. Start with an internship.")   # only "Hi there!" goes
  expect_equal(out$opening_removed[2], "Hi there!")
  expect_true(is.na(out$closing_removed[2]))
  expect_equal(out$text[3:5], rep("Talk to a nurse.", 3))
  expect_equal(out$closing_removed[3:5], c("Sincerely, Maria", "Cheers!", "- John"))
  expect_equal(out$opening_removed[3:5], c("Hey there!", "Dear student,", "Greetings,"))
  expect_equal(out$text[6], "A minor can help.")
  expect_equal(out$closing_removed[7:8], c("Good luck! Jane", "Best,\nJane Doe"))
})

test_that("advice, personal experience and in-text courtesies are left alone", {
  keep <- c("Hello and thank you for your question. Work in a lab first.",
            "Great question! I worked as a nurse for 10 years.\n\nGood luck with your career search!",
            "Talk to people in the field.\n\nHope this helps!",
            "I hope you find a good fit. Good luck!",
            "Shadow a physician.\n\nBest of luck in your journey and keep studying hard every day.")
  out <- display_answer_text(keep)
  expect_equal(out$text, keep)
  expect_true(all(is.na(out$opening_removed) & is.na(out$closing_removed)))
})

test_that("removal never empties an answer and the remaining text is otherwise identical", {
  out <- display_answer_text(c("Hi,", "Hello Shawn,\n\nDo X. Then do Y.\n\nCheers, Sam"))
  expect_equal(out$text[1], "Hi,")
  expect_equal(out$text[2], "Do X. Then do Y.")
  original <- "Hello Shawn,\n\nDo X. Then do Y.\n\nCheers, Sam"
  expect_true(str_detect(original, fixed(out$text[2])))
})

test_that("hashtags are removed from questions and logged", {
  out <- display_question_text(c("I want to be a nurse. #nursing #health-care\n#college", "C# or Java? #coding", "#job-search", NA))
  expect_equal(out$text, c("I want to be a nurse.", "C# or Java?", "", NA))
  expect_equal(out$hashtags_removed, c("#nursing #health-care #college", "#coding", "#job-search", NA))
})

test_that("has_list flags HTML and text lists", {
  expect_equal(has_list(c("<ul><li>a</li></ul>", "<p>x</p>", "<p>x</p>", "<p>x</p>", "<ol>"),
                        c("a", "- one\n- two", "Intro\n1. First", "Plain text", "a")),
               c(TRUE, TRUE, TRUE, FALSE, TRUE))
})

test_that("display edits are logged for every changed answer in the frame", {
  skip_if_no_data()
  fr <- real_frame()
  fa <- fr$frame_answers
  edits <- fr$display_edits
  changed <- fa$answer_id[fa$answer_text_display != fa$answer_text_clean]
  expect_setequal(unique(edits$answer_id), changed)
  expect_true(all(edits$part %in% c("opening", "closing")))
  expect_equal(fa$answer_word_count_display, count_words(fa$answer_text_display))
  # Removing logged parts is the only change: display text is a contiguous piece of the clean text.
  expect_true(all(str_detect(fa$answer_text_clean, fixed(fa$answer_text_display))))
  fq <- fr$frame_questions
  q_changed <- fq$question_id[coalesce(fq$question_text_display, "") != normalize_whitespace(coalesce(fq$question_text_clean, ""))]
  expect_true(all(q_changed %in% fr$question_display_edits$question_id))
})
