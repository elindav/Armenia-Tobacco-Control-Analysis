# Methodology

This document describes what the code in [`analysis/`](../analysis/) does. It follows the implementation, and each section names the script that contains it. Parameters that are assumptions are explained in [`assumptions.md`](assumptions.md).

## 1. Overview

The workflow has five stages, run in this order by `analysis/main.R`:

1. **Data import and validation** (`data_cleaning.R`): read the input files, check columns and value ranges, build the 2024 baseline, and estimate a relative business-as-usual (BAU) trend.
2. **Model checks** (`scenario_analysis.R`, `run_model_checks`): run the model once at central parameter values under all three scenarios and stop if any invariant fails.
3. **Monte Carlo simulation** (`simulation.R`): draw 5,000 parameter sets and run all three scenarios for each draw.
4. **Sensitivity analysis** (`sensitivity_analysis.R`).
5. **Outputs** (`policy_comparison.R`, `visualizations.R`, `write_all_tables` in `scenario_analysis.R`).

The model is a *scenario model*: it asks what would happen to smoking and lung cancer in Armenia if policies changed in specified ways, given stated assumptions. It is calibrated to a single baseline year and is not fitted to, or validated against, a time series.

## 2. Baseline inputs (`data_cleaning.R`)

| Input | Value | Source file |
|-------|-------|-------------|
| Lung cancer cases 2024, men / women | 1,170 / 343 (total 1,513) | `cancer_top_sites_by_sex.csv` |
| Lung cancer deaths 2024, both sexes | 1,270 | `cancer_by_site.csv` |
| Current cigarette smoking, adults 15+, men / women | 47.9% / 1.4% (WHO age-standardised modelled estimate, 2023, used as 2024) | `tobacco_prevalence.csv` |
| Smoke-free compliance score | 8 out of 10 | `tobacco_policy.csv` |
| Tobacco tax share of retail price | 48.9% | `tobacco_policy.csv` |

Lung cancer deaths by sex are not in the data. Only total deaths are used as the calibration anchor.

**BAU trend.** The only multi-year Armenian series in the data is SDG indicator 3.a.1 (any tobacco use, 5 survey points between 2007 and 2022). Its definition differs from cigarette smoking, so it is used only for a *relative* trend. For each sex, `log(prevalence)` is regressed on year; the BAU annual relative change `rho` has mean equal to **half** the fitted slope (a deliberate shrinkage toward zero) and a standard deviation equal to the larger of the standard error and 0.01 (men) or 0.02 (women). The fitted slopes are written to `data/processed/bau_trend_estimates.csv`.

## 3. Smoking model (`smoking_model.R`)

The model is run separately for men and women and tracks population *fractions* among adults aged 15 and over.

**States.**

- Never smokers, `N = 1 − ΣC − ΣF`.
- Current cigarette smokers `C_1…C_8`, in eight five-year bands of smoking duration (the last band is 35+ years).
- Former smokers `F_1…F_4`, by years since quitting (0–4, 5–9, 10–19, 20+). Annual probabilities of moving to the next band are 0.2, 0.2, 0.1, and 0.
- `X_1…X_4`: the duration-weighted excess-risk mass of former smokers, used by the cancer model.

**Annual transition.**

- A share `q_eff` of current smokers quit. A further proportion `extra_quit` of the remaining smokers quit (the price response, see Section 5).
- A share `i_eff` of never smokers start smoking and enter the first duration band.
- One fifth of each duration band moves to the next band each year.
- A share `m` of all groups leaves the adult population (death or ageing out) and is replaced by never smokers.

**Baseline hazards.** Quitting `q` is constant. Initiation is **calibrated** so that prevalence changes at the relative rate `rho` in the first year:

```
i = (rho + q + m) * C0 / N0          (capped at 0.2)
```

The hazards are then held constant, so prevalence converges smoothly rather than extrapolating a constant rate.

**Initial state.** Current smokers start at the WHO prevalence, former smokers at 14.2% (men) and 0.9% (women) from the 2016 WHO STEPS survey (a different definition and age range; see `assumptions.md`). The initial duration profile of current smokers is a quasi-stationary distribution given `q` and `m`, drawn from a Dirichlet distribution around that profile. The initial years-since-quitting profile of former smokers is a Dirichlet draw around (0.35, 0.25, 0.25, 0.15).

**A note on BAU behaviour.** Baseline male prevalence falls from about 48.0% to about 45.4% by 2034 although the estimated trend `rho` is close to zero. This follows from the model structure: former smokers start at 14.2% and accumulate as smokers quit (because the share who quit each year is constant), the never-smoker pool that feeds initiation shrinks accordingly, and so initiation falls. In other words, the initial former-smoker share is not in equilibrium with the quitting hazard. This is a property of the assumed initial state and hazards, not of observed Armenian trends. It affects all three scenarios equally, so it does not affect differences between scenarios.

## 4. Lung cancer model (`cancer_model.R`)

**Incidence.** The lung cancer rate in each sex is assumed proportional to a risk index built from the smoking exposure history:

```
I(t) = 1 + (RR − 1) · E(t)
E(t) = Σ psi(d_j) · C_j(t)  +  Σ D(y_b) · X_b(t)
psi(d) = min(1, (d / 35)^kappa)          duration (latency) weight of a current smoker
D(y)   = rinf + (1 − rinf) · 2^(−y / half)  slow, incomplete fall in risk after quitting
```

`RR` is the relative risk of lung cancer for a long-duration current smoker compared with a never smoker. The unknown rate in never smokers cancels when the projection is scaled to the 2024 baseline:

```
cases_s(t) = cases_s(2024) · cases_err · I(t) / I(2024) · A_s(t)
```

`cases_err` is a lognormal calibration error on GLOBOCAN incidence. `A_s(t) = (1 + g_s)^(t − 2024)` is the demographic factor for population ageing and growth, with `g` an uncertain annual growth rate (assumption). If a UN WPP file is supplied, `A` is computed from it instead, using a lung cancer age pattern proportional to `age^5` for ages 35 and over.

Because of the duration weights and the slow fall in risk after quitting, **reduced initiation helps cancer only decades later and quitting helps gradually**. This is why the scenarios avert few cases within ten years.

**Mortality** is modelled separately from incidence. Deaths in year `t` are a calibrated fraction `f` of lagged incident cases:

```
lagged_s(t) = w1 · cases_s(t) + w2 · cases_s(t−1) + w3 · cases_s(t−2)      (w ~ Dirichlet, mean 0.55/0.30/0.15)
deaths_m(t) = f_m · lagged_m(t);   deaths_f(t) = f_m · phif · lagged_f(t)
f_m = deaths_2024 · death_err / (lagged_m(2024) + phif · lagged_f(2024))
```

`f_m` is set so that 2024 total deaths reproduce the GLOBOCAN deaths (allowing for the error `death_err`). `phif` is the female-to-male case-fatality ratio; it is uncertain because deaths by sex are not available. No fixed mortality-to-incidence ratio is imposed. Draws with an implied fatality fraction above 0.98 are rejected. Cases in 2022 and 2023, needed for the lag, are assumed to be at the 2024 level deflated by ageing growth.

## 5. Scenarios and policy mechanics (`scenario_analysis.R`)

Policies change the *hazards* of the smoking model, never prevalence directly. Policy effects begin in 2026 (2025 values are identical in all scenarios). `k = year − 2026 + 1`.

| Scenario | Mechanism |
|----------|-----------|
| **S1 BAU** | No change. |
| **S2 Stricter enforcement** | Compliance gain `dc = phi · (9.5 − 8) · min(1, k/3)`. Quit hazard × `(1 + bsf · dc)`; initiation × `(1 − gsf · dc)`. `phi` is the share of the planned improvement that is delivered (mean 0.6). |
| **S3 Comprehensive package** | S2 plus the measures below. A ramp `r3 = phi3 · min(1, k/4)` is applied to non-price measures, and an overlap factor `omega` (mean 0.8) discounts them to limit double counting. |

S3 components:

- **Cessation support:** extra quit probability `omega · r3 · reach · eff`.
- **Mass media:** `omega · r3 · media` is added to the quit-hazard multiplier (which is `1 + bsf · dc` under S2).
- **Advertising and warnings:** initiation × `(1 − omega · r3 · [1 − (1 − ad)(1 − warn)])`.
- **Tax:** raises the tax share of the retail price from 48.9% to 60%. The price increase is `dP = tau · ((1 − 0.489)/(1 − 0.60) − 1)`, about 28% before pass-through `tau`. The participation elasticity is `|eps| · u`. Half of the prevalence response operates through extra quitting and half through reduced initiation. The tax effect phases in over four years.

The target compliance of 9.5 and the tax target of 60% (the WHO benchmark is 75%) are scenario assumptions.

## 6. Monte Carlo simulation (`simulation.R`)

`build_param_spec` is the single source of truth for uncertain parameters. It defines **33 scalar parameters** (15 Beta, 12 lognormal, 5 truncated normal, 1 uniform) plus **Dirichlet-distributed profiles** (duration of smoking, years since quitting, survival-lag weights). Every parameter's distribution, bounds, central value, and rationale are in [`results/tables/assumptions_parameters.csv`](../results/tables/assumptions_parameters.csv).

For each of the 5,000 draws:

1. Draw all parameters. Re-draw if the implied case-fatality fraction exceeds 0.98 in BAU.
2. Run the three scenarios with the **same** parameter draw (common random numbers).
3. Store prevalence (both sexes), cases and deaths (by sex and total).

`set.seed(20241125)` is called once at the start of the simulation. Results are summarised by year and scenario as mean, median, and the 2.5th and 97.5th percentiles (the "95% uncertainty interval"). **Cases and deaths averted** are computed within each draw as BAU minus scenario, for 2025–2034 cumulatively and for 2034 alone, and then summarised, with the share of draws in which the difference is positive.

Intervals describe **parameter** uncertainty only. Scenario uncertainty is represented by the three scenarios, and **structural** uncertainty is not sampled. The main structural simplifications are no age structure, no relapse after quitting, no differential smoker mortality, and policy effect sizes that are assumed rather than estimated.

## 7. Sensitivity analysis (`sensitivity_analysis.R`)

- **Global.** Spearman rank correlation between each sampled parameter (the 33 scalars plus five summaries of the Dirichlet profiles) and four outcomes: cumulative deaths averted under S3 and S2, BAU cases in 2034, and male prevalence in 2034 under S3. All parameters vary jointly. Output: [`results/sensitivity/sensitivity_rank_correlations.csv`](../results/sensitivity/sensitivity_rank_correlations.csv).
- **One at a time (tornado).** Each scalar parameter is moved to its 2.5th and 97.5th sampled percentile with all others at central values, and the effect on S3 cumulative deaths averted and BAU cases in 2034 is recorded. Output: [`results/sensitivity/sensitivity_tornado.csv`](../results/sensitivity/sensitivity_tornado.csv). At central parameter values, S3 averts about 61 deaths over 2025–2034.

## 8. Model checks (`run_model_checks`)

Before the simulation, the code verifies at central parameters that:

- all compartments lie in [0, 1] and sum to 1 for each sex;
- cases and deaths are non-negative and finite;
- 2024 male cases and total 2024 deaths are reproduced exactly;
- male prevalence is ordered S3 ≤ S2 ≤ S1 in 2034, and S3 male cases do not exceed BAU;
- all policy-effect multipliers are within their allowed ranges.

The run stops with an error if any check fails.

## 9. Policy comparison (`policy_comparison.R`)

The comparison of Armenia, Georgia, Ireland, and Australia is **descriptive**. It uses indicators available for every country, all reported by WHO:

- `legal_score` = mean of the MPOWER smoke-free, cessation, and taxation levels (each 0–3) divided by 3;
- `compliance_score` = WHO smoke-free compliance score / 10 (a self-reported rating, not an inspection statistic; not reported for Ireland and Australia);
- `enforcement_infra` = share of four smoke-free enforcement features present (fines required, fines on the establishment, dedicated funds, complaint system);
- `implementation_gap` = `legal_score − compliance_score`.

These are ordinal descriptors, not effect sizes, and should not be used to rank countries. MPOWER levels for Georgia and Ireland were derived by hand from the WHO legend (see `derivation_note` in `gtr2025_supplement.csv`); Ireland's cessation level is borderline. The full qualitative table is `data/curated/policy_comparison.csv`. The policy comparison is not an input to the quantitative model.

## 10. Survey summary

`data_cleaning.R` tabulates the five substantive questions of the Armenian survey (n = 65) as counts and percentages. This is descriptive only and is not used in any calibration. The Georgian survey is not processed by any script in this repository.
