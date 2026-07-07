import os
import pandas as pd
import glob
import csv
import argparse
import json

#NAME: Suchita Ganesan
#DATE CREATED: August 13th, 2024

def is_no(response):
    return response.lower() in ["no", "n"]

def read_n_harmonize_csv(data):
	
	df = pd.read_csv(data, encoding='utf-8') 
	df.columns = df.columns.str.strip()
	df = df.map(lambda x: x.strip() if isinstance(x, str) else x)

	with open(amyloid_json_dict, "r") as f:
		column_map = json.load(f)
	df.rename(columns=column_map, inplace=True)
	return df

def find_image_id(path):
    image_paths = [d for d in glob.glob(os.path.join(path, "*I*")) if os.path.isdir(d)]
    return os.path.basename(image_paths[0]) if image_paths else None


def create_results_csv(organized_data_path, amyloid_log_csv_path, visit_code, output_csv_path):
    # Read the processed CSV into a DataFrame
    amyloid_log = read_n_harmonize_csv(amyloid_log_csv_path)

    # Define the columns to include in the final DataFrame
    output_columns = [
        "PTID", "Visit_Code", "IMAGE_ID_T1", "IMAGE_ID_AMYLOID_PET", "T1_DATE", "AMYLOID_PET_DATE",
        "Interval_Abeta (months)", "FRONTAL_SUVR", "LATERAL_PARIETAL_SUVR",
        "LATERAL_TEMPORAL_SUVR", "APCC_SUVR", "COMPOSITE_SUVR", "AMYLOID_STATUS"
    ]

    data_path = os.path.join(organized_data_path, 'NIFTIs')
    print(f"Data path: {data_path}")

    final_df_rows = []

    if os.path.exists(output_csv_path):
        existing_df = read_n_harmonize_csv(output_csv_path)
        existing_df = existing_df.astype(str)
        existing_subjects = set(zip(existing_df["PTID"], existing_df["Visit_Code"]))
    else:
    	os.makedirs(os.path.dirname(output_csv_path), exist_ok=True)
    	existing_df = pd.DataFrame(columns=output_columns)
    	existing_subjects = set()
    	existing_df.to_csv(output_csv_path, index=False)

    for subject_id in os.listdir(data_path):
        if subject_id.startswith('.'):
            continue

        subject_path = os.path.join(data_path, subject_id, visit_code)

        # Get the paths for PET and T1 scans
        PET_path = glob.glob(f"{subject_path}/Amyloid-PET_*")
        T1_path = glob.glob(f"{subject_path}/T1_*")

        if not PET_path or not T1_path:
            print(f"Missing PET or T1 scans for {subject_id}, skipping...")
            continue

        PET_path, T1_path = PET_path[0], T1_path[0]
        PET_ID, T1_ID = find_image_id(PET_path), find_image_id(T1_path)
        PET_date, T1_date = os.path.basename(PET_path).split('_')[1], os.path.basename(T1_path).split('_')[1]

        # Skip if already in the output CSV
        if (str(subject_id), str(visit_code)) in existing_subjects:
            print(f"PTID {subject_id}, Visit {visit_code} already exists. Skipping.")
            continue

        # Filter for the matching row in processed data
        print(f"Adding NEW PTID {subject_id}, Visit {visit_code}")
        matching_rows = amyloid_log.loc[
            (amyloid_log["PTID"].astype(str) == str(subject_id)) &
            (amyloid_log["Visit_Code"].astype(str) == str(visit_code)) &
            (amyloid_log["IMAGE_ID_T1"].astype(str) == str(T1_ID)) &
            (amyloid_log["IMAGE_ID_AMYLOID_PET"].astype(str) == str(PET_ID)) &
            (amyloid_log["T1_DATE"].astype(str) == str(T1_date)) &
            (amyloid_log["AMYLOID_PET_DATE"].astype(str) == str(PET_date))
        ]

        # If there's a matching row, process it
        if not matching_rows.empty:
            row = matching_rows.iloc[0].to_dict()

            # Add placeholder values for the SUV columns
            for suvr in ["FRONTAL_SUVR", "LATERAL_PARIETAL_SUVR", "LATERAL_TEMPORAL_SUVR", "APCC_SUVR", "COMPOSITE_SUVR", "AMYLOID_STATUS"]:
                row[suvr] = ""

            # Append the row to the results list
            final_df_rows.append(row)

    # Convert the results list to a DataFrame and save it to CSV
    if final_df_rows:
        final_df = pd.DataFrame(final_df_rows, columns=output_columns)

        # Ensure both DataFrames have the same columns and order
        existing_df = existing_df.reindex(columns=output_columns)
        final_df = final_df.reindex(columns=output_columns)

        # Drop completely empty columns (avoids the FutureWarning)
        existing_df = existing_df.dropna(axis=1, how="all")
        final_df = final_df.dropna(axis=1, how="all")

        revised_df = pd.concat([existing_df, final_df], ignore_index=True)
        #Drop "Interval_Abeta (months)" from revised_df
        revised_df.drop('Interval_Abeta (months)', axis=1, inplace=True)
        revised_df.to_csv(output_csv_path, index=False, encoding="utf-8-sig")
        print(f"Results CSV saved to {output_csv_path}")
    else:
        print("No new data to add.")

def compile_suvrs(SUVR_csv_path, SUVRs_Path, visit_code):
    # Load the existing CSV into a dataframe
    SUVR_df = pd.read_csv(SUVR_csv_path)
    
    # Convert 'PTID' and 'Visit_Code' to integers
    SUVR_df['PTID'] = SUVR_df['PTID'].astype(int)
    SUVR_df['Visit_Code'] = SUVR_df['Visit_Code'].astype(int)
    SUVR_df['AMYLOID_STATUS'] = SUVR_df['AMYLOID_STATUS'].astype(str)
    
    # Loop through all subjects in the SUVRs_Path
    for subject in os.listdir(SUVRs_Path):
        subject = subject.strip()  # Remove any leading/trailing whitespace
        if subject.startswith('.') or 'old' in subject.lower():  # Skip hidden directories
            continue
        
        subject_num = int(subject)  # Convert subject to an integer
        visit_code = int(visit_code)
        # Construct file paths for each SUVR measure
        composite_file = f'{SUVRs_Path}/{subject}/{visit_code}/{subject}_Amyloid_amyloid_composite_ROI_v.txt'
        frontal_file = f'{SUVRs_Path}/{subject}/{visit_code}/{subject}_Amyloid_frontal_new_v.txt'
        parietal_file = f'{SUVRs_Path}/{subject}/{visit_code}/{subject}_Amyloid_lat_parietal_new_v.txt'
        temporal_file = f'{SUVRs_Path}/{subject}/{visit_code}/{subject}_Amyloid_lat_temporal_new_v.txt'
        apcc_file = f'{SUVRs_Path}/{subject}/{visit_code}/{subject}_Amyloid_APCC_new_v.txt'
        
        # Check if all required files exist before proceeding
        if os.path.exists(composite_file) and os.path.exists(frontal_file) and os.path.exists(parietal_file) \
           and os.path.exists(temporal_file) and os.path.exists(apcc_file):
            print(f"Checking PTID: {subject_num}, Visit_Code: {visit_code}")
            # Read the SUVR values from the files
            with open(composite_file, 'r') as f:
                composite_value = float(f.readline().strip())
            with open(frontal_file, 'r') as f:
                frontal_value = float(f.readline().strip())
            with open(parietal_file, 'r') as f:
                parietal_value = float(f.readline().strip())
            with open(temporal_file, 'r') as f:
                temporal_value = float(f.readline().strip())
            with open(apcc_file, 'r') as f:
                apcc_value = float(f.readline().strip())


            # Find the matching row in the dataframe for this subject and visit
            subject_num = int(subject.strip())
            subject_row = SUVR_df.loc[(SUVR_df['PTID'] == subject_num) & (SUVR_df['Visit_Code'] == visit_code)]

            # Check if the subject row exists
            if subject_num in SUVR_df['PTID'].values:
                SUVR_df.loc[subject_row.index, 'FRONTAL_SUVR'] = frontal_value
                SUVR_df.loc[subject_row.index, 'LATERAL_PARIETAL_SUVR'] = parietal_value
                SUVR_df.loc[subject_row.index, 'LATERAL_TEMPORAL_SUVR'] = temporal_value
                SUVR_df.loc[subject_row.index, 'APCC_SUVR'] = apcc_value
                SUVR_df.loc[subject_row.index, 'COMPOSITE_SUVR'] = composite_value
                
                # Determine AB classification based on composite value
                if composite_value >= 1.08:
                    SUVR_df.loc[subject_row.index, 'AMYLOID_STATUS'] = "Positive"
                else:
                    SUVR_df.loc[subject_row.index, 'AMYLOID_STATUS'] = "Negative"
            else:
                print(f"No matching row found for PTID: {subject_num}, Visit_Code: {visit_code}")
        else:
            #print(f"No data for PTID: {subject_num}, Visit_Code: {visit_code}")
            continue
     
    if 'QC_RESULT' not in SUVR_df.columns:
    	col_idx = SUVR_df.columns.get_loc("AMYLOID_PET_DATE")
    	SUVR_df.insert(col_idx + 1, "QC_RESULT", "")
    	
    SUVR_df.to_csv(SUVR_csv_path, index=False)
    print(f"PPG Amyloid PET SUVRs Written to: {SUVR_csv_path}\n")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Compile Amyloid-PET SUVR Data PPG USC Subjects.")
    parser.add_argument('--PPG_Amyloid_Log_Summary', type=str, required=True,
                        help='Please specify the processed data csv from here: /path_to_data/PPG/Data_Pull_CSVs/PET/Processed_CSVs/{date_ran}/PPG_Amyloid_{date_ran}.csv (SEE OUTPUT OF SCRIPT 2_Process_PET_CSVs.py)')
    parser.add_argument('--visit_code', type=str, required=True,
                        help='Please specify the visit_code for which you want to compile Amyloid SUVR results (1/2/3 etc).')
    parser.add_argument('--output_csv_path', type=str, required=True,
                        help='Please specify a dated directory (MM_DD_YYYY) where you want to write SUVR data to (specify path to a new csv/ path to existing csv) located here : /path_to_data/PPG/PPG_Data_Organized/PET/Results/Amyloid_Latest/date/Compile_SUVRs_Amyloid_Subjects_Latest_date.csv')
    
    args = parser.parse_args()
    amyloid_log_csv_path = args.PPG_Amyloid_Log_Summary
    visit_code = args.visit_code
    SUVR_csv_path = args.output_csv_path

    print(f"Path to latest log/summary of Amyloid PET imaging data csv: {amyloid_log_csv_path}")

    ########################################### PATHS to DATA/DERIVATIVES etc ########################################################
    amyloid_json_dict = '/path_to_data/PPG/Scripts/PET_Latest/AMYLOID_Scripts/Amyloid_Dictionary.json'
    organized_data_path = '/path_to_data/PPG/PPG_Data_Organized/PET/Has_Amyloid' 
    SUVRs_Path = '/path_to_data/PPG/PPG_Data_Organized/PET/Has_Amyloid_derivatives/PET_subjects_process_SUVRs'
    
    ########################################### CALL FUNCTIONS ##################################################################
    create_results_csv(organized_data_path, amyloid_log_csv_path, visit_code, SUVR_csv_path)
    compile_suvrs(SUVR_csv_path, SUVRs_Path, visit_code)
