# smoking_model.R -- sex-specific compartmental smoking model (adults 15+, population FRACTIONS).
# States per sex: Never smokers N; current cigarette smokers C[1..8] by duration band (5-yr bands, last = 35+ yrs);
# former smokers F[1..4] by years-since-quitting band (0-4, 5-9, 10-19, 20+); X[1..4] = duration-weighted excess-risk
# mass of former smokers (see cancer_model.R). N = 1 - sum(C) - sum(F) so all fractions stay in [0,1].
DUR_MID <- seq(2.5, 37.5, by = 5)     # mid-points of smoking-duration bands (years)
YSQ_MID <- c(2.5, 7.5, 15, 27)        # mid-points of years-since-quitting bands
YSQ_RATE <- c(0.2, 0.2, 0.1, 0)       # annual probability of moving to the next quitting band

dirichlet1 <- function(alpha) { g <- rgamma(length(alpha), shape = alpha); g / sum(g) }

# Quasi-stationary duration profile of current smokers given quit (q) and exit (m) hazards:
# an assumption about HISTORICAL EXPOSURE (no Armenian duration data exist in the uploaded files).
stationary_duration_weights <- function(q, m) {
  sv <- (1 - (q + m))^5
  w <- c(sv^(0:6), sv^7 / (q + m)); w / sum(w)
}

# Duration weight (Doll-Peto style): relative excess risk of a current smoker after d years, capped at 1 at 35 y.
psi_fun <- function(d, kappa) pmin(1, (d / 35)^kappa)

smoking_init <- function(p, sex) {
  C0 <- p[[paste0("C0_", sex)]]; F0 <- p[[paste0("F0_", sex)]]
  if (C0 < 0 || F0 < 0 || C0 + F0 >= 1) stop("Invalid baseline smoking fractions for ", sex)
  psi <- psi_fun(DUR_MID, p$kappa)
  Fv <- F0 * p[[paste0("ysq_", sex)]]
  list(C = C0 * p[[paste0("dur_", sex)]], F = Fv, X = Fv * p$psi_f0, psi = psi)
}

# One annual transition. i_eff, q_eff: annual probabilities (initiation among never smokers; quitting among smokers);
# extra_quit: additional proportional quitting (price response); m: annual exit (death/ageing out), replaced by new never smokers.
smoking_step <- function(st, i_eff, q_eff, extra_quit, m) {
  stopifnot(i_eff >= 0, i_eff <= 1, q_eff >= 0, q_eff <= 1, extra_quit >= 0, extra_quit <= 1)
  N <- 1 - sum(st$C) - sum(st$F)
  quit <- q_eff * st$C
  quit <- quit + extra_quit * (st$C - quit)
  prog <- st$C / 5; prog[length(prog)] <- 0
  Cn <- st$C - quit - prog
  Cn[-1] <- Cn[-1] + prog[-length(prog)]
  Cn[1] <- Cn[1] + i_eff * N
  fo <- st$F * YSQ_RATE; xo <- st$X * YSQ_RATE
  Fn <- st$F - fo; Xn <- st$X - xo
  Fn[-1] <- Fn[-1] + fo[-length(fo)]; Xn[-1] <- Xn[-1] + xo[-length(xo)]
  Fn[1] <- Fn[1] + sum(quit); Xn[1] <- Xn[1] + sum(st$psi * quit)
  st$C <- Cn * (1 - m); st$F <- Fn * (1 - m); st$X <- Xn * (1 - m)
  st
}

# Baseline (BAU) hazards. Initiation is CALIBRATED so that, with quit probability q and exit m, current prevalence
# changes at the relative annual rate rho at t=0: dC = i*N - (q+m)*C = rho*C  ->  i = (rho+q+m)*C/N.
# Hazards are then held constant, so prevalence converges smoothly (no constant-rate extrapolation).
bau_hazards <- function(p, sex) {
  C0 <- p[[paste0("C0_", sex)]]; F0 <- p[[paste0("F0_", sex)]]; q <- p[[paste0("q_", sex)]]
  rho <- p[[paste0("rho_", sex)]]; N0 <- 1 - C0 - F0
  list(i = min(0.2, max(0, (rho + q + p$m_exit) * C0 / N0)), q = q)
}

# Run one sex under one scenario; returns data.frame with year, current, former, never, E (exposure index).
run_smoking_sex <- function(p, sex, scenario, years, const) {
  st <- smoking_init(p, sex); hz <- bau_hazards(p, sex)
  D <- p$rinf + (1 - p$rinf) * 2^(-YSQ_MID / p$half)      # residual-risk factor after quitting
  out <- vector("list", length(years))
  for (k in seq_along(years)) {
    N <- 1 - sum(st$C) - sum(st$F)
    out[[k]] <- data.frame(year = years[k], current = sum(st$C), former = sum(st$F), never = N,
                           E = sum(st$psi * st$C) + sum(D * st$X))
    if (k == length(years)) break
    ef <- policy_effects(p, scenario, years[k + 1], const)  # effect in force during the transition into year k+1
    q_eff <- min(0.5, hz$q * ef$mq + ef$dq); i_eff <- min(0.2, hz$i * ef$mi)
    st <- smoking_step(st, i_eff, q_eff, ef$extra_quit, p$m_exit)
  }
  do.call(rbind, out)
}
