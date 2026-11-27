# Assumptions

The model separates three kinds of input: **observed data** (taken from the input files), **assumptions** (chosen by the team, with or without indirect literature support), and **modelled estimates** (outputs, or modelled inputs such as GLOBOCAN incidence). This document lists the inputs and states for each one which kind it is.

Every sampled parameter, with its distribution, bounds, central value, and rationale, is in [`results/tables/assumptions_parameters.csv`](../results/tables/assumptions_parameters.csv) (written by the code from `analysis/simulation.R`). The literature behind the effect sizes is in [`reference/effect_size_sources.csv`](reference/effect_size_sources.csv). The overall assumption register is in [`reference/assumptions.csv`](reference/assumptions.csv).

## 1. Observed or externally reported inputs

| Input | Value | Caveat |
|-------|-------|--------|
| Lung cancer cases 2024 (men / women) | 1,170 / 343 | GLOBOCAN estimate; modelled for Armenia, not registry counts |
| Lung cancer deaths 2024 (total) | 1,270 | GLOBOCAN estimate; no deaths by sex available |
| Current cigarette smoking, 15+ (men / women) | 47.9% / 1.4% | WHO age-standardised *modelled* estimate for 2023, used as 2024. Female smoking may be under-reported |
| Former tobacco users (men / women) | 14.2% / 0.9% | WHO STEPS 2016, ages 18–69, *any tobacco* (including smokeless). Definition, age range, and year differ from the baseline; sampled with an allowance for this |
| Smoke-free compliance score | 8 out of 10 | WHO-reported rating, not an inspection statistic |
| Tax share of retail price | 48.9% | WHO Global Tobacco Report 2025 profile |
| BAU relative trend | Half the log-linear slope of the SDG 3.a.1 series | The series measures *any tobacco use*; used only for the trend |

## 2. Structural assumptions

- Adults aged 15 and over, by sex, with **no age structure**. Age-specific smoking histories were not available.
- Smoking is represented by **current cigarette smoking**. Other indicators (any tobacco, daily smoking, HSPA) have different definitions and are not merged.
- **No relapse** after quitting and **no differential mortality** of smokers.
- Annual exit from the adult population (`m`) is replaced by never-smoking entrants.
- Hazards are held constant after the first year, so prevalence converges rather than extrapolating a constant rate.
- Lung cancer rate is proportional to a risk index built from exposure history. The rate in never smokers is unknown and cancels in the calibration to 2024.
- Deaths are a lagged, calibrated fraction of incident cases; draws implying a case-fatality fraction above 0.98 are rejected.
- Lung cancer cases in 2022 and 2023, needed for the survival lag, are assumed equal to the 2024 level deflated by ageing growth.
- Population ageing and growth increase cases by an uncertain annual factor (about 1.0% per year for men and 1.5% for women) unless a UN WPP file is supplied.

## 3. Scenario constants

| Constant | Value | Status |
|----------|-------|--------|
| Policy start year | 2026 | Assumption; no effect in 2025 |
| Enforcement phase-in | 3 years | Assumption |
| Tax and other measures phase-in | 4 years | Assumption |
| S2 compliance target | 9.5 out of 10 | Assumption (closes 75% of the gap to full compliance) |
| S3 tax share target | 60% of retail price | Assumption (the WHO benchmark is 75%); implies a price rise of about 28% before pass-through |

## 4. Parameter assumptions and their evidential support

The evidential status below follows [`reference/effect_size_sources.csv`](reference/effect_size_sources.csv). "Assumption" means the team found no source that supports the specific value. The values and uncertainty ranges are in the parameter table linked above.

| Parameter(s) | Meaning | Status |
|--------------|---------|--------|
| `q_m`, `q_f` | Annual quit probability among smokers (0.03 / 0.04) | **Assumption.** STEPS 2016 reports quit attempts and quit ratios, which cannot be converted to an annual probability |
| `rho_m`, `rho_f` | BAU relative annual change in prevalence | Derived from data (shrunk by 50%); definition differs |
| `RR_m`, `RR_f`, `kappa` | Relative risk of lung cancer in smokers (15 / 12) and duration exponent (3) | Consistent with the literature in a loose sense (Doll & Peto 1978); the RR values do not come from a source the team read |
| `half`, `rinf` | Half-life (8 years) and irreducible share (0.15) of excess risk after quitting | **Not calibrated.** Peto et al. 2000 gives a pattern to which they should be fitted before the cessation benefit is relied upon |
| `psi_f0` | Mean duration weight of baseline former smokers | **Assumption** |
| `g_m`, `g_f` | Annual ageing/growth factor for cases | **Assumption**; UN WPP data not supplied |
| `phif`, `cases_err`, `death_err` | Female:male case-fatality ratio; error on GLOBOCAN incidence and deaths | Assumed uncertainty; incidence is given a larger error because it is modelled |
| `phi`, `phi3` | Share of planned enforcement and of additional S3 measures actually implemented | **Assumption** |
| `bsf`, `gsf` | Effect of one compliance point on quitting (+4%) and initiation (−2%) | **Assumption with weak support.** A Cochrane review (Frazer et al. 2016) finds clear effects of smoke-free laws on secondhand smoke exposure, but inconsistent effects on smoking prevalence. The distribution can only give a benefit, so **S2 is probably optimistic** |
| `eps_abs` | Absolute price elasticity of cigarette demand (0.5) | Literature-consistent (secondary citation of IARC Handbook 14); no Armenian estimate |
| `u` | Share of the elasticity operating through participation (0.5) | At the upper end of the evidence found (US-based); a lower value (about 0.3) is a suggested sensitivity run |
| `tau` | Pass-through of tax increase to retail price (0.85) | **Assumption** |
| `eff` | Absolute increase in sustained quitting among those treated (0.08) | Consistent with trial efficacy (Cochrane network meta-analyses); effect in Armenian practice is probably lower |
| `reach`, `media`, `ad`, `warn`, `omega` | Cessation reach, media, advertising, warning effects, overlap discount | **Assumption** |

The sensitivity analysis shows that the price-elasticity parameters, the half-life of risk after quitting, and the enforcement effect on quitting have the most influence on the results. Several of these are among the weakest-supported inputs. Results should be read with that in mind.

## 5. What is not modelled

- Age-specific results and cohort effects.
- Relapse, switching to or from other nicotine products (heated tobacco, e-cigarettes, smokeless tobacco).
- Differences by region, income, or education.
- Illicit trade and cross-border purchasing, and changes in tax revenue.
- Costs of policies or health-care costs of lung cancer.
- Causal effects of policies observed in other countries. Georgia, Ireland, and Australia are described, not used as controls.
