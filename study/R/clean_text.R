# HTML -> plain text: decode entities, keep paragraph breaks, remove URLs.

# A URL stops at whitespace or brackets and does not swallow trailing punctuation.
URL_PATTERN <- "(?i)\\b(?:(?:https?|ftp)://|www\\.)(?:[^\\s<>\"()\\[\\]]*[^\\s<>\"()\\[\\].,;:!?'])?"

clean_text <- function(html) {
  vapply(html, clean_one_html, character(1), USE.NAMES = FALSE)
}

clean_one_html <- function(x) {
  if (is.na(x)) return(NA_character_)
  # Turn block-level tags into line breaks before the parser drops them.
  x <- str_replace_all(x, regex("<br\\s*/?>", ignore_case = TRUE), "\n")
  x <- str_replace_all(x, regex("</?(p|div|ul|ol|h[1-6]|blockquote|pre|table|tr)\\b[^>]*>", ignore_case = TRUE), "\n\n")
  x <- str_replace_all(x, regex("<li\\b[^>]*>", ignore_case = TRUE), "\n- ")
  doc <- xml2::read_html(paste0("<html><head><meta charset='utf-8'></head><body>", x, "</body></html>"),
                         encoding = "UTF-8")
  txt <- xml2::xml_text(xml2::xml_find_first(doc, "//body"))
  if (is.na(txt)) txt <- ""
  normalize_whitespace(remove_urls(txt))
}

remove_urls <- function(x) {
  x <- str_replace_all(x, URL_PATTERN, "")
  str_replace_all(x, "\\(\\s*\\)|\\[\\s*\\]|<\\s*>", "")
}

normalize_whitespace <- function(x) {
  x <- str_replace_all(x, " ", " ")
  x <- str_replace_all(x, "\r\n?", "\n")
  x <- str_replace_all(x, "[ \t\f\v]+", " ")
  x <- str_replace_all(x, " *\n *", "\n")
  x <- str_replace_all(x, "\n{3,}", "\n\n")
  str_trim(x)
}
