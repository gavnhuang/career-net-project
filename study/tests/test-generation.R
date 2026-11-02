g_test <- function(max_tries = 3) {
  list(model = "test-model", reasoning_effort = "none", max_tries = max_tries, length_tolerance = 0.20,
       length_request_factor = 0.88,
       prompt_template = "Write about {request_words} words, and no more than {max_words}.", prompt_md5 = "abc")
}
words <- function(n) paste(rep("word", n), collapse = " ")
fake_call <- function(texts) {
  i <- 0
  function(g, instructions, input) {
    i <<- i + 1
    list(text = texts[[min(i, length(texts))]], response_id = paste0("r", i), model_returned = "test-model-2026",
         raw = list(id = paste0("r", i)), error = NA_character_)
  }
}
q_test <- tibble::tibble(question_id = "1", question_title = "Title", question_text_display = "Body", target_words = "100")

test_that("length window is +/-20% of the human answer", {
  expect_equal(unname(length_bounds(100, 0.2)), c(80, 120))
  expect_true(check_answer(words(80), 100, 0.2)$ok)
  expect_true(check_answer(words(120), 100, 0.2)$ok)
  expect_equal(check_answer(words(79), 100, 0.2)$reason, "too_short")
  expect_equal(check_answer(words(121), 100, 0.2)$reason, "too_long")
})

test_that("lists, headings, bold and greetings are rejected", {
  expect_equal(check_answer(paste("Intro.\n- one", words(95)), 100, 0.2)$reason, "formatting")
  expect_equal(check_answer(paste("Intro.\n2. two", words(95)), 100, 0.2)$reason, "formatting")
  expect_equal(check_answer(paste("## Head\n", words(98)), 100, 0.2)$reason, "formatting")
  expect_equal(check_answer(paste("Some **bold**", words(97)), 100, 0.2)$reason, "formatting")
  expect_equal(check_answer(paste("Hi Erin, thanks.", words(97)), 100, 0.2)$reason, "greeting")
  expect_true(check_answer(paste("In 2. years", words(97)), 100, 0.2)$ok)
})

test_that("URLs are stripped from accepted text", {
  r <- check_answer(paste("See https://example.com today.", words(97)), 100, 0.2)
  expect_true(r$ok); expect_true(r$urls_removed); expect_false(grepl("http", r$text))
})

test_that("prompt placeholders ask for target * factor words, capped at the window's upper bound (D103)", {
  tpl <- "Write about {request_words} words, and no more than {max_words}."
  expect_equal(build_instructions(tpl, 100, 0.88, 0.2), "Write about 88 words, and no more than 120.")
  expect_equal(build_instructions(tpl, "259", 0.88, 0.2), "Write about 228 words, and no more than 310.")
  expect_equal(build_instructions(tpl, 40, 0.88, 0.2), "Write about 35 words, and no more than 48.")
  expect_equal(unname(request_lengths(51, 0.88, 0.2)), c(45L, 61L))
})

test_that("the prompt file must contain both length placeholders", {
  dir <- withr::local_tempdir()
  cfg_with <- function(prompt) {
    f <- file.path(dir, "prompt.txt"); writeLines(prompt, f)
    list(generation = list(endpoint = "x", model = "m", reasoning_effort = "none", prompt_file = f, max_tries = 5,
                           length_tolerance = 0.2, length_request_factor = 0.88, output_dir = dir))
  }
  expect_error(generation_settings(cfg_with("Aim for approximately {target_words} words.")), "\\{request_words\\}")
  expect_error(generation_settings(cfg_with("Write about {request_words} words.")), "\\{max_words\\}")
  expect_silent(generation_settings(cfg_with("Write about {request_words} words, and no more than {max_words}.")))
  cfg <- cfg_with("Write about {request_words} words, and no more than {max_words}.")
  cfg$generation$length_request_factor <- NULL
  expect_error(generation_settings(cfg), "length_request_factor")
})

test_that("the real prompt file and config pass the settings check", {
  g <- withr::with_dir(ROOT, generation_settings(CFG))
  expect_equal(g$length_request_factor, 0.83)
  expect_false(grepl("{target_words}", g$prompt_template, fixed = TRUE))
})

test_that("model input", {
  expect_equal(build_input("T", "B"), "T\n\nB")
  expect_equal(build_input("T", ""), "T")
})

test_that("normalize_typography: curly quotes to straight, em/en dash to ' - ', nothing else (D102)", {
  expect_equal(normalize_typography("It’s ‘fine’"), "It's 'fine'")
  expect_equal(normalize_typography("“Quoted”"), "\"Quoted\"")
  expect_equal(normalize_typography("help—not a failure"), "help - not a failure")
  expect_equal(normalize_typography("help — not"), "help - not")
  expect_equal(normalize_typography("10–15 years"), "10 - 15 years")
  expect_equal(normalize_typography("Line one.\n\nLine two -- ok."), "Line one.\n\nLine two -- ok.")
  expect_equal(normalize_typography(c("a’b", NA)), c("a'b", NA))
})

test_that("answers are normalized before checking; raw text and the change flag are kept", {
  r <- check_answer(paste0("It’s a step—not a promise. ", words(90)), 100, 0.2)
  expect_true(r$ok); expect_true(r$typography_changed)
  expect_false(grepl("[‘’“”–—]", r$text))
  expect_equal(r$word_count, 95L)  # counted before normalization: the dash is not a word
  expect_false(check_answer(words(100), 100, 0.2)$typography_changed)
  raw <- paste0("A “step”. ", words(98))
  g <- generate_one(q_test, g_test(), call = fake_call(list(raw)))
  expect_equal(g$row$response_text_raw, raw)
  expect_equal(g$row$response_text, paste0("A \"step\". ", words(98)))
  expect_true(g$row$typography_changed)
})

test_that("the length check counts words before normalization, so a dash never adds a word", {
  r <- check_answer("step—not", 2, 0.2)
  expect_equal(r$text, "step - not")
  expect_equal(r$word_count, 1L)  # count_words() splits on whitespace only, as for the human answers
  expect_equal(r$word_count, count_words("step—not"))
  expect_lt(r$word_count, count_words(r$text))
  expect_equal(check_answer(paste("A step—not a promise.", words(95)), 100, 0.2)$word_count,
               check_answer(paste("A step-not a promise.", words(95)), 100, 0.2)$word_count)
  expect_true(check_answer(paste0(words(120), "—end"), 100, 0.2)$ok)  # 120 words, not 122
})

test_that("retries until a passing answer, logging every attempt", {
  r <- generate_one(q_test, g_test(), call = fake_call(list(words(50), paste("- a", words(99)), words(100))))
  expect_equal(r$row$status, "accepted"); expect_equal(r$row$attempts, 3L)
  expect_equal(r$row$rejection_reasons, "too_short;formatting;ok")
  expect_length(r$attempts, 3)
})

test_that("outside the window every time: the closest-length attempt is kept and flagged (D101)", {
  r <- generate_one(q_test, g_test(5), call = fake_call(list(words(50), words(130), paste("- a", words(99)), words(70), words(140))))
  expect_equal(r$row$status, "closest_length"); expect_equal(r$row$word_count, 130L)
  expect_equal(r$row$accepted_attempt, 2L); expect_equal(r$row$attempts, 5L)
})

test_that("failed only when no attempt passes the format checks", {
  r <- generate_one(q_test, g_test(), call = fake_call(list(paste("- a", words(99)))))
  expect_equal(r$row$status, "failed"); expect_true(is.na(r$row$response_text)); expect_equal(r$row$attempts, 3L)
})

test_that("output text is pulled from a Responses API message", {
  raw <- list(output = list(list(type = "reasoning"),
                            list(type = "message", content = list(list(type = "output_text", text = "Hello there.")))))
  expect_equal(extract_output_text(raw), "Hello there.")
  expect_true(is.na(extract_output_text(list(output = list()))))
})

test_that("a frozen prompt must match its recorded md5", {
  g <- list(generation_frozen = TRUE, frozen_prompt_md5 = "x", prompt_md5 = "y")
  expect_error(verify_generation_frozen(g), "differs from the frozen")
  g$prompt_md5 <- "x"; expect_true(verify_generation_frozen(g))
})
