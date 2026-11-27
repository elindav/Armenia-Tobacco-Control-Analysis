# scenario_analysis.R -- scenario definitions, policy-effect mechanics, model runner, checks, output tables.
SCENARIOS <- data.frame(
  id = c("S1_BAU", "S2_Enforcement", "S3_Comprehensive"),
  label = c("1. Business as usual", "2. Strengthened enforcement", "3. Comprehensive intervention"),
  enforcement = c(FALSE, TRUE, TRUE), comprehensive = c(FALSE, FALSE, TRUE), stringsAsFactors = FALSE)

# Scenario constants taken from the uploaded data where possible.
make_const <- function(dat) {
  pa <- dat$policy_arm
  list(policy_start = POLICY_START,
       compliance_now = pa$sf_compliance_score,            # WHO smoke-free compliance score 0-10 (Armenia 2024)
       compliance_target = 9.5,                            # S2/S3 target (assumption: closes 75% of the gap to 10)
       tax_share_now = pa$mp_tax_share_pct_retail_price / 100,
       tax_share_target = 0.60,                            # S3 target (WHO benchmark is 0.75; 0.60 = assumption)
       phase_in_enf = 3, phase_in_tax = 4, phase_in_other = 4)  # years to reach full effect
}

# Policy effects on hazards in calendar year `yr`. Mechanisms (all multiply/add to baseline hazards, never to prevalence):
#  S2: smoke-free compliance gain  dc = phi * (target - now) * ramp  ->  quit hazard x (1 + bsf*dc); initiation x (1 - gsf*dc)
#      phi = fraction of the planned enforcement improvement actually delivered (implementation gap).
#  S3 adds (scaled by overlap factor omega <1 to avoid double-counting of the non-price package):
#      cessation support : extra quit prob = reach * efficacy * phi3 * ramp
#      mass media        : quit hazard x (1 + media)
#      ad bans + warnings: initiation x (1 - [1-(1-ad)(1-warn)])   (multiplicative combination of two reductions)
#      tax               : price rise dP = tau*(nontax/(1-target) - 1); participation elasticity e = |eps_d|*u;
#                          half of the prevalence response via quitting (extra_quit) and half via initiation.
policy_effects <- function(p, scenario, yr, const) {
  d <- list(mq = 1, mi = 1, extra_quit = 0, dq = 0)
  sc <- SCENARIOS[SCENARIOS$id == scenario, ]; if (nrow(sc) != 1) stop("Unknown scenario ", scenario)
  k <- yr - const$policy_start + 1
  if (k < 1 || !sc$enforcement) return(d)
  dc <- p$phi * (const$compliance_target - const$compliance_now) * min(1, k / const$phase_in_enf)
  d$mq <- d$mq + p$bsf * dc; d$mi <- d$mi * (1 - min(0.9, p$gsf * dc))
  if (sc$comprehensive) {
    r3 <- p$phi3 * min(1, k / const$phase_in_other)
    d$dq <- p$omega * r3 * p$reach * p$eff
    d$mq <- d$mq + p$omega * r3 * p$media
    d$mi <- d$mi * (1 - p$omega * r3 * (1 - (1 - p$ad) * (1 - p$warn)))
    dP <- p$tau * ((1 - const$tax_share_now) / (1 - const$tax_share_target) - 1)
    cum <- dP * min(1, k / const$phase_in_tax); prev <- dP * min(1, (k - 1) / const$phase_in_tax)
    e <- p$eps_abs * p$u
    d$extra_quit <- min(0.5, e * 0.5 * (cum - prev) / (1 + prev))
    d$mi <- d$mi * (1 - min(0.9, e * 0.5 * cum))
  }
  d
}

# Run one parameter set under one scenario -> list of vectors (length = n years).
run_one <- function(p, scenario, dat, const, years = START_YEAR:END_YEAR, wpp = NULL) {
  sm <- run_smoking_sex(p, "m", scenario, years, const); sf <- run_smoking_sex(p, "f", scenario, years, const)
  ca <- project_lung(p, dat$base, list(m = sm, f = sf), years, wpp)
  list(prev_m = sm$current, prev_f = sf$current, former_m = sm$former, former_f = sf$former,
       never_m = sm$never, never_f = sf$never, cases_m = ca$cases_m, cases_f = ca$cases_f,
       deaths_m = ca$deaths_m, deaths_f = ca$deaths_f, f_m = ca$f_m, f_f = ca$f_f)
}

# Deterministic checks run before the simulation. Stops with an error if any invariant fails.
run_model_checks <- function(dat) {
  const <- make_const(dat); spec <- build_param_spec(dat); p <- central_params(spec)
  res <- lapply(SCENARIOS$id, function(s) run_one(p, s, dat, const))
  names(res) <- SCENARIOS$id
  chk <- function(cond, msg) if (!isTRUE(cond)) stop("MODEL CHECK FAILED: ", msg)
  for (s in names(res)) { r <- res[[s]]
    for (v in c("prev_m","prev_f","former_m","former_f","never_m","never_f")) chk(all(r[[v]] >= -1e-12 & r[[v]] <= 1 + 1e-12), paste(v, "outside [0,1]", s))
    chk(all(abs(r$prev_m + r$former_m + r$never_m - 1) < 1e-9), "male compartments do not sum to 1")
    chk(all(abs(r$prev_f + r$former_f + r$never_f - 1) < 1e-9), "female compartments do not sum to 1")
    chk(all(c(r$cases_m, r$cases_f, r$deaths_m, r$deaths_f) >= 0), paste("negative cases/deaths", s))
    chk(is.finite(sum(unlist(r))), "non-finite value") }
  chk(abs(res[[1]]$cases_m[1] - dat$base$cases_m) < 1e-6, "2024 male cases not reproduced")
  chk(abs(res[[1]]$deaths_m[1] + res[[1]]$deaths_f[1] - dat$base$deaths_total) < 1e-6, "2024 deaths not reproduced")
  n <- length(res[[1]]$prev_m)
  chk(res[[2]]$prev_m[n] <= res[[1]]$prev_m[n] + 1e-12, "S2 male prevalence above BAU")
  chk(res[[3]]$prev_m[n] <= res[[2]]$prev_m[n] + 1e-12, "S3 male prevalence above S2")
  chk(res[[3]]$cases_m[n] <= res[[1]]$cases_m[n] + 1e-9, "S3 cases above BAU")
  for (sc in SCENARIOS$id) for (y in START_YEAR:END_YEAR) { e <- policy_effects(p, sc, y, const)
    chk(e$mq >= 1 && e$mi > 0 && e$mi <= 1 && e$dq >= 0 && e$extra_quit >= 0 && e$extra_quit <= 0.5, "policy effect out of range") }
  message("Model checks passed (compartments sum to 1, prevalence in [0,1], non-negative counts, scenario ordering, 2024 calibration).")
  invisible(res)
}

# Summaries over Monte Carlo draws: arr[iter, year, scenario, outcome]
mc_summary <- function(arr, outcome, years) {
  do.call(rbind, lapply(dimnames(arr)[[3]], function(s) {
    m <- arr[, , s, outcome, drop = TRUE]
    data.frame(scenario = s, year = years, mean = colMeans(m), median = apply(m, 2, median),
               lo95 = apply(m, 2, quantile, 0.025), hi95 = apply(m, 2, quantile, 0.975), outcome = outcome)
  }))
}

write_all_tables <- function(dat, sim, sens, pol) {
  yrs <- sim$years; arr <- sim$arr
  # derived totals
  arr2 <- sim$arr_tot
  outs <- c("prev_m","prev_f","cases_m","cases_f","cases_t","deaths_m","deaths_f","deaths_t")
  yr <- do.call(rbind, lapply(outs, function(o) mc_summary(arr2, o, yrs)))
  yr$scenario <- SCENARIOS$label[match(yr$scenario, SCENARIOS$id)]
  yr[, c("mean","median","lo95","hi95")] <- lapply(yr[, c("mean","median","lo95","hi95")], function(x) ifelse(yr$outcome %in% c("prev_m","prev_f"), round(x * 100, 2), round(x, 1)))
  names(yr)[names(yr) == "outcome"] <- "outcome (prevalence in %, counts per year)"
  write.csv(yr, file.path(PATHS$simulations, "year_by_year_results.csv"), row.names = FALSE)
  write.csv(sim$averted, file.path(PATHS$simulations, "averted_vs_bau.csv"), row.names = FALSE)
  write.csv(sens$rank, file.path(PATHS$sensitivity, "sensitivity_rank_correlations.csv"), row.names = FALSE)
  write.csv(sens$tornado, file.path(PATHS$sensitivity, "sensitivity_tornado.csv"), row.names = FALSE)
  write.csv(sim$spec[, c("name","group","distribution","p1","p2","lower","upper","central","rationale")], file.path(PATHS$tables, "assumptions_parameters.csv"), row.names = FALSE)
  write.csv(pol$table, file.path(PATHS$tables, "policy_comparison_table.csv"), row.names = FALSE)
  write.csv(pol$scores, file.path(PATHS$tables, "policy_implementation_scores.csv"), row.names = FALSE)
  if (!is.null(dat$survey)) write.csv(dat$survey, file.path(PATHS$tables, "armenia_convenience_survey_summary.csv"), row.names = FALSE)
  write.csv(data_limitations(sim), file.path(PATHS$tables, "data_limitations.csv"), row.names = FALSE)
  write.csv(sim$meta, file.path(PATHS$simulations, "simulation_diagnostics.csv"), row.names = FALSE)
}

data_limitations <- function(sim) data.frame(
  limitation = c("Single-year GLOBOCAN baseline", "GLOBOCAN incidence is modelled (derived from mortality/registry proxies)",
    "No sex-specific lung deaths in uploaded data", "No historical Armenian lung cancer mortality series in uploaded data",
    "Cigarette prevalence is one modelled year (WHO 2023, age-standardised)", "Historical series use a different definition (any tobacco, SDG 3.a.1)",
    "No age-by-sex population projections supplied", "No Armenian smoking duration / former-smoker / quit-rate data supplied",
    "No age-structured cancer results", "Policy effect sizes are literature-style assumptions, not Armenian estimates",
    "Relapse after quitting and differential smoker mortality omitted", "Comparative countries are not causal controls",
    "External sources listed in the brief not opened in the build session", "Survey data are convenience samples (n=65 Armenia)"),
  consequence = c("No fitting of historical trends; results are calibrated scenario projections, not validated forecasts",
    "Incidence and mortality are not treated as independent observations; larger uncertainty is placed on incidence",
    "Sex split of deaths relies on the relative case-fatality parameter phif",
    "Calibration cannot be validated against a time series", "2024 baseline assumed equal to 2023 estimate; prevalence uncertainty is a stated assumption",
    "Used only to inform relative BAU trend (shrunk 50% toward zero, wide uncertainty)",
    "Ageing represented by an uncertain annual growth factor; supply WPP 2024 file to replace it (data/raw/wpp_armenia_age_sex.csv)",
    "Literature-based Beta/Dirichlet priors used; strong influence on results (see sensitivity)",
    "Age-specific outputs not produced because required parameters are unsupported", "Intervals reflect assumed distributions only",
    "Prevalence reductions may be somewhat overstated", "Legal/implementation differences are described, not transferred as effects",
    "Policy comparison rows marked NOT VERIFIED must be completed manually", "Survey used descriptively only; not used in calibration"),
  stringsAsFactors = FALSE)
