library(parallel)
library(doParallel)
library(foreach)

# Parallel K-fold cross-validation function
pKfold <- function(x, method, TrTsList, ..., n_cores = NULL) {
  # Determine number of cores
  if (is.null(n_cores)) {
    n_cores <- min(detectCores() - 1, length(TrTsList))
  }

  # Setup cluster
  cl <- makeCluster(n_cores)
  on.exit(stopCluster(cl))  # Ensure cluster is stopped even if error occurs

  # Export the method function and data to workers
  clusterExport(cl, varlist = c("method", "x"), envir = environment())

  # Also export any packages needed by the method
  # clusterEvalQ(cl, library(yourpackage))

  # Capture additional arguments
  extra_args <- list(...)

  # Run parallel cross-validation
  results <- parLapply(cl, TrTsList, function(fold) {
    # Each fold contains trainIdx and testIdx
    trainIdx <- fold$trainIdx
    testIdx <- fold$testIdx

    # Call the method function with the data and indices
    result <- method(x = x,
                     trainIdx = trainIdx,
                     testIdx = testIdx,
                     extra_args = extra_args)

    return(result)
  })

  return(results)
}

# Example method function for linear regression
lm_method <- function(x, trainIdx, testIdx, extra_args = list()) {
  # Train model
  train_data <- x[trainIdx, ]

  # Build formula (assuming 'y' is response, rest are predictors)
  formula <- as.formula(paste("y ~", paste(names(x)[-1], collapse = " + ")))

  mdl <- lm(formula, data = train_data)

  # Test model
  test_data <- x[testIdx, ]
  predictions <- predict(mdl, newdata = test_data)

  # Calculate error metrics
  actual <- test_data$y
  mse <- mean((actual - predictions)^2)
  rmse <- sqrt(mse)
  mae <- mean(abs(actual - predictions))

  # Return results
  list(
    predictions = predictions,
    actual = actual,
    mse = mse,
    rmse = rmse,
    mae = mae,
    model = mdl,
    fold_size = list(train = length(trainIdx), test = length(testIdx))
  )
}

# Example with more complex method (Random Forest)
rf_method <- function(x, trainIdx, testIdx, extra_args = list()) {
  library(randomForest)  # Load in worker

  train_data <- x[trainIdx, ]
  test_data <- x[testIdx, ]

  # Get parameters from extra_args
  ntree <- ifelse(is.null(extra_args$ntree), 500, extra_args$ntree)
  mtry <- ifelse(is.null(extra_args$mtry), floor(sqrt(ncol(x) - 1)), extra_args$mtry)

  formula <- as.formula(paste("y ~", paste(names(x)[-1], collapse = " + ")))

  mdl <- randomForest(formula, data = train_data, ntree = ntree, mtry = mtry)

  predictions <- predict(mdl, newdata = test_data)
  actual <- test_data$y

  list(
    predictions = predictions,
    actual = actual,
    mse = mean((actual - predictions)^2),
    rmse = sqrt(mean((actual - predictions)^2)),
    importance = importance(mdl)
  )
}

# Helper function to create K-fold splits
create_kfold_splits <- function(n, K = 5, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)

  # Create random fold assignments
  fold_ids <- sample(rep(1:K, length.out = n))

  # Create list of train/test index pairs
  TrTsList <- lapply(1:K, function(k) {
    list(
      trainIdx = which(fold_ids != k),
      testIdx = which(fold_ids == k)
    )
  })

  return(TrTsList)
}

# ============================================
# EXAMPLE USAGE
# ============================================

# Create sample dataset
set.seed(123)
n <- 1000
x <- data.frame(
  y = rnorm(n),
  x1 = rnorm(n),
  x2 = rnorm(n),
  x3 = rnorm(n)
)
x$y <- 2 + 3*x$x1 - 1.5*x$x2 + 0.5*x$x3 + rnorm(n, sd = 0.5)

# Create 5-fold splits
K <- 5
TrTsList <- create_kfold_splits(nrow(x), K = K, seed = 42)

# Run parallel K-fold cross-validation with linear regression
cat("Running", K, "fold CV with linear regression...\n")
results_lm <- pKfold(x, lm_method, TrTsList, n_cores = 4)

# Aggregate results
mean_rmse <- mean(sapply(results_lm, function(r) r$rmse))
mean_mae <- mean(sapply(results_lm, function(r) r$mae))
cat("Average RMSE:", mean_rmse, "\n")
cat("Average MAE:", mean_mae, "\n")

# Run with Random Forest (with extra parameters)
cat("\nRunning", K, "fold CV with Random Forest...\n")
results_rf <- pKfold(x, rf_method, TrTsList, ntree = 100, mtry = 2, n_cores = 4)

mean_rmse_rf <- mean(sapply(results_rf, function(r) r$rmse))
cat("RF Average RMSE:", mean_rmse_rf, "\n")
