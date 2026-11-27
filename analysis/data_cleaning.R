# data_cleaning.R -- import original files, validate columns, build baseline inputs.
# Sourced by main.R, which defines PATHS (input/output folders, relative to the project root).

# Stop with a clear message if an input file is missing.
require_file <- function(path) {
  if (!file.exists(path))
    stop("Missing input file: ", path, " (working directory: ", getwd(), "). See data/README.md for the expected files.", call. = FALSE)
  invisible(path)
}

read_raw <- function(f) {
  p <- file.path(PATHS$raw, f)
  require_file(p)
  read.csv(p, stringsAsFactors = FALSE, na.strings = c("NA", ""), fileEncoding = "UTF-8", check.names = FALSE)
}
need_cols <- function(df, cols, nm) {
  m <- setdiff(cols, names(df)); if (length(m)) stop(nm, " lacks columns: ", paste(m, collapse = ", "))
}

load_all_data <- function() {
  prev <- read_raw("tobacco_prevalence.csv")
  need_cols(prev, c("country","year","sex","age_group","indicator","measure","value_pct","source","source_type"), "tobacco_prevalence")
  prev$value_pct <- as.numeric(prev$value_pct)
  prev <- prev[prev$country == "Armenia", ]
  if (any(prev$value_pct < 0 | prev$value_pct > 100, na.rm = TRUE)) stop("Prevalence outside 0-100")

  cs <- read_raw("cancer_by_sex.csv"); need_cols(cs, c("sex","population","new_cases","deaths"), "cancer_by_sex")
  top <- read_raw("cancer_top_sites_by_sex.csv"); need_cols(top, c("sex","cancer_site","new_cases"), "cancer_top_sites_by_sex")
  site <- read_raw("cancer_by_site.csv"); need_cols(site, c("cancer_site","new_cases","deaths"), "cancer_by_site")
  ctx <- read_raw("country_context.csv"); pol <- read_raw("tobacco_policy.csv")
  px <- read_raw("tobacco_prices_taxes.csv"); tax <- read_raw("tobacco_tax_revenue.csv")

  lung_sex <- top[top$cancer_site == "Lung" & top$sex %in% c("male","female"), ]
  lung_all <- site[site$cancer_site == "Lung", ]
  if (nrow(lung_sex) != 2 || nrow(lung_all) != 1) stop("Lung rows not found as expected")
  cases_m <- lung_sex$new_cases[lung_sex$sex == "male"]; cases_f <- lung_sex$new_cases[lung_sex$sex == "female"]
  if (cases_m + cases_f != lung_all$new_cases) warning("Sex-specific lung cases do not sum to total")
  # NB: lung DEATHS by sex are NOT in the uploaded files -> only total deaths are used as the anchor.
  base <- list(
    cases_m = cases_m, cases_f = cases_f, deaths_total = lung_all$deaths,
    pop_m = cs$population[cs$sex == "male"], pop_f = cs$population[cs$sex == "female"],
    # WHO age-standardised modelled estimates, current CIGARETTE smoking, 15+, 2023 (used as 2024 baseline)
    cig_m = prev$value_pct[prev$indicator=="cigarette_smoking" & prev$measure=="current" & prev$sex=="male" & prev$source_type=="who_model"]/100,
    cig_f = prev$value_pct[prev$indicator=="cigarette_smoking" & prev$measure=="current" & prev$sex=="female" & prev$source_type=="who_model"]/100)
  if (length(base$cig_m) != 1 || length(base$cig_f) != 1) stop("WHO cigarette prevalence rows not unique")

  # Historical any-tobacco series (SDG 3.a.1). DIFFERENT DEFINITION from cigarette smoking:
  # used only to estimate the *relative* trend, never combined with cigarette levels.
  hist_any <- prev[prev$indicator == "any_tobacco_use" & prev$source_type == "sdg" & prev$sex %in% c("male","female"), c("year","sex","value_pct")]
  trend <- do.call(rbind, lapply(c("male","female"), function(s) {
    d <- hist_any[hist_any$sex == s, ]; fit <- lm(log(value_pct) ~ year, d); sm <- summary(fit)$coefficients
    data.frame(sex = s, slope = sm["year","Estimate"], se = sm["year","Std. Error"], n = nrow(d))
  }))
  pol_arm <- pol[pol$country == "Armenia", ]
  survey <- summarise_survey()
  hist_all <- prev[prev$sex %in% c("male","female") & prev$age_group %in% c("15+") & prev$indicator %in% c("any_tobacco_use","cigarette_smoking","tobacco_smoking"), ]
  out <- list(prev = prev, base = base, trend = trend, hist_any = hist_any, hist_all = hist_all, policy_arm = pol_arm,
              policy_all = pol, prices = px, tax = tax, ctx = ctx, survey = survey, lung_all = lung_all)
  write.csv(trend, file.path(PATHS$processed, "bau_trend_estimates.csv"), row.names = FALSE)
  out
}

# Descriptive summary of the group's convenience survey (Armenian). Columns addressed by position (long text headers).
summarise_survey <- function() {
  f <- file.path(PATHS$raw, "SurveyArmenia.csv"); if (!file.exists(f)) return(NULL)   # optional input
  s <- read_raw("SurveyArmenia.csv")
  if (ncol(s) < 7) return(NULL)
  qs <- c(current_user = 3, secondhand_30d = 4, saw_violation_30d = 5, perceived_compliance = 6, most_helpful_measure = 7)
  do.call(rbind, lapply(names(qs), function(n) {
    t <- table(s[[qs[[n]]]], useNA = "ifany")
    data.frame(question = n, response = names(t), n = as.integer(t), pct = round(100 * as.integer(t) / nrow(s), 1))
  }))
}

# OPTIONAL: UN WPP 2024 age-by-sex file supplied locally -> demographic ageing factor.
# Expected file data/raw/wpp_armenia_age_sex.csv with columns year, sex ("male"/"female"), age (0..100), pop.
# Lung cancer age pattern is approximated by rate ~ age^5 for ages >= 35 (Armitage-Doll shape; an assumption).
wpp_ageing_factor <- function() {
  f <- file.path(PATHS$raw, "wpp_armenia_age_sex.csv"); if (!file.exists(f)) return(NULL)   # optional input
  w <- read.csv(f); need_cols(w, c("year","sex","age","pop"), "wpp_armenia_age_sex")
  w <- w[w$age >= 35, ]; w$wt <- w$pop * w$age^5
  a <- aggregate(wt ~ year + sex, w, sum)
  a$factor <- ave(a$wt, a$sex, FUN = function(x) x / x[1]); a
}
