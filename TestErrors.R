#!/usr/bin/env R

# Set path
rm(list = ls(all.names = T))
message("Setting path to files...")

pathToFiles <- if (.Platform$OS.type == "windows") Sys.getenv("USERPROFILE") else Sys.getenv("HOME")
pathToFiles <- gsub("\\\\", "/", file.path(pathToFiles, "hsuApps","error-reports"))
if (!file.exists(pathToFiles)) stop("Error report files could not be found")

message(paste0("Path set to \"", pathToFiles, "\"!"))

# Check files

message("Checking availability of required files...")

updatesLocation <- file.path(pathToFiles, "upd.csv")
if (!file.exists(updatesLocation)) stop("Updates file not found")
customCodeLocation <- file.path(pathToFiles, "custom.R")
if (!file.exists(customCodeLocation)) stop("Custom code file not found")
exclusionPattern <- file.path(pathToFiles, "exclude.R")
if (!file.exists(exclusionPattern)) stop("Exclusion patterns file not found")
source(exclusionPattern)
reportLocation <- file.path(pathToFiles, "tmp", "ErrorReport.csv")
if (!file.exists(dirname(reportLocation))) dir.create(dirname(reportLocation))
if (!file.exists(reportLocation)) invisible(file.create(reportLocation))

message("All required files are available!")

# Get error report

message("Creating Redcap API object and initializing it with data...")

suppressPackageStartupMessages(library(RedcapData))

cinObj <- redcap_project(api_url = "http://localhost/redcap/api/", 
                         token = "B5B5E2F66FC63A9CDF94279377BF9D0E",
                         local = T,
                         chunked = T,
                         chunksize =10000,                        
                         report_location = reportLocation,
                         updates_location = updatesLocation, 
                         custom_code_location = customCodeLocation, 
                         exclusion_pattern = exclusionPatterns,
                         hosp_to_validate = "55"
#hosp_to_validate = "51;52;53;54;55;57;58;62;63;64;66;68;70;71"
)

cinObj$load_data()

message("Redcap object set!")
message("Generating error report...")


cinObj$get_data_validation_report(pop = F)

message("Error report generated!")
