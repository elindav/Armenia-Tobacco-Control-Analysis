# main.R -- runs the complete workflow, from the raw CSV files to the final tables and figures.
#
# USAGE (from the repository root):
#   Rscript analysis/main.R                 # full run: 5,000 Monte Carlo draws -> results/
#   N_SIM=500 Rscript analysis/main.R       # quick test run -> results/quick_test_n500/ (never overwrites results/)
# In RStudio: open Armenia-Tobacco-Control-Analysis.Rproj, then run source("analysis/main.R").
#
# Execution order (each script only defines functions; main.R calls them in this order):
#   data_cleaning.R        import + validation of data/raw/*.csv, baseline inputs, BAU trend estimate
#   smoking_model.R        sex-specific compartmental smoking model
#   cancer_model.R         exposure-history lung cancer model and mortality calibration
#   scenario_analysis.R    scenario definitions, policy mechanics, model checks, output tables
#   simulation.R           parameter specification (all assumptions) and the Monte Carlo engine
#   sensitivity_analysis.R global (Spearman) and one-at-a-time (tornado) sensitivity analysis
#   policy_comparison.R    comparative policy table and implementation scores
#   visualizations.R       all figures

# ---- 1. Locate the project root (all paths below are relative to it) ---------------------------
find_project_root <- function() {
  file_arg <- grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)
  if (length(file_arg) == 1) {                      # Rscript analysis/main.R (from any directory)
    script_dir <- dirname(normalizePath(sub("^--file=", "", file_arg)))
    return(normalizePath(file.path(script_dir, "..")))
  }
  if (file.exists(file.path("analysis", "main.R"))) return(normalizePath("."))   # source() from the repository root
  stop("Cannot locate the project root. Set the working directory to the repository root ",
       "(the folder that contains analysis/ and data/), or run: Rscript analysis/main.R", call. = FALSE)
}
PROJECT_ROOT <- find_project_root()
setwd(PROJECT_ROOT)

# ---- 2. Packages ---------------------------------------------------------------------------------
# ggplot2 >= 3.4.0 is needed (geom_line(linewidth = ...) is used in visualizations.R).
pkgs <- c("ggplot2", "scales")
miss <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
if (length(miss)) stop("Install packages first: install.packages(c(", paste0('"', miss, '"', collapse = ", "), "))")
suppressPackageStartupMessages({library(ggplot2); library(scales)})
if (packageVersion("ggplot2") < "3.4.0") stop("ggplot2 >= 3.4.0 is required (found ", as.character(packageVersion("ggplot2")), ")")

# ---- 3. Model configuration ----------------------------------------------------------------------
N_SIM <- as.integer(Sys.getenv("N_SIM", unset = "5000"))   # Monte Carlo draws (5000 = published run)
if (is.na(N_SIM) || N_SIM < 1) stop("N_SIM must be a positive integer")
SEED       <- 20241125   # random seed, set once at the start of run_simulation() (simulation.R)
START_YEAR <- 2024       # baseline year
END_YEAR   <- 2034       # end of the projection horizon
POLICY_START <- 2026     # first year in which scenario policies begin to take effect

# ---- 4. Input / output locations (relative to the project root) ------------------------------------
# A reduced run (N_SIM != 5000) is written to its own folder so it cannot overwrite the published results.
RESULTS_DIR <- if (N_SIM == 5000L) "results" else file.path("results", paste0("quick_test_n", N_SIM))
PATHS <- list(
  raw         = file.path("data", "raw"),            # original input files (never modified by the code)
  curated     = file.path("data", "curated"),        # hand-compiled team tables used as input
  processed   = file.path("data", "processed"),      # intermediate files written by the code
  figures     = file.path(RESULTS_DIR, "figures"),
  tables      = file.path(RESULTS_DIR, "tables"),
  simulations = file.path(RESULTS_DIR, "simulations"),
  sensitivity = file.path(RESULTS_DIR, "sensitivity"))
for (d in c(PATHS$processed, PATHS$figures, PATHS$tables, PATHS$simulations, PATHS$sensitivity))
  dir.create(d, recursive = TRUE, showWarnings = FALSE)

# ---- 5. Load function definitions -------------------------------------------------------------------
for (f in c("data_cleaning.R", "smoking_model.R", "cancer_model.R", "scenario_analysis.R",
            "simulation.R", "sensitivity_analysis.R", "policy_comparison.R", "visualizations.R"))
  source(file.path("analysis", f))

# ---- 6. Run the workflow ----------------------------------------------------------------------------
message("Project root: ", PROJECT_ROOT, " | N_SIM = ", N_SIM, " | outputs -> ", RESULTS_DIR)
dat <- load_all_data()                         # data_cleaning.R
run_model_checks(dat)                          # scenario_analysis.R (deterministic unit checks; stops on failure)
sim <- run_simulation(dat, N_SIM, SEED)        # simulation.R
sens <- run_sensitivity(dat, sim)              # sensitivity_analysis.R
pol <- build_policy_comparison()               # policy_comparison.R
make_all_figures(dat, sim, sens, pol)          # visualizations.R
write_all_tables(dat, sim, sens, pol)          # scenario_analysis.R
message("Done. Outputs written to ", RESULTS_DIR, "/ (figures, tables, simulations, sensitivity).")
