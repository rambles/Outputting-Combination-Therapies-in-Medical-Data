/********************************************************************************

  Program name:     Combo_Therapies_-_Example_Data.sas
  Author:           Richard Baxter                 Date Created: January, 2014
  SAS Version:      9.3                                      OS: Win / Unix

  ### Note

  This program is part of the suite of programs for determining combination
  therapies.  These programs are stored on Github using the version control
  system Git:-

    https://github.com/rambles/combo_therapies

  To read about the algorithm, view the readme file in the Git repository:-

    http://bit.ly/1fU3UTc

  ### Purpose

  This program creates some example data to be used with the main combination
  therapies macro.  It creates two datasets:-

  Patient level:

    1 row per patient with start and end dates for their analysis period 
    (*obs_start* and *obs_end* respectively). The macro ensures only therapies 
    starting or ending in the analysis period are used (although see the README 
    in the Git repository regarding MPR dates and going past the end of the
    analysis period)

  Therapy level:

    One row per therapy.  Each therapy must have a label and a start and end date.

  The example data are based on CPRD as is the macro code.  However, it would be
  easy to adapt to other data sources.

  ### Output

  combo1a_pat_lvl: Patient level dset
  combo1b_ther_lvl: Therapy level dset

  combo2_one_row_per_day_per_ther:

    This is the analysis dataset used by the macro.  It is the result of a merge
    between the datasets above done to get the period dates for each patient
    onto the therapy data.  Then, a row is output for each day the therapy covers.

    Eg.  If a script is 30 days in length, 30 rows wwill be output for it.

********************************************************************************/

  options comamid=tcp remote=x nodate nonumber nocenter pageno=1 mergenoby=warn msglevel=i obs=max nofmterr ps=54 ls=100;

  options nodate nonumber nocenter pageno=1 obs=max nofmterr ps=52 ls=100 fmtsearch=(codes);
  options dsoptions=note2err mergenoby=warn msglevel=i;
  options formchar="|----|+|---+=|-/\<>*";
  ods noproctitle;

  ************************************************************************;
  **  SIMULATED DATA: Create simulated patient and therapy level datasets ;
  ************************************************************************;

  **  Patient level: 1 row per patient with their "period dates" (e.g. obs pd, yr after index);  
  data combo1a_pat_lvl;
    format obs_start obs_end date11.;
    
    patid = 1; obs_start = "01JAN2000"d; obs_end = "31JAN2000"d; output; 
    patid = 2; obs_start = "01JAN2000"d; obs_end = "28FEB2000"d; output;
    patid = 3; obs_start = "01JAN2000"d; obs_end = "31JAN2000"d; output;
    patid = 4; obs_start = "01JAN2000"d; obs_end = "31JAN2000"d; output;

  proc sort;
    by patid;
  run;

  **  Therapy level: 1 row per prescription with start and end dates;
  data combo1b_ther_lvl;
    length thergrp $15;
    format ther_start ther_end date11.;

    patid = 1;
    thergrp = 'ics';            ther_start = "03DEC1999"d; ther_end = "29DEC1999"d; output;
    thergrp = 'ics/laba';       ther_start = "30DEC1999"d; ther_end = "14JAN2000"d; output;
    thergrp = 'lama';           ther_start = "04JAN2000"d; ther_end = "23JAN2000"d; output;
    thergrp = 'laba';           ther_start = "12JAN2000"d; ther_end = "14FEB2000"d; output;
    thergrp = 'ics/lama/laba';  ther_start = "19JAN2000"d; ther_end = "23JAN2000"d; output;
    thergrp = 'ics';            ther_start = "25JAN2000"d; ther_end = "04FEB2000"d; output;

    patid = 2;
    thergrp = 'lama';           ther_start = "13DEC1999"d; ther_end = "14JAN2000"d; output;
    thergrp = 'ics';            ther_start = "04JAN2000"d; ther_end = "24JAN2000"d; output;
    thergrp = 'lama';           ther_start = "03FEB2000"d; ther_end = "17FEB2000"d; output;
    thergrp = 'lama';           ther_start = "22FEB2000"d; ther_end = "25FEB2000"d; output;

    patid = 3;
    thergrp = 'ics';            ther_start = "01JAN2000"d; ther_end = "21JAN2000"d; output;
    thergrp = 'ics';            ther_start = "07JAN2000"d; ther_end = "21JAN2000"d; output;
    thergrp = 'laba';           ther_start = "25JAN2000"d; ther_end = "31JAN2000"d; output;

    patid = 4;
    thergrp = 'lama';           ther_start = "03DEC1999"d; ther_end = "04JAN2000"d; output;
    thergrp = 'ics';            ther_start = "04JAN2000"d; ther_end = "14JAN2000"d; output;
    thergrp = 'lama';           ther_start = "08JAN2000"d; ther_end = "17JAN2000"d; output;
    thergrp = 'laba';           ther_start = "12JAN2000"d; ther_end = "21JAN2000"d; output;
    thergrp = 'laba/ics';       ther_start = "19JAN2000"d; ther_end = "25JAN2000"d; output;
    thergrp = 'ics/laba/lama';  ther_start = "23JAN2000"d; ther_end = "31JAN2000"d; output;

  proc sort;
    by patid ther_start ther_end thergrp;
  run;

  ****************************************************************************************;
  **  Merge on obs dates for each patient and, taking these into account, output 1 row per;
  **  day the therapy was available (e.g. a 30 day script will output 30 rows);
  **  NOTE: Make sure a text copy of the therapy group variable is made (var = therapy);
  ****************************************************************************************;

  data combo2_one_row_per_day_per_ther(keep = patid date pd_len num_thers therapy);
    merge combo1b_ther_lvl(in = a) combo1a_pat_lvl(in = b keep = patid obs_start obs_end);
    by patid;

    attrib date       length = 5    format = date11. ;
    attrib therapy    length = $15  label = 'Therapy: Indivdual therapies';
    attrib pd_len     length = 3    label = "Pd_Len: Num days of patient pd.";
    attrib num_thers  length = 3    label = "Num_thers: Num thers for combo";
    retain pd_len .;

    if first.patid then pd_len = obs_end - obs_start + 1;
/*    therapy = strip(put(thergrp, thergrp.));  ** Alternative if therpy var is numeric and formatted.;*/
    therapy = therGrp;
    num_thers = countc(therapy, '/') + 1;

    **  Taking into account the analysis pd, output a row for each day each script covers; 
    if a and b then do date = max(obs_start, ther_start) to min(obs_end, ther_end);
      output;
    end;
  
  proc sort;  ** KEY!  Do not remove duplicates here as dates for MPR will be incorrect;
    by patid date therapy;
  run;
