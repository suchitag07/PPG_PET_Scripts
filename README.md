### PPG PET Pipeline Instructions: Amyloid (FBB) and Tau-PET (FTP)

- This document contains step-by-step instructions for processing Amyloid (FBB) and Tau (FTP) PET data provided by the USC PPG cohort. The pipeline covers inventory, organization, FreeSurfer processing/ROI extraction, PET-MRI coregistration, and SUVR calculation. All script call locations, required inputs, expected outputs, and directory structures are described in detail.
- Note: These scripts were written and troubleshooted across the period of July 2024 - August 2025 under the supervison of Dr. Ioannis Pappas. Any major changes to the PET IDA data format post that period will need to be accounted for. 

```bash
								OVERVIEW OF PPG PET PIPELINE SCRIPTS
=========================================================================================================
## Scripts																			# Purpose
├── Scripts/                                    
│   	└── PET_Latest/
│			   │ 
│			   ├── README.md
│			   ├──1_Check_PET_Inventory.py											# Returns log of existing data/IMAGE-IDs located on the server
│			   ├──2_Process_PET_CSVs.py												# Processes IDA data sheets and returns which PET/T1 IMAGE-ID pairs need to be processed. Utility functions located inside utils/PET_CSV_Wrangling.py. 
│			   ├──3_Organize_IDA_PET_latest_version.sh								# PET/T1 data organization script
│			   ├──4_PET_dcm2niix.sh													# Data conversion
│			   ├──5_Check_Subs_to_Process.sh								        # Generates list of subjects that require processing 
│			   ├──6_Copy_FreeSurfer_parcellations.sh							    # Pulls FreeSurfer dependencies 
│			   │
│			   ├──AMYLOID_Scripts
│			   │	├──Amyloid_Dictionary.json										# Used to harmonize columns for IDA CSV. Utlized inside 9_Compile_Amyloid_SUVR.py.
│			   │ 	├──Create_ADNI_amyloid_ROIs_T1_space.sh 	                    # Subscript called inside main Amyloid Pipeline
│			   │	├──7_SG_Amyloid_PET.sh											# Main Amyloid Pipeline called inside QSUB script and Serial_Process script
│			   │	├──8_QSUB_AMYLOID.sh
│			   │	└──9_Compile_Amyloid_SUVR.py									# Compiles Amyloid SUVRs and produces IDA formatted results CSV.  
│			   │
│			   ├──TAU_Scripts
│			   │	├──Tau_Dictionary.json											# Used to harmonize columns for IDA CSV. Utlized inside 10_Compile_Tau_SUVR_Nonweighted.py and 12_Compile_Tau_FS_stats_SUVR.py.
│			   │	├──Tau_ROIs.json												# Used for calculation of volume weighted SUVRs (Dictionary of FreeSurfer codes for each Braak ROI). Utilized inside 12_Compile_Tau_FS_stats_SUVR.py
│			   │	├──Create_ADNI_Tau_ROIs.sh					                    # Subscript called inside main Tau Pipeline
│			   │	├──SG_process_SUIT_v2.m											# MATLAB function to extract reference region from the SUIT Atlas
│			   │	├──7a_Process_SUIT.sh											# Calls SUIT function - can run from the cmd line or via QSUB/Serial process 									
│			   │	├──7_QSUB_SUIT.sh																					
│			   │	├──8_SG_Tau_PET.sh												# Main Tau Pipeline called inside QSUB script and Serial_Process script. Two sets of SUVRs are generated from this script: 1) Standard Nonweighted Tau SUVRs for Braak ROIs 2) SUVRs for all freesurfer wide regions (mri_segstats)
│			   │	├──9_QSUB_TAU.sh
│			   │	├──10_Compile_Tau_SUVR_Nonweighted.py							# Script to compile 1) Standard non-weighted Tau SUVRs
│			   │	├──11_asegstatscheat_SUVR_N_Volume.sh							# Script to extract 2) FreeSurfer derived volumes and SUVRs (produced through mri_segstats) from .stats files 
│			   │	└──12_Compile_Tau_FS_stats_SUVR.py								# Script to compile volume weighted Tau SUVRs (crosses FreeSurfer metrics with SUVRs) and merge them with our non-weighted results. Produces IDA formatted CSV.  
│			   │
│			   └──utils
│					├──__init__.py
│					├──PET_CSV_Wrangling.py
│					└──READMEUTILS.md
			
=========================================================================================================
```	
---
