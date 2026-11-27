# Changes Made to the Original Code

The original project folder (`Armenia_Tobacco_Model`) was reorganised into this repository. The aim was to change **only** file locations, error handling, and project plumbing, and to leave the mathematics, assumptions, and random-number logic untouched.

## Unchanged files

These four scripts are **identical** to the originals (verified by byte comparison):

- `analysis/smoking_model.R`
- `analysis/cancer_model.R`
- `analysis/simulation.R` (parameter specification and Monte Carlo engine, including `set.seed(seed)`)
- `analysis/sensitivity_analysis.R`

## Changed files

| File | Change | Reason |
|------|--------|--------|
| `analysis/main.R` | Rewritten. Locates the project root itself (`Rscript analysis/main.R` works from any directory; RStudio uses the `.Rproj`). Defines a `PATHS` list for all input and output folders. Reads `N_SIM` from an environment variable (default 5000). Quick test runs (`N_SIM` not 5000) write to `results/quick_test_n<N>/`. Sources scripts from `analysis/`. Checks `ggplot2 >= 3.4.0`. | The original sourced scripts by bare file name from the working directory. A quick test would have overwritten the published outputs. The original also created an unused `outputs/reports` folder |
| `analysis/main.R` | `dplyr` and `tidyr` are no longer loaded. | Neither package is used by any script (checked by searching for their functions and pipes). Fewer dependencies |
| `analysis/main.R` | `SEED`, `START_YEAR`, `END_YEAR`, `POLICY_START` kept with the original values and documented. | Unchanged values |
| `analysis/data_cleaning.R` | Added `require_file()`; `read_raw()` uses `PATHS$raw`; processed output and optional inputs use `PATHS`. | Relative paths from one place; clear error message (including the working directory) for a missing file |
| `analysis/policy_comparison.R` | Reads the curated table from `data/curated/`; added missing-file checks before the three direct `read.csv` calls. Read arguments are unchanged. | The original had a check for one file but not for `tobacco_policy.csv` or `gtr2025_supplement.csv` |
| `analysis/scenario_analysis.R` | Output paths use `PATHS` (simulation summaries, sensitivity tables, and other tables go to separate folders). Removed two unused lines (`wpp <- NULL` in `run_model_checks`, an unused helper function `tot` in `write_all_tables`). | New folder layout; dead code |
| `analysis/visualizations.R` | `ggsave` path uses `PATHS$figures`. | New folder layout |

## Moved or renamed files

| Original | New location |
|----------|--------------|
| `*.R` | `analysis/` (names unchanged) |
| `data/raw/*.csv` | `data/raw/` (contents unchanged, except the survey timestamps below) |
| `policy_comparison.csv` | `data/curated/policy_comparison.csv` (hand-compiled input, not raw data) |
| `outputs/figures/*.png` | `results/figures/` |
| `outputs/tables/year_by_year_results.csv`, `averted_vs_bau.csv`, `simulation_diagnostics.csv` | `results/simulations/` |
| `outputs/tables/sensitivity_*.csv` | `results/sensitivity/` |
| other `outputs/tables/*.csv` | `results/tables/` |
| `assumptions.csv`, `effect_size_sources.csv`, `references.csv`, `source_verification_log.csv` | `documentation/reference/` |

## Data changes

- `SurveyArmenia.csv` and `SurveyGeorgia.csv`: the `Timestamp` column (accurate to the second) was replaced by `Date` (date only). All answers are unchanged. The Armenian survey is read by column position, so the summary is unaffected.

## Files not carried over

`.Rhistory`, `.Rproj.user/`, `.DS_Store`, `__MACOSX/`, and the original `README.md` and `Armenia_Tobacco_Model.Rproj`. The original `README.md` stated that the code had not been run and that no results existed, which no longer matched the folder (results are present); its model description has been incorporated into `methodology.md` and `assumptions.md`. A new `.Rproj` was written without user-specific state.

## Observations that were left unchanged

- `data_cleaning.R` loads `country_context.csv`, `tobacco_prices_taxes.csv`, and `tobacco_tax_revenue.csv`, but no later calculation uses them. `tobacco_package_warnings.csv` is not read.
- No script analyses `SurveyGeorgia.csv`.
- `data_limitations()` (in `scenario_analysis.R`) refers to policy rows marked "NOT VERIFIED", but no row in the policy table uses that wording; the statuses are phrased differently (for example "Not collected", "Press only, inconsistent"). The text appears in the pre-generated `results/tables/data_limitations.csv`, so it was not edited.
- The result list from `run_simulation()` contains `arr_tot`, an alias of `arr`.
- The original code is written as dense one-line statements. It was not restyled, because the changes could not be tested by re-running R.

## Testing performed

R was not available when this repository was prepared, so the reorganised workflow was **not executed**. What was checked:

- Bracket and quote balance in all nine scripts.
- Every `PATHS$` key used in any script is defined in `main.R`; every sourced script exists; every input CSV named in the code exists in `data/raw/` or `data/curated/`.
- No absolute paths and no references to the old `outputs/` folder remain in the code.
- The pre-generated results were cross-checked: the trend parameters in `results/tables/assumptions_parameters.csv` match an independent recalculation from `data/raw/tobacco_prevalence.csv`, and the headline numbers in the README match the tables in `results/`.

**Recommended next step:** run `Rscript analysis/main.R` once and compare the regenerated `results/` with the committed version.
