test_that("an opening salutation and a closing sign-off are removed, nothing else", {
  out <- display_answer_text(closing_pleasantries = CFG$closing_pleasantries, c(
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
            "I hope you find a good fit. Good luck!",
            "Shadow a physician.\n\nGood luck with your interviews next week, and remember to rest.",
            "Hope this helps you decide.\n\nShadow a physician first.",
            "Shadow a physician.\n\nBest of luck in your journey and keep studying hard every day.",
            "Shadow a physician.\n\nThen Y.")
  out <- display_answer_text(keep, CFG$closing_pleasantries)
  expect_equal(out$text, keep)
  expect_true(all(is.na(out$opening_removed) & is.na(out$closing_removed)))
})

test_that("a final line that is only a closing pleasantry is removed", {
  x <- c("Shadow a physician.\n\nHope this helps!", "Shadow a physician.\n\nI hope this helps.",
         "Shadow a physician.\n\nHope that helps", "Shadow a physician.\n\nGood luck!",
         "Shadow a physician.\n\nBest of luck!", "Shadow a physician.\n\nAll the best!",
         "Shadow a physician.\n\nWishing you the best!", "Shadow a physician.\n\nHope this helps! Good luck! Jane",
         "Shadow a physician.\n\nI hope this helps and good luck!", "Shadow a physician.\n\nBest of luck to you!\nJenna")
  out <- display_answer_text(x, CFG$closing_pleasantries)
  expect_equal(out$text, rep("Shadow a physician.", length(x)))
  expect_equal(out$closing_removed[c(1, 8, 10)], c("Hope this helps!", "Hope this helps! Good luck! Jane", "Best of luck to you!\nJenna"))
  # Not on the last line: stays.
  mid <- "Hope this helps!\n\nShadow a physician."
  expect_equal(display_answer_text(mid, CFG$closing_pleasantries)$text, mid)
  # Without the configured list, pleasantries are not touched.
  expect_equal(display_answer_text("Shadow a physician.\n\nGood luck!")$text, "Shadow a physician.\n\nGood luck!")
})

test_that("list markers are removed, items stay on their own lines with identical words", {
  html <- "<p>Steps:</p><ul><li>Call a nurse</li><li>Shadow a doctor, then apply</li></ul>"
  clean <- clean_text(html)
  out <- display_answer_text(clean, CFG$closing_pleasantries)
  expect_equal(out$text, "Steps:\n\nCall a nurse\nShadow a doctor, then apply")
  expect_equal(out$list_markers_removed, "- -")

  numbered <- "Do these:\n1. Get an internship.\n2) Network with nurses.\n10. Apply early.\n\u2022 Rest\n\u2013 Repeat\n* Relax"
  out2 <- display_answer_text(numbered, CFG$closing_pleasantries)
  expect_equal(out2$text, "Do these:\nGet an internship.\nNetwork with nurses.\nApply early.\nRest\nRepeat\nRelax")
  words <- function(x) str_split(str_squish(x), " ")[[1]]
  markers <- c("1.", "2)", "10.", "\u2022", "\u2013", "*")
  expect_equal(words(out2$text), setdiff(words(numbered), markers))

  untouched <- "2.5 years is typical.\n-getting started is hard\n2020. A hard year"
  expect_equal(display_answer_text(untouched)$text, untouched)
  expect_true(has_list("<ul><li>a</li></ul>", "a"))
})

test_that("removal never empties an answer and the remaining text is otherwise identical", {
  out <- display_answer_text(c("Hi,", "Hello Shawn,\n\nDo X. Then do Y.\n\nCheers, Sam"), CFG$closing_pleasantries)
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
  expect_true(all(edits$part %in% c("opening", "closing", "list_marker")))
  expect_equal(fa$answer_word_count_display, count_words(fa$answer_text_display))
  # Removing logged parts is the only change: display text is a contiguous piece of the clean text
  # once list markers are stripped from it.
  expect_true(all(str_detect(str_replace_all(fa$answer_text_clean, LIST_MARKER_PATTERN, ""), fixed(fa$answer_text_display))))
  fq <- fr$frame_questions
  q_changed <- fq$question_id[coalesce(fq$question_text_display, "") != normalize_whitespace(coalesce(fq$question_text_clean, ""))]
  expect_true(all(q_changed %in% fr$question_display_edits$question_id))
})
