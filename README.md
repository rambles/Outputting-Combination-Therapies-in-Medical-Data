### Purpose

The core of the porject is a SAS macro that takes a dataset of therapies - with start and end dates - to determine where the therapies overlap and output all therapy combinations.  

### Programs
There are three programs in the project; one with the macro and two support files with example data and analysis code.

The header of each file provides is sufficient foe use.  However, the header for the macro file itself is dense so much of it is repeated here so it's easier to read.

### Macro

The macro is called *create_combi_thers* and takes the following parameters:-

+ ***Data:*** The name of the input dataset.  It must feature one row per day per therapy.  See the 'example data' program in the repository for guidance on the input data.

+ ***Gap_days:*** Number of days between therapies before subsequent therapy is considered a new treatment block.  Default is **1 day**.  (This affects the *trtmt_blk* variable).  

+ ***Out_prim:*** Name of the primary output datset.

+ ***Out_sec:*** Name of the secondary output datset.

### Output datasets

For the **primary output** dataset, the most complex therapy combination is listed for the period (e.g. if the patient has *ICS* and *LABA* recorded on the same day, the given therapy will be *ICS/LABA*).

The **secondary output** dataset is much the same but lists all lower-order compounds for a period as well as the most complex.  From above, *ICS/LABA* would be listed the same but there would also be separate rows for *ICS* and *LABA*.  Furthermore, their period dates might differ if, for example, *ICS* had been prescribed separately beforehand.  

This second dataset can helps answer certain types of questions (see example code for details) though it's likely most analyses will only need the primary output.  

> **Note:** switch variables are not output in the secondary dataset as switching does not make sense when looking at inclusive/overlapping dates.

The following table lists the output variables and the datasets they are output to.

|Output Dset | Varname | Description | 
|:---|:---|:---|
| Both | patid | Patient ID
| Both | pd\_len | Num days of patient pd
| Both |num\_days | Number of days
| Both |prop\_days | Proportion of days relative to total pd for pat
| Both |ther\_combo | Therapy combination
| Both |num\_thers | Num thers for combo
| Both |ther\_start | Start date of therapy combo
| Both |ther\_end |  End date of therapy combo
| Both |trtmt\_blk | Blocks of consec trtmt. Gap allowed is *xx* day/s.
| Primary |switch\_num | Shows a switch in trtmt.
| Primary |switched\_from | Therapy the patient switched from.
| Both |primary\_ther | Shows the most complex original script of the pd. E.g. if ther_combo = ICS/LABA - and primary_ther = ICS/LABA too - we know patient directly receivd ICS/LABA rather than separate ICS & LABA scripts.

### Switching and treatment blocks

Switching and treatment blocks require a little explanation:-

+ **Switch\_num**
This shows the number of therapy switches the patient has made if there is a break in treatment - but the patient later resumes on the same therapy - this is NOT considered a switch.

  Further, counting starts at 0 ie. for the first therapy combo switch_num = 0.

+ **Switched_from**: 
Each time there is a switch, this lists the therapy combo that the patient was using before.

+ **Trtmt_blk**
This shows the consecutive treatment block the therapy is recorded under.  If the value is 2 - ie. the 2nd treatment block - this shows there has been one break in treatment since the start of the observation period.

### PDC / MPR

The program makes the distinction between PDC and MPR:-

+ **PDC (Proportion of Days Covered)**
For each day of overlap for multiple scripts of the same compound, the day is only counted once.  Eg. if two ICS script overlap each other by a week, this number of days is still treated as 7.

   This means that a total PDC value - as a proportion of the patient's period - can never be greater than 1.

+ **MPR (Medication Possession Ratio)**
In contrast to above, the overlapped days would be counted for each script so, with the above example, the overlapped week would contribute 14 days, not 7.

  In practice, this means a total MPR value for a patient can exceed 1.

In general, the PDC approach is most often used.