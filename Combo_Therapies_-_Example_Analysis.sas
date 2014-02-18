/********************************************************************************

  Program name:     Combo_Therapies_-_Example_Analyses.sas
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

  The output datasets from the macro can be used and analysed in many ways.
  This program features example code to work through some common - and not
  so common - analyses.

  There are examples on the primary and secondary datasets.  Most are on the 
  PDC dates but there are some for MPR too.

  ### Output

  Primarily output tables are created but several of the examples demonstrate
  the creation of output datasets too.

********************************************************************************/

  options comamid=tcp remote=x nodate nonumber nocenter pageno=1 mergenoby=warn msglevel=i obs=max nofmterr ps=54 ls=100;

  options nodate nonumber nocenter pageno=1 obs=max nofmterr ps=52 ls=100 fmtsearch=(codes);
  options dsoptions=note2err mergenoby=warn msglevel=i;
  options formchar="|----|+|---+=|-/\<>*";
  ods noproctitle;

  **------------------------;
  **  Primary Output Dataset;
  **------------------------;

  **  Number of trtmt blocks per patient;
  proc means data = pdc_row_per_trtmt_change_or_brk nway missing maxdec=0 max nonobs;
    title1 "1. Number of trtmt blocks per patient.";
    title2 "Source: Primary output dataset";
    class patid;
    var trtmt_blk;
    output out = out1_num_trtmt_blocks(drop=_:) max(trtmt_blk) = num_trtmt_blks;
  run;

  **  Number of trtmt switches per patient;
  proc means data = pdc_row_per_trtmt_change_or_brk nway missing maxdec=0 max nonobs;
    title1 "2. Number of trtmt switches per patient.";
    title2 "Initial therapy = 0.  Therefore, if switch num = 3, this means patient had 4 different trtmts.";
    title3 "Source: Primary output dataset";
    class patid;
    var switch_num;
    output out = out2_num_switches(drop=_:) max(switch_num) = num_switches;
  run;

  **   - Time to first switch;
  proc print data = pdc_row_per_trtmt_change_or_brk  label; 
    Title1 "2a. Number of days from initial treatment to first switch."; 
    title2 "Source: Primary output dataset";
    id patid;
    var ther_combo num_days prop_days;
    format prop_days percent8.1 num_days patid 3.;    
    label num_days = "No days" prop_days = "% of pd" ther_combo = "Initial Therapy";
    where switch_num = 0;
  run;  

  **   - Summary of switching meds;
  proc tabulate data = pdc_row_per_trtmt_change_or_brk format = comma8. missing;
    title1 "2b. A summary showing counts of switched-from/switched-to therapy chains";
    title2 "Source: Primary output dataset";
    class switched_from ther_combo / order=formatted;
    table switched_from='Switched From' * ther_combo = 'Switched To' all='Total', (n='N' colpctn='Col %') / rts=40;
    where switched_from ne '';
  run; 
  
  **  PDC total per patient;
  proc means data = pdc_row_per_trtmt_change_or_brk nway missing maxdec=2 sum nonobs;
    title1 "3. Proportion of Days Covered (PDC) by all therapies per patient.";
    title2 "Source: Primary output dataset";
    class patid;
    var prop_days;
    output out = out3_overall_PDC(drop=_:) sum(prop_days) = PDC_all;
  run;

  **  - PDC of LAMA-containing therapies per patient;
  proc means data = pdc_row_per_trtmt_change_or_brk nway missing maxdec=2 sum nonobs;
    title1 "3a. Proportion of Days Covered (PDC) by a LAMA-containing therapy per patient.";
    title2 "Source: Primary output dataset";
    class patid;
    var prop_days;
    output out = out3a_any_lama_PDC(drop=_:) sum(prop_days) = PDC_any_lama;
    where ther_combo contains 'lama';
  run;

  **  - The following merge-and-print shows the proportion of time on LAMA containing therapies;
  **    as a proportion of time spent on any LBAD therapies;
  data out3b_lama_as_prop_of_all;
    merge out3_overall_PDC(in=a) out3a_any_lama_PDC(in=b);
    title2 "Source: Primary output dataset";
    by patid;
    
    if a and b then prop_lama = pdc_any_lama / pdc_all;
    else prop_lama = 0;
    if a then output;
  run;

  **  - Print the results above;
  proc print data=out3b_lama_as_prop_of_all label; 
    Title1 "3b. Percentage of time on LAMA therapies relative to time spent on LABD therapies."; 
    title2 "Source: Primary output dataset";
    id patid;
    var pdc_any_lama pdc_all prop_lama;
    format _numeric_ percent8.1 patid 3.;    
    label pdc_all = "% on LABD" pdc_any_lama = "% on LAMA" prop_lama = "% on LAMA / % on LABD";
  run;  

  **---------------------------------------------------------------------------------------------------------------;
  **  Secondary Output Dataset:  The secondary dataset does not end a therapy combination should another one start;
  **  This means there are overlapping dates for therapies groups - however, it allows you to determine more easily;
  **  when a patient was taking *at least* the therapy of interest;
  **---------------------------------------------------------------------------------------------------------------;
  
  **  Summarise the number of days a patient was taking at least ICS/LABA;
  proc means data = pdc_summ_inclusive_thers nway missing maxdec=0 sum n max min mean nonobs;
    title1 "4a. Summary of trtmt blocks for ICS/LABA by patient - Secondary output dataset!.";
    title2 "Source: Secondary output dataset";
    title3 "Sum = Total num days | N = Num trtmt pds | Max = Longest trtmt pd in days"; 
    class patid ther_combo;
    var num_days;
    output out = out4a_sec_trtmt_days(drop=_t: rename=(_freq_ = num_occasions)) sum(num_days) = sum_days;
    where ther_combo = 'ics/laba';
  run;

  **  Repeat above but using the primary data.  This will produce a different result;
  proc means data = _pdc_row_per_trtmt_change_or_brk nway missing maxdec=0 sum n max min mean nonobs;
    title1 "4b. Summary of trtmt blocks for ICS/LABA by patient - Primary output dataset!.";
    title2 "Source: Primary output dataset";
    title3 "This example is as above but shows different results as it is from the primary output dataset";
    title4 "For pat 1, there is an extra episode as it counts ICS/LABA (01JAN - 03JAN) and ICS/LABA/LAMA (04JAN - 14JAN)";
    title5 "as two separate ICS/LABA events.  Arguably, given the question, table 4a would be considered correct.";
    class patid trtmt_blk;
    var num_days;
    output out = out4b_sec_trtmt_days(drop=_t: rename=(_freq_ = num_occasions)) sum(num_days) = sum_days;
    where ther_combo ? 'ics' and ther_combo ? 'laba' ;
  run;

  **  Imagine a patient has an index date and we are interested what (other) therapies they were taking on that;
  **  day.  The following shows how using the secondary dataset will be better;

  **  Use the 2nd script for each patient as their 'index' date;
/*  data out5_indx_dates;*/
/*    set pdc_row_per_trtmt_change_or_brk(where=(switch_num = 1));*/
/*  run;*/
/**/
/*  proc sql noprint undo_policy=none;*/
/**/
/*    create table E3_final_index_dates as*/
/*    select l.*, r.ther_combo as ics_check, r.ther_start as ics_date*/
/*    from E3_final_index_dates l left outer join mart.E1_pdc_summ_inclusive_thers r*/
/*      on l.patid = r.patid*/
/*     and r.ther_start < l.eventdate and r.ther_end >= l.eventdate*/
/*    order by l.patid, l.eventdate;*/
/**/
/*  quit;*/

  **  Write MPR code!!;
