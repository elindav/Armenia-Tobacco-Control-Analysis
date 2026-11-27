# Data

This folder contains the input data used by the analysis code. The code reads these files and never modifies them.

```
data/
├── raw/        input data (WHO, GLOBOCAN, national surveys, project surveys)
├── curated/    one table compiled by the team from documents it read
└── processed/  created by analysis/main.R on the first run (intermediate files)
```

A column-by-column description of the WHO/GLOBOCAN-derived files is in [`raw/data_dictionary.csv`](raw/data_dictionary.csv). Sources, licensing notes, and known gaps are in [`../documentation/data_sources.md`](../documentation/data_sources.md).

## Files in `raw/`

"Used in model" means the values feed the scenario model. "Loaded only" means the script reads and validates the file but no later calculation uses it. "Not read" means no script reads it.

| File | Content | Rows | Countries | Use in code |
|------|---------|-----:|-----------|-------------|
| `cancer_by_sex.csv` | GLOBOCAN 2024 totals by sex: population, new cases, deaths, rates | 3 | Armenia | Loaded and validated; population is stored in the baseline but not used in later calculations |
| `cancer_top_sites_by_sex.csv` | GLOBOCAN 2024 leading cancer sites by sex | 18 | Armenia | Used in model (lung cases by sex) |
| `cancer_by_site.csv` | GLOBOCAN 2024 cases and deaths by cancer site | 34 | Armenia | Used in model (lung deaths, total) |
| `tobacco_prevalence.csv` | Tobacco use by sex, age group, indicator, and source (WHO modelled estimates, SDG 3.a.1, STEPS, HSPA, HBSC) | 121 | Armenia, Australia, Sweden | Used in model (Armenia rows) and Figure 01 |
| `tobacco_policy.csv` | WHO MPOWER and smoke-free indicators (143 columns) | 3 | Armenia, Australia, Sweden | Used in model (Armenia compliance score and tax share); policy scores |
| `gtr2025_supplement.csv` | MPOWER indicators for Georgia and Ireland, transcribed from the WHO Global Tobacco Report 2025 profiles; includes derivation notes | 2 | Georgia, Ireland | Policy scores |
| `country_context.csv` | Population, FCTC dates, national tobacco-control agency, government spending | 3 | Armenia, Australia, Sweden | Loaded only |
| `tobacco_prices_taxes.csv` | Retail prices and tax structure by product | 16 | Armenia, Australia, Sweden | Loaded only |
| `tobacco_tax_revenue.csv` | Tobacco tax revenue | 3 | Armenia, Australia, Sweden | Loaded only |
| `tobacco_package_warnings.csv` | Health-warning requirements on packages | 9 | Armenia, Australia, Sweden | Not read |
| `SurveyArmenia.csv` | Armenian survey, Armenian-language responses | 65 | – | Descriptive summary only |
| `SurveyGeorgia.csv` | Georgian survey, Georgian/English/Russian responses | 72 | – | Not read (see below) |
| `data_dictionary.csv` | Column descriptions for the files above | 276 | – | Documentation |



## File in `curated/`

`policy_comparison.csv` (55 rows) is a standardised comparison of Armenia, Georgia, Ireland, and Australia (NSW). It was compiled by the team from the documents listed in [`../documentation/reference/source_verification_log.csv`](../documentation/reference/source_verification_log.csv). Each row separates legal provisions, enforcement infrastructure, and reported compliance, and has an `evidence_type`, a `source`, and a `verification_status`. Some rows are marked as read only in part, as press-only, or as not collected. Use the `verification_status` column before citing a row.

## Survey data and privacy

- The two survey files contain categorical answers to five questions plus a residency screening question. They contain **no names, contact details, free-text answers, or other direct identifiers.**
- The original files contained a response timestamp accurate to the second. Before publication this was reduced to the **date only** (column renamed from `Timestamp` to `Date`). No answer was changed, and no analysis uses the time of day.
- With small samples, combinations of answers can in principle be distinguishing. The files contain only a few coarse questions, but the team should confirm that respondents were told their answers could be published in anonymised form. This is not documented in the supplied materials.
- `SurveyGeorgia.csv` includes one respondent who answered "No" to the question "Do you live in Georgia?". No script in this repository processes the Georgian survey, so no eligibility filter has been applied. Any analysis of it should apply the residency screen and harmonise the answer variants (for example "დიახ / Yes" and "დიახ / Yes / Да").
- `SurveyArmenia.csv` is read by position (columns 3–7), so column order must not change.

