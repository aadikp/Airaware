library(shiny)
library(leaflet)
library(plotly)
library(rpart)
library(randomForest)

if (!file.exists("data/processed/air_quality_cleaned.csv") && file.exists("../data/processed/air_quality_cleaned.csv")) {
  setwd("..")
}

air <- read.csv("data/processed/air_quality_cleaned.csv", stringsAsFactors = FALSE)
air$AQI_Category <- factor(
  air$AQI_Category,
  levels = c("Good", "Moderate", "Unhealthy for Sensitive", "Unhealthy", "Hazardous")
)
air$date <- as.Date(sprintf("%04d-%02d-%02d", air$year, air$month, air$day))
air$station <- as.factor(air$station)
air$wd <- as.factor(air$wd)

station_coords <- read.csv("outputs/results/station_coords.csv", stringsAsFactors = FALSE)
model_tree     <- readRDS("outputs/results/classifier_tree.rds")
model_rf       <- readRDS("outputs/results/classifier_rf.rds")
model_lm       <- readRDS("outputs/results/linear_model.rds")
class_metrics  <- read.csv("outputs/results/classification_metrics.csv", stringsAsFactors = FALSE)
rf_importance  <- read.csv("outputs/results/rf_feature_importance.csv", stringsAsFactors = FALSE)
cm_rf          <- read.csv("outputs/results/confusion_matrix_rf.csv", row.names = 1, check.names = FALSE)

aqi_colors <- c(
  "Good" = "#2ecc71",
  "Moderate" = "#f1c40f",
  "Unhealthy for Sensitive" = "#e67e22",
  "Unhealthy" = "#e74c3c",
  "Hazardous" = "#8e44ad"
)

ui <- navbarPage(
  title = div(
    span(style = "font-weight: 800; font-size: 20px; color: #2c3e50;", "AirAware 2.0"),
    span(style = "font-size: 13px; color: #7f8c8d; margin-left: 8px;", "Data Mining & Air Quality Intelligence")
  ),
  id = "main_nav",
  windowTitle = "AirAware 2.0 - Beijing Air Quality Mining",
  
  header = tags$head(
    tags$style(HTML("
      body { font-family: 'Segoe UI', -apple-system, BlinkMacSystemFont, Roboto, sans-serif; background-color: #f8f9fa; }
      .navbar { background-color: #ffffff; border-bottom: 2px solid #e9ecef; box-shadow: 0 2px 4px rgba(0,0,0,0.04); }
      .navbar-default .navbar-nav > .active > a { background-color: #3498db !important; color: white !important; border-radius: 4px; font-weight: 600; }
      .card-kpi { background: white; border-radius: 8px; padding: 16px; margin-bottom: 16px; box-shadow: 0 1px 3px rgba(0,0,0,0.08); border-left: 5px solid #3498db; }
      .card-kpi h4 { margin: 0 0 6px 0; font-size: 12px; text-transform: uppercase; letter-spacing: 0.5px; color: #7f8c8d; font-weight: 700; }
      .card-kpi .val { font-size: 26px; font-weight: 800; color: #2c3e50; }
      .card-box { background: white; border-radius: 8px; padding: 18px; margin-bottom: 20px; box-shadow: 0 1px 4px rgba(0,0,0,0.08); }
      .badge-aqi { padding: 8px 16px; border-radius: 6px; font-weight: 700; color: white; display: inline-block; font-size: 16px; letter-spacing: 0.3px; }
      .well { background-color: #ffffff; border: 1px solid #e2e8f0; border-radius: 8px; box-shadow: 0 1px 3px rgba(0,0,0,0.05); }
      .table > thead > tr > th { background-color: #f1f5f9; color: #334155; font-weight: 700; }
    "))
  ),
  
  tabPanel(
    title = tagList(icon("map-marker-alt", verify_fa = FALSE), " Geospatial Map"),
    fluidRow(
      column(
        width = 3,
        div(
          class = "well",
          h4(style = "font-weight: 700; color: #2c3e50; margin-top: 0;", "Station & Time Controls"),
          p(style = "font-size: 12px; color: #7f8c8d;", "Select historical period to inspect live spatial pollution distribution across Beijing."),
          selectInput("map_year", "Select Year", choices = 2013:2017, selected = 2016),
          selectInput("map_date", "Select Date", choices = NULL),
          sliderInput("map_hour", "Hour of Day (24-hr)", min = 0, max = 23, value = 12, step = 1, ticks = TRUE),
          hr(),
          h5(style = "font-weight: 700;", "AQI Color Legend:"),
          tags$div(
            tags$div(span(style = "color:#2ecc71; font-weight:900;", "●"), " Good (0-35)"),
            tags$div(span(style = "color:#f1c40f; font-weight:900;", "●"), " Moderate (35-75)"),
            tags$div(span(style = "color:#e67e22; font-weight:900;", "●"), " Unhealthy Sensitive (75-115)"),
            tags$div(span(style = "color:#e74c3c; font-weight:900;", "●"), " Unhealthy (115-150)"),
            tags$div(span(style = "color:#8e44ad; font-weight:900;", "●"), " Hazardous (>150)")
          )
        )
      ),
      column(
        width = 9,
        fluidRow(
          column(3, div(class = "card-kpi", style = "border-left-color: #3498db;",
                        h4("Citywide Mean PM2.5"), div(class = "val", textOutput("kpi_mean_pm")))),
          column(3, div(class = "card-kpi", style = "border-left-color: #e74c3c;",
                        h4("Dominant Status"), div(class = "val", textOutput("kpi_dominant_aqi")))),
          column(3, div(class = "card-kpi", style = "border-left-color: #2ecc71;",
                        h4("Cleanest Station"), div(class = "val", style = "font-size: 16px;", textOutput("kpi_cleanest")))),
          column(3, div(class = "card-kpi", style = "border-left-color: #8e44ad;",
                        h4("Highest Pollution"), div(class = "val", style = "font-size: 16px;", textOutput("kpi_worst"))))
        ),
        div(
          class = "card-box",
          leafletOutput("beijing_map", height = "520px")
        )
      )
    )
  ),
  
  tabPanel(
    title = tagList(icon("chart-line", verify_fa = FALSE), " Exploratory Mining"),
    fluidRow(
      column(
        width = 6,
        div(
          class = "card-box",
          h4(style = "font-weight: 700; color: #2c3e50;", "Environmental Correlation Heatmap"),
          p(style = "font-size: 12px; color: #7f8c8d;", "Interactive correlation between co-pollutants and meteorological factors. Hover to see exact Pearson coefficients."),
          plotlyOutput("plotly_corr", height = "430px")
        )
      ),
      column(
        width = 6,
        div(
          class = "card-box",
          h4(style = "font-weight: 700; color: #2c3e50;", "24-Hour Diurnal PM2.5 Cycle (Rush-Hour Smog)"),
          p(style = "font-size: 12px; color: #7f8c8d;", "Hourly pollution pattern reflecting morning/evening traffic spikes and evening thermal inversions."),
          plotlyOutput("plotly_diurnal", height = "430px")
        )
      )
    ),
    fluidRow(
      column(
        width = 12,
        div(
          class = "card-box",
          h4(style = "font-weight: 700; color: #2c3e50;", "Spatial Pollution Variance Across 12 Monitoring Stations"),
          p(style = "font-size: 12px; color: #7f8c8d;", "Compare long-term historical mean PM2.5 levels across urban, suburban, and industrial zones."),
          plotlyOutput("plotly_stations", height = "360px")
        )
      )
    )
  ),
  
  tabPanel(
    title = tagList(icon("sliders-h", verify_fa = FALSE), " Scenario Simulator"),
    fluidRow(
      column(
        width = 4,
        div(
          class = "well",
          h4(style = "font-weight: 700; color: #2c3e50; margin-top:0;", "Atmospheric Sliders"),
          p(style = "font-size: 12px; color: #7f8c8d;", "Adjust meteorological inputs to test the trained Data Mining models in real-time."),
          sliderInput("sim_temp", "Temperature (°C)", min = -15, max = 40, value = 5, step = 1),
          sliderInput("sim_wspm", "Wind Speed (m/s)", min = 0, max = 12, value = 1.2, step = 0.2),
          sliderInput("sim_pres", "Atmospheric Pressure (hPa)", min = 980, max = 1040, value = 1020, step = 1),
          sliderInput("sim_dewp", "Dew Point (°C)", min = -25, max = 25, value = -5, step = 1),
          hr(),
          h5(style = "font-weight: 700;", "Co-Pollutant Levels"),
          sliderInput("sim_co", "CO (ug/m3)", min = 200, max = 5000, value = 1200, step = 100),
          sliderInput("sim_no2", "NO2 (ug/m3)", min = 5, max = 150, value = 60, step = 5),
          sliderInput("sim_so2", "SO2 (ug/m3)", min = 2, max = 100, value = 25, step = 2),
          sliderInput("sim_o3", "Ozone O3 (ug/m3)", min = 2, max = 200, value = 30, step = 5),
          selectInput("sim_station", "Monitoring Station", choices = sort(unique(air$station)), selected = "Dongsi")
        )
      ),
      column(
        width = 8,
        div(
          class = "card-box",
          h4(style = "font-weight: 700; color: #2c3e50;", "Model Prediction Output"),
          fluidRow(
            column(
              width = 6,
              div(
                style = "text-align: center; padding: 24px 12px; border-radius: 8px; background: #f8fafc; border: 1px solid #e2e8f0;",
                h5(style = "text-transform: uppercase; color: #64748b; font-weight: 700; margin-bottom: 12px;", "Random Forest Classification"),
                uiOutput("sim_badge"),
                br(), br(),
                div(style = "font-size: 13px; color: #475569; text-align: left; padding: 8px 12px; background: white; border-radius: 6px; border-left: 4px solid #3b82f6;",
                    uiOutput("sim_advisory"))
              )
            ),
            column(
              width = 6,
              div(
                style = "text-align: center; padding: 24px 12px; border-radius: 8px; background: #f8fafc; border: 1px solid #e2e8f0;",
                h5(style = "text-transform: uppercase; color: #64748b; font-weight: 700; margin-bottom: 12px;", "Linear Regression Estimate"),
                div(style = "font-size: 40px; font-weight: 900; color: #1e293b; margin: 10px 0;",
                    textOutput("sim_lm_pm25")),
                p(style = "color: #64748b; font-size: 13px;", "Estimated continuous PM2.5 (ug/m3) based on training features.")
              )
            )
          ),
          hr(),
          h4(style = "font-weight: 700; color: #2c3e50; margin-top: 15px;", "Random Forest Class Probability Breakdown"),
          p(style = "font-size: 12px; color: #7f8c8d;", "Shows confidence distribution across all 5 standard hazard categories."),
          plotlyOutput("sim_prob_plot", height = "260px")
        )
      )
    )
  ),
  
  tabPanel(
    title = tagList(icon("tachometer-alt", verify_fa = FALSE), " Model Benchmark"),
    fluidRow(
      column(
        width = 6,
        div(
          class = "card-box",
          h4(style = "font-weight: 700; color: #2c3e50;", "Faculty Rubric: Classification Model Benchmark"),
          p(style = "font-size: 12px; color: #7f8c8d;", "Evaluated on independent 2017 test dataset (N = 16,728). Both models trained on 2013-2016."),
          tableOutput("eval_summary_table"),
          hr(),
          h5(style = "font-weight: 700;", "Key Findings:"),
          tags$ul(
            tags$li("Random Forest achieved higher Overall Accuracy (73.2%) compared to Decision Tree (69.6%)."),
            tags$li("Macro Precision and F1-Score improved significantly with ensemble bagging, reducing false alarms on high-risk tiers."),
            tags$li("Hazardous and Good air categories demonstrate high predictive sensitivity (>80% recall).")
          )
        )
      ),
      column(
        width = 6,
        div(
          class = "card-box",
          h4(style = "font-weight: 700; color: #2c3e50;", "Random Forest Feature Importance"),
          p(style = "font-size: 12px; color: #7f8c8d;", "Identifies top atmospheric predictors driving PM2.5 hazard categorization (Mean Decrease Gini)."),
          plotlyOutput("plotly_importance", height = "360px")
        )
      )
    ),
    fluidRow(
      column(
        width = 12,
        div(
          class = "card-box",
          h4(style = "font-weight: 700; color: #2c3e50;", "Confusion Matrix: Random Forest (2017 Test Dataset)"),
          p(style = "font-size: 12px; color: #7f8c8d;", "Rows: Actual Category | Columns: Predicted Category"),
          tableOutput("eval_cm_table")
        )
      )
    )
  )
)

server <- function(input, output, session) {
  
  observeEvent(input$map_year, {
    year_data <- air[air$year == as.integer(input$map_year), ]
    dates <- sort(unique(as.character(year_data$date)))
    updateSelectInput(session, "map_date", choices = dates, selected = dates[1])
  })
  
  map_snapshot <- reactive({
    req(input$map_date, input$map_hour)
    subset(
      air,
      date == as.Date(input$map_date) & hour == as.integer(input$map_hour)
    )
  })
  
  output$kpi_mean_pm <- renderText({
    snap <- map_snapshot()
    if (nrow(snap) == 0) return("N/A")
    sprintf("%.1f ug/m3", mean(snap$PM2.5, na.rm = TRUE))
  })
  
  output$kpi_dominant_aqi <- renderText({
    snap <- map_snapshot()
    if (nrow(snap) == 0) return("N/A")
    tbl <- table(snap$AQI_Category)
    names(tbl)[which.max(tbl)]
  })
  
  output$kpi_cleanest <- renderText({
    snap <- map_snapshot()
    if (nrow(snap) == 0) return("N/A")
    cleanest <- snap[which.min(snap$PM2.5), ]
    sprintf("%s (%.0f)", cleanest$station, cleanest$PM2.5)
  })
  
  output$kpi_worst <- renderText({
    snap <- map_snapshot()
    if (nrow(snap) == 0) return("N/A")
    worst <- snap[which.max(snap$PM2.5), ]
    sprintf("%s (%.0f)", worst$station, worst$PM2.5)
  })
  
  output$beijing_map <- renderLeaflet({
    leaflet(station_coords) %>%
      addTiles() %>%
      setView(lng = 116.40, lat = 39.95, zoom = 10)
  })
  
  observe({
    snap <- map_snapshot()
    req(nrow(snap) > 0)
    
    color_map <- c(
      "Good" = "#2ecc71",
      "Moderate" = "#f1c40f",
      "Unhealthy for Sensitive" = "#e67e22",
      "Unhealthy" = "#e74c3c",
      "Hazardous" = "#8e44ad"
    )
    
    snap$marker_color <- color_map[as.character(snap$AQI_Category)]
    
    leafletProxy("beijing_map", data = snap) %>%
      clearMarkers() %>%
      addCircleMarkers(
        lng = ~longitude,
        lat = ~latitude,
        radius = 14,
        fillColor = ~marker_color,
        fillOpacity = 0.85,
        color = "#ffffff",
        weight = 2,
        label = ~sprintf("%s: %s (PM2.5: %.0f)", station, AQI_Category, PM2.5),
        popup = ~sprintf(
          "<b>Station:</b> %s (%s)<br/>
           <b>AQI Tier:</b> <span style='color:%s; font-weight:bold;'>%s</span><br/>
           <b>PM2.5:</b> %.1f ug/m3<br/>
           <b>PM10:</b> %.1f ug/m3<br/>
           <b>Temp:</b> %.1f °C | <b>Wind:</b> %.1f m/s (%s)",
          station, station_type, marker_color, AQI_Category, PM2.5, PM10, TEMP, WSPM, wd
        )
      )
  })
  
  output$plotly_corr <- renderPlotly({
    pollutants_meteo <- air[, c("PM2.5", "PM10", "SO2", "NO2", "CO", "O3", "TEMP", "PRES", "DEWP", "WSPM")]
    cor_mat <- round(cor(pollutants_meteo, use = "complete.obs"), 2)
    
    plot_ly(
      x = colnames(cor_mat),
      y = rownames(cor_mat),
      z = cor_mat,
      type = "heatmap",
      colors = colorRamp(c("#e74c3c", "#ffffff", "#2980b9"))
    ) %>%
      layout(
        xaxis = list(title = ""),
        yaxis = list(title = "")
      )
  })
  
  output$plotly_diurnal <- renderPlotly({
    hourly_agg <- aggregate(PM2.5 ~ hour, data = air, mean)
    
    plot_ly(hourly_agg, x = ~hour, y = ~PM2.5, type = "scatter", mode = "lines+markers",
            line = list(color = "#c0392b", width = 3),
            marker = list(color = "#962d22", size = 7)) %>%
      layout(
        xaxis = list(title = "Hour of Day (0 - 23)", dtick = 2),
        yaxis = list(title = "Average PM2.5 (ug/m3)")
      )
  })
  
  output$plotly_stations <- renderPlotly({
    station_agg <- aggregate(PM2.5 ~ station + station_type, data = air, mean)
    station_agg <- station_agg[order(station_agg$PM2.5), ]
    
    plot_ly(station_agg, x = ~PM2.5, y = ~reorder(station, PM2.5), type = "bar", orientation = "h",
            marker = list(color = ~PM2.5, colorscale = "Viridis", showscale = TRUE)) %>%
      layout(
        xaxis = list(title = "Historical Mean PM2.5 (ug/m3)"),
        yaxis = list(title = "Station")
      )
  })
  
  sim_input_data <- reactive({
    data.frame(
      TEMP = as.numeric(input$sim_temp),
      PRES = as.numeric(input$sim_pres),
      DEWP = as.numeric(input$sim_dewp),
      RAIN = 0,
      WSPM = as.numeric(input$sim_wspm),
      SO2 = as.numeric(input$sim_so2),
      NO2 = as.numeric(input$sim_no2),
      CO = as.numeric(input$sim_co),
      O3 = as.numeric(input$sim_o3),
      hour = 12,
      month = 1,
      station = factor(input$sim_station, levels = levels(air$station)),
      wd = factor("N", levels = levels(air$wd)),
      stringsAsFactors = FALSE
    )
  })
  
  output$sim_badge <- renderUI({
    new_data <- sim_input_data()
    pred_cat <- as.character(predict(model_rf, newdata = new_data, type = "response")[1])
    bg_color <- aqi_colors[pred_cat]
    
    div(
      class = "badge-aqi",
      style = sprintf("background-color: %s;", bg_color),
      pred_cat
    )
  })
  
  output$sim_advisory <- renderUI({
    new_data <- sim_input_data()
    pred_cat <- as.character(predict(model_rf, newdata = new_data, type = "response")[1])
    
    advisory_map <- c(
      "Good" = "Air quality is considered satisfactory, and air pollution poses little or no risk.",
      "Moderate" = "Air quality is acceptable; however, sensitive individuals may experience minor irritation.",
      "Unhealthy for Sensitive" = "Members of sensitive groups may experience health effects. General public not likely affected.",
      "Unhealthy" = "Everyone may begin to experience health effects; members of sensitive groups may experience serious effects.",
      "Hazardous" = "Health alert: The risk of health effects is increased for everyone. Avoid outdoor exertion!"
    )
    
    HTML(sprintf("<b>Health Advisory:</b> %s", advisory_map[pred_cat]))
  })
  
  output$sim_lm_pm25 <- renderText({
    new_data <- sim_input_data()
    est_pm <- predict(model_lm, newdata = new_data)
    sprintf("%.1f", max(0, est_pm[1]))
  })
  
  output$sim_prob_plot <- renderPlotly({
    new_data <- sim_input_data()
    probs <- predict(model_rf, newdata = new_data, type = "prob")[1, ]
    prob_df <- data.frame(
      Category = names(probs),
      Probability = as.numeric(probs) * 100,
      stringsAsFactors = FALSE
    )
    prob_df$Category <- factor(prob_df$Category, levels = names(aqi_colors))
    
    plot_ly(prob_df, x = ~Probability, y = ~Category, type = "bar", orientation = "h",
            marker = list(color = unname(aqi_colors[levels(prob_df$Category)]))) %>%
      layout(
        xaxis = list(title = "Predicted Probability (%)", range = c(0, 100)),
        yaxis = list(title = "")
      )
  })
  
  output$eval_summary_table <- renderTable({
    class_metrics
  }, striped = TRUE, hover = TRUE, bordered = TRUE)
  
  output$eval_cm_table <- renderTable({
    cm_rf
  }, rownames = TRUE, striped = TRUE, hover = TRUE, bordered = TRUE)
  
  output$plotly_importance <- renderPlotly({
    imp_sub <- rf_importance[order(rf_importance$MeanDecreaseGini, decreasing = TRUE), ][1:8, ]
    
    plot_ly(imp_sub, x = ~MeanDecreaseGini, y = ~reorder(Feature, MeanDecreaseGini), type = "bar", orientation = "h",
            marker = list(color = "#3498db")) %>%
      layout(
        xaxis = list(title = "Importance (Mean Decrease Gini)"),
        yaxis = list(title = "Feature")
      )
  })
}

shinyApp(ui = ui, server = server)
