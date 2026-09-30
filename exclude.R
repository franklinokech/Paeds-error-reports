#	 
#	====================================================================================================
#	 
#	Copyright:
#	----------
#		File : "Cin_Exclusion_Pattern.R"
#		Company : "KEMRI Wellcome Trust"
#		Copyright (c) 2014 All rights reserved, www.kemri-wellcome.org/
#	 
#	Disclaimer:
#	----------
#		This source code is owned and managed by KEMRI Wellcome Trust.
#		Permission must be sought from the above mentioned entity for use, distribution or modification.
#		If you are not a KEMRI employee, any violation of the above can constitute malice and criminal intent.
#		All other rights reserved.
#	 
#	Author: Boniface Makone
#	Email: BMakone@kemri-wellcome.org
#	Date of Creation: 28 October, 2014
#	 
#	Summary:
#	--------
#		This is a regex pattern of the rows to exclude during code autogeneration.
#		These are then filtered out of the meta data.
#		The variables then either should not be validated( eg obsolete) or are part of the custom script.
#	 
#	====================================================================================================
 
exclusionPatterns = c(
  "^dx1_([a-zA-Z0-9*()])",
  "^dx2_([a-zA-Z0-9*])",
  "^dsc_dx1_([a-zA-Z0-9*])",
  "^dsc_dx2_([a-zA-Z0-9*])",
  "^dx2_([a-zA-Z0-9*])",
  "^dsc_rx([a-zA-Z0-9*_])",
  "^adm_rx([a-zA-Z0-9*_])",
  "depid",
  "cap_refill([a-zA-Z0-9*_])",
  "random"
    )