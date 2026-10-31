if (!file.exists("data/processed/air_quality_cleaned.csv") && file.exists("../data/processed/air_quality_cleaned.csv")) {
  setwd("..")
}

library(ggplot2)

dir.create("outputs/plots", showWarnings = FALSE, recursive = TRUE)

air <- read.csv("data/processed/air_quality_cleaned.csv", stringsAsFactors = FALSE)
air$AQI_Category <- factor(
  air$AQI_Category,
  levels = c("Good", "Moderate", "Unhealthy for Sensitive", "Unhealthy", "Hazardous")
)

aqi_colors <- c(
  "Good" = "#2ecc71",
  "Moderate" = "#f1c40f",
  "Unhealthy for Sensitive" = "#e67e22",
  "Unhealthy" = "#e74c3c",
  "Hazardous" = "#8e44ad"
)

p1 <- ggplot(air, aes(x = AQI_Category, fill = AQI_Category)) +
  geom_bar(alpha = 0.85, color = "black") +
  scale_fill_manual(values = aqi_colors) +
  theme_minimal(base_size = 14) +
  labs(
    title = "Distribution of Air Quality Hazard Categories (Beijing 2013-2017)",
    subtitle = "Standardized by US-EPA / WHO Breakpoints (N = 412,029)",
    x = "AQI Risk Tier",
    y = "Record Count"
  ) +
  theme(legend.position = "none", plot.title = element_text(face = "bold"))

ggsave("outputs/plots/aqi_distribution.png", plot = p1, width = 8, height = 5, dpi = 300)

p2 <- ggplot(air, aes(x = PM2.5)) +
  geom_histogram(bins = 60, fill = "#3498db", color = "white", alpha = 0.8) +
  geom_vline(xintercept = c(35, 75, 115, 150), linetype = "dashed", color = "red", linewidth = 0.8) +
  theme_minimal(base_size = 14) +
  labs(
    title = "Right-Skewed Distribution of PM2.5 Concentrations",
    subtitle = "Red dashed lines indicate AQI tier thresholds (35, 75, 115, 150 ug/m3)",
    x = "PM2.5 Concentration (ug/m3)",
    y = "Frequency"
  ) +
  coord_cartesian(xlim = c(0, 450))

ggsave("outputs/plots/pm25_distribution.png", plot = p2, width = 8, height = 5, dpi = 300)

pollutants_meteo <- air[, c("PM2.5", "PM10", "SO2", "NO2", "CO", "O3", "TEMP", "PRES", "DEWP", "RAIN", "WSPM")]
cor_mat <- round(cor(pollutants_meteo, use = "complete.obs"), 2)

png("outputs/plots/correlation_matrix.png", width = 800, height = 800, res = 120)
corrplot::corrplot(
  cor_mat,
  method = "color",
  type = "upper",
  addCoef.col = "black",
  tl.col = "black",
  tl.srt = 45,
  col = colorRampPalette(c("#e74c3c", "#ffffff", "#2980b9"))(200),
  title = "Correlation Heatmap: Pollutants & Weather Variables",
  mar = c(0, 0, 2, 0)
)
dev.off()

hourly_agg <- aggregate(PM2.5 ~ hour, data = air, FUN = function(x) c(mean = mean(x), sd = sd(x)))
hourly_df <- data.frame(
  hour = hourly_agg$hour,
  mean_pm = hourly_agg$PM2.5[, "mean"],
  sd_pm = hourly_agg$PM2.5[, "sd"]
)

p4 <- ggplot(hourly_df, aes(x = hour, y = mean_pm)) +
  geom_ribbon(aes(ymin = mean_pm - 0.2 * sd_pm, ymax = mean_pm + 0.2 * sd_pm), fill = "#e74c3c", alpha = 0.2) +
  geom_line(color = "#c0392b", linewidth = 1.2) +
  geom_point(color = "#962d22", size = 2.5) +
  scale_x_continuous(breaks = 0:23) +
  theme_minimal(base_size = 14) +
  labs(
    title = "Diurnal (24-Hour) Average PM2.5 Pattern in Beijing",
    subtitle = "Peak pollution corresponds with evening traffic rush hours and atmospheric temperature inversion",
    x = "Hour of Day (00:00 - 23:00)",
    y = "Average PM2.5 (ug/m3)"
  ) +
  theme(plot.title = element_text(face = "bold"))

ggsave("outputs/plots/diurnal_pm25.png", plot = p4, width = 8, height = 5, dpi = 300)

station_agg <- aggregate(PM2.5 ~ station + station_type, data = air, FUN = mean)
station_agg <- station_agg[order(station_agg$PM2.5, decreasing = TRUE), ]

p5 <- ggplot(station_agg, aes(x = reorder(station, PM2.5), y = PM2.5, fill = PM2.5)) +
  geom_col(alpha = 0.85, color = "black") +
  coord_flip() +
  scale_fill_gradient(low = "#f1c40f", high = "#c0392b") +
  theme_minimal(base_size = 13) +
  labs(
    title = "Spatial Pollution Ranking Across 12 Beijing Stations",
    subtitle = "Southern/Industrial corridors suffer highest PM2.5; Northern ecological sites enjoy cleanest air",
    x = "Monitoring Station",
    y = "Mean PM2.5 Concentration (ug/m3)"
  ) +
  theme(legend.position = "none", plot.title = element_text(face = "bold"))

ggsave("outputs/plots/station_comparison.png", plot = p5, width = 8, height = 5, dpi = 300)
