rm(list=ls(all.names = T))
library(RedcapData)
cinObj <- redcap_project(api_url = "http://localhost/redcap/api/", 
                         token = "7F4D600F2AE7B9B61C4C8D8071DC591F",
                         chunked =T,
                         chunksize =500,
                         local = TRUE
)

cinObj$load_data()
#==============================================================================================================
# LOAD PACKAGES
#==============================================================================================================
library(data.table)

message("packages loaded ...........")
message("Reading data from a location..........................")
cin_data <- cinObj$get_raw_data()

message("Data read successifully.........................................................")
if(!("data.table") %in% class(cin_data))
  cin_data=data.table(cin_data)

if(!haskey(cin_data)){
  cin_data[, key:=.I]
  setkey(cin_data, key)
}

message("Validating ids .................................................................")

message("Validate recursively ...........................................................")
is_identical <- function(...){
  args <- c(...)
  args<-args[!is.na(args)]
  if( length( args ) > 2L ){
    names(args)<-NULL
    out <- c( identical( args[1] , args[2] ) , is_identical(args[-1]))
  }else{
    names(args)<-NULL
    out <- identical( args[1] , args[2] )
  }
  return( all( out ) )
}

message("Done...............")
message("Validating Id's with hospital ID..................................")
ids.validation = data.table(id=cin_data$id,from.id = substr(cin_data$id, 1, 2), from.hosp.id = cin_data$hosp_id)
ids.validation[, matched:= apply(.SD, 1, is_identical ), .SDcols=c("from.id","from.hosp.id")]

message("Done..........")

message("get records with correctly validated ids.........................")
cin_data[,validated.ids:=ids.validation[, matched]]

message("getting Matched data ids ........................................")
data_matched <- cin_data[validated.ids==T, .SD] 

message("getting unmatched data ids ......................................")
data_unmatched <- cin_data[validated.ids==F, .SD] 

message("DONE!.............................................................")
cat("\n\tFormatting raw data ...\n\t")

#rm(list=ls(all.names = T))
