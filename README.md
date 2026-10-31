# AirAware : Air Quality Hazard Classification & Spatial-Temporal Mining

[![R](https://img.shields.io/badge/Language-R%20%3E%3D%204.0-blue.svg)](https://www.r-project.org/)
[![Shiny](https://img.shields.io/badge/Framework-R%20Shiny-3498db.svg)](https://shiny.posit.co/)
[![Leaflet](https://img.shields.io/badge/Geospatial-Leaflet-green.svg)](https://rstudio.github.io/leaflet/)
[![Plotly](https://img.shields.io/badge/Interactive%20Plots-Plotly-orange.svg)](https://plotly.com/r/)
[![License](https://img.shields.io/badge/License-MIT-lightgrey.svg)](LICENSE)

An end-to-end atmospheric Data Mining and real-time predictive intelligence platform developed entirely in **R**. AirAware transforms over 420,000 multi-site hourly meteorological and chemical observations into standardized Air Quality Index (AQI) hazard classifications, benchmarks supervised machine learning algorithms, and deploys an interactive 4-tab web application for public health risk assessment.


## Project Overview & Problem Statement

Fine particulate matter ($PM_{2.5}$) poses severe cardiopulmonary and respiratory risks in urban centers. While monitoring stations capture continuous chemical concentrations ($CO, NO_2, SO_2, O_3, PM_{10}$), raw environmental data exhibits missing observations, sensor noise, non-linear atmospheric dynamics, and extreme diurnal volatility.

Traditional continuous regression models estimate single numeric concentrations but do not provide actionable risk tiers required by public health authorities to trigger emergency smog protocols, traffic restrictions, or school advisories.

**AirAware addresses this challenge by:**
1. Cleaning and structuring 412,029 historical hourly measurements across 12 Beijing monitoring stations.
2. Discretizing continuous concentrations into 5 standardized international AQI Hazard Tiers.
3. Benchmarking supervised classification algorithms (**Decision Tree** vs. **Random Forest**) on multi-class accuracy, precision, recall, and F1-score.
4. Extracting atmospheric feature importance (Mean Decrease Gini) to identify primary smog precursors.
5. Deploying a reactive, multi-tab **R Shiny Dashboard** with Leaflet geospatial tracking and a real-time "What-If" meteorological simulator.

---

## Dataset Description

- **Source:** [UCI Machine Learning Repository — Beijing Multi-Site Air Quality Dataset](https://archive.ics.uci.edu/dataset/501/beijing+multi+site+air+quality+data)
- **Period:** March 1, 2013 to February 28, 2017 (Hourly readings)
- **Scale:** 12 Nationally Controlled Monitoring Stations (Aotizhongxin, Changping, Dingling, Dongsi, Guanyuan, Gucheng, Huairou, Nongzhanguan, Shunyi, Tiantan, Wanliu, Wanshouxigong)
- **Total Records:** 420,768 raw observations $\rightarrow$ **412,029 clean observations** (after removing missing target entries)
- **Variables (23 features):**
  - **Target:** $PM_{2.5}$ mapped to categorical `AQI_Category`
  - **Co-pollutants:** $PM_{10}, SO_2, NO_2, CO, O_3$
  - **Meteorological:** Temperature (`TEMP`), Atmospheric Pressure (`PRES`), Dew Point (`DEWP`), Rainfall (`RAIN`), Wind Speed (`WSPM`), Wind Direction (`wd`)
  - **Spatial:** `station`, `latitude`, `longitude`, `station_type`
  - **Temporal:** `year`, `month`, `day`, `hour`, `date`

### AQI Hazard Classification Thresholds

Standardized according to WHO / US-EPA breakpoints:
- **Good (0 – 35 $\mu g/m^3$):** 37.34% of observations
- **Moderate (35 – 75 $\mu g/m^3$):** 23.58% of observations
- **Unhealthy for Sensitive Groups (75 – 115 $\mu g/m^3$):** 15.48% of observations
- **Unhealthy (115 – 150 $\mu g/m^3$):** 8.39% of observations
- **Hazardous (> 150 $\mu g/m^3$):** 15.21% of observations

---

## Data Mining Methodology & Results

Models were trained on records from 2013–2016 ($N = 395,301$) and evaluated on the independent 2017 benchmark test dataset ($N = 16,728$):

### Model Evaluation Benchmark

| Metric | Algorithm 1: Decision Tree (`rpart`) | Algorithm 2: Random Forest (`randomForest`) |
| :--- | :---: | :---: |
| **Overall Accuracy** | 69.62% | **73.24%** (+3.62%) |
| **Macro Precision** | 0.4675 | **0.5660** (+0.0985) |
| **Macro Recall** | 0.4960 | **0.5445** (+0.0485) |
| **Macro F1-Score** | 0.4811 | **0.5468** (+0.0657) |
| **Training Time** | 11.12 seconds | 28.07 seconds |

### Random Forest Per-Class Performance

- **Good Air Quality (0 – 35 $\mu g/m^3$):** Precision = **86.58%** | Recall = **94.81%** | F1 = **0.9051**
- **Moderate (35 – 75 $\mu g/m^3$):** Precision = **45.42%** | Recall = **54.32%** | F1 = **0.4948**
- **Unhealthy for Sensitive (75 – 115 $\mu g/m^3$):** Precision = **41.27%** | Recall = **31.81%** | F1 = **0.3593**
- **Unhealthy (115 – 150 $\mu g/m^3$):** Precision = **27.29%** | Recall = **11.91%** | F1 = **0.1658**
- **Hazardous Episodes (> 150 $\mu g/m^3$):** Precision = **82.44%** | Recall = **79.43%** | F1 = **0.8090**

### Confusion Matrix (Random Forest — 2017 Test Dataset)

```
Actual \ Predicted         Good   Moderate   Sensitive   Unhealthy   Hazardous
Good                      7,305        351          25           2          22
Moderate                    803      1,250         201          24          23
Unhealthy for Sensitive     163        807         612         137         205
Unhealthy                    46        162         359         128         380
Hazardous                   120        182         286         178       2,957
```

### Top Atmospheric Predictors (Mean Decrease Gini)

1. **Carbon Monoxide (CO):** Primary indicator of incomplete fossil fuel and vehicular combustion.
2. **Nitrogen Dioxide (NO2):** Marker for high-density traffic emissions.
3. **Dew Point (DEWP):** Elevated humidity accelerates secondary particulate hygroscopic growth.
4. **Sulfur Dioxide (SO2):** Regional coal-burning and industrial emission precursor.
5. **Monitoring Station Location:** Captures spatial disparity between industrial corridors and northern ecological zones.

---

## User Interface Design

The interactive web application is built in `app/app.R` with a modern 4-tab architecture:

1. **Geospatial Real-Time Command Map (`leaflet`):**
   - Renders all 12 monitoring stations across Beijing at exact geodetic coordinates.
   - Dynamic pulsing circle markers colored by AQI status (🟢 Good, 🟡 Moderate, 🟠 Sensitive, 🔴 Unhealthy, 🟣 Hazardous).
   - Click popups with multi-pollutant and weather metrics.
   - Citywide KPI summary cards (Mean PM2.5, Dominant Status, Cleanest Station, Highest Pollution Site).

2. **Exploratory Mining & Trends (`plotly`):**
   - Interactive Pearson correlation heatmap between all pollutants and meteorological factors.
   - 24-hour diurnal cycle curve capturing rush-hour traffic peaks and nocturnal thermal inversions.
   - Spatial station ranking comparing southern industrial corridors with northern background sites.

3. **Interactive Scenario Simulator:**
   - Sliders for Temperature, Wind Speed, Pressure, Dew Point, $CO, NO_2, SO_2$, and $O_3$.
   - Live **Random Forest Classification Badge** with official health advisory guidance.
   - Continuous Linear Regression prediction.
   - Horizontal probability distribution chart across all 5 hazard categories.

4. **Model Benchmark & Evaluation Arena:**
   - Live comparison table of Accuracy, Precision, Recall, and F1-score.
   - Random Forest Feature Importance chart.
   - 5×5 multi-class Confusion Matrix table.

---

## Project Structure

```
AirAware/
├── app/
│   └── app.R                           # 4-Tab Interactive R Shiny Dashboard
├── data/
│   ├── raw/                            # 12 raw station CSV files (UCI Repository)
│   └── processed/
│       ├── air_quality_combined_raw.csv# Combined multi-site dataset
│       └── air_quality_cleaned.csv     # Cleaned 412K records with AQI categories
├── R/
│   ├── 01_import_inspect.R             # Multi-file import and schema verification
│   ├── 02_data_quality.R               # Missingness and duplicate record analysis
│   ├── 03_clean_data.R                 # Median imputation, AQI categorization, Geocoding
│   ├── 04_eda.R                        # ggplot2 figures and correlation matrix
│   └── 05_models.R                     # Decision Tree & Random Forest training & evaluation
├── outputs/
│   ├── plots/                          # Generated high-resolution visualizations
│   │   ├── aqi_distribution.png
│   │   ├── correlation_matrix.png
│   │   ├── diurnal_pm25.png
│   │   ├── pm25_distribution.png
│   │   └── station_comparison.png
│   └── results/                        # Saved models (.rds) and evaluation tables (.csv)
│       ├── classification_metrics.csv
│       ├── classifier_rf.rds
│       ├── classifier_tree.rds
│       ├── confusion_matrix_rf.csv
│       ├── linear_model.rds
│       └── rf_feature_importance.csv
├── .gitignore                          # Git ignore configuration
├── AirAware.Rproj                      # RStudio Project file
└── README.md                           # Documentation
```

---

## Getting Started & Installation

### Prerequisites

Ensure you have **R (version 4.0 or higher)** installed. Install the required R packages:

```R
install.packages(c(
  "shiny",
  "leaflet",
  "plotly",
  "randomForest",
  "rpart",
  "ggplot2",
  "corrplot"
))
```

### Running the Interactive Shiny Dashboard

1. Clone the repository:
   ```bash
   git clone https://github.com/aadikp/Airaware.git
   cd Airaware
   ```

2. Launch the Shiny application in R or RStudio:
   ```R
   shiny::runApp("app")
   ```
   The dashboard will start and open automatically at `http://127.0.0.1:7777`.

### Executing the Data Mining Pipeline from Source

To re-run the entire pipeline from raw data to trained models:

```bash
# 1. Inspect raw records
Rscript R/01_import_inspect.R

# 2. Quality check
Rscript R/02_data_quality.R

# 3. Clean, impute, categorize, and geocode
Rscript R/03_clean_data.R

# 4. Generate EDA visualizations
Rscript R/04_eda.R

# 5. Train and evaluate models
Rscript R/05_models.R
```

---
