# simulation.R -- parameter specification (single source of truth for assumptions) and Monte Carlo engine.
# Uncertainty represented: PARAMETER uncertainty only (distributions below). Scenario uncertainty is shown by running
# three explicit scenarios with common random numbers (same draws in every scenario). STRUCTURAL uncertainty (model form,
# e.g. omitted relapse, no age structure) is NOT sampled and is listed as a limitation.
build_param_spec <- function(dat) {
  b <- dat$base; tr <- dat$trend
  tm <- tr[tr$sex == "male", ]; tf <- tr[tr$sex == "female", ]
  S <- function(name, group, dist, p1, p2, lo = NA, hi = NA, central = NA, why = "")
    data.frame(name = name, group = group, distribution = dist, p1 = p1, p2 = p2, lower = lo, upper = hi,
               central = ifelse(is.na(central), p1, central), rationale = why, stringsAsFactors = FALSE)
  rbind(
    S("C0_m","Baseline smoking","beta(mean,sd)", b$cig_m, 0.03, central = b$cig_m, why = "WHO 2023 age-standardised current cigarette prevalence, males 15+ (uploaded file); sd = assumed modelled-estimate error"),
    S("C0_f","Baseline smoking","beta(mean,sd)", b$cig_f, 0.005, central = b$cig_f, why = "WHO 2023 age-standardised current cigarette prevalence, females 15+; female smoking may be under-reported"),
    S("F0_m","Historical exposure","beta(mean,sd)", 0.142, 0.02, why = "WHO STEPS Armenia 2016 (cited in FCTC Needs Assessment 2020): former tobacco users (smoked and/or smokeless), men 18-69 = 14.2%. Definition/age/year differ from the cigarette baseline -> sd 0.02 is an assumed allowance"),
    S("F0_f","Historical exposure","beta(mean,sd)", 0.009, 0.004, why = "WHO STEPS Armenia 2016 (FCTC Needs Assessment 2020): former tobacco users, women 18-69 = 0.9%; same definitional caveat"),
    S("q_m","Smoking cessation","beta(mean,sd)", 0.03, 0.01, why = "ASSUMPTION: annual quit probability among current smokers (low-to-middle-income range ~2-5%)"),
    S("q_f","Smoking cessation","beta(mean,sd)", 0.04, 0.015, why = "ASSUMPTION: as for men, slightly higher"),
    S("m_exit","Population","uniform(min,max)", 0.008, 0.016, 0.008, 0.016, central = 0.012, why = "Annual exit (death/ageing out) replaced by never-smoking entrants; ~1/(adult life expectancy 15+)"),
    S("rho_m","Smoking initiation","truncnormal(mean,sd)", 0.5 * tm$slope, max(tm$se, 0.01), -0.1, 0.1, why = "BAU relative annual change in male prevalence: 50% of log-linear slope of the SDG any-tobacco series (definition differs -> trend only), sd = max(SE, 0.01)"),
    S("rho_f","Smoking initiation","truncnormal(mean,sd)", 0.5 * tf$slope, max(tf$se, 0.02), -0.1, 0.1, why = "As rho_m for females (tiny prevalence, very wide uncertainty)"),
    S("RR_m","Relative risks","lognormal(median,sdlog)", 15, 0.25, why = "Lung cancer RR, long-duration current vs never smokers, men (broad literature range ~8-25)"),
    S("RR_f","Relative risks","lognormal(median,sdlog)", 12, 0.30, why = "Lung cancer RR, current vs never smokers, women"),
    S("kappa","Latency / duration","lognormal(median,sdlog)", 3, 0.25, why = "Exponent of duration-dependence of excess risk (Doll & Peto: ~3-4.5)"),
    S("half","Time since quitting","lognormal(median,sdlog)", 8, 0.30, why = "Half-life (years) of the reducible excess risk after quitting"),
    S("rinf","Time since quitting","beta(mean,sd)", 0.15, 0.05, why = "Share of excess risk that never disappears after quitting"),
    S("psi_f0","Historical exposure","beta(mean,sd)", 0.6, 0.12, why = "ASSUMPTION: mean duration-weight of baseline former smokers' excess risk"),
    S("g_m","Population ageing","truncnormal(mean,sd)", 0.010, 0.004, -0.02, 0.04, why = "ASSUMPTION: annual growth in male lung cancer counts from ageing/growth at constant rates; replace with WPP-based factor"),
    S("g_f","Population ageing","truncnormal(mean,sd)", 0.015, 0.005, -0.02, 0.04, why = "ASSUMPTION: as above, females"),
    S("phif","Cancer calibration","lognormal(median,sdlog)", 1, 0.15, why = "Female:male case-fatality ratio (needed because lung deaths by sex are not in the data)"),
    S("cases_err","Cancer calibration","lognormal(median,sdlog)", 1, 0.15, why = "Multiplicative error of modelled GLOBOCAN incidence (larger: incidence is modelled)"),
    S("death_err","Cancer calibration","lognormal(median,sdlog)", 1, 0.07, why = "Multiplicative error of GLOBOCAN deaths (mortality is the more direct anchor)"),
    S("phi","Policy effectiveness","beta(mean,sd)", 0.6, 0.15, why = "Share of planned enforcement improvement actually implemented (implementation gap)"),
    S("phi3","Policy effectiveness","beta(mean,sd)", 0.5, 0.15, why = "Share of the additional S3 measures actually implemented"),
    S("bsf","Policy effectiveness","lognormal(median,sdlog)", 0.04, 0.6, why = "Relative rise in quit hazard per +1 smoke-free compliance point (assumption)"),
    S("gsf","Policy effectiveness","lognormal(median,sdlog)", 0.02, 0.6, why = "Relative fall in initiation hazard per +1 compliance point (assumption)"),
    S("eps_abs","Price elasticity","truncnormal(mean,sd)", 0.5, 0.15, 0.1, 1.0, why = "|Price elasticity of cigarette demand|; typical low/middle-income value ~0.5"),
    S("u","Price elasticity","beta(mean,sd)", 0.5, 0.1, why = "Share of demand elasticity operating through participation (prevalence) rather than intensity"),
    S("tau","Policy effectiveness","beta(mean,sd)", 0.85, 0.07, why = "Pass-through of tax increase to retail price"),
    S("reach","Policy effectiveness","beta(mean,sd)", 0.05, 0.02, why = "Annual share of smokers reached by cessation support (S3)"),
    S("eff","Policy effectiveness","beta(mean,sd)", 0.08, 0.03, why = "Absolute increase in sustained quitting among those treated"),
    S("media","Policy effectiveness","lognormal(median,sdlog)", 0.05, 0.6, why = "Relative rise in quit hazard from mass-media campaigns"),
    S("ad","Policy effectiveness","lognormal(median,sdlog)", 0.03, 0.6, why = "Relative fall in initiation from stronger advertising restrictions"),
    S("warn","Policy effectiveness","lognormal(median,sdlog)", 0.03, 0.6, why = "Relative fall in initiation from improved warnings"),
    S("omega","Policy effectiveness","beta(mean,sd)", 0.8, 0.1, why = "Overlap discount applied to the non-price S3 package to avoid double-counting")
  )
}

draw_one <- function(spec) {
  v <- lapply(seq_len(nrow(spec)), function(k) with(spec[k, ], switch(sub("\\(.*", "", distribution),
    beta = { kk <- p1 * (1 - p1) / p2^2 - 1; if (kk <= 0) stop("Beta sd too large for ", name); rbeta(1, p1 * kk, (1 - p1) * kk) },
    lognormal = rlnorm(1, log(p1), p2),
    uniform = runif(1, p1, p2),
    truncnormal = qnorm(runif(1, pnorm(lower, p1, p2), pnorm(upper, p1, p2)), p1, p2),
    stop("Unknown distribution ", distribution))))
  p <- setNames(v, spec$name)
  add_vectors(p, draw = TRUE)
}

# Dirichlet-distributed profile parameters (historical exposure & survival lag), conditional on scalars.
add_vectors <- function(p, draw = TRUE) {
  for (s in c("m", "f")) {
    w <- stationary_duration_weights(p[[paste0("q_", s)]], p$m_exit)
    d <- if (draw) dirichlet1(60 * w) else w
    for (k in 1:8) p[[sprintf("dur_%s_%d", s, k)]] <- d[k]
    y <- if (draw) dirichlet1(30 * c(.35, .25, .25, .15)) else c(.35, .25, .25, .15)
    for (k in 1:4) p[[sprintf("ysq_%s_%d", s, k)]] <- y[k]
  }
  l <- if (draw) dirichlet1(30 * c(.55, .30, .15)) else c(.55, .30, .15)
  for (k in 1:3) p[[paste0("lagw_", k)]] <- l[k]
  pack_vectors(p)
}
pack_vectors <- function(p) {
  for (s in c("m", "f")) { p[[paste0("dur_", s)]] <- unlist(p[sprintf("dur_%s_%d", s, 1:8)]); p[[paste0("ysq_", s)]] <- unlist(p[sprintf("ysq_%s_%d", s, 1:4)]) }
  p
}
central_params <- function(spec) {
  p <- setNames(as.list(spec$central), spec$name)
  p$m_exit <- 0.012; add_vectors(p, draw = FALSE)
}

run_simulation <- function(dat, n_sim, seed) {
  set.seed(seed)
  const <- make_const(dat); spec <- build_param_spec(dat); years <- START_YEAR:END_YEAR
  wa <- wpp_ageing_factor(); if (is.null(wa)) message("No WPP file supplied: using assumed ageing growth parameters g_m, g_f.")
  outs <- c("prev_m","prev_f","former_m","former_f","cases_m","cases_f","deaths_m","deaths_f","cases_t","deaths_t")
  arr <- array(NA_real_, c(n_sim, length(years), nrow(SCENARIOS), length(outs)), dimnames = list(NULL, years, SCENARIOS$id, outs))
  P <- vector("list", n_sim); rejected <- 0
  for (i in seq_len(n_sim)) {
    repeat {                                         # rejection: implied case-fatality fractions must be <= 0.98
      p <- draw_one(spec); r0 <- run_one(p, "S1_BAU", dat, const, years, wa)
      if (r0$f_m <= 0.98 && r0$f_f <= 0.98) break
      rejected <- rejected + 1
    }
    P[[i]] <- p
    for (s in SCENARIOS$id) { r <- if (s == "S1_BAU") r0 else run_one(p, s, dat, const, years, wa)
      for (o in outs[1:8]) arr[i, , s, o] <- r[[o]]
      arr[i, , s, "cases_t"] <- r$cases_m + r$cases_f; arr[i, , s, "deaths_t"] <- r$deaths_m + r$deaths_f }
    if (i %% 500 == 0) message("Monte Carlo ", i, "/", n_sim)
  }
  if (any(!is.finite(arr))) stop("Non-finite values in simulation output")
  if (any(arr[, , , c("prev_m","prev_f")] < 0 | arr[, , , c("prev_m","prev_f")] > 1)) stop("Prevalence out of bounds")
  nY <- length(years)
  averted <- do.call(rbind, lapply(SCENARIOS$id[-1], function(s) {
    cum_d <- rowSums(arr[, -1, "S1_BAU", "deaths_t"]) - rowSums(arr[, -1, s, "deaths_t"])
    cum_c <- rowSums(arr[, -1, "S1_BAU", "cases_t"]) - rowSums(arr[, -1, s, "cases_t"])
    d34 <- arr[, nY, "S1_BAU", "deaths_t"] - arr[, nY, s, "deaths_t"]
    c34 <- arr[, nY, "S1_BAU", "cases_t"] - arr[, nY, s, "cases_t"]
    q <- function(x) quantile(x, c(.025, .5, .975))
    data.frame(scenario = s, metric = c("cum. cases averted 2025-2034", "cum. deaths averted 2025-2034", "cases averted in 2034", "deaths averted in 2034"),
      median = c(q(cum_c)[2], q(cum_d)[2], q(c34)[2], q(d34)[2]), lo95 = c(q(cum_c)[1], q(cum_d)[1], q(c34)[1], q(d34)[1]),
      hi95 = c(q(cum_c)[3], q(cum_d)[3], q(c34)[3], q(d34)[3]),
      prob_positive = c(mean(cum_c > 0), mean(cum_d > 0), mean(c34 > 0), mean(d34 > 0)))
  }))
  meta <- data.frame(n_sim = n_sim, seed = seed, rejected_draws_fatality_gt_0.98 = rejected, years = paste(range(years), collapse = "-"))
  list(arr = arr, arr_tot = arr, years = years, spec = spec, params = P, averted = averted, meta = meta, const = const, wpp = wa)
}
