## REQUIREMENTS
- You will require access to compute9.q in order to submit all QSUB scripts. Make sure you have access and are logged into the appropriate nodes (c2001, c2002, c2003, c2004).
- Before running any python scripts, kindly source the env here: `conda activate /cfs/loni/faculty/ipappas/pappaslab/suchita/Tools/PPG_PET_env`: Python version should be atleast 3.9 and pandas version at least 2.2.2. SG_environment.yml is located inside /cfs/loni/faculty/ipappas/pappaslab/suchita/Tools/ if you want to rebuild. 

## Step-Wise Description of PPG USC PET Processing Pipeline

## 1_Check_PET_Inventory.py

- Before we pull data from the IDA, we must cross check which images currently reside on our server so as to avoid pulling/uploading redundant imaging data. This script reads the scan dates/IMAGE IDs for our existing subjects and appends this information to a log which will be utilized for subsequent organization. 

1. Run via cmd line: ```python 1_Check_PET_Inventory.py```
2. Reads raw data directory and logs existing image IDs/scans.
3. Output path: `{PET_directory}/Data_Pull_CSVs/Existing_Data/`

```bash

# Terminal Output 

Checking existing data inside: /cfs/loni/faculty/ipappas/pappaslab/suchita/PPG/Raw_IDA_Downloads/PET/PPG
CSV file has been saved to /cfs/loni/faculty/ipappas/pappaslab/suchita/PPG/Data_Pull_CSVs/PET/Existing_Data/PET_Inventory.csv
Image IDs saved to /cfs/loni/faculty/ipappas/pappaslab/suchita/PPG/Data_Pull_CSVs/PET/Existing_Data/Existing_PET_Image_IDs.txt

...

/cfs/loni/faculty/ipappas/pappaslab/suchita/PPG/ 
│					
├── Data_Pull_CSVs/                                    
│   	└──PET/
│			├──Existing_Data
│			│	├──Existing_PET_Image_IDs.txt
│			│	└── PET_Inventory.csv 				


```

---

## 2_Process_PET_CSVs.py

- The purpose of this script is to identify new scans available in the IDA. We pull the Raw IDA CSV, parse it, and return which IMAGE IDs are new and which PET-T1 IMAGE IDs pair up. 

1. **Before running:** Pull the fresh/latest CSV from the IDA.
2. To do this, navigate to PPG/Advanced Image Search Builder and select these:
    - PPG
    - Study Date
    - MRI: Enter `Accelerated Sagittal MPRAGE`
    - PET: Enter `AA-APOE_AMYLOID (AC)`
    - PET: Enter `AA-APOE_TAU (AC)`
    - Sequentially add these scans to a new collection.
3. Download the CSV of the new collection.
4. Store the CSV copy inside `{PET_directory}/Data_Pull_CSVs/Raw_IDA_CSV`

```bash

/cfs/loni/faculty/ipappas/pappaslab/suchita/PPG/ 
│					
├── Data_Pull_CSVs/                                    
│   	└──PET/
│			├──Existing_Data
│			│	├──Existing_PET_Image_IDs.txt
│			│	└── PET_Inventory.csv
│			│
│			├──Raw_IDA_CSV
│			│	└──PET_pull_USC_{date}.csv <--- name accordingly and store HERE

```
5. Run `2_Process_PET_CSVs.py`. 

Note: Information regarding utility functions called in `2_Process_PET_CSVs.py` can be found here: https://gist.github.com/suchitag07/8e81fa8ef646e246fc89a516eee1ab9c 

```bash

Usage: 
python 2_Process_PET_CSVs.py \
--raw_data_csv_path \
--date_ran

optional arguments:
  -h, --help            show this help message and exit
  --raw_data_csv_path 	RAW_DATA_CSV_PATH
                        Please pull the raw data csv from the IDA and store/source it from here:
                        /cfs/loni/faculty/ipappas/pappaslab/suchita/PPG/Data_Pull_CSVs/PET/Raw_IDA_CSV/{PET_pull_USC_date}.csv
  --date_ran DATE_RAN   Please enter a date string for output folder/file names (format: MM_DD_YYYY).


Example Call:
python 2_Process_PET_CSVs.py \
--raw_data_csv_path /cfs/loni/faculty/ipappas/pappaslab/suchita/PPG/Data_Pull_CSVs/PET/Raw_IDA_CSV/PET_pull_USC_42925_4_29_2025.csv \
--date_ran 08_23_2025
  

# Terminal Output Should Look Like:

Have you completed running the latest PET image inventory check? (yes/no): yes
PET inventory check completed: yes
Date entered: 08_23_2025
Path to latest PET imaging data csv: /cfs/loni/faculty/ipappas/pappaslab/suchita/PPG/Data_Pull_CSVs/PET/Raw_IDA_CSV/PET_pull_USC_42925_4_29_2025.csv

CHECKING NUM OF SUBJECTS IN EACH GROUP
Total subs tau: 95
Total subs amyloid: 96
Subs who have amyloid and tau: 83

CHECKING IMAGE ID TOTALS
Number of tau-PET images inside stand-alone Tau-spreadsheet: 110
Number of amyloid-PET images inside stand-alone Amyloid-spreadsheet: 115
Total number of T1 images across stand-alone-Tau + stand-alone-Amyloid + Amyloid_plus_Tau sheet: 130
Total number of images (sum): 355

Number of images logged in PET_Server_Log_Summary spreadsheet: 355
New image IDs written to /cfs/loni/faculty/ipappas/pappaslab/suchita/PPG/Data_Pull_CSVs/PET/Processed_CSVs/{date}/PET_Server_Image_IDs_{date}_new.txt

.... You should see this....

/cfs/loni/faculty/ipappas/pappaslab/suchita/PPG/ 
│					
├── Data_Pull_CSVs/                                    
│   	└──PET/
│			├──Existing_Data
│			│	├──Existing_PET_Image_IDs.txt
│			│	└── PET_Inventory.csv
│			│
│			├──Raw_IDA_CSV
│			│	└──PET_pull_USC_{date}.csv
│			│
│			└──Processed_CSVs
│				└──{date_folder}
│				 	├──PET_Server_Image_IDs_{date}_all.txt
│				 	├──PET_Server_Image_IDs_{date}_new.txt ----->	# Consists of comma separated list of NEW IMAGE IDs, Paste Contents into IDA Advance Search Builder
│				 	├──PET_Server_Log_Summary_{date}.csv
│				 	├──PPG_ABETA_PLUS_TAU_{date}.csv
│				 	├──PPG_Amyloid_{date}.csv
│				 	├──PPG_Tau_{date}.csv
│
│
```
    
8. **After running:**
    - Copy and paste contents of `{PET_directory}/Data_Pull_CSVs/Processed_CSVs/{date_folder}/PET_Server_Image_IDs_MM_DD_YYYY_new.txt` into the “Image ID” search tab on IDA (Advanced Image Search Builder).
    - Add to new image collection.
    - Download resulting zip file, unzip inside `{PET_directory}/Raw_IDA_Downloads/PET/`
    - New data will automatically nest inside the `PPG` and subject subdirectories.

```bash

/cfs/loni/faculty/ipappas/pappaslab/suchita/PPG/ 
│
├──Raw_IDA_Downloads
│		└── PET ---------> PASTE AND UNZIP HERE
│			 │
│			 └── PPG
│			 	  └── {SUBJECT_DIRECTORY}
│						└──Accelerated_Sagittal_MPRAGE  # T1 Scan
│						└──AA-APOE_AMYLOID__AC_ 		# Amyloid-PET Scan
│						└──AA-APOE_TAU__AC_				# Tau-PET Scan      
│								└──{date}_{time}
│										 └──{IMAGE_ID}
│										 		  └──dicom_files  # All subject directories have this identical structure (not all may have both an AMYLOID and a TAU Scan - but they will have at least a T1 and 1 of EITHER)
│																  # This automatically organizes as such when you unzip your IDA_download.zip 
│		

```
---

## 3_Organize_IDA_PET_latest_version.sh

1. Run via the command line. `./3_Organize_IDA_PET_latest_version.sh ` **Follow input prompts.**
2. Organizes raw data from `{PET_directory}/Raw_IDA_Downloads/`, matching PET + MRI for each subject/visit_code for both modalities (Amyloid and Tau).
3. Organized outputs are in:  {PET_directory}/Has_Amyloid` and `{PET_directory}/Has_Tau
   

## 4_PET_dcm2niix.sh

1. Run via the command line. `./4_PET_dcm2niix.sh `**No input prompts.**
2. Uses dcm2niix for DICOM to NIFTI conversion.  


```bash  

Either runs dcm2niix or prints.."Skipping {path} NIfTI file already exists."

# Folders should be populated as below

/cfs/loni/faculty/ipappas/pappaslab/suchita/PPG/     
├──PPG_Data_Organized
│		└──PET
│			├──Has_Amyloid
│			│		└──NIFTIs
│			│			 └── {SUBJECT_DIRECTORY}/{VISIT_CODE}/ 
│			│								  			│
│			│			 			  		  			├──Amyloid-PET_{scan_date}
│			│			 			  		  			│		 ├──{SUBJID}_Amyloid-PET_{scan_date}_{IMAGE_ID}.json     
│			│			 			  		  			│	     └──{SUBJID}_Amyloid-PET_{scan_date}_{IMAGE_ID}.nii.gz    # Amyloid-PET NIFTI
│			│			 			  		  			└──T1_{scan_date}
│			│			 			  		  			 	   	 ├──{SUBJID}_T1_{scan_date}_{IMAGE_ID}.json
│			│			 			  		  			 	     └──{SUBJID}_T1_{scan_date}_{IMAGE_ID}.nii.gz			  # T1 matched to Amyloid scan
│			├──Has_Tau
│			│		└──NIFTIs
│			│			 └── {SUBJECT_DIRECTORY}/{VISIT_CODE}/
│			│								  			│
│			│			 			  		  			├──Tau-PET_{scan_date}
│			│			 			  		  			│			├──{SUBJID}_Tau-PET_{scan_date}_{IMAGE_ID}.json     
│			│			 			  		  			│			└──{SUBJID}_Tau-PET_{scan_date}_{IMAGE_ID}.nii.gz     # Tau-PET NIFTI
│			│			 			  		  			└──T1_{scan_date}
│			│			 			  		  			 			├──{SUBJID}_T1_{scan_date}_{IMAGE_ID}.json
│			│			 			  		  			 			└──{SUBJID}_T1_{scan_date}_{IMAGE_ID}.nii.gz		  # T1 matched to Tau scan

```
---


3. After script 3/4 run, always ensure you have one T1 scan and an Amyloid/Tau (there must NEVER be two T1s paired with a single pet scan within a /subject/visit/ directory). You can check this roughly by cd'ing into the NIFTI subdirectory and checking the subdirectory tree. 

```bash
cd ..../path-to Has_{Amyloid} or Has_{Tau}/NIFTIs/
find . -maxdepth 3 -type d
```

4. Additionally, to check if the correct T1 and PET IMAGE IDs were paired, you can reference the logs we generated via script 2 earlier (this is just a sanity check). 

5. If you find duplicate or additional T1s for any subject that has been already processed, check all output derivative directories to ensure the correct T1 image was pulled and processed (this will be logged across FreeSurfer and SUIT logs). If you find a discrepancy - make a note and reprocess that subject, push incorrect derivatives into an "old" folder. Never delete. 

```bash
/cfs/loni/faculty/ipappas/pappaslab/suchita/PPG/ 
│					
├── Data_Pull_CSVs/                                    
│   	└──PET/
│			└──Processed_CSVs
│				└──{date_folder}
│				 	├──PPG_Amyloid_{date}.csv  ---> you can use either of these 
│				 	├──PPG_Tau_{date}.csv     ----> to double check if what's inside Has_{Amyloid/Tau}/NIFTIs/{SUBJECT_DIRECTORY}/{VISIT_CODE}/ is correct via the date and image id's of the paired scans.


```

## 5_Check_Subs_to_Process.sh

3. Run via command line. `./5_Check_Subs_to_Process.sh ` **Follow input prompts.**
4. Output log: `{PET_directory}/Data_Pull_CSVs/Processed_CSVs/{date_folder}/Subjects_to_Process_{date}.txt`  
   This will contain a list of subjects/visits who's prerequisites (FreeSurfer/SUIT) are ready/require processing, and who's SUVR data are yet to be extracted. 

```bash

# Example Terminal Output

Enter Date (format: MM_DD_YYYY):08_26_2025
Check /cfs/loni/faculty/ipappas/pappaslab/suchita/PPG/Data_Pull_CSVs/PET/Processed_CSVs/08_26_2025/Subjects_to_Process_08_26_2025.txt for subjects and visits to process.

Logging new subjects and visits missing from PET_Outputs (SUVR) Directory
Date ran: 08_26_2025
-------------------------------
Has_Amyloid : New Subject: {subject} Visit: 2, FreeSufer_Status: Prerequisite MISSING
Has_Amyloid : New Subject: {subject} Visit: 1, FreeSufer_Status: Prerequisite Ready
Has_Tau : New Subject: {subject} Visit: 2, FreeSufer_Status: Prerequisite Ready, SUIT_status: Prerequisite MISSING
Has_Tau : New Subject: {subject} Visit: 1, FreeSufer_Status: Prerequisite Ready, SUIT_status: Prerequisite Ready
Has_Tau : New Subject: {subject} Visit: 2, FreeSufer_Status: Prerequisite MISSING, SUIT_status: Prerequisite MISSING
......
```

## 6_Copy_FreeSurfer_parcellations.sh

1. FreeSurfer parcellations (aparc+aseg etc) are required for both amyloid and tau pipelines. 
2. The above script navigates to the `{Freesurfer_Directory}` and checks if FreeSurfer output exists for each subject’s T1 data/per visit. If it exists, it will copy the necessary files over to a different PET-FreeSurfer directory (see below). 
3. Run via the command line. **Follow input prompts.**
4. For subjects with “FreeSurfer output not currently available for......”, make a note, grab that T1 image id from the IDA. Upload it to the original FreeSurfer directory and run it through the structural processing pipeline. Once that is complete, run this script to copy over the required files. 

```bash

# Example Call and Terminal Output

./6_Copy_FreeSurfer_parcellations.sh 

What modality are you processing (Has_Tau or Has_Amyloid): Has_Tau
What is the visit code (1, 2, etc.): 2
Modality: Has_Tau
Visit Code: 2
PET_FS_directory: TAU

No data for {subject_1} at Visit Code: 2 yet.
No data for {subject_2} at Visit Code: 2 yet.
FreeSurfer data already exists for {subject_3} at Visit Code: 2 with ID {IMAGE_ID}.
[[ NEW SUBJECT - COPYING OVER {subject_4}_{scan_date}_{IMAGE_ID} ]]
FreeSurfer output not currently available for {subject_5} at Visit Code: 2 with ID {IMAGE_ID}. Download {IMAGE_ID} from IDA and run Freesurfer first
[[ NEW SUBJECT - COPYING OVER {subject_6}_{scan_date}_{IMAGE_ID} ]]
......

# After this runs you should see the PET-Freesurfer directory populated as such


/cfs/loni/faculty/ipappas/pappaslab/suchita/PPG/ 
├──PPG_Data_Organized
│		└──PET				
│			├──SG_Freesurfer_Outputs_v_7_1
│			│			│
│			│			├──AMYLOID/{VISIT_CODE}/{SUBJECT_DIRECTORY}/
│			│			│								├──mri			
│			│			│								└──scripts
│			│			└──TAU/{VISIT_CODE}/{SUBJECT_DIRECTORY}/
│			│								  			├──mri			# Contains a copy of the minimum necessary FreeSurfer files for ref region/SUVR extraction (aparc.aseg)
│			│											└──scripts		# Contains copy of recon_all.log (Used here for sanity checks)
│	
```
---

## 7_QSUB_SUIT.sh

1. In addition to getting Freesurfer data ready, for Tau there is another requirement - the SUIT cerebellar atlas must be warped to native T1 space before it is called and utilized within the main Tau-PET pipeline. It can take around 15-20min to run, which is why we batch process it first. SUIT scripts are located here: `/cfs/loni/faculty/ipappas/pappaslab/suchita/PPG/Scripts/PET_Latest/TAU_Scripts`.
2. For Tau PET processing we extract the reference region using the SUIT MATLAB toolbox functions. `SG_process_SUIT_v2.m` does this. 
3. First edit `7a_Process_SUIT.sh` with the **visit_code** you are processing.
4. Next edit `7_QSUB_SUIT.sh` with the **subject IDs** to process (recall step 5 : Subjects_to_Process_{date}.txt).
5. Run this script via the command line as `./7_QSUB_SUIT`. Alternatively, if QSUB is down, add your subjects and run `./7alt_SUIT_Serial_Process.sh`.
6. Output/error logs for SUIT processing will be located inside `Has_Tau_derivatives/Tau-SUIT/{SUBJECT_DIRECTORY}/{VISIT_CODE}/Processing_Logs_SUIT`.
7. Remember to check this log before running the main Tau scripts.


---
## BASH_PROFILE REQUIREMENTS FOR MAIN PET SCRIPTS

By now, you will have fresh data and the main processing directories prepped with the prerequisites.

To run the amyloid/tau scripts: **EDIT your `.bash_profile` first AND SOURCE IT prior to running!**  
Your profile must include:

```
export FSL_DIR=/usr/local/fsl-5.0.9
export ANTSPATH=/usr/local/ANTs/bin
export PATH=$ANTSPATH:$PATH
export FREESURFER_HOME=/usr/local/freesurfer-7.1.1
export FSFAST_HOME=$FREESURFER_HOME/fsfast
export MNI_DIR=$FREESURFER_HOME/mni
export FSF_OUTPUT_FORMAT=nii.gz
export SUBJECTS_DIR={FreeSurfer_Directory}
source $FREESURFER_HOME/SetUpFreeSurfer.sh
``` 

# AMYLOID PET PIPELINE INSTRUCTIONS

## Pipeline Summary

- The current pipeline concerns the method for processing amyloid-PET data using [18F] florbetaben (FBB). The procedures followed are consistent with the AV45 protocol provided by the Jagust Lab at UC Berkeley for ADNI (revised, 01/14/2021). All amyloid-PET scans were acquired on a Siemens Biograph64 TruePoint system (University of Southern California). 
- Key Points:
	- The Desikan-Killiany atlas is used to extract regions of interest (ROIs) for the frontal, lateral parietal, lateral temporal, and anterior-posterior cingulate areas.
	- Using the Advanced Normalization Toolbox (ANTs), each ROI and the reference region is registered to PET space for uptake analysis. 
	- Standardized uptake value ratios (SUVRs) are calculated by dividing the mean uptake in each ROI by the whole cerebellum, with a composite SUVR used as a global measure of amyloid burden. Amyloid status is determined based on thresholds established by the UC Berkeley ADNI protocol, with a composite SUVR of ≥1.08 indicating amyloid positivity.

- Just to give you an idea, here is a visual summary of the processing steps outlined in the main pipeline/script `7_SG_Amyloid_PET.sh`.

![](https://gist.github.com/user-attachments/assets/84510fe7-5394-4fd0-a0a3-8c3bd62d0cb7)

- Now getting back to running the code:
- All Amyloid PET Scripts must be run from inside here: ***`/cfs/loni/faculty/ipappas/pappaslab/suchita/PPG/Scripts/PET_Latest/AMYLOID_Scripts`***
- ***Always run the scripts in their numerical order. Do not try to edit/run any of the subscripts via the cmd line.***

- All you need to do from this point is:
	- ***Step 1***: Edit `7_SG_Amyloid_PET.sh` with the ***visit code**** you are processing (1/2/3) and save it. This script is later called from scripts 8/9 for batch processing. 
	- ***Step 2***: If you are processing via qsub, edit `8_QSUB_AMYLOID.sh` with the ***subject list*** you generated from `5_Check_Subs_to_Process.sh` (you can run that as many times as you need). Just edit their subject IDs, save, and call the script as `./8_QSUB_AMYLOID.sh` and type `qstat -u <username>` to track the job status. 
	- ***Step 2 Alternative*** : ***If qsub is down*** you can process via `8alt_Amyloid_PET_Serial_Process.sh` For that, edit the ***subject list*** and call as `./8alt_Amyloid_PET_Serial_Process.sh` 
	- ***Step 3***: After processing via QSUB or via serial/cmd line, you can glance at the latest output and error logs. Look at example logs from the past to get an idea of what constitues a fairly error-free run.
	
	
```bash

/cfs/loni/faculty/ipappas/pappaslab/suchita/PPG/   
├── Scripts/                                    
│   	└── PET_Latest/
│			   │
│			   ├──AMYLOID_Scripts
│			   │	├──Amyloid_Dictionary.json										# Used to harmonize columns for IDA CSV. Utlized inside 9_Compile_Amyloid_SUVR.py.
│			   │ 	├──ROI_TEMP_PROCESSING/Create_ADNI_amyloid_ROIs_T1_space.sh 	# Subscript called inside main Amyloid Pipeline
│			   │	├──7_SG_Amyloid_PET.sh											# Main Amyloid Pipeline called inside QSUB script and Serial_Process script
│			   │	├──8_QSUB_AMYLOID.sh 
│			   │	├──8alt_Amyloid_PET_Serial_Process.sh
│			   │	├──9_Compile_Amyloid_SUVR.py									# Compiles Amyloid SUVRs and produces IDA formatted results CSV.  
│			   │	└──10_Amyloid-PET_QC.sh											# Amyloid-PET QC script


.....

# PET Processing Logs are Located here

/cfs/loni/faculty/ipappas/pappaslab/suchita/PPG/ 
├──PPG_Data_Organized
│		└──PET
│			├──PET_Processing_Logs
│			│			├──Amyloid_error_logs				
│			│			├──Amyloid_output_logs			
│			│			├──Tau_error_logs				    		
│			│			└──Tau_output_logs	
│			│

```

## Amyloid Outputs

- The main outputs of the Amyloid Pipeline are summarized here:


```bash

/cfs/loni/faculty/ipappas/pappaslab/suchita/PPG/ 
├──PPG_Data_Organized
│		└──PET
│			│			 			  		  		 			  		  
│			├──Has_Amyloid_derivatives
│			│			├──PET_subjects_output/{SUBJECT_DIRECTORY}/{VISIT_CODE}/			# Contains Amyloid-PET SUVR image warped to Native T1 space (sm8mm)		
│			│			├──PET_subjects_process/{SUBJECT_DIRECTORY}/{VISIT_CODE}/			# Contains all intermediate processing files (T1-PET coregistration, including freesurfer extracted reference region in PET space etc)
│			│			├──rois/{SUBJECT_DIRECTORY}/{VISIT_CODE}/				    		# Contains all ADNI-protocol amyloid ROIs warped to T1, and PET space
│			│			└──PET_subjects_process_SUVRs/{SUBJECT_DIRECTORY}/{VISIT_CODE}/ 	# Contains ADNI-protocol amyloid ROI SUVRs computed in Native PET Space written to txt files

```
---

## Amyloid SUVR Results

- ***Step 4: Compile Amyloid SUVRs***
	- To compile SUVRs use this python script. `9_Compile_Amyloid_SUVR.py`
	- New subjects are appended automatically to: `{PET_Directory}/Results/Amyloid_Latest`
	

```
 python 9_Compile_Amyloid_SUVR.py \
		--PPG_Amyloid_Log_Summary PPG_AMYLOID_LOG_SUMMARY \
		--visit_code VISIT_CODE \
		--output_csv_path OUTPUT_CSV_PATH


optional arguments:
  -h, --help            show this help message and exit
  --PPG_Amyloid_Log_Summary PPG_AMYLOID_LOG_SUMMARY
                        	Please specify the processed data csv from here: /cfs/loni/faculty/ipappas/pappaslab/suchita/PPG/Data_Pull_CSVs/PET/Processed_CSVs/{date_ran}/PPG_Amyloid_{date_ran}.csv
                        	(SEE OUTPUT OF SCRIPT 2_Process_PET_CSVs.py)
                        	
  --visit_code VISIT_CODE	Please specify the visit_code for which you want to compile Amyloid SUVR results (1/2/3 etc).
  
  --output_csv_path OUTPUT_CSV_PATH   Please specify a dated directory (MM_DD_YYYY) where you want to write SUVR data to (specify path to a new csv/ path to existing csv) located here :
                        			/cfs/loni/faculty/ipappas/pappaslab/suchita/PPG/PPG_Data_Organized/PET/Results/Amyloid_Latest/date/Compile_SUVRs_Amyloid_Subjects_Latest_date.csv


# Example 
python 9_Compile_Amyloid_SUVR.py 
--PPG_Amyloid_Log_Summary /cfs/loni/faculty/ipappas/pappaslab/suchita/PPG/Data_Pull_CSVs/PET/Processed_CSVs/08_24_2025/PPG_Amyloid_08_24_2025.csv \
--visit_code 1 \
--output_csv_path /cfs/loni/faculty/ipappas/pappaslab/suchita/PPG/PPG_Data_Organized/PET/Results/Amyloid_Latest/Compile_SUVRs_Amyloid_Subjects_Latest_08_24_2025.csv

# You can pass in both visit_code 1 and then 2. All SUVR sets will be appended to the same csv here:

/cfs/loni/faculty/ipappas/pappaslab/suchita/PPG/ 
│	
├──PPG_Data_Organized
│		└──PET
│			└────────Results
│						├──Amyloid_Latest
│						│		└──{DATE}/Compile_SUVRs_Amyloid_Subjects_Latest_{datestamp}.csv	===> Use for IDA
│				 		│
```

---

## Amyloid-PET QC

1. Manually edit for visit code. Call via the cmd line `./10_Amyloid-PET_QC <subjID>`
2. Refer to the google drive documents on the criteria for PET QC. 

---

# TAU PET PIPELINE INSTRUCTIONS

## Pipeline Summary

- The following section describes the methods for processing tau-PET data using [18F] AV-1451 flortaucipir (FTP). These procedures follow the FTP protocol provided by the Jagust Lab at UC Berkeley for ADNI (revised, 01/14/2021).  All tau-PET scans were acquired on a Siemens Biograph64 TruePoint system (University of Southern California). 

- Key Points
	- Regions of interest (ROIs) are defined for Braak stages I, III-IV, and V-VI, along with a meta-temporal composite. The inferior cerebellum is designated  as the reference region, extracted through the SUIT toolbox. 
	- ANTs is utilized to register each ROI and the reference region to PET space to facilitate SUVR analysis. 
	- SUVRs are calculated by dividing the mean uptake within each region by the mean uptake in the inferior cerebellum. Both unweighted and volume-weighted SUVRs are computed for all composite ROIs.

## Tau Processing Scripts

- All Tau PET Scripts must be run from inside here: ***`/cfs/loni/faculty/ipappas/pappaslab/suchita/PPG/Scripts/PET_Latest/TAU_Scripts`***
- ***Always run the scripts in their numerical order. Do not try to edit/run any of the subscripts via the cmd line.***
	
- ***Step 1: Main Tau PET Script***
	- Edit 8_SG_Tau_PET.sh with the ***visit_code*** you are processing.
	- Edit 9_QSUB_SUIT.sh with the subject IDs to process (recall the `Subjects_to_Process_{date}.txt` from step 5). 
	- Run this script via the command line as `./9_QSUB_TAU`. Alternatively, if QSUB is down, add your subjects and run `./9alt_Tau_PET_Serial_Process.sh`
	- Output/error logs will be located inside `PET_Processing_Logs`.

- After processing via QSUB or via serial/cmd line, you can glance at the latest output and error logs. 
- Look at example logs from the past to get an idea of what constitues a fairly error-free run.

```bash
│			   │
│			   ├──TAU_Scripts
│			   │	├──Tau_Dictionary.json											# Used to harmonize columns for IDA CSV. Utlized inside 10_Compile_Tau_SUVR_Nonweighted.py and 12_Compile_Tau_FS_stats_SUVR.py.
│			   │	├──Tau_ROIs.json												# Used for calculation of volume weighted SUVRs (Dictionary of FreeSurfer codes for each Braak ROI). Utilized inside 12_Compile_Tau_FS_stats_SUVR.py
│			   │	├──ROI_TEMP_PROCESSING/Create_ADNI_Tau_ROIs.sh					# Subscript called inside main Tau Pipeline
│			   │	├──SG_process_SUIT_v2.m											# MATLAB function to extract reference region from the SUIT Atlas
│			   │	├──7a_Process_SUIT.sh											# Calls SUIT function - can run from the cmd line or call inside QSUB/Serial process 									
│			   │	├──7_QSUB_SUIT.sh												# Process_SUIT is quite intensive and can take 10-20min which is why it is run prior to the main pipeline via QSUB									
│			   │	├──7alt_SUIT_Serial_Process.sh
│			   │	├──8_SG_Tau_PET.sh												# Main Tau Pipeline called inside QSUB script and Serial_Process script. Two sets of SUVRs are generated from this script: 1) Standard Nonweighted Tau SUVRs for Braak ROIs 2) SUVRs for all freesurfer wide regions (mri_segstats)
│			   │	├──9_QSUB_TAU.sh
│			   │	├──9alt_Tau_PET_Serial_Process.sh
│			   │	├──10_Compile_Tau_SUVR_Nonweighted.py							# Script to compile (1) Standard non-weighted Tau SUVRs
│			   │	├──11_asegstatscheat_SUVR_N_Volume.sh							# Script to extract (2a) Text files containing FreeSurfer derived volumes and SUVRs (produced through mri_segstats) from .stats files. 
│			   │	├──12_Compile_Tau_FS_stats_SUVR.py								# Script to compile (2b) Volume weighted Tau SUVRs. Crosses (2a) FreeSurfer metrics with SUVRs and merges those stats with our (1) standard non-weighted results. Produces IDA formatted CSV.  
│			   │	└──13_Tau-PET_QC.sh												# Tau-PET QC script

....

# Main Tau PET Processing Logs are Located here (QSUB_TAU)

/cfs/loni/faculty/ipappas/pappaslab/suchita/PPG/ 
├──PPG_Data_Organized
│		└──PET
│			├──PET_Processing_Logs		
│			│			├──Tau_error_logs				    		
│			│			└──Tau_output_logs	

```

## Tau Outputs

- The main outputs of the Tau Pipeline are summarized here: 
	- The first part of the pipeline outputs Braak ROI SUVRs in native PET space: `Has_Tau_derivatives/PET_subjects_process_SUVRs/{SUBJECT_DIRECTORY}/{VISIT_CODE}/`
	- The second part outputs an aseg.stats file consisting of SUVRs for Freesurfer-wide regions (DK atlas): `Has_Tau_derivatives/FS_SUVR_stats/{VISIT_CODE}/{SUBJECT_DIRECTORY}/stats/`

```bash

/cfs/loni/faculty/ipappas/pappaslab/suchita/PPG/ 
├──PPG_Data_Organized
│		└──PET
│			├──Has_Tau_derivatives
│			│			├──PET_subjects_output/{SUBJECT_DIRECTORY}/{VISIT_CODE}/			# Contains Tau-PET SUVR image warped to Native T1 space (sm8mm)		
│			│			├──PET_subjects_process/{SUBJECT_DIRECTORY}/{VISIT_CODE}/			# Contains all intermediate processing files (T1-PET coregistration, SUIT extracted reference region in PET Space etc)
│			│			├──rois/{SUBJECT_DIRECTORY}/{VISIT_CODE}/				    		# Contains all ADNI-protocol Braak ROIs warped to T1, and PET space
│			│			├──Tau-SUIT/{SUBJECT_DIRECTORY}/{VISIT_CODE}/						# Contains initial MATALAB SUIT extracted reference region (inferior cerebellum) - Also includes subject/visit-specific processing log
│			│			├──PET_subjects_process_SUVRs/{SUBJECT_DIRECTORY}/{VISIT_CODE}/ 	# Contains ADNI-protocol Braak ROI SUVRs computed in Native PET Space written to txt files
│			│			│
│			│			├──PET_subjects_process_FSout/{SUBJECT_DIRECTORY}/{VISIT_CODE}/	    # Contains Tau-PET SUVR image warped to FreeSurfer T1 space (sm8mm)
│			│			└──FS_SUVR_stats/{VISIT_CODE}/{SUBJECT_DIRECTORY}/stats/			# Contains ADNI-protocol FreeSurfer-wide (ALL REGIONS) SUVRs computed in FreeSurfer anat space via mri_segstats. These stats are stored in subj/stats 'aseg.stats' files. 
│			│
│			│
```

## Tau SUVR Results

- ***Step 2: Compile Nonweighted SUVRs***
	- To compile the standard ADNI-protocol Braak ROI SUVRs, call `python 10_Compile_Tau_SUVR_Nonweighted.py` with the following arguments

```bash
python 10_Compile_Tau_SUVR_Nonweighted.py -h
usage: 10_Compile_Tau_SUVR_Nonweighted.py [-h] --PPG_Tau_Log_Summary PPG_TAU_LOG_SUMMARY --visit_code VISIT_CODE --output_csv_path OUTPUT_CSV_PATH

Compile Tau-PET SUVR Data PPG USC Subjects - NONWEIGHTED SUVRs.

optional arguments:
  -h, --help            show this help message and exit
 --PPG_Tau_Log_Summary 	PPG_TAU_LOG_SUMMARY
                        Please specify the processed data csv from here: /cfs/loni/faculty/ipappas/pappaslab/suchita/PPG/Data_Pull_CSVs/PET/Processed_CSVs/{date_ran}/PPG_Tau_{date_ran}.csv (SEE
                        OUTPUT OF SCRIPT 2_Process_PET_CSVs.py)
                        
  --visit_code VISIT_CODE	Please specify the visit_code for which you want to compile Tau SUVR results (1/2/3 etc).
  
  --output_csv_path 	OUTPUT_CSV_PATH
                        Please specify a dated directory (MM_DD_YYYY) where you want to write SUVR data to (specify path to a new csv/ path to existing csv) located here :
                        /cfs/loni/faculty/ipappas/pappaslab/suchita/PPG/PPG_Data_Organized/PET/Results/Tau_Latest/Tau_Nonweighted/{date_ran}/Compile_SUVRs_Tau_Subjects_Latest_NonAdjusted_{date_ran}.csv

Example call:

python 10_Compile_Tau_SUVR_Nonweighted.py --PPG_Tau_Log_Summary /cfs/loni/faculty/ipappas/pappaslab/suchita/PPG/Data_Pull_CSVs/PET/Processed_CSVs/08_24_2025/PPG_Tau_08_24_2025.csv \
--visit_code 1 \
--output_csv_path /cfs/loni/faculty/ipappas/pappaslab/suchita/PPG/PPG_Data_Organized/PET/Results/Tau_Latest/Tau_Nonweighted/Compile_SUVRs_Tau_Subjects_Latest_NonAdjusted_08_24_2025.csv

.....You can pass in visit_code 1 and then 2. All SUVR sets will be appended to the same csv here:

	
├──PPG_Data_Organized
│		└──PET
│			└────────Results
│						└──Tau_Latest			
│							├──Tau_Nonweighted	
│			    		    │       └──{DATE}/Compile_SUVRs_Tau_Subjects_Latest_NonAdjusted_{datestamp}.csv

```

- ***Step 3: Compile Volume-weighted SUVRs***
	- `11_asegstatscheat_SUVR_N_Volume.sh` extracts the FreeSurfer stats from each subject's .stats file using the `asegstats2table` cmd. This script draws from a subject list specified inside `/cfs/loni/faculty/ipappas/pappaslab/suchita/PPG/PPG_Data_Organized/PET/Results/Tau_Latest/Tau_Volume_Weighted/Subject_Lists/subjects_${visit_code}.txt`. 
	- Before you run script 11, paste the **all subject IDs available for Tau for a particular visit code** and save it as subjects_${visit_code}.txt. (eg subjects_1.txt, subjects_2.txt etc). You can pick up the list of subs/per vist using the latest log you generated from step 2: `/cfs/loni/faculty/ipappas/pappaslab/suchita/PPG/Data_Pull_CSVs/PET/Processed_CSVs/{date_ran}/PPG_Tau_{date_ran}.csv`
	- Next run `./11_asegstatscheat_SUVR_N_Volume.sh --visits "1, 2" --date MM_DD_YYYY`. This generates suvr and volume txt files for all visit codes you specify in the input argument. If you run into errors specify `-h`. 
	- Next we run `python 12_Compile_Tau_FS_stats_SUVR.py --date_ran MM_DD_YYYY --visit_code_list 1,2` 
		- This script does the following
			- Converts the txt files to csv's.
			- Merges the SUVR and Volume data/per visit. 
			- Stacks the SUVR-Volume data across visits.
			- Calculates the volume weighted SUVRs for all ROIs including Braak/Meta-Temporal ROI. 
			- Merges the volume-weighted SUVR columns and non-weighted SUVRs ('_RAW_SUVR') into a single sheet, harmonizes the column names to suit the format accepted by the IDA. 

```
├──PPG_Data_Organized
│		└──PET
│			└────────Results
│						├──Amyloid_Latest
│						│		└──{DATE}/Compile_SUVRs_Amyloid_Subjects_Latest_{datestamp}.csv	
│				 		│
│						└──Tau_Latest			
│							├──Tau_Nonweighted	
│			    		    │       └──{DATE}/Compile_SUVRs_Tau_Subjects_Latest_NonAdjusted_{datestamp}.csv           # Standard Non-weighted results
│							└──Tau_Volume_Weighted
│									│
│									└──{DATE}
│										├──TXT_files
│										│		{VISIT_CODE}
│			       						│	  		├──fs_suvrs_tau_{VISIT_CODE}.txt		   # 11_asegstatscheat_SUVR_N_Volume.sh outputs
│										│	  		└──fs_volume_tau_{VISIT_CODE}.txt          # SUVR and Volume txt data
│										│	  		
│										│	  
│										└──CSV
│											├──{VISIT_CODE}
│											│		├──fs_suvrs_tau_{VISIT_CODE}.csv		   # 12_Compile_Tau_FS_stats_SUVR.py outputs
│											│		├──fs_volume_tau_{VISIT_CODE}.csv          # Merged SUVR-Volume data/per visit.
│											│		└──FS_SUVR_Vol_Merged_{VISIT_CODE}.csv
│											│	
│											├──FS_SUVR_Vol_Merged_All_Visits.csv                # Stacked SUVR-Volume data across visits.
│											├──FS_SUVR_Vol_Weighted.csv                         # Contains calculated volume weighted SUVRs for all ROIs including Braak/Meta-Temporal ROI
│											├──TAU_4_IDA_To_be_cleaned_{DATE}.csv				# Merged volume-weighted SUVR data and non-weighted SUVR data
│											└──TAU_READY_4_IDA_cleaned_{DATE}.csv			    # Cleaned/Formatted CSV for IDA - Use for IDA 
│
```

## Tau-PET QC

1. Manually edit for visit code. Call via the cmd line `./13_Tau-PET_QC.sh <subjID>`
2. QC steps are similar to Amyloid. For ROIs we check the registration of the PET image to FreeSurfer space (DK atlas). QC notes for the strutural processing are carried over eg if meta-roi is failed, we fail that ROI for PET as well. 

## Setting Up the IDA Release Spreadsheets

```
├──PPG_Data_Organized
│		└──PET
│			└────────Results
│						├──Amyloid_Latest
│						│		└──{DATE}/Compile_SUVRs_Amyloid_Subjects_Latest_{datestamp}.csv	 # Cleaned/Formatted CSV for IDA - Use for IDA 
│				 		│
│						└──Tau_Latest			
│							└──Tau_Volume_Weighted
│									└──{DATE}
│										└──CSV
│											└──TAU_READY_4_IDA_cleaned_{DATE}.csv			# Cleaned/Formatted CSV for IDA - Use for IDA , Contains Volume Weighted + Standard Non-weighted results in 1 sheet
│
```
## IMPORTANT: Regarding Pipeline Updates
Please check with your current supervisor on what ROIs you want to continue to process and release. Eg: `The more recent ADNI protocols have shifted away from deriving Braak ROIs for Tau-PET`. Make it a point to have a discussion on what aspects of the amyloid/tau pipelines require revision and update them. Please remember to consult recent literature and updated imaging protocols published by ADNI. For current protocols being utilized check our March SOPs. Version control must extend to code and data - document by creating new gists/github repos. When releasing data produced through revised-pipelines, explicitly state changes in `updated SOPs`. If you ever catch mistakes in previously processed/released data, state which subjects were reprocessed if any.  

##### Documentation by: Suchita Ganesan, Date: 08/29/2025
