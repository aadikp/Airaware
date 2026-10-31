air <- read.csv("data/processed/air_quality_combined_raw.csv")

missing_values <- colSums(is.na(air))
duplicate_records <- sum(duplicated(air[c("station", "year", "month", "day", "hour")]))

dir.create("outputs/results", showWarnings = FALSE, recursive = TRUE)
write.csv(as.data.frame(missing_values), "outputs/results/missing_values_summary.csv")
