# sensitivity_analysis.R -- (a) Spearman rank correlation of every sampled parameter with scenario outcomes across the
# Monte Carlo draws (global, accounts for all parameters varying jointly); (b) one-at-a-time tornado: each scalar parameter
# moved to its 2.5th / 97.5th sampled percentile with all others at central values.
# Dirichlet profile parameters (duration/years-since-quit/lag weights) are included in (a) through summary components
# (share of smokers in the 35+ duration band, share of former smokers quit <5 y, weight of same-year deaths) but not in (b).
run_sensitivity <- function(dat, sim) {
  spec <- sim$spec; const <- sim$const; arr <- sim$arr; years <- sim$years
  scal <- spec$name
  extra <- c("dur_m_8", "dur_f_8", "ysq_m_1", "ysq_f_1", "lagw_1")
  X <- do.call(rbind, lapply(sim$params, function(p) unlist(p[c(scal, extra)])))
  S2 <- "S2_Enforcement"; S3 <- "S3_Comprehensive"; nY <- length(years)
  Y <- data.frame(
    deaths_averted_cum_S3 = rowSums(arr[, -1, "S1_BAU", "deaths_t"]) - rowSums(arr[, -1, S3, "deaths_t"]),
    deaths_averted_cum_S2 = rowSums(arr[, -1, "S1_BAU", "deaths_t"]) - rowSums(arr[, -1, S2, "deaths_t"]),
    BAU_cases_2034 = arr[, nY, "S1_BAU", "cases_t"],
    S3_male_prev_2034 = arr[, nY, S3, "prev_m"])
  grp <- c(setNames(spec$group, spec$name), dur_m_8 = "Historical exposure", dur_f_8 = "Historical exposure",
           ysq_m_1 = "Historical exposure", ysq_f_1 = "Historical exposure", lagw_1 = "Cancer calibration")
  rk <- do.call(rbind, lapply(colnames(X), function(v) {
    cr <- sapply(Y, function(y) if (sd(X[, v]) == 0) NA_real_ else cor(X[, v], y, method = "spearman"))
    data.frame(parameter = v, group = grp[[v]], t(round(cr, 3)), row.names = NULL) }))
  rk$importance_S3_deaths_averted <- rank(-abs(rk$deaths_averted_cum_S3), na.last = "keep")
  rk <- rk[order(rk$importance_S3_deaths_averted), ]

  pc <- central_params(spec)
  metric <- function(p) {
    b <- run_one(p, "S1_BAU", dat, const, years, sim$wpp); s3 <- run_one(p, S3, dat, const, years, sim$wpp)
    c(averted = sum((b$deaths_m + b$deaths_f)[-1]) - sum((s3$deaths_m + s3$deaths_f)[-1]), bau2034 = (b$cases_m + b$cases_f)[nY])
  }
  m0 <- metric(pc)
  Pm <- do.call(rbind, lapply(sim$params, function(p) unlist(p[scal])))
  tor <- do.call(rbind, lapply(scal, function(v) {
    qs <- quantile(Pm[, v], c(.025, .975)); res <- lapply(qs, function(val) { p <- pc; p[[v]] <- val; metric(p) })
    data.frame(parameter = v, group = spec$group[spec$name == v], low_value = qs[1], high_value = qs[2],
               averted_low = res[[1]]["averted"], averted_high = res[[2]]["averted"], central_averted = m0["averted"],
               bau2034_low = res[[1]]["bau2034"], bau2034_high = res[[2]]["bau2034"], central_bau2034 = m0["bau2034"], row.names = NULL)
  }))
  tor$swing_averted <- abs(tor$averted_high - tor$averted_low); tor$swing_bau2034 <- abs(tor$bau2034_high - tor$bau2034_low)
  tor <- tor[order(-tor$swing_averted), ]
  list(rank = rk, tornado = tor, central = m0)
}
