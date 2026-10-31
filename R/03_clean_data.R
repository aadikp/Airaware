if (!file.exists("data/processed/air_quality_combined_raw.csv") && file.exists("../data/processed/air_quality_combined_raw.csv")) {
  setwd("..")
}

raw_path <- "data/processed/air_quality_combined_raw.csv"
if (!file.exists(raw_path)) {
  stop("Raw dataset not found at: ", raw_path)
}

air <- read.csv(raw_path, stringsAsFactors = FALSE)
air <- air[!is.na(air$PM2.5), ]
air$wd[is.na(air$wd) | air$wd == ""] <- "Unknown"

numeric_columns <- setdiff(names(air)[sapply(air, is.numeric)], c("No", "year", "month", "day", "hour"))
for (col in numeric_columns) {
  air[[col]][is.na(air[[col]])] <- median(air[[col]], na.rm = TRUE)
}

if ("No" %in% names(air)) {
  air$No <- NULL
}

air$AQI_Category <- cut(
  air$PM2.5,
  breaks = c(-Inf, 35, 75, 115, 150, Inf),
  labels = c("Good", "Moderate", "Unhealthy for Sensitive", "Unhealthy", "Hazardous"),
  right = TRUE
)

station_coords <- data.frame(
  station = c(
    "Aotizhongxin", "Changping", "Dingling", "Dongsi",
    "Guanyuan", "Gucheng", "Huairou", "Nongzhanguan",
    "Shunyi", "Tiantan", "Wanliu", "Wanshouxigong"
  ),
  latitude = c(
    39.982, 40.218, 40.292, 39.929,
    39.929, 39.914, 40.328, 39.937,
    40.127, 39.886, 39.987, 39.878
  ),
  longitude = c(
    116.397, 116.230, 116.220, 116.417,
    116.339, 116.184, 116.628, 116.461,
    116.655, 116.407, 116.287, 116.352
  ),
  station_type = c(
    "Urban Commercial", "Suburban North", "Ecological Background", "Urban Core",
    "Urban Core", "Industrial Southwest", "Suburban Mountain", "Diplomatic / East Core",
    "Suburban Northeast", "Cultural Park", "Urban Educational", "Urban South"
  ),
  stringsAsFactors = FALSE
)

air <- merge(air, station_coords, by = "station", all.x = TRUE)
air$date <- as.Date(sprintf("%04d-%02d-%02d", air$year, air$month, air$day))
air <- air[order(air$station, air$date, air$hour), ]

dir.create("data/processed", showWarnings = FALSE, recursive = TRUE)
dir.create("outputs/results", showWarnings = FALSE, recursive = TRUE)

write.csv(air, "data/processed/air_quality_cleaned.csv", row.names = FALSE)
write.csv(station_coords, "outputs/results/station_coords.csv", row.names = FALSE)

summary_stats <- data.frame(
  Total_Observations = nrow(air),
  Total_Variables = ncol(air),
  Missing_Values_Remaining = sum(is.na(air)),
  Good_AQI_Pct = round(mean(air$AQI_Category == "Good") * 100, 2),
  Moderate_AQI_Pct = round(mean(air$AQI_Category == "Moderate") * 100, 2),
  Unhealthy_Sensitive_Pct = round(mean(air$AQI_Category == "Unhealthy for Sensitive") * 100, 2),
  Unhealthy_Pct = round(mean(air$AQI_Category == "Unhealthy") * 100, 2),
  Hazardous_Pct = round(mean(air$AQI_Category == "Hazardous") * 100, 2)
)

write.csv(summary_stats, "outputs/results/cleaned_data_summary.csv", row.names = FALSE)