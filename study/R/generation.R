# AI answer generation (B02). One call per attempt, no memory between calls.
# Protocol: D4/D100 model and settings, D10 prose only and length matched, D24 URLs stripped,
# D101 failure rule: up to max_tries; if none fits the length window, keep the attempt that passes the
# format checks and is closest in length, flagged. Questions are never dropped for the model's failures.

GEN_FORMAT_PATTERN <- "(?m)(^\\s*[-*•]\\s|^\\s*\\d+[.)]\\s|^\\s*#{1,6}\\s|\\*\\*|__)"
GEN_GREETING_PATTERN <- "(?i)^\\s*(hi|hello|hey|dear|greetings)\\b"

generation_settings <- function(cfg) {
  g <- cfg$generation
  if (is.null(g)) stop("Config has no generation section", call. = FALSE)
  needed <- c("endpoint", "model", "reasoning_effort", "prompt_file", "max_tries", "length_tolerance",
              "length_request_factor", "output_dir")
  miss <- setdiff(needed, names(g))
  if (length(miss)) stop("generation is missing: ", paste(miss, collapse = ", "), call. = FALSE)
  if (!file.exists(g$prompt_file)) stop("Prompt file not found: ", g$prompt_file, call. = FALSE)
  g$prompt_template <- paste(readLines(g$prompt_file, encoding = "UTF-8", warn = FALSE), collapse = "\n")
  g$prompt_md5 <- digest::digest(file = g$prompt_file, algo = "md5")
  for (ph in c("{request_words}", "{max_words}")) {
    if (!grepl(ph, g$prompt_template, fixed = TRUE)) stop("Prompt has no ", ph, " placeholder", call. = FALSE)
  }
  g$generation_frozen <- isTRUE(g$generation_frozen)
  g$pause_seconds <- g$pause_seconds %||% 0
  g
}

# Once frozen, the prompt file must match the md5 recorded at freezing.
verify_generation_frozen <- function(g) {
  if (!g$generation_frozen) return(invisible(TRUE))
  if (!nzchar(g$frozen_prompt_md5 %||% "")) stop("generation_frozen is true but frozen_prompt_md5 is empty", call. = FALSE)
  if (!identical(g$prompt_md5, g$frozen_prompt_md5)) {
    stop("The prompt file differs from the frozen version (md5 ", g$prompt_md5, ", frozen ",
         g$frozen_prompt_md5, "). Generation is frozen; restore the prompt.", call. = FALSE)
  }
  invisible(TRUE)
}

# D103: the model runs long, so it is asked for target * length_request_factor words with the window's
# upper bound as a ceiling. Acceptance is still checked against target_words and the +/-20% window.
request_lengths <- function(target_words, request_factor, tolerance) {
  target_words <- as.integer(target_words)
  c(request = as.integer(round(target_words * request_factor)),
    max = as.integer(length_bounds(target_words, tolerance)[["max"]]))
}

build_instructions <- function(template, target_words, request_factor, tolerance) {
  n <- request_lengths(target_words, request_factor, tolerance)
  x <- gsub("{request_words}", as.character(n[["request"]]), template, fixed = TRUE)
  gsub("{max_words}", as.character(n[["max"]]), x, fixed = TRUE)
}

# What the model sees: the same question text the raters see.
build_input <- function(title, body) {
  title <- str_trim(coalesce(title, ""))
  body <- str_trim(coalesce(body, ""))
  if (nzchar(title) && nzchar(body)) paste0(title, "\n\n", body) else paste0(title, body)
}

length_bounds <- function(target_words, tolerance) {
  c(min = ceiling((1 - tolerance) * target_words), max = floor((1 + tolerance) * target_words))
}

# Returns list(ok, reason, text, word_count, urls_removed, typography_changed). Text is returned with
# URLs removed (D24) and typography normalized (D102). The format and greeting checks use that text
# (what raters see); the word count uses the URL-stripped text before normalization, as the human
# target_words were counted, so the " - " that replaces a dash is never counted as a word.
check_answer <- function(text, target_words, tolerance) {
  if (is.na(text) || !nzchar(str_trim(text))) {
    return(list(ok = FALSE, reason = "empty", text = text, word_count = 0L, urls_removed = FALSE, typography_changed = FALSE))
  }
  stripped <- normalize_whitespace(remove_urls(text))
  urls_removed <- !identical(stripped, normalize_whitespace(text))
  cleaned <- normalize_typography(stripped)
  typography_changed <- !identical(cleaned, stripped)
  wc <- count_words(stripped)
  b <- length_bounds(target_words, tolerance)
  reason <- if (str_detect(cleaned, GEN_FORMAT_PATTERN)) "formatting"
    else if (str_detect(cleaned, GEN_GREETING_PATTERN)) "greeting"
    else if (wc < b[["min"]]) "too_short"
    else if (wc > b[["max"]]) "too_long"
    else "ok"
  list(ok = reason == "ok", reason = reason, text = cleaned, word_count = wc, urls_removed = urls_removed,
       typography_changed = typography_changed)
}

# One API call. Returns list(text, response_id, model_returned, usage, raw, error).
call_openai <- function(g, instructions, input, api_key = Sys.getenv("OPENAI_API_KEY")) {
  body <- list(model = g$model, instructions = instructions, input = input,
               reasoning = list(effort = g$reasoning_effort), store = FALSE)
  req <- httr2::request(g$endpoint) |>
    httr2::req_auth_bearer_token(api_key) |>
    httr2::req_body_json(body) |>
    httr2::req_retry(max_tries = 5, is_transient = function(resp) httr2::resp_status(resp) %in% c(429, 500, 502, 503, 504)) |>
    httr2::req_timeout(180) |>
    httr2::req_error(is_error = function(resp) FALSE)
  resp <- tryCatch(httr2::req_perform(req), error = function(e) e)
  if (inherits(resp, "error")) return(list(text = NA_character_, error = conditionMessage(resp), raw = NULL))
  raw <- httr2::resp_body_json(resp, simplifyVector = FALSE)
  if (httr2::resp_status(resp) >= 400) {
    return(list(text = NA_character_, error = paste0("HTTP ", httr2::resp_status(resp), ": ", raw$error$message %||% ""), raw = raw))
  }
  list(text = extract_output_text(raw), response_id = raw$id %||% NA_character_,
       model_returned = raw$model %||% NA_character_, usage = raw$usage, raw = raw, error = NA_character_)
}

extract_output_text <- function(raw) {
  parts <- character()
  for (item in raw$output %||% list()) {
    if (identical(item$type, "message")) {
      for (c in item$content %||% list()) if (identical(c$type, "output_text")) parts <- c(parts, c$text)
    }
  }
  if (!length(parts)) NA_character_ else paste(parts, collapse = "\n\n")
}

# Up to max_tries attempts for one question. `call` is injectable for tests.
# Returns list(row = one-row tibble, attempts = list of attempt records for the raw log).
generate_one <- function(q, g, call = call_openai) {
  target <- as.integer(q$target_words)
  instructions <- build_instructions(g$prompt_template, target, g$length_request_factor, g$length_tolerance)
  input <- build_input(q$question_title, q$question_text_display)
  attempts <- list()
  accepted <- NULL
  closest <- NULL
  for (i in seq_len(g$max_tries)) {
    res <- call(g, instructions, input)
    chk <- if (is.na(res$error %||% NA)) check_answer(res$text, target, g$length_tolerance)
           else list(ok = FALSE, reason = "api_error", text = NA_character_, word_count = 0L, urls_removed = FALSE,
                     typography_changed = FALSE)
    attempts[[i]] <- list(question_id = q$question_id, attempt = i, timestamp = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
                          model_requested = g$model, model_returned = res$model_returned %||% NA_character_,
                          reasoning_effort = g$reasoning_effort, prompt_md5 = g$prompt_md5,
                          target_words = target, result = chk$reason, word_count = chk$word_count,
                          response_id = res$response_id %||% NA_character_, error = res$error %||% NA_character_,
                          output_text = res$text, raw_response = res$raw)
    if (chk$ok) { accepted <- list(chk = chk, res = res, attempt = i); break }
    if (chk$reason %in% c("too_short", "too_long")) {
      dist <- abs(chk$word_count - target)
      if (is.null(closest) || dist < closest$dist) closest <- list(chk = chk, res = res, attempt = i, dist = dist)
    }
    if (identical(chk$reason, "api_error") && grepl("^HTTP (401|403|404)", res$error %||% "")) {
      stop("API refused the request (", res$error, "). Check the key and model ID.", call. = FALSE)
    }
  }
  status <- "accepted"
  if (is.null(accepted) && !is.null(closest)) { accepted <- closest; status <- "closest_length" }
  if (is.null(accepted)) status <- "failed"
  b <- length_bounds(target, g$length_tolerance)
  n_attempts <- length(attempts)
  reasons <- paste(vapply(attempts, function(a) a$result, ""), collapse = ";")
  row <- tibble::tibble(
    question_id = q$question_id,
    status = status,
    accepted_attempt = if (is.null(accepted)) NA_integer_ else as.integer(accepted$attempt),
    response_text = if (is.null(accepted)) NA_character_ else accepted$chk$text,
    response_text_raw = if (is.null(accepted)) NA_character_ else accepted$res$text,
    word_count = if (is.null(accepted)) NA_integer_ else as.integer(accepted$chk$word_count),
    target_words = target, target_min_words = as.integer(b[["min"]]), target_max_words = as.integer(b[["max"]]),
    attempts = n_attempts, regenerations = n_attempts - 1L,
    rejection_reasons = reasons,
    urls_removed = if (is.null(accepted)) NA else accepted$chk$urls_removed,
    typography_changed = if (is.null(accepted)) NA else accepted$chk$typography_changed,
    model_requested = g$model,
    model_returned = if (is.null(accepted)) NA_character_ else accepted$res$model_returned %||% NA_character_,
    reasoning_effort = g$reasoning_effort, prompt_md5 = g$prompt_md5,
    response_id = if (is.null(accepted)) NA_character_ else accepted$res$response_id %||% NA_character_,
    generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")
  )
  list(row = row, attempts = attempts)
}

append_jsonl <- function(records, path) {
  con <- file(path, open = "a", encoding = "UTF-8")
  on.exit(close(con))
  for (r in records) writeLines(jsonlite::toJSON(r, auto_unbox = TRUE, null = "null", na = "null"), con)
}

read_done_ids <- function(answers_csv) {
  if (!file.exists(answers_csv)) return(character())
  x <- readr::read_csv(answers_csv, col_types = readr::cols(.default = "c"), progress = FALSE)
  unique(x$question_id)
}
