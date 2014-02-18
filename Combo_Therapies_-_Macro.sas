/****************************************************************************

  Program name:     Combo_Therapies_-_Macro.sas
  Author:           Richard Baxter                 Date Created: January, 2014
  SAS Version:      9.3                                      OS: Unix

  ### Note

  This program is part of the suite of programs for determining combination
  therapies.  These programs are stored on Github using the version control
  system Git:-

    https://github.com/rambles/combo_therapies

  To read about the algorithm, view the readme file in the Git repository:-

    http://bit.ly/1fU3UTc

  ### Purpose

  This is a SAS macro that takes a dataset of therapies - with start and
  end dates - to determine where the therapies overlap and output all therapy
  combinations.

  The macro uses variable naming conventions consistent with CPRD.  Still, it
  should be straightforward to edit for use with other data sources.

 ============================================================================
  NOTE: The macro includes example calling code at the end for demonstrating
  the difference between PDC and MPR dates (see later note).  This should be
  deleted if you want to run the file to only compile the macro.
 ============================================================================

  ### Macro

  The macro is called create_combi_thers and is composed of 4 parameters:
  
    Data:     The name of the input dataset.  It must feature one row per day
              per therapy.  See the 'example data' program in the repository
              for guidance on the input data

   Gap_days:  Number of days between therapies before subsequent therapy
              is considered a new treatment block.  Default is 1 day.
              (This affects the trtmt_blk variable).  

   Out_Prim:  Name of the primary output datset.
   Out_sec:   Name of the secondary output datset.

  ### Output datasets

  For the primary output dataset, the most complex therapy combination is
  listed for the period (e.g. if the patient has ICS and LABA recorded on
  the same day, the given therapy will be ICS/LABA).

  The secondary output dataset is much the same but lists all lower-order
  compounds for a period as well as the most complex.  From above, ICS/LABA
  would be listed the same but there would also be separate rows for ICS and
  LABA.  Furthermore, their period dates might differ if, for example, ICS
  had been prescribed separately beforehand.

  This second dataset can helps answer certain types of questions (see example
  code for details) though it's likely most analyses will only need the primary
  output.

    Note: switch variables are not output in the secondary dataset as
    switching does not make sense when looking at inclusive/overlapping dates.

  The following table lists the output variables and the datasets they are output 
  to.

  | Output Dset | Varname        | Description 
  | Both        | patid          | Patient ID
  | Both        | pd_len         | Num days of patient pd
  | Both        | num_days       | Number of days
  | Both        | prop_days      | Proportion of days relative to total pd for pat
  | Both        | ther_combo     | Therapy combination
  | Both        | num_comps      | Num compounds in combo
  | Both        | num_scripts    | Num scripts contributing to the combo.  Duplicates 
                                   are counted if there are duplicates in the original data 
  | Both        | ther_start     | Start date of therapy combo
  | Both        | ther_end       | End date of therapy combo
  | Both        | trtmt_blk      | Blocks of consec trtmt. Gap allowed is *xx* day/s.
  | Both        | primary_ther   | Shows the most complex original script of the pd. E.g. 
                                   if ther_combo = ICS/LABA - and primary_ther = ICS/LABA too - 
                                   we know patient directly receivd ICS/LABA rather than 
                                   separate ICS & LABA scripts.

  | Primary     | switch_num     | Shows a switch in trtmt.
  | Primary     | switched_from  | Therapy the patient switched from.

  ### Switching and treatment blocks

  Switching and treatment blocks require a little explanation:-

    Switch_num:  This shows the number of therapy switches the patient has
    made if there is a break in treatment - but the patient later resumes on the
    same therapy - this is NOT considered a switch.

    Further, counting starts at 0 ie. for the first therapy combo switch_num = 0.

    Switched_from: Each time there is a switch, this lists the therapy combo
    that the patient was using before.

    Trtmt_blk: This shows the consecutive treatment block the therapy is
    recorded under.  If the value is 2 - ie. the 2nd treatment block - this
    shows there has been one break in treatment since the start of the
    observation period.

  ### PDC / MPR

  The program makes the distinction between PDC and MPR:-

    PDC (Proportion of Days Covered): For each day of overlap for multiple
    scripts of the same compound, the day is only counted once.  Eg. if two ICS
    script overlap each other by a week, this number of days is still treated as
    7.

    This means that a total PDC value - as a proportion of the patient's period
    - can never be greater than 1.

    MPR (Medication Possession Ratio): In contrast to above, the overlapped
    days would be counted for each script so, with the above example, the
    overlapped week would contribute 14 days, not 7.

    In practice, this means a total MPR value for a patient can exceed 1.

  In general the PDC approach is most often used.

********************************************************************************/

  %macro create_combi_thers(data = combo2a_PDC_row_per_day_per_ther, gap_days = 1, out_prim =, out_sec =);

    %*  Uncomment when debugging;
/*    %let data = combo2a_PDC_row_per_day_per_ther;*/
/*    %let out_prim = m_row_per_trtmt_change_or_brk;*/
/*    %let out_sec = m_summarised_inclusive_thers;*/
/*    %let gap_days = 1;*/

    %*  Ensure the data is sorted by patid and date;
    proc sort data = &data;
      by patid date;
    run;

    %*  Join together all therapy compounds per day into one string.  The HASH ensures the compounds;
    %*  are deduped and joing in alphabetical order.  Output is 1 row per patient per day.; 
    data m_combo1_dedupe_therapies (drop = i rc ther therapy prim);
      length ther prim primary_ther $30 all_thers $120;

      attrib primary_ther length = $30 label = "Primary_Ther: Most complex original script for pd to check dual/ther compounds origin.";
      attrib num_scripts length = 3 label = "Num_Scripts: Num scripts contributing to pd.  Counts dupes if dupes in orig data.";

      declare hash pat_thers(ordered:'a');    %*  Declare a hash with only therapy name as a var;
        pat_thers.definekey('ther');          %*  Therapy name is also made KEY so there are no duplicates;
        pat_thers.definedone();               %*  Also, this means THERAPY NAMES are stored in alphabetical order;
      declare hiter iter("pat_thers");        %*  Finally create an ITERATOR to go through the HASH at the end of each date;

      do until (eof);
        set &data end = eof;
        by patid date;
        num_scripts ++ 1;

        prim = ifc(countc(therapy, '/') > countc(prim, '/'), therapy, prim);  %*  Ensure most complex script for day is saved;

        do i = 1 to countc(therapy, '/') + 1;    
          ther = scan(therapy, i, '/');          %*  Take each compound in the current row of therapies ...; 
          rc = pat_thers.ref();                  %*   ... and add it to the HASH if it does not already exist;
        end;

        if last.date then do;   %*  Output 1 row per date.;

          rc = iter.first();    %*  Go through the hash ...;
          do while (rc=0);
            all_thers = catx('/', all_thers, ther);  %* ... and concat each therapy into one string, automatically deduped and in alpha order;
            if findw(prim, ther, '/', 'it') then primary_ther = catx('/', primary_ther, ther);  %* Do same for primary_ther (with obvious checks);
            rc = iter.next(); 
          end;

          if countc(primary_ther, '/') = 0 then primary_ther = '[ Indiv Compounds ]';
          output;

          num_scripts = 0;          %*  This section tidies up vars used above;
          all_thers = '';           %*  Because of the main DO-UNTIL loop, many vars are seemingly;
          rc = pat_thers.clear();   %*  RETAINED hence having to clear the vars by hand here;
          prim = '';
          primary_ther = '';
        end;
      end;
      stop;
    run;

    %*  Output a day for each therapy but, if the therapy is a combination, output it *and* its subsets;
    %*  For example, if ICS/LABA/LAMA, 7 rows will be output - the triple therapy, three dual therapies;
    %*  and then the three individual therapies;
    data m_combo2_1_row_per_day_per_combo(keep = patid date ther_combo max_thers_for_day Num_comps num_scripts pd_len primary_ther);
      set m_combo1_dedupe_therapies;
      array a[10] $50 _temporary_;    %*  At most, 10 different therapies can be combined;

      attrib ther_combo         length = $15   label = "Ther_Combo: Therapy combination";
      attrib max_thers_for_day  length = 3     label = "Max_thers_for_day: Total num thers for date";
      attrib Num_comps          length = 3     label = "Num_comps: Num compounds in combo";

      call missing (of a[*]);

      max_thers_for_day = countc(all_thers, '/') + 1;

      do i = 1 to max_thers_for_day;      
        a[i] = scan(all_thers, i, '/');  %* Copy each compound into an array cell...;
      end;

      if max_thers_for_day > 1 then do Num_comps = 1 to max_thers_for_day;    **  Loop for the num compounds on the day;
        do k = 1 to comb(max_thers_for_day, Num_comps);   %*  Loop through each combination (incl subsets);
          call lexcomb(k, Num_comps, of a[*]);            %*  Get the combination of compounds (array cells are rearranged);

          ther_combo = '';                                %*  This var will hold final arrangement of compounds.  Ensure empty;
          do m = 1 to Num_comps;                          %*  In loop, alphabetically join the combinations together;
            ther_combo = catx('/', ther_combo, a[m]);
          end;
          output;

        end;
      end;
      else do;                                             %*  Simply output row if only 1 compound for the day;
        Num_comps = 1; 
        ther_combo = all_thers; 
        output; 
      end;

    proc sort;
      by patid date ther_combo;
    run;  

    %**************************************************************************************************;
    %*  PRIMARY OUTPUT DSET: The output dset has one row per day of therapy (per patient) ;
    %*  The therapy listed will be the most complex for that day (in terms of the number of compounds) ;
    %**************************************************************************************************;

    %*  Keep the most complex therapy (see the WHERE stmt).  Create vars flagging different trtmt;
    %*  blocks or when a patient changed therapy;
    data m_combo3_1_row_per_ther_day;
      set m_combo2_1_row_per_day_per_combo(where=(Num_comps = max_thers_for_day));
      by patid date ther_combo;

      attrib switch_num     length = 5    label = "Switch_num: Shows a switch in trtmt.  Final val in pat = Total Changes.";
      attrib switched_from  length = $50  label = "Switched_from: Therapy the patient switched from.";

      if ther_combo ne lag(ther_combo) then do;
        switch_num ++ 1;
        switched_from = lag(ther_combo);
      end;

      attrib trtmt_blk length=5 label = "Trtmt_blk: Blocks of consec trtmt. Gap allowed is &gap_days day/s.";
      if date - &gap_days > lag(date) then trtmt_blk ++ 1;

      attrib num_days length = 3 format = comma6. label = 'Num_Days: Number of Days';
      num_days = 1;

      attrib prop_days length = 3 format = 5.2 label = 'Prop_Days: Prop of days relative to total pd for pat';
      prop_days = 1/pd_len;   **  No point labeling var as it is dropped in the proc summary below;

      **  Ensure the vars receiving lagged results are reset when starting a new patient;
      if first.patid then do; 
        switch_num = 0; 
        switched_from = ""; 
        trtmt_blk = 1;
      end;
    run;

    %*  The dataset above can be very large so summarise ensuring days of switching and trtmt blocks are recorded;
    proc summary data = m_combo3_1_row_per_ther_day nway;
      by patid;
      class switch_num trtmt_blk ;
      id ther_combo pd_len Num_comps switched_from primary_ther;
      var date prop_days num_days num_scripts;
      output out = &out_prim(label = "One row per trtmt change or change in cont medication (Gap allowed is &gap_days day/s).  See model prog for example analysis code"
                    drop=_:) min(date) = ther_start max(date) = ther_end sum(prop_days) = prop_days sum(num_days) = num_days max(num_scripts) = num_scripts;
    run;

    %********************************************************************************************;
    %*  SECONDARY OUTPUT DSET:  A second dataset is output that summarises the treatment periods; 
    %*  (start date, end date, etc.) of ALL THERAPY combinations.  This includes lower-order;
    %*  even for days when a higher-order combination exists.  Although this dset will be seldom;
    %*  needed it is still easier to create now in the macro than from the primary output dataset;
    %********************************************************************************************;
   
    %*  Within therapies, sort the events by date;
    proc sort data = m_combo2_1_row_per_day_per_combo out = m_combo4_incl_therapies;
      by patid ther_combo date;
    run;

    %*  As before, create a variable indicating consecutive trtmt blocks;
    %*  NOTE: A switch var is not made as it does not make much sense here;
    data m_combo4_incl_therapies;
      set m_combo4_incl_therapies;
      by patid ther_combo;

      attrib trtmt_blk length=5 label = "trtmt_blk: Blocks of consec trtmt (within trtmt). Gap allowed is &gap_days day/s.";
      if date - &gap_days > lag(date) then trtmt_blk ++ 1;

      attrib num_days length = 3 format = comma6. label = 'Num_Days: Length in days of pd';
      num_days = 1;

      attrib prop_days length = 3 format = 5.2 label = 'Prop_Days: Proportion of days relative to total pd for pat';
      prop_days = 1/pd_len;   **  No point labeling var as it is dropped in the proc summary below;

      if first.ther_combo then trtmt_blk = 1;
    run;

    %*  Create start and end dates for each trtmt * trmt_block combination.  Also count the number of days;
    proc summary data = m_combo4_incl_therapies nway;
      by patid;
      class ther_combo trtmt_blk;
      id pd_len Num_comps primary_ther;
      var date;
      output out = &out_sec(label = "One row per change in continuous meds (Gap = &gap_days day/s).  TRTMTS OVERLAP IN THIS OUTPUT. See model prog for example analysis code"
                             drop = _:) min(date) = ther_start max(date) = ther_end sum(prop_days) = prop_days sum(num_days) = num_days;
    run;

    %*  Delete interim datasets;
    proc datasets library = work nolist nodetails nowarn; delete M_: / memtype=all; quit;

  %mend create_combi_thers;

  **************;
  **  PDC dates ;
  **************;

  **  For PDC calculations, we can de-dupe multiple therapies of the same type on the same day; 
  proc sort data = combo2_one_row_per_day_per_ther out = combo2a_PDC_row_per_day_per_ther nodupkey;
    by patid date therapy;
  run;

  **  Std therapy combinations.  Could be used to determine PDC values;
  %create_combi_thers( data = combo2a_PDC_row_per_day_per_ther, gap_days = 1, 
                          out_prim = pdc_row_per_trtmt_change_or_brk, out_sec = pdc_summ_inclusive_thers);

  **************;
  **  MPR dates ;
  **************;

  **  For compounds of the same type, process overlapping days by taking this number of days and
  **  adding them to the end of the compound's chain of scripts.;
  **  For example, an ICS script from Jan 1 to Jan 10 overlaps the next ICS script (Jan 6 to Jan 15) 
  **  by 5 days.  The code will add 5 days to Jan 15 and output the scripts as Jan1-Jan10 & Jan11-Jan21;
  **  NOTE: The same number of rows will be output as went in;
  **  NOTE: The period dates for the patient are NOT REAPPLIED - therefore it is now possible for
  **  there to be dates after the end of their patient period.  This is on purpose as it should be possible
  **  for MPR results to take value greater than 1;
  proc sort data = combo2_one_row_per_day_per_ther out = combo2b_MPR_row_per_day_per_ther;
    by patid therapy date;
  data combo2b_MPR_row_per_day_per_ther(drop = i ref_date date rename=(mpr_date = date));
    set combo2b_MPR_row_per_day_per_ther;
    by patid therapy;

    attrib ref_date length = 5 format = date11. label = "Ref_date: First date within block of concurrent dates"; 
    attrib mpr_date length = 5 format = date11. label = "MPR_date: New date used in MPR calculations"; 
    retain ref_date .;

    if first.therapy or sum(ref_date, i, 1) < date then do;  ** If new therapy or a break in serial events, fix new reference date;
      ref_date = date;
      i = 0;
    end;
    else i ++ 1;

    mpr_date = sum(ref_date, i);  **  Create new MPR date based on prev ref_date or new one just fixed in DO LOOP;
/*      put therapy= date= i= ref_date= mpr_date=;*/  ** Useful for debugging;
  run;

  %create_combi_thers( data = combo2b_MPR_row_per_day_per_ther, gap_days = 1,  
                          out_prim = mpr_one_row_per_day, out_sec = mpr_summ_inclusive_thers);

