test_that("scenario labels split only on ';' and keep commas inside names", {
  x <- c("Career Decision-Making, Transitioning, and Exploration Resources; College Queries",
         "Barriers, Equity, and Resource Considerations", "", NA, "College Queries;  ; College Queries")
  p <- parse_scenario_labels(x)
  expect_equal(p[[1]], c("Career Decision-Making, Transitioning, and Exploration Resources", "College Queries"))
  expect_equal(p[[2]], "Barriers, Equity, and Resource Considerations")
  expect_equal(p[[3]], character())
  expect_equal(p[[4]], character())
  expect_equal(p[[5]], "College Queries")

  ind <- scenario_label_indicators(p, CFG$scenario_labels)
  expect_equal(ncol(ind), 18)
  expect_equal(ind$label_career_decision_making_transitioning_and_exploration_resources, c(1L, 0L, 0L, 0L, 0L))
  expect_equal(ind$label_college_queries, c(1L, 0L, 0L, 0L, 1L))
  expect_error(scenario_label_indicators(list("Not A Label"), CFG$scenario_labels), "Unknown scenario label")
})

test_that("soc_code handles repeated hierarchy entries, several occupations and flags", {
  two_occ <- paste(
    "29-0000 Healthcare Practitioners and Technical Occupations; 29-1000 Healthcare Diagnosing or Treating Practitioners;",
    "29-1210 Physicians; 29-1211 Anesthesiologists; 29-0000 Healthcare Practitioners and Technical Occupations;",
    "29-1000 Healthcare Diagnosing or Treating Practitioners; 29-1210 Physicians; 29-1212 Cardiologists;",
    "27-0000 Arts, Design, Entertainment, Sports, and Media Occupations; 27-3000 Media and Communication Workers;",
    "27-3020 News Analysts, Reporters and Journalists; 27-3023 News Analysts, Reporters, and Journalists")
  s <- parse_soc(c(two_occ, "No career mentioned in question",
                   "Career in question not aligned with a label; 15-0000 Computer and Mathematical Occupations; 15-1200 Computer Occupations; 15-1250 Software and Web Developers, Programmers, and Testers; 15-1252 Software Developers",
                   NA))
  expect_equal(s$soc_major_groups[1],
               "Healthcare Practitioners and Technical Occupations; Arts, Design, Entertainment, Sports, and Media Occupations")
  expect_equal(s$n_soc_major_groups, c(2L, 0L, 1L, 0L))
  expect_equal(s$soc_detailed_codes[1],
               "29-1211 Anesthesiologists; 29-1212 Cardiologists; 27-3023 News Analysts, Reporters, and Journalists")
  expect_equal(s$soc_flag, c(NA, "no_career_mentioned", "not_aligned", NA))
  expect_true(is.na(s$soc_major_groups[2]))
  expect_equal(s$soc_detailed_codes[3], "15-1252 Software Developers")
  expect_error(parse_soc("garbage entry"), "Unrecognized soc_code")
})

test_that("multi-label reasoning strings split on ';'", {
  r <- parse_reasoning(c("Predictive Causal Reasoning/Interventional Reasoning; Necessary Conditions",
                         "No reasoning - explanation only", "", NA))
  expect_equal(r[[1]], c("Predictive Causal Reasoning/Interventional Reasoning", "Necessary Conditions"))
  expect_equal(lengths(r), c(2L, 1L, 0L, 0L))
  expect_warning(parse_reasoning("Made-up Reasoning"), "Unknown reasoning label")
})

test_that("clean_text decodes entities, keeps paragraph breaks and removes URLs", {
  html <- "<p>Hi &amp; welcome!</p><p>See https://example.com/a?b=1 or www.site.org for more.</p>Line<br>break &lt;3"
  out <- clean_text(html)
  expect_equal(out, "Hi & welcome!\n\nSee or for more.\n\nLine\nbreak <3")
  expect_equal(clean_text(c(NA, "plain text")), c(NA, "plain text"))
  expect_equal(clean_text("<ul><li>one</li><li>two</li></ul>"), "- one\n- two")
  expect_equal(clean_text("Visit (https://x.org) now"), "Visit now")
})

test_that("word counts strip tags then split on whitespace", {
  expect_equal(count_words(c("<p>one two</p><p>three</p>", "", NA, "a\n\nb\tc")), c(3L, 0L, 0L, 3L))
})

test_that("ratings and dates parse", {
  expect_equal(rating_num(c("4 - Fully Correct", "1 - Very Incomplete", NA), "x"), c(4L, 1L, NA))
  expect_error(rating_num("Excellent", "x"), "unrecognized rating")
  d <- parse_careernet_date(c("October 18, 2011, 5:39 PM", NA), "x")
  expect_equal(format(d[1], "%Y-%m-%d %H:%M"), "2011-10-18 17:39")
  expect_error(parse_careernet_date("18/10/2011", "x"), "unparseable")
})

test_that("derived seeds are stable and distinct per stage", {
  expect_equal(derive_seed(1, "a"), derive_seed(1, "a"))
  expect_false(derive_seed(1, "a") == derive_seed(1, "b"))
  expect_false(derive_seed(1, "study_draw") == derive_seed(1, "study_draw_DRY_RUN"))
  expect_true(derive_seed(20261027, "x") < .Machine$integer.max)
})
