# Display text for raters and generation. Starts from the *_text_clean columns and removes only:
#   answers:   an opening salutation, a closing sign-off / signature / pleasantry, and list markers
#   questions: CareerVillage hashtag tags
# Nothing is reworded. Every removal is returned so it can be logged.

SALUTATION_WORD <- "(?i:hi|hello|hey|hiya|howdy|greetings|good (?:morning|afternoon|evening|day))"
# Words that may follow a salutation word: capitalized names or a few fixed addressees.
ADDRESSEE <- "(?:[A-Z][\\p{L}'\u2019.-]*|(?i:there|all|everyone|everybody|friend|friends|folks|students?|again|y'all))"
# "Hello Shawn,"  "Hi there!"  "Hi Claire - "  "Hi,"  "Hello" or "Hi maddie" alone on its line
# "Dear student,"  "Dear NIEAM S.,"
OPENING_PATTERN <- paste0(
  "^[ \\t]*(?:", SALUTATION_WORD, "\\b(?:[ \\t]+", ADDRESSEE, "){0,4}[ \\t]*(?:[,.!:;]+|[-\u2013\u2014~]+(?=[ \\t\\n]|$)|(?=\\n|$))",
  "|", SALUTATION_WORD, "\\b[ \\t]+\\p{L}+[ \\t]*[,.!:;]*[ \\t]*(?=\\n|$)",
  "|(?i:dear)[ \\t]+[^\\n!?:;]{1,40}?[,!:;]+)[ \\t]*"
)

# Valedictions. Closing pleasantries ("Hope this helps", "Good luck", ...) come from the config.
VALEDICTION <- paste0(
  "(?i:best(?: wishes| regards)?|(?:kind|warm|warmest) regards|regards|warmly",
  "|sincerely(?: yours)?|yours(?: truly| sincerely)?|cheers|take care|respectfully|cordially",
  "|thanks(?: again)?|thank you(?: again)?|many thanks|with gratitude)"
)
SIGNATURE_NAME <- "[A-Z][\\p{L}'\u2019.-]*(?:[ \\t]+[A-Z][\\p{L}'\u2019.-]*){0,2}"
VALEDICTION_LINE <- paste0("^[ \\t]*", VALEDICTION, "[ \\t]*[,.!:;]*(?:[ \\t]+", SIGNATURE_NAME, ")?[ \\t]*[,.!]*[ \\t]*$")
# A bare last line counts as a signature only if it does not start with a common sentence word
# ("Then Y.", "Practice Gratitude," stay).
NOT_NAME_START <- paste0("^[ \\t]*(?:Then|Good|Great|Yes|No|Hope|Note|Also|So|And|But|Remember|Practice|Keep|Stay|",
                         "Enjoy|Happy|Go|Do|Be|Try|Never|Always|Thank|Thanks|Congrats|Congratulations|Welcome|",
                         "Done|Finally|Lastly|Ok|Okay|Onward|Onwards|Peace|Love|Believe|Dream|Work|Study|Learn)\\b")
NAME_LINE <- paste0("^[ \\t]*", SIGNATURE_NAME, "[ \\t]*[,.]?[ \\t]*$")
DASH_NAME_LINE <- paste0("^[ \\t]*[-\u2013\u2014~][ \\t]*", SIGNATURE_NAME, "[ \\t]*$")
RULE_LINE <- "^[ \\t]*[-\u2013\u2014~_=]{2,}[ \\t]*$"   # "--" signature separator

HASHTAG_PATTERN <- "(?<![\\p{L}\\p{N}_&#/])#[A-Za-z][A-Za-z0-9_]*(?:-[A-Za-z0-9_]+)*"
LIST_TEXT_PATTERN <- "(?m)^[ \\t]*(?:[-*\u2022]|1\\.)[ \\t]"
# A list marker at the start of a line: "-", "*", "•", "–", or a 1-2 digit number with "." or ")",
# followed by whitespace. The marker and the whitespace after it are removed; the item stays.
LIST_MARKER_PATTERN <- "(?m)^[ \\t]*(?:[-*\u2022\u2013]|[0-9]{1,2}[.)])[ \\t]+"
CLOSING_TRAIL <- "[ \\t,.!?;:()\\p{So}\\p{Sk}-]*"

# A line that is only closing pleasantries (up to three, e.g. "Hope this helps! Good luck!",
# "I hope this helps and good luck!"), optionally followed by a name.
pleasantry_line_pattern <- function(phrases) {
  if (!length(phrases)) return("(?!x)x")
  alt <- paste(str_replace_all(str_escape(str_to_lower(phrases)), " +", "[ \\\\t]+"), collapse = "|")
  one <- paste0("(?i:", alt, ")")
  sep <- "[ \\t]*[,.!;:]*[ \\t]*(?:(?i:and)[ \\t]+)?"
  paste0("^[ \\t]*", one, "(?:", sep, one, "){0,2}[ \\t]*[,.!;:]*(?:[ \\t]+", SIGNATURE_NAME, ")?", CLOSING_TRAIL, "$")
}

# Returns tibble(text, opening_removed, closing_removed, list_markers_removed); removed parts are NA
# when nothing was removed. Order: opening, closing, then list markers (so a list's last item is
# never mistaken for a signature).
display_answer_text <- function(clean, closing_pleasantries = character()) {
  closing_line <- paste0("(?:", VALEDICTION_LINE, ")|(?:", pleasantry_line_pattern(closing_pleasantries), ")")
  purrr::map_dfr(clean, display_answer_one, closing_line = closing_line)
}

display_answer_one <- function(x, closing_line = VALEDICTION_LINE) {
  out <- tibble::tibble(text = x, opening_removed = NA_character_, closing_removed = NA_character_,
                        list_markers_removed = NA_character_)
  if (is.na(x)) return(out)

  opening <- str_extract(x, OPENING_PATTERN)
  if (!is.na(opening) && nzchar(str_trim(opening))) {
    rest <- str_trim(str_sub(x, nchar(opening) + 1), side = "left")
    if (count_words(rest) > 0) {
      out$opening_removed <- str_trim(opening)
      x <- rest
    }
  }

  lines <- str_split_1(x, "\n")
  removed <- character()
  repeat {
    while (length(lines) && str_trim(lines[length(lines)]) == "") lines <- lines[-length(lines)]
    n <- length(lines)
    if (n < 2) break
    prev <- if (n >= 2) max(c(0L, which(str_trim(lines[seq_len(n - 1)]) != ""))) else 0L
    if (prev > 0 && str_detect(lines[n], NAME_LINE) && str_detect(lines[prev], closing_line)) {
      drop <- c(prev, n)
    } else if (str_detect(lines[n], closing_line) || str_detect(lines[n], DASH_NAME_LINE) ||
               (str_detect(lines[n], NAME_LINE) && !str_detect(lines[n], NOT_NAME_START)) ||
               str_detect(lines[n], RULE_LINE)) {
      drop <- n
    } else {
      break
    }
    keep <- lines[-(min(drop):n)]
    if (count_words(paste(keep, collapse = " ")) == 0) break
    removed <- c(str_trim(lines[min(drop):n][str_trim(lines[min(drop):n]) != ""]), removed)
    lines <- keep
  }
  if (length(removed)) {
    out$closing_removed <- paste(removed, collapse = "\n")
    x <- str_trim(paste(lines, collapse = "\n"), side = "right")
  }

  markers <- str_trim(str_extract_all(x, LIST_MARKER_PATTERN)[[1]])
  if (length(markers)) {
    out$list_markers_removed <- paste(markers, collapse = " ")
    x <- str_replace_all(x, LIST_MARKER_PATTERN, "")
  }
  out$text <- x
  out
}

# Returns tibble(text, hashtags_removed).
display_question_text <- function(clean) {
  tags <- str_extract_all(coalesce(clean, ""), HASHTAG_PATTERN)
  text <- ifelse(is.na(clean), NA_character_, normalize_whitespace(str_replace_all(coalesce(clean, ""), HASHTAG_PATTERN, "")))
  tibble::tibble(text = text, hashtags_removed = purrr::map_chr(tags, ~ if (length(.x)) paste(.x, collapse = " ") else NA_character_))
}

# D102: plain typography for display, so the AI and human answers do not differ in punctuation style.
# Curly quotes -> straight, em/en dash -> " - ", doubled spaces collapsed; nothing else changes.
# Applied to AI answers at generation (07). The frozen human answer files are not changed; the same
# function is applied to human answers when the surveys are built (B16).
normalize_typography <- function(x) {
  x <- str_replace_all(x, "[‘’]", "'")
  x <- str_replace_all(x, "[“”]", "\"")
  x <- str_replace_all(x, "[–—]", " - ")
  str_replace_all(x, " {2,}", " ")
}

has_list <- function(raw_html, text) {
  coalesce(str_detect(raw_html, "(?i)<(?:ul|ol|li)\\b"), FALSE) | coalesce(str_detect(text, LIST_TEXT_PATTERN), FALSE)
}
