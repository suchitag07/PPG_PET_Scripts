#NAME: Suchita Ganesan
#DATE: Aug 16, 2024

from utils import PET_CSV_Wrangling as execute
import pandas as pd
import os
import sys
import argparse


#Define input variables (ie the scans for this cohort - check protocol names)
keep_scans_PET = [
    'Accelerated Sagittal MPRAGE',
    'AA-APOE_TAU (AC)',
    'AA-APOE_AMYLOID (AC)'
]

#-------------------------------------------------------------PROMPTS-------------------------------------------------##################

parser = argparse.ArgumentParser(description="Process PET CSVs and set folder/file names.")

parser.add_argument('--raw_data_csv_path', type=str, required=True,
                    help='Please pull the raw data csv from the IDA and store/source it from here: /path_to_data/PPG/Data_Pull_CSVs/PET/Raw_IDA_CSV/{PET_pull_USC_date}.csv')
parser.add_argument('--date_ran', type=str, required=True,
                    help='Please enter a date string for output folder/file names (format: MM_DD_YYYY).')

args = parser.parse_args()
date_ran = args.date_ran
imaging_raw_CSV = args.raw_data_csv_path

def is_no(response):
    return response.lower() in ["no", "n"]

pet_inventory_check = input("Have you completed running the latest PET image inventory check? (yes/no): ").strip()

if is_no(pet_inventory_check):
    print("Please run the inventory check before running this script.")
    sys.exit()

print(f"PET inventory check completed: {pet_inventory_check}")
print(f"Date entered: {date_ran}")
print(f"Path to latest PET imaging data csv: {imaging_raw_CSV}")

#-----------------------------------------------------MAKE OUTPUT DIRECTORY-------------------------------------------------##################

output_dir = f'/path_to_data/PPG/Data_Pull_CSVs/PET/Processed_CSVs/{date_ran}'
os.makedirs(output_dir, exist_ok=True)

#-----------------------------------------------------INPUT DATA-------------------------------------------------##################

Imaging_Data_Raw = pd.read_csv(imaging_raw_CSV) 
inventory_df = pd.read_csv('/path_to_data/PPG/Data_Pull_CSVs/PET/Existing_Data/PET_Inventory.csv')
Existing_PET_Image_IDs = "/path_to_data/PPG/Data_Pull_CSVs/PET/Existing_Data/Existing_PET_Image_IDs.txt"


#-----------------------------------------------------CALL FUNCTIONS-------------------------------------------------##################
cleaned_imaging = execute.clean_imaging_data(Imaging_Data_Raw, keep_scans_PET) # cleans out the raw IDA CSV and retains all rows with a T1/PET scan description
complete_imaging = execute.find_complete_data(cleaned_imaging) # retains all subjects that have at least 1 mri + 1 pet, Note: we have not checked if the mri-pet interval is within acceptable limits yet, that is done by subsequent functions
filtered_imaging = execute.update_status(complete_imaging, inventory_df) # this compares the inventory csv against the raw data csv and notes which image IDs Exist on the server (updates the status column as: TRUE/FALSE)

Subs_PET_Data = filtered_imaging['Subject'].unique().tolist() 

# Pair data
all_scan_dates = execute.get_dates_for_PET_dataset(filtered_imaging) # function reads the scan dates from the above dataframe and returns a dictionary where key-> subject, value is dict where key is scan_type_description : value is list of all available scan dates
paired_data = execute.pair_imaging(Subs_PET_Data, all_scan_dates, filtered_imaging) # accepts list of subjects, filtered_imaging dataframe, and all_scan_dates dict -> and pairs up each PET scan to nearest T1, returns as dataframe
tau_subs, amyloid_subs, abeta_plus_tau = execute.get_processed_dataframes_PET(paired_data) # takes paired up data and splits into dedicated dataframes 1) one with all tau, 2) one with all amyloid, 3) one with subjects who have amyloid and tau
PET_Server_Log= execute.generate_processed_CSV_data_PET(filtered_imaging, tau_subs, amyloid_subs, abeta_plus_tau) # retrieves all image IDs from: tau_subs, amyloid_subs, abeta_plus_tau, and subsets filtered_imaging using those ie filtered_imaging[Image_ID].isin(list) 

# Check Counts
execute.get_subject_counts(tau_subs, amyloid_subs, abeta_plus_tau) # you can report this the "PET numbers" - should anyone ask how many useable tau/amyloid/both exist for USC PPG subjects
execute.check_img_id_counts_in_final_spreadsheet(PET_Server_Log,tau_subs, amyloid_subs, abeta_plus_tau) #this makes sure the PET_Server_Loglog has all the image IDs from tau_subs, amyloid_subs, abeta_plus_tau

#-----------------------------------------------------RESET VISIT CODE AND WRITE OUTPUTS-------------------------------------------------##################

# Extract the new image IDs as a text file
PET_Server_Log.to_csv(f'{output_dir}/PET_Server_Log_Summary_{date_ran}.csv', index=False) # This has all the data paired up. If you filter according to column [Exists_on_Server]:'FALSE' -> this will show you the details of all 'new images'
Extracted_Image_IDs = f'{output_dir}/PET_Server_Image_IDs_{date_ran}_all.txt' 
execute.save_image_ids_to_txt(PET_Server_Log,Extracted_Image_IDs) # This returns all image id's (those that exist on the server and those that don't)
execute.get_new_img_ids(Existing_PET_Image_IDs, Extracted_Image_IDs, f'{output_dir}/PET_Server_Image_IDs_{date_ran}_new.txt') # This returns only the new image IDs as a text file, you can directly copy and paste these image IDs into the IDA search tab and download them as the 'new-data'. This list/txt file of image IDs should correspond with all rows in PET_Server_Log_Summary_{date_ran}.csv after filtering according to column [Exists_on_Server]:'FALSE' 

#Dataframes
#Write paired tau to csv
tau_subs = execute.reset_visit_code(tau_subs)
tau_subs.to_csv(f'{output_dir}/PPG_Tau_{date_ran}.csv', index=False)

#Write paired amyloid to csv
amyloid_subs = execute.reset_visit_code(amyloid_subs)
amyloid_subs.to_csv(f'{output_dir}/PPG_Amyloid_{date_ran}.csv', index=False)

#Write those with amyloid and tau to csv
abeta_plus_tau = execute.reset_visit_code(abeta_plus_tau)
abeta_plus_tau.to_csv(f'{output_dir}/PPG_ABETA_PLUS_TAU_{date_ran}.csv', index=False)
