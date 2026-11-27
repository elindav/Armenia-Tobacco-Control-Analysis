# policy_comparison.R -- standardised comparative policy table + transparent implementation scores.
# The table (data/curated/policy_comparison.csv) separates LEGAL provisions, ENFORCEMENT infrastructure and reported COMPLIANCE, and flags every
# cell whose source has not been verified. Additional countries (e.g. Ireland) are added by dropping a CSV into data/raw/policy_modules/.
build_policy_comparison <- function() {
  f_tab <- file.path(PATHS$curated, "policy_comparison.csv"); require_file(f_tab)
  tab <- read.csv(f_tab, stringsAsFactors = FALSE)
  mods <- list.files(file.path(PATHS$raw, "policy_modules"), pattern = "\\.csv$", full.names = TRUE)
  for (f in mods) { m <- read.csv(f, stringsAsFactors = FALSE)
    if (!identical(names(m), names(tab))) stop("Module ", f, " must have columns: ", paste(names(tab), collapse = ", "))
    tab <- rbind(tab, m) }
  f_pol <- file.path(PATHS$raw, "tobacco_policy.csv"); f_sup <- file.path(PATHS$raw, "gtr2025_supplement.csv")
  require_file(f_pol); require_file(f_sup)
  pol <- read.csv(f_pol, stringsAsFactors = FALSE, na.strings = c("NA", ""))
  sup <- read.csv(f_sup, stringsAsFactors = FALSE)   # Georgia, Ireland: transcribed from WHO GTR 2025 profiles
  # Scores use only a CORE set of indicators that exist for every country (so scores are comparable); all inputs are WHO-reported:
  #  legal_score       = mean(smoke-free level, cessation level, taxation level) / 3   (MPOWER levels 0-3; levels for GE/IE derived from the WHO legend, see derivation_note)
  #  compliance_score  = WHO smoke-free compliance score / 10  (self-reported rating, not an inspection statistic)
  #  enforcement_infra = share of 4 binary smoke-free enforcement features present (fines required, fines on establishment, dedicated funds, complaint system)
  #  implementation_gap = legal_score - compliance_score (positive = legal strength exceeds reported compliance). Ordinal descriptors, NOT effect sizes.
  cols <- c("country", "year", "mp_smoke_free_level", "mp_cessation_level", "mp_taxation_level", "sf_compliance_score",
            "sf_fines_required", "sf_fines_on_establishment", "sf_enforcement_funds", "sf_complaint_system")
  pol <- pol[pol$country %in% c("Armenia", "Australia"), cols]
  pol <- rbind(pol, sup[, cols])
  sc <- data.frame(country = pol$country, year = pol$year,
    legal_score = rowMeans(cbind(pol$mp_smoke_free_level, pol$mp_cessation_level, pol$mp_taxation_level) / 3),
    compliance_score = pol$sf_compliance_score / 10,
    enforcement_infra = rowMeans(cbind(pol$sf_fines_required, pol$sf_fines_on_establishment, pol$sf_enforcement_funds, pol$sf_complaint_system)))
  sc$implementation_gap <- sc$legal_score - sc$compliance_score
  extra <- setdiff(unique(tab$country), sc$country)
  if (length(extra)) sc <- rbind(sc, data.frame(country = extra, year = NA, legal_score = NA, compliance_score = NA, enforcement_infra = NA, implementation_gap = NA))
  sc$note <- ifelse(is.na(sc$legal_score), "No quantitative inputs in uploaded data; qualitative rows only", "Computed from WHO-reported inputs (tobacco_policy.csv, gtr2025_supplement.csv); compliance score missing = not reported by WHO")
  list(table = tab, scores = sc)
}
