# visualizations.R -- all figures. Colour = scenario; observed points are shapes, projections are ribbons (95% interval).
SC_COL <- c(S1_BAU = "#7f7f7f", S2_Enforcement = "#1f77b4", S3_Comprehensive = "#d62728")
theme_proj <- function() theme_minimal(base_size = 12) + theme(legend.position = "bottom", plot.title = element_text(face = "bold"), plot.caption = element_text(size = 8, hjust = 0))
CAP <- "Calibrated epidemiological scenario projections (parameter uncertainty only), not validated forecasts. Baseline: GLOBOCAN 2024 / WHO 2023 estimates (modelled)."
save_fig <- function(p, name, w = 9, h = 5.5) ggsave(file.path(PATHS$figures, name), p, width = w, height = h, dpi = 300)
lab_sc <- function(x) factor(x, levels = SCENARIOS$id, labels = SCENARIOS$label)

proj_plot <- function(sim, outcome, title, ylab, pct = FALSE) {
  d <- mc_summary(sim$arr, outcome, sim$years); d$scenario <- lab_sc(d$scenario); f <- if (pct) 100 else 1
  cols <- setNames(SC_COL, SCENARIOS$label)
  ggplot(d, aes(year, median * f, colour = scenario, fill = scenario)) +
    geom_ribbon(aes(ymin = lo95 * f, ymax = hi95 * f), alpha = 0.15, colour = NA) + geom_line(linewidth = 1) +
    geom_vline(xintercept = 2024, linetype = 2, colour = "grey40") +
    annotate("text", x = 2024.1, y = -Inf, label = "baseline year", hjust = 0, vjust = -0.5, size = 3, colour = "grey30") +
    scale_colour_manual(values = cols) + scale_fill_manual(values = cols) + scale_x_continuous(breaks = seq(2024, 2034, 2)) +
    labs(title = title, y = ylab, x = NULL, colour = NULL, fill = NULL, caption = CAP) + theme_proj()
}

make_all_figures <- function(dat, sim, sens, pol) {
  # 1-2 historical tobacco use (observed / modelled). Definitions kept separate (shape = indicator).
  h <- dat$hist_all; h$series <- paste(h$indicator, h$measure, h$source_type)
  h <- h[h$measure %in% c("current", "current_or_unspecified"), ]
  h$def <- ifelse(h$indicator == "any_tobacco_use", "Any tobacco use", ifelse(h$indicator == "cigarette_smoking", "Current cigarette smoking", "Current tobacco smoking"))
  p1 <- ggplot(h, aes(year, value_pct, colour = sex, shape = def)) + geom_point(size = 3) + geom_line(data = h[h$source_type == "sdg", ], aes(group = interaction(sex, def)), linewidth = 0.6) +
    facet_wrap(~sex, scales = "free_y") + labs(title = "Armenia: historical tobacco use, adults 15+ (observed surveys and WHO modelled estimate)",
      subtitle = "Indicators have different definitions and are NOT merged; lines join SDG 3.a.1 survey points only", y = "Prevalence (%)", x = NULL, shape = "Indicator", colour = "Sex",
      caption = "Source: uploaded tobacco_prevalence.csv (SDG 3.a.1; WHO age-standardised modelled estimates 2023).") + theme_proj()
  save_fig(p1, "01_historical_tobacco_use_by_sex.png", 10, 5.5)
  # 3-4 smoking projections
  save_fig(proj_plot(sim, "prev_m", "Male current cigarette smoking prevalence (15+): scenarios 2024-2034", "Prevalence (%)", TRUE), "02_male_smoking_projection.png")
  save_fig(proj_plot(sim, "prev_f", "Female current cigarette smoking prevalence (15+): scenarios 2024-2034", "Prevalence (%)", TRUE), "03_female_smoking_projection.png")
  # 5-7 cancer
  save_fig(proj_plot(sim, "cases_t", "Projected lung cancer incidence (new cases per year)", "Cases per year"), "04_lung_incidence_total.png")
  save_fig(proj_plot(sim, "deaths_t", "Projected lung cancer mortality (deaths per year)", "Deaths per year"), "05_lung_mortality_total.png")
  sx <- rbind(transform(mc_summary(sim$arr, "cases_m", sim$years), sex = "Male", what = "Incidence"), transform(mc_summary(sim$arr, "cases_f", sim$years), sex = "Female", what = "Incidence"),
              transform(mc_summary(sim$arr, "deaths_m", sim$years), sex = "Male", what = "Mortality"), transform(mc_summary(sim$arr, "deaths_f", sim$years), sex = "Female", what = "Mortality"))
  sx$scenario <- lab_sc(sx$scenario); cols <- setNames(SC_COL, SCENARIOS$label)
  p6 <- ggplot(sx, aes(year, median, colour = scenario, fill = scenario)) + geom_ribbon(aes(ymin = lo95, ymax = hi95), alpha = .15, colour = NA) + geom_line(linewidth = 1) +
    facet_grid(what ~ sex, scales = "free_y") + scale_colour_manual(values = cols) + scale_fill_manual(values = cols) + scale_x_continuous(breaks = seq(2024, 2034, 5)) +
    labs(title = "Sex-specific lung cancer projections", y = "Per year", x = NULL, colour = NULL, fill = NULL, caption = paste(CAP, "Sex split of deaths is model-derived.")) + theme_proj()
  save_fig(p6, "06_lung_cancer_by_sex.png", 10, 6.5)
  # 8 averted distribution
  nY <- length(sim$years); arr <- sim$arr
  dist <- do.call(rbind, lapply(SCENARIOS$id[-1], function(s) data.frame(scenario = s, averted = rowSums(arr[, -1, "S1_BAU", "deaths_t"]) - rowSums(arr[, -1, s, "deaths_t"]))))
  dist$scenario <- lab_sc(dist$scenario)
  p8 <- ggplot(dist, aes(averted, fill = scenario)) + geom_histogram(bins = 60, alpha = .6, position = "identity") + geom_vline(xintercept = 0, linetype = 2) +
    scale_fill_manual(values = setNames(SC_COL[-1], SCENARIOS$label[-1])) + labs(title = "Uncertainty in cumulative lung cancer deaths averted vs business as usual, 2025-2034",
      x = "Deaths averted (negative = more deaths than BAU in that draw)", y = "Monte Carlo draws", fill = NULL, caption = CAP) + theme_proj()
  save_fig(p8, "07_deaths_averted_distribution.png")
  # 9 tornado
  tor <- sens$tornado[seq_len(min(12, nrow(sens$tornado))), ]
  tl <- rbind(data.frame(parameter = tor$parameter, side = "2.5th percentile", value = tor$averted_low), data.frame(parameter = tor$parameter, side = "97.5th percentile", value = tor$averted_high))
  c0 <- sens$central["averted"]; tl$parameter <- factor(tl$parameter, levels = rev(tor$parameter))
  p9 <- ggplot(tl, aes(value - c0, parameter, fill = side)) + geom_col(position = "identity", alpha = .8, width = .6) + geom_vline(xintercept = 0) +
    labs(title = "Tornado: effect on cumulative deaths averted (S3 vs BAU, 2025-2034)", subtitle = paste0("One-at-a-time at central values; central = ", round(c0), " deaths averted"),
         x = "Change in deaths averted", y = NULL, fill = NULL, caption = CAP) + theme_proj()
  save_fig(p9, "08_tornado_deaths_averted.png", 9, 6)
  rk <- sens$rank[seq_len(min(15, nrow(sens$rank))), ]; rk$parameter <- factor(rk$parameter, levels = rev(rk$parameter))
  p10 <- ggplot(rk, aes(deaths_averted_cum_S3, parameter, fill = group)) + geom_col() + geom_vline(xintercept = 0) +
    labs(title = "Parameter importance: Spearman rank correlation with deaths averted (S3 vs BAU)", x = "Spearman rho", y = NULL, fill = "Group", caption = "Global: all parameters varied jointly across Monte Carlo draws.") + theme_proj()
  save_fig(p10, "09_parameter_importance.png", 9, 6.5)
  # 11 policy scores
  sc <- pol$scores[!is.na(pol$scores$legal_score), ]
  ps <- rbind(data.frame(country = sc$country, measure = "Legal strength (smoke-free, cessation, tax)", value = sc$legal_score), data.frame(country = sc$country, measure = "Reported compliance", value = sc$compliance_score),
              data.frame(country = sc$country, measure = "Enforcement infrastructure", value = sc$enforcement_infra))
  p11 <- ggplot(ps, aes(country, value, fill = measure)) + geom_col(position = "dodge") + scale_y_continuous(limits = c(0, 1), labels = percent) +
    labs(title = "Policy implementation indicators (Armenia, Georgia, Ireland, Australia (2022 data))", subtitle = "Ordinal descriptors, not effect sizes; Australia and Ireland: WHO reports no smoke-free compliance score",
         x = NULL, y = "Score (0-1)", fill = NULL, caption = "Definitions in policy_comparison.R. Missing bars = not reported.") + theme_proj()
  save_fig(p11, "10_policy_implementation_scores.png", 9, 5.5)
  invisible(TRUE)
}
