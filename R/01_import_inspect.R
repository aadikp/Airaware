files <- list.files("data/raw", pattern = "\\.csv$", full.names = TRUE)

air_list <- lapply(files, function(file) {
  read.csv(file, stringsAsFactors = FALSE, na.strings = c("NA", ""))
})

air <- do.call(rbind, air_list)
rownames(air) <- NULL

dir.create("data/processed", showWarnings = FALSE, recursive = TRUE)
write.csv(air, "data/processed/air_quality_combined_raw.csv", row.names = FALSE)
