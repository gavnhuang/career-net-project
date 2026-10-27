# soc_code: ";"-separated "CODE Title" entries listing the full SOC hierarchy for each
# occupation (so entries repeat), plus optional flags. Titles contain commas.

SOC_FLAGS <- c("No career mentioned in question" = "no_career_mentioned",
               "Career in question not aligned with a label" = "not_aligned")

# Returns one row per input: soc_flag, soc_major_groups, n_soc_major_groups, soc_detailed_codes.
parse_soc <- function(x) {
  purrr::map_dfr(x, parse_soc_one)
}

parse_soc_one <- function(s) {
  empty <- tibble::tibble(soc_flag = NA_character_, soc_major_groups = NA_character_,
                          n_soc_major_groups = 0L, soc_detailed_codes = NA_character_)
  if (is_missing(s)) return(empty)
  e <- str_trim(str_split_1(s, fixed(";")))
  e <- e[e != ""]

  flags <- unname(SOC_FLAGS[intersect(names(SOC_FLAGS), e)])
  entries <- e[!e %in% names(SOC_FLAGS)]
  ok <- str_detect(entries, "^\\d{2}-\\d{4}\\s+\\S")
  if (!all(ok)) stop("Unrecognized soc_code entr(y/ies): ", paste(entries[!ok], collapse = " | "), call. = FALSE)

  code <- str_extract(entries, "^\\d{2}-\\d{4}")
  title <- str_trim(str_remove(entries, "^\\d{2}-\\d{4}"))
  is_major <- str_ends(code, "-0000")
  is_detailed <- str_detect(code, "[1-9]$")
  majors <- title[is_major][!duplicated(code[is_major])]
  detailed <- paste(code, title)[is_detailed][!duplicated(code[is_detailed])]

  tibble::tibble(
    soc_flag = if (length(flags)) paste(flags, collapse = "; ") else NA_character_,
    soc_major_groups = if (length(majors)) paste(majors, collapse = "; ") else NA_character_,
    n_soc_major_groups = length(majors),
    soc_detailed_codes = if (length(detailed)) paste(detailed, collapse = "; ") else NA_character_
  )
}
