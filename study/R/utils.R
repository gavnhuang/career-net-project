# Small shared helpers: missing values, word counts, ids, seeds, markdown.

`%||%` <- function(x, y) if (is.null(x)) y else x

# CareerNet v1.0 wrote missing values as the text "NA"; v1.1 writes "".
MISSING_STRINGS <- c("", "NA")

is_missing <- function(x) is.na(x) | x %in% MISSING_STRINGS

normalize_missing <- function(x) {
  x[is_missing(x)] <- NA_character_
  x
}

# Word count rule: strip HTML tags, then split on whitespace.
count_words <- function(x) {
  x <- str_trim(str_replace_all(coalesce(x, ""), "<[^>]*>", " "))
  ifelse(x == "", 0L, lengths(str_split(x, "\\s+")))
}

to_integer <- function(x, name) {
  y <- suppressWarnings(as.integer(x))
  bad <- !is.na(x) & is.na(y)
  if (any(bad)) stop(name, ": ", sum(bad), " non-integer value(s), e.g. '", x[bad][1], "'", call. = FALSE)
  y
}

# Dates look like "October 18, 2011, 5:39 PM". Parsed as UTC (the release states no time zone).
parse_careernet_date <- function(x, name) {
  y <- lubridate::mdy_hm(x, tz = "UTC", quiet = TRUE)
  bad <- !is.na(x) & is.na(y)
  if (any(bad)) stop(name, ": ", sum(bad), " unparseable date(s), e.g. '", x[bad][1], "'", call. = FALSE)
  y
}

# Ids sort numerically when they are all digits, otherwise in C-locale order,
# so every random step starts from the same canonical order on any machine.
id_key <- function(x) if (all(grepl("^[0-9]+$", x[!is.na(x)]))) as.numeric(x) else x

canonical_ids <- function(x) {
  x <- unique(x)
  x[order(id_key(x), method = "radix")]
}

snake_case <- function(x) {
  x <- str_replace_all(str_to_lower(x), "[^a-z0-9]+", "_")
  str_remove_all(x, "^_+|_+$")
}

# ---- Seeds -------------------------------------------------------------------

# A stage seed is the first 7 hex digits of md5("<master_seed>:<stage>").
derive_seed <- function(master_seed, stage) {
  h <- digest::digest(paste(master_seed, stage, sep = ":"), algo = "md5", serialize = FALSE)
  strtoi(substr(h, 1, 7), base = 16L)
}

# The real study draw's master seed: first 7 hex digits of md5 of the OSF DOI string, exactly
# as written in the config (no case or whitespace normalization).
doi_seed <- function(doi) {
  if (!is.character(doi) || length(doi) != 1 || is.na(doi) || !nzchar(doi)) stop("doi_seed() needs a non-empty DOI", call. = FALSE)
  strtoi(substr(digest::digest(doi, algo = "md5", serialize = FALSE), 1, 7), base = 16L)
}

# Evaluate `expr` under a fixed seed and the study RNG kinds, then restore the
# caller's RNG state, so sampling functions have no side effect on global RNG.
with_seed <- function(seed, expr) {
  genv <- globalenv()
  had_seed <- exists(".Random.seed", envir = genv, inherits = FALSE)
  old_seed <- if (had_seed) get(".Random.seed", envir = genv)
  old_kind <- RNGkind()
  on.exit({
    do.call(RNGkind, as.list(old_kind))
    if (had_seed) assign(".Random.seed", old_seed, envir = genv)
    else if (exists(".Random.seed", envir = genv, inherits = FALSE)) rm(".Random.seed", envir = genv)
  }, add = TRUE)
  RNGkind("Mersenne-Twister", "Inversion", "Rejection")
  set.seed(seed)
  expr
}

# Sample k elements of x without replacement. Safe when length(x) == 1
# (base sample() would treat a single number n as 1:n).
sample_k <- function(x, k) x[sample.int(length(x), k)]

# ---- Markdown ----------------------------------------------------------------

md_table <- function(df) {
  if (nrow(df) == 0) return("_(none)_")
  cells <- lapply(df, function(col) {
    col <- if (is.numeric(col)) format(col, trim = TRUE, big.mark = ",", scientific = FALSE) else as.character(col)
    col[is.na(col) | col == "NA"] <- ""
    str_replace_all(col, fixed("|"), "\\|")
  })
  header <- paste0("| ", paste(names(df), collapse = " | "), " |")
  sep <- paste0("|", paste(rep("---", ncol(df)), collapse = "|"), "|")
  rows <- do.call(paste, c(cells, sep = " | "))
  c(header, sep, paste0("| ", rows, " |"))
}

fmt_pct <- function(x, digits = 1) ifelse(is.na(x), NA_character_, sprintf(paste0("%.", digits, "f%%"), 100 * x))
