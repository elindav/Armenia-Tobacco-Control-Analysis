# Data Sources

This document lists the sources behind the files in [`data/`](../data/), how much of each source was actually read, and what is known about redistribution. File-level details are in [`data/README.md`](../data/README.md). The full reference list is in [`reference/references.csv`](reference/references.csv) and the source-by-source verification record is in [`reference/source_verification_log.csv`](reference/source_verification_log.csv).

## 1. Quantitative data

| Source | Used for | Where in the repository | How to obtain |
|--------|----------|-------------------------|---------------|
| **GLOBOCAN 2024** (IARC / WHO, Global Cancer Observatory) | Lung cancer cases and deaths for Armenia by sex and site; Armenian population by sex | `data/raw/cancer_by_sex.csv`, `cancer_by_site.csv`, `cancer_top_sites_by_sex.csv`, `country_context.csv` | https://gco.iarc.fr (Cancer Today) |
| **WHO modelled estimates of tobacco use** (age-standardised, 2023) | 2024 baseline smoking prevalence | `data/raw/tobacco_prevalence.csv` (`source_type = who_model`) | WHO Global Health Observatory / data.who.int |
| **SDG indicator 3.a.1** (age-standardised tobacco use) | Historical any-tobacco series used for the BAU trend | `data/raw/tobacco_prevalence.csv` (`source_type = sdg`) | WHO / UN SDG database |
| **National surveys**: WHO STEPS, HSPA, HBSC | Context; former-smoker shares (STEPS 2016) | `data/raw/tobacco_prevalence.csv`; former-smoker shares via the FCTC Needs Assessment | WHO STEPS survey reports for Armenia; HBSC and HSPA publications |
| **WHO Global Tobacco Report 2025** (MPOWER country profiles) | Policy indicators: smoke-free level, compliance score, cessation, taxation, fines | `data/raw/tobacco_policy.csv`, `gtr2025_supplement.csv` | WHO country profiles (Armenia, Georgia, Ireland) |
| WHO price and tax data; tobacco tax revenue; package-warning data | Prices, tax structure, revenue, health-warning requirements | `data/raw/tobacco_prices_taxes.csv`, `tobacco_tax_revenue.csv`, `tobacco_package_warnings.csv` | WHO Global Tobacco Report data |
| **WHO FCTC Armenia Needs Assessment (August 2020)** | Legal timeline, enforcement bodies, STEPS 2016 former-tobacco-use (men 14.2%, women 0.9%), tax, cessation, funding | Values entered in `simulation.R`; documented in `reference/` | https://fctc.who.int |
| **Project surveys** (Armenia n = 65; Georgia n = 72) | Descriptive perceptions of smoke-free compliance and policy preferences | `data/raw/SurveyArmenia.csv`, `SurveyGeorgia.csv` | Collected by the team |

The data dictionary does not record, for every file, which exact WHO or IARC product it was extracted from, or the download date. This should be added by the team (see Section 4).

## 2. Policy and legal sources

The curated comparison table `data/curated/policy_comparison.csv` draws on, among others: Armenian legislation (the 2020 Tobacco Control Law and Article 173.2 of the Administrative Offences Code, via ARLIS), the Armenian government's description of the Health and Labour Inspection Body, Tobacco Control Laws (tobaccocontrollaws.org) enforcement summaries, a mixed-methods evaluation of the Armenian dining-venue smoking ban (Grigoryan et al., 2023, *Tobacco Induced Diseases*), NSW Health enforcement pages, and Health Service Executive (Ireland) pages and a 2025 observational study of enforcement in Ireland (Houghton and Lombard). Each row of the table records its own source and verification status.

## 3. Methods literature used for model structure and priors

Doll and Peto (1978); Peto et al. (2000); Chaloupka and Warner (2000); IARC Handbooks of Cancer Prevention, volume 14 (2011); Cochrane reviews on smoke-free legislation (Frazer et al., 2016) and on pharmacological cessation interventions (Cahill et al., 2013; a 2023 network meta-analysis). Full references and what was read of each are in `reference/references.csv`. Several of these were read only as abstracts or summaries; the log states which.

## 4. Known gaps and unverified items

These should be resolved or stated explicitly before the repository is shared as a finished record.

- **Provenance of each data file.** Original download URLs, product names, and dates are not recorded for the WHO and GLOBOCAN extracts.
- **Sources not read in full** (from the verification log): the later amendments to the Armenian tobacco law (HO-509-N, HO-38-N); Article 173.2 of the Administrative Offences Code was read only as an excerpt; for Georgia, three sources were not opened and the law on matsne.gov.ge was read only in part; for Ireland, the full text of Houghton and Lombard (2025) and the Irish statutes. Inspection data for Georgia were not found.
- **Fine amounts for Georgia** come from press reports that disagree with each other.
- **Armenian fines.** The documents disagree on whether fines fall on establishments (WHO: no fines on establishment) or on businesses (Grigoryan et al., 2023). The record explains the difference by Article 173.2, which fines officials and individuals; the article text should be checked on arlis.am.
- **Georgia and Ireland MPOWER levels** were derived by hand from the WHO legend; Ireland's cessation level is borderline, and WHO reports no compliance score for Ireland.
- **One reference** (a 2023 Cochrane network meta-analysis, CD015226) has no author list in `references.csv`; it is marked to be completed from PubMed.
- **Some documentation files contain working notes** written during the build (for example, "a source I read"). They are preserved unchanged for traceability and may need editing before final submission.
- **The Georgian survey** is included but no script analyses it, and the survey instrument and sampling method are not documented in the supplied materials.

## 5. Licensing and redistribution

This is a summary of publicly stated terms and is **not legal advice**. The team should confirm that it is comfortable with the following before making the repository public.

- **WHO.** WHO publications are generally made available under the Creative Commons Attribution-NonCommercial-ShareAlike 3.0 IGO licence (CC BY-NC-SA 3.0 IGO), and datasets on data.who.int under CC BY 4.0 with additional WHO terms, unless stated otherwise. Both require attribution and a statement that WHO does not endorse the work. The non-commercial and share-alike conditions apply to the WHO-derived files.
- **IARC / GLOBOCAN.** IARC's terms of use allow extracts of its materials to be reproduced for research, private study, educational, or non-commercial purposes with limited circulation, provided the source is acknowledged. Reproduction of substantial portions, or for wider circulation, requires written permission, and systematic retrieval of data to compile a database is prohibited. The three GLOBOCAN files here are small, Armenia-only extracts, and a public repository is arguably wider circulation. If there is doubt, the files can be removed from the repository and replaced with instructions for downloading them from https://gco.iarc.fr (the code stops with a clear message if they are absent), or permission can be requested from IARC.
- **Project surveys.** The survey data were collected by the team. They contain no direct identifiers, and timestamps have been reduced to dates (see `data/README.md`). The team should confirm that respondents were informed that anonymised responses could be published.
- **Code and original documentation.** No licence has been applied. A licence should be chosen by the authors (and, if required, by their institution) before publication.

## 6. Suggested citation of sources

Please cite the original data providers, not this repository, when using the underlying data: IARC for GLOBOCAN (Global Cancer Observatory, https://gco.iarc.fr) and the World Health Organization for the tobacco data (WHO Global Tobacco Report 2025; WHO Global Health Observatory). Use the access date of your own download.
