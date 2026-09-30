# Validate hospital and unique ids

if (exists("hosp_to_validate", envir = environment())) {
  if (!isTRUE(data_missing(hosp_to_validate))) {
    if (isTRUE(is_int(hosp_to_validate))) {
      hosp_to_validate = as.integer(hosp_to_validate)
      if (!isTRUE(data_missing(hosp_id))) {
        if (!isTRUE(hosp_id %in% hosp_to_validate)) {
          form__x2014cin = c(form__x2014cin, "Biodata")
          name__x2014cin = c(name__x2014cin, "hosp_to_validate")
          msg__x2014cin = c (msg__x2014cin, "Invalid Hospital ID [hosp_id] (does not match hospital)!")
          sect__x2014cin = c(sect__x2014cin, "")
          type__x2014cin = c(type__x2014cin, "")
          entry__x2014cin = c(entry__x2014cin, "")
        }
      }
      if (!isTRUE(data_missing (id))) {
        if (isTRUE(nchar(id) > 6L)) {
          if (isTRUE(!as.integer(substr(id, 1L, 2L)) %in% hosp_to_validate)) {
            form__x2014cin = c(form__x2014cin, "Biodata")
            name__x2014cin = c(name__x2014cin, "id")
            msg__x2014cin = c(msg__x2014cin, "Invalid Unique ID [id] (does not match hospital)!")
            sect__x2014cin = c(sect__x2014cin, "")
            type__x2014cin = c(type__x2014cin, "")
            entry__x2014cin = c(entry__x2014cin, "")
          }
        } else {
          form__x2014cin = c(form__x2014cin, "Biodata")
          name__x2014cin = c(name__x2014cin, "id")
          sect__x2014cin = c(sect__x2014cin, "")
          type__x2014cin = c(type__x2014cin, "")
          entry__x2014cin = c(entry__x2014cin, "")
        }
      }
    }
  }
}


######################################
#
# check date
#
##############################################

# Check dates

if (isTRUE(date_can_be_validated(date_adm) && date_can_be_validated(date_discharge))) {
  if (!(isTRUE(as.Date(date_adm)%in% c(seq(as.Date('1913-01-01', "%Y-%m-%d"), by="year",length.out = 5))))){
    if (isTRUE(as.Date(date_adm) > as.Date(date_discharge))) {
      form__x2014cin = c(form__x2014cin, "Biodata")
      name__x2014cin = c(name__x2014cin, "date_adm")
      msg__x2014cin = c(msg__x2014cin, "'Admission Date' cannot be after 'Discharge/Death Date'")
      sect__x2014cin = c(sect__x2014cin, "")
      type__x2014cin = c(type__x2014cin, "")
      entry__x2014cin = c(entry__x2014cin, date_adm)
    }
  }
}

if (isTRUE(date_can_be_validated(date_adm))) {
  if (isTRUE(as.Date(date_adm) > Sys.Date())) {
    form__x2014cin = c(form__x2014cin, "Biodata")
    name__x2014cin = c(name__x2014cin, "date_adm")
    msg__x2014cin = c(msg__x2014cin, "Admission Date' cannot be in the future!")
    sect__x2014cin = c(sect__x2014cin, "")
    type__x2014cin = c(type__x2014cin, "")
    entry__x2014cin = c(entry__x2014cin, date_adm)
  }
}

if (isTRUE(date_can_be_validated(date_discharge))) {
  if (isTRUE(as.Date(date_discharge) > Sys.Date())) {
    form__x2014cin = c(form__x2014cin, "Biodata")
    name__x2014cin = c(name__x2014cin, "date_discharge")
    msg__x2014cin = c(msg__x2014cin, "Discharge/Death Date' cannot be in the future!")
    sect__x2014cin = c(sect__x2014cin, "")
    type__x2014cin = c(type__x2014cin, "")
    entry__x2014cin = c(entry__x2014cin, date_discharge)
  }
}

