# Freeze AI answer generation after the pilot (B02 step 7). From the project root:
#   Rscript study/scripts/freeze_generation.R
# Records the prompt's md5 and sets generation_frozen: true in the config. From then on 07
# refuses to run if the prompt file changes. Commit the config, prompt and code right after.
source("study/scripts/_common.R")
run <- start_run("freeze-gen")
g <- generation_settings(run$cfg)
if (g$generation_frozen) stop("Generation is already frozen (prompt md5 ", g$frozen_prompt_md5, ")", call. = FALSE)
lines <- readLines(run$config_path, encoding = "UTF-8", warn = FALSE)
i_frozen <- grep("^  generation_frozen:", lines)
i_md5 <- grep("^  frozen_prompt_md5:", lines)
if (length(i_frozen) != 1 || length(i_md5) != 1) stop("Could not find the generation freeze lines in the config", call. = FALSE)
lines[i_frozen] <- "  generation_frozen: true"
lines[i_md5] <- paste0('  frozen_prompt_md5: "', g$prompt_md5, '"')
lines <- append(lines, paste0('  frozen_at: "', format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"), '"'), after = i_md5)
writeLines(lines, run$config_path, useBytes = TRUE)
message("Generation frozen. Model ", g$model, ", reasoning ", g$reasoning_effort, ", prompt md5 ", g$prompt_md5,
        "\nNow commit study/config/study_config.yml, ", g$prompt_file, ", study/R/generation.R and study/scripts/07_generate_answers.R.")
