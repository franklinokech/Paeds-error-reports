##########################################################
#
# Project         : Error Reporting - Site Machines
# Author(s)       : Morris Ogero
# Date            : 12-02-2016
# Organization    : KEMRI Wellcome Trust
# Maintainer      : Morris Ogero
# Department      : HSRG (Data & Analytics Team)
#
############################################################
rm(list = ls(all=TRUE))

# ---------------------------------------------------------------------------
# Helper: read config from environment (see .env / docker-compose.yml)
# ---------------------------------------------------------------------------
env_chr <- function(name, default = NULL) {
  v <- Sys.getenv(name, unset = NA_character_)
  if (is.na(v) || !nzchar(v)) default else v
}
env_num <- function(name, default = NULL) {
  v <- env_chr(name)
  if (is.null(v)) default else as.numeric(v)
}
env_lgl <- function(name, default = NULL) {
  v <- env_chr(name)
  if (is.null(v)) default else tolower(v) %in% c("true", "t", "1", "yes", "y")
}

start_time <- Sys.time()
message(sprintf("Hi, %s!\nError reporting approximately started at %s!",
                (if (.Platform$OS.type == "windows")
                  Sys.getenv("USERNAME") else
                    Sys.getenv("USER")
                )
                , format(start_time, "%I:%M %p [%A %e %B, %Y]")))

# ---------------------------------------------------------------------------
# Load packages
# ---------------------------------------------------------------------------
if (!"RedcapData" %in% rownames(installed.packages())) {
  stop("RedcapData is not installed in this image. Rebuild with the Dockerfile.")
}
if (packageVersion("RedcapData") != "1.1.1") {
  stop(sprintf("RedcapData %s found, expected 1.1.1. Rebuild with the Dockerfile.",
               packageVersion("RedcapData")))
}
message("Loading required packages...")
suppressPackageStartupMessages({
  library(RedcapData)
  library(data.table)
  library(stringr)
  library(magrittr)
  library(dplyr, warn.conflicts = F)
  library(parallel)
})
message("Packages attached!")

message("Setting and validating global options...")

# ---------------------------------------------------------------------------
# Parameters — all overridable via .env
# ---------------------------------------------------------------------------
end_date   <- Sys.Date()
interval   <- env_num("REPORT_INTERVAL", 1100)
start_date <- end_date - interval

# Set global options — secrets and endpoint come from .env
Sys.setenv(LD_LIBRARY_PATH = "/usr/lib/libreoffice/program")

api_url <- env_chr("REDCAP_API_URL", "http://nbo.kemri-wellcome.org/")
token   <- env_chr("REDCAP_API_TOKEN")
if (is.null(token) || !nzchar(token))
  stop("REDCAP_API_TOKEN is not set. Add it to .env and restart the container.")

local            <- env_lgl("LOCAL", FALSE)
chunked          <- env_lgl("CHUNKED", TRUE)
chunk_size       <- env_num("CHUNK_SIZE", 200)
id_var           <- env_chr("ID_VAR", "id")
date_var         <- env_chr("DATE_VAR", "date_today")
hosp_var         <- env_chr("HOSP_VAR", "hosp_id")
surrogate_id_var <- env_chr("SURROGATE_ID_VAR", "ipno")

# Hospital(s) to validate. Blank → validate all. Supports comma-separated IDs.
.hosp_env        <- env_chr("HOSP_TO_VALIDATE", "")
hosp_to_validate <- if (!nzchar(.hosp_env)) NA else as.numeric(strsplit(.hosp_env, ",")[[1]])

gui <- TRUE

if (chunked) stopifnot(is.numeric(chunk_size) && chunk_size > 0)
chunk_size <- as.integer(chunk_size)

message("Global options OK!")

# ---------------------------------------------------------------------------
# File paths
# ---------------------------------------------------------------------------
message("File system checking...")

# create a function to wrap file-allied functionality
file_system_checks <- function(file_path, create = FALSE, verify = TRUE, dir = FALSE, ...) {
  if (create && !file.exists(file_path)) {
    if (!file.exists(basename(file_path)))
      stopifnot(dir.create(basename(file_path), recursive = T))
    stopifnot(if (dir) dir.create(file_path) else file.create(file_path))
  }
  if (verify) stopifnot(file.exists(file_path))
  normalizePath(file_path)
}

# Project root comes from PROJECT_ROOT (set in docker-compose.yml), with a
# sensible fallback for local runs on Windows or Linux.
path_to_files <- Sys.getenv("PROJECT_ROOT", unset = NA_character_)
if (is.na(path_to_files) || !nzchar(path_to_files)) {
  path_to_files <- (if (.Platform$OS.type == "windows")
                      Sys.getenv("USERPROFILE") else
                        Sys.getenv("HOME")) %>%
    file.path("hsuApps", "error-reports") %>%
    gsub("\\\\", "/", .)
}
path_to_files <- file_system_checks(path_to_files)
message(sprintf("Project root: %s", path_to_files))

updates_location            <- file_system_checks(file.path(path_to_files, "upd.csv"), verify = FALSE)
custom_code_location        <- file_system_checks(file.path(path_to_files, "custom.R"), verify = FALSE)
exclusion_patterns_location <- file_system_checks(file.path(path_to_files, "exclude.R"), verify = FALSE)
# report_location             <- file_system_checks(file.path(path_to_files, "tmp", "ErrorReport.csv"),
#                                                    create = TRUE, verify = FALSE)
report_location <- file.path(path_to_files, "tmp", "ErrorReport.csv")
if (!dir.exists(dirname(report_location))) {
  dir.create(dirname(report_location), recursive = TRUE, showWarnings = FALSE)
}

message("File system OK!")

# ---------------------------------------------------------------------------
# Running the application
# ---------------------------------------------------------------------------
message("Running the application...")

# populate the global namespace with the regular expressions matching the exclusion criteria
source(exclusion_patterns_location)

# get ids and date of entry for data entered between the start and end period
ids_matching_dates <- tbl_df(get_redcap_data(
  api = api_url,
  token = token,
  content = "record",
  local = local,
  fields = c(id_var, date_var))
)
names(ids_matching_dates) <- c("id", "date")

ids_matching_dates %<>%
  mutate(date = as.Date(date)) %>%
  filter(date >= start_date & date <= end_date)
ids_matching_dates <- ids_matching_dates$id

if ((data_size <- length(ids_matching_dates)) == 0)
  stop("No data to validate!")

message(sprintf("%d records to validate...", data_size))

message("Pulling data from REDCap...")
if (chunked) {
  data_to_validate <- get_redcap_data(
    api = api_url,
    token = token,
    content = "record",
    local = local,
    ids_to_pull = ids_matching_dates
  )
} else {
  get_chunked_redcap_data(
    dataset_name = "data_to_validate",
    metadataset_name = "..meta_tmp..",
    api = api_url,
    token = token,
    content = "record",
    local = local,
    ids_to_pull = ids_matching_dates
  )
}
data_to_validate <- as.data.table(data_to_validate)

# get data and metadata
message("Getting & cleaning metadata...")
meta_data <- tbl_df(get_redcap_data(
  api = api_url,
  token = token,
  content = "metadata",
  local = local
))
metadata.formatted <- format_branching_logics(metadata = meta_data, data = data_to_validate)

# Clean metadata
metadata.formatted %<>%
  filter(
    field_type != "descriptive"
  ) %>%
  mutate(required_field = ifelse(field_type == "checkbox", TRUE, required_field)) %>%
  mutate_each(funs(remove_empties = ifelse((is.na(.) | str_trim(.) == ""), NA, .)))

if (exists("exclusion_patterns") && length(na.omit(exclusion_patterns))) {
  metadata.formatted %<>%
    mutate(`..to_exclude..` = grepl(paste0(str_trim(exclusion_patterns), collapse = "|"), field_name)) %>%
    filter(!`..to_exclude..`) %>%
    select(-`..to_exclude..`)
}
metadata.formatted <- as.data.table(metadata.formatted)
message("Metadata in memory!")

data_to_validate <- data.table(data_to_validate)
data_to_validate <- data_to_validate[, key := .I]
setkey(data_to_validate, key)

message("Data in memory!")

# ---------------------------------------------------------------------------
# Generating validation function code
# ---------------------------------------------------------------------------
message("Generating data validation code...")

# getting custom logic
if (file.exists(custom_code_location)) {
  custom_code <- readLines(custom_code_location, warn = F)
  custom_code <- custom_code[!(is.na(custom_code) | custom_code == "")]
  custom_code <- if (0 == length(custom_code)) NA else custom_code
} else {
  custom_code <- NA
}

# getting updates
updates <- if (file.exists(updates_location))
  RedcapData:::load_updates(read.csv(updates_location, stringsAsFactors = F)) else
    list()

# generate code and evaluate in current namespace
data_validation_code <- generate_data_validation_code(
  metadata.formatted,
  date_var,
  hosp_var,
  custom_code = custom_code,
  surrogate_id_var = surrogate_id_var,
  updates = "updates",
  updates_envir_depth = 1
)
eval(parse(text = data_validation_code))

message("Data validation code generated!")

# ---------------------------------------------------------------------------
# Validate data entry
# ---------------------------------------------------------------------------
message("Validating data (This might take a while)...")

# Cap workers so a small container doesn't get OOM-killed
n_workers <- max(1L, min(detectCores() * 2,
                         as.integer(env_num("R_WORKERS", 2))))

if (1 < length(chunks <- get_chunks(seq_len(nrow(data_to_validate)), chunk_size)) && chunked) {
  message("Validating in parallel (2 nodes per core)...")
  tryCatch({
    message(sprintf("** %d nodes spawned **", n_workers))
    cl <- makeCluster(n_workers)

    invisible(clusterEvalQ(cl, {
      # load relevant packages to cluster
      library(data.table)
      library(stringr)
      library(RedcapData)
      return(NULL)
    }))

    clusterExport(cl, c("validate_data_entry", "data_to_validate",
                        "hosp_to_validate", "updates", "metadata.formatted"))
    # Execute code in parallel
    error_report1 <- clusterApplyLB(
      cl,
      chunks,
      function(x) {
        data_to_validate[x, validate_data_entry(.SD,
                                                hosp_to_validate = hosp_to_validate,
                                                updates = updates,
                                                metadata = metadata.formatted),
                         by = key]
      }
    ) %>% rbindlist()
  }, error = function(e) {
    stop(sprintf("An error has occured.\nDetails:\n%s", paste0(e$message, collapse = "\n")))
  }, finally = {
    if (exists("cl")) {
      stopCluster(cl)
      rm(cl)
    }
  })
  message("DONE!")
} else {
  error_report1 <- data_to_validate[, validate_data_entry(.SD,
                                                          hosp_to_validate = hosp_to_validate,
                                                          updates = updates,
                                                          metadata = metadata.formatted),
                                    by = key]
}

# all variables with branching logic
# * exclude variables with ranges and required (have been validated above)
conditional_variables <- metadata.formatted[branching_logic != ""
                                            & field_type != 'descriptive'
                                            & required_field != "y"
                                            & (is.na(text_validation_max) | text_validation_max == '')
                                            & (text_validation_min == '' | is.na(text_validation_min))
                                            , (field_name)]

# Get variables that will be Assessed as a group [at least one]
admissionDiag <- conditional_variables[grepl('^dx1\\_|^dx2\\_', conditional_variables)]
dischDiag     <- conditional_variables[grepl('^dsc\\_dx1\\_|^dsc\\_dx2\\_', conditional_variables)]
admissionTrt  <- conditional_variables[grepl('^adm_rx[0-9]|^adm_rx', conditional_variables)]
dischargeTrt  <- conditional_variables[grepl('^dsc\\_rx[0-9]{1,}|^dsc\\_rx\\_[a-z]', conditional_variables)]
drugs2WksOnt  <- conditional_variables[grepl('drugs_2wks_[1-4]_ont|drugs_2wks_ont', conditional_variables)]
nonGrouping   <- conditional_variables[!(conditional_variables %in% c(admissionDiag,
                                                                      dischDiag,
                                                                      admissionTrt,
                                                                      dischargeTrt,
                                                                      drugs2WksOnt))]

error_report2 <- data_to_validate[, validate_data_in_branching_logic(rec = .SD
                                                ,ipno_var = surrogate_id_var
                                                ,dateOfEntry_var = date_var
                                                ,recordID_var = id_var
                                                ,hospitalID_var = hosp_var
                                                ,individual.vars = 'nonGrouping'
                                                ,metadataName = 'metadata.formatted'
                                                ,dataName = 'data_to_validate'
                                                ,validateTreatmentDates = T
                                                ,treatmentFormName = "treatment"
                                                ,dischargeDateVar = "date_discharge"
                                                ,admissionDateVar = "date_adm"
                                                ,n.groups = 5
                                                ,group.names = c('admissionDiag', 'dischDiag',
                                                                 'admissionTrt', 'dischargeTrt',
                                                                 'drugs2WksOnt')
)
, by = key]

error_report2[, key := NULL]
error_report2[, DateOfEntry := as.character(DateOfEntry)]
error_report1[, DateOfEntry := as.character(DateOfEntry)]

error_report <- data.table::rbindlist(list(error_report1, error_report2),
                                      use.names = T, fill = T)

message("Data validated!")

# ---------------------------------------------------------------------------
# Save error report and pop it open using default system app
# ---------------------------------------------------------------------------
message("Saving error report...")
write.csv(error_report, file = report_location, row.names = FALSE)

# Only try to open a viewer if a display is actually available.
# Inside the Docker container there is no GUI, so skip silently.
if (gui && (interactive() || nzchar(Sys.getenv("DISPLAY")))) {
  try(RedcapData::open_using_default_app(report_location), silent = TRUE)
} else {
  message(sprintf("Report written to %s", report_location))
}

message(sprintf("Error report located in \"%s\"!", report_location))

end_time <- Sys.time()
time_diff <-
  difftime(end_time, start_time, units = "mins") %>%
  as.numeric() %>%
  `*`(60) %>%
  round(0)
time_diff <- sprintf("%d minutes, %d seconds", (time_diff %/% 60), (time_diff %% 60))

message(sprintf("Error reporting approximately ended at %s!",
                format(end_time, "%I:%M %p [%A %e %B, %Y]")))
message(sprintf("The session took approximately %s", time_diff))
Sys.sleep(10)