if (!file.exists("data/processed/air_quality_cleaned.csv") && file.exists("../data/processed/air_quality_cleaned.csv")) {
  setwd("..")
}

library(rpart)
library(randomForest)

dir.create("outputs/results", showWarnings = FALSE, recursive = TRUE)

air <- read.csv("data/processed/air_quality_cleaned.csv", stringsAsFactors = FALSE)
air$AQI_Category <- factor(
  air$AQI_Category,
  levels = c("Good", "Moderate", "Unhealthy for Sensitive", "Unhealthy", "Hazardous")
)

air$station <- as.factor(air$station)
air$wd <- as.factor(air$wd)

features <- c("AQI_Category", "TEMP", "PRES", "DEWP", "RAIN", "WSPM",
              "SO2", "NO2", "CO", "O3", "hour", "month", "station")

data_subset <- air[, features]

train_idx <- which(air$year < 2017)
test_idx  <- which(air$year == 2017)

train_data <- data_subset[train_idx, ]
test_data  <- data_subset[test_idx, ]

model_tree <- rpart(
  AQI_Category ~ .,
  data = train_data,
  method = "class",
  control = rpart.control(cp = 0.005, maxdepth = 8)
)

set.seed(42)
sample_size <- min(35000, nrow(train_data))
rf_sample_idx <- sample(seq_len(nrow(train_data)), size = sample_size)
rf_train_data <- train_data[rf_sample_idx, ]

model_rf <- randomForest(
  AQI_Category ~ .,
  data = rf_train_data,
  ntree = 100,
  mtry = 4,
  importance = TRUE
)

pred_tree_class <- predict(model_tree, newdata = test_data, type = "class")
pred_rf_class   <- predict(model_rf, newdata = test_data, type = "response")

actual <- test_data$AQI_Category

compute_multiclass_metrics <- function(actual, predicted, model_name) {
  classes <- levels(actual)
  cm <- table(Actual = actual, Predicted = predicted)
  accuracy <- sum(diag(cm)) / sum(cm)
  
  precision_vec <- numeric(length(classes))
  recall_vec    <- numeric(length(classes))
  f1_vec        <- numeric(length(classes))
  
  for (i in seq_along(classes)) {
    tp <- cm[i, i]
    fp <- sum(cm[, i]) - tp
    fn <- sum(cm[i, ]) - tp
    
    precision_vec[i] <- if ((tp + fp) > 0) tp / (tp + fp) else 0
    recall_vec[i]    <- if ((tp + fn) > 0) tp / (tp + fn) else 0
    f1_vec[i]        <- if ((precision_vec[i] + recall_vec[i]) > 0) {
      2 * (precision_vec[i] * recall_vec[i]) / (precision_vec[i] + recall_vec[i])
    } else 0
  }
  
  macro_precision <- mean(precision_vec)
  macro_recall    <- mean(recall_vec)
  macro_f1        <- mean(f1_vec)
  
  summary_row <- data.frame(
    Model = model_name,
    Accuracy = round(accuracy, 4),
    Macro_Precision = round(macro_precision, 4),
    Macro_Recall = round(macro_recall, 4),
    Macro_F1 = round(macro_f1, 4),
    stringsAsFactors = FALSE
  )
  
  per_class_df <- data.frame(
    Class = classes,
    Precision = round(precision_vec, 4),
    Recall = round(recall_vec, 4),
    F1_Score = round(f1_vec, 4),
    stringsAsFactors = FALSE
  )
  
  list(cm = cm, summary = summary_row, per_class = per_class_df)
}

eval_tree <- compute_multiclass_metrics(actual, pred_tree_class, "Decision_Tree_Classifier")
eval_rf   <- compute_multiclass_metrics(actual, pred_rf_class, "Random_Forest_Classifier")

metrics_summary <- rbind(eval_tree$summary, eval_rf$summary)

write.csv(metrics_summary, "outputs/results/classification_metrics.csv", row.names = FALSE)
write.csv(as.data.frame.matrix(eval_tree$cm), "outputs/results/confusion_matrix_tree.csv")
write.csv(as.data.frame.matrix(eval_rf$cm), "outputs/results/confusion_matrix_rf.csv")
write.csv(eval_rf$per_class, "outputs/results/rf_per_class_metrics.csv", row.names = FALSE)

reg_train <- air[train_idx, c("PM2.5", "TEMP", "PRES", "DEWP", "RAIN", "WSPM", "SO2", "NO2", "CO", "O3", "station", "wd")]
reg_test  <- air[test_idx,  c("PM2.5", "TEMP", "PRES", "DEWP", "RAIN", "WSPM", "SO2", "NO2", "CO", "O3", "station", "wd")]

model_lm <- lm(PM2.5 ~ ., data = reg_train)
pred_lm <- predict(model_lm, newdata = reg_test)

evaluate_reg <- function(act, prd) {
  c(
    RMSE = sqrt(mean((act - prd)^2)),
    MAE = mean(abs(act - prd)),
    R2 = 1 - sum((act - prd)^2) / sum((act - mean(act))^2)
  )
}
reg_results <- rbind(Linear_Regression = evaluate_reg(reg_test$PM2.5, pred_lm))
write.csv(reg_results, "outputs/results/model_comparison.csv")

saveRDS(model_tree, "outputs/results/classifier_tree.rds")
saveRDS(model_rf,   "outputs/results/classifier_rf.rds")

model_lm$residuals <- NULL
model_lm$fitted.values <- NULL
model_lm$effects <- NULL
model_lm$model <- NULL
model_lm$qr$qr <- model_lm$qr$qr[1:ncol(model_lm$qr$qr), , drop = FALSE]
saveRDS(model_lm,   "outputs/results/linear_model.rds")

rf_importance <- as.data.frame(importance(model_rf))
rf_importance$Feature <- rownames(rf_importance)
write.csv(rf_importance, "outputs/results/rf_feature_importance.csv", row.names = FALSE)
