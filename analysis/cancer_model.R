# cancer_model.R -- exposure-history lung-cancer model, calibrated to the 2024 GLOBOCAN baseline.
# Population lung-cancer rate in sex s, year t:   rate = b_s * [ N + sum_j C_j*RR_j + sum_b F_b*RR_b ]
#   RR for a current smoker of duration d:  1 + (RR_cur-1)*psi(d),  psi(d)=min(1,(d/35)^kappa)   (latency / duration)
#   RR for a former smoker:  1 + (RR_cur-1)*psi(duration at quitting)*D(years since quit),
#        D(y) = rinf + (1-rinf)*2^(-y/half)            (delayed, incomplete fall in risk)
# => rate index I_s(t) = 1 + (RR_cur-1)*E_s(t), E = sum(psi*C) + sum(D*X). The unknown b_s cancels when we scale to 2024:
#   cases_s(t) = cases_s(2024) * I_s(t)/I_s(2024) * A_s(t),  A_s = demographic (ageing/growth) factor relative to 2024.
# Mortality is kept DISTINCT: deaths are a lagged, calibrated fraction of incident cases (survival-lag distribution w),
# calibrated so that 2024 total deaths reproduce the GLOBOCAN death anchor; sex split comes from the relative case-fatality
# parameter phif (no sex-specific lung deaths are in the uploaded files). No fixed mortality:incidence ratio is imposed;
# the implied fatality fraction f is a calibrated, uncertain quantity constrained to <= 0.98.
project_lung <- function(p, base, smk, years, wpp = NULL) {
  cases <- list(); hist <- list()
  for (s in c("m", "f")) {
    sx <- if (s == "m") "male" else "female"
    idx <- 1 + (p[[paste0("RR_", s)]] - 1) * smk[[s]]$E
    if (any(idx <= 0)) stop("Non-positive risk index")
    if (!is.null(wpp)) {
      w <- wpp[wpp$sex == sx & wpp$year %in% years, ]; A <- w$factor[match(years, w$year)]
      if (anyNA(A)) stop("WPP file does not cover all projection years")
      pre <- rep(A[1], 2)
    } else { g <- p[[paste0("g_", s)]]; A <- (1 + g)^(seq_along(years) - 1); pre <- (1 + g)^c(-2, -1) }
    b <- base[[paste0("cases_", s)]] * p$cases_err
    cases[[s]] <- b * idx / idx[1] * A
    hist[[s]] <- c(b * pre, cases[[s]])           # 2022, 2023 (assumed at 2024 rate, deflated by ageing), then projection
  }
  w <- c(p$lagw_1, p$lagw_2, p$lagw_3)
  lagged <- function(s, t) { h <- hist[[s]]; k <- t + 2; w[1] * h[k] + w[2] * h[k - 1] + w[3] * h[k - 2] }
  tt <- seq_along(years)
  lm_ <- sapply(tt, function(t) lagged("m", t)); lf_ <- sapply(tt, function(t) lagged("f", t))
  f_m <- base$deaths_total * p$death_err / (lm_[1] + p$phif * lf_[1])
  list(cases_m = cases$m, cases_f = cases$f, deaths_m = f_m * lm_, deaths_f = f_m * p$phif * lf_,
       f_m = f_m, f_f = f_m * p$phif)
}
