import os
import pandas as pd
import glob
import csv
import argparse
import json

def read_n_harmonize_csv(data):
	
	df = pd.read_csv(data, encoding='utf-8') 
	df.columns = df.columns.str.strip()
	df = df.map(lambda x: x.strip() if isinstance(x, str) else x)

	with open(TAU_json_dict, "r") as f:
		column_map = json.load(f)
	df.rename(columns=column_map, inplace=True)
	return df

def find_image_id(path):
    image_paths = [d for d in glob.glob(os.path.join(path, "*I*")) if os.path.isdir(d)]
    return os.path.basename(image_paths[0]) if image_paths else None

def create_results_csv(organized_data_path, tau_log_csv_path, visit_code, output_csv_path):
    # Read the processed CSV into a DataFrame
    tau_log = read_n_harmonize_csv(tau_log_csv_path)

    # Define the columns to include in the final DataFrame
    output_columns = [
        "PTID", "Visit_Code", "IMAGE_ID_T1", "IMAGE_ID_TAU_PET", "T1_DATE", "TAU_PET_DATE",
        "Interval_Tau (months)", "BRAAK_I_RAW_SUVR", "BRAAK_III_IV_RAW_SUVR",
        "BRAAK_V_VI_RAW_SUVR", "META_TEMPORAL_RAW_SUVR"
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
        PET_path = glob.glob(f"{subject_path}/Tau-PET_*")
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
        matching_rows = tau_log.loc[
            (tau_log["PTID"].astype(str) == str(subject_id)) &
            (tau_log["Visit_Code"].astype(str) == str(visit_code)) &
            (tau_log["IMAGE_ID_T1"].astype(str) == str(T1_ID)) &
            (tau_log["IMAGE_ID_TAU_PET"].astype(str) == str(PET_ID)) &
            (tau_log["T1_DATE"].astype(str) == str(T1_date)) &
            (tau_log["TAU_PET_DATE"].astype(str) == str(PET_date))
        ]

        # If there's a matching row, process it
        if not matching_rows.empty:
            row = matching_rows.iloc[0].to_dict()

            # Add placeholder values for the SUV columns
            for suvr in ["BRAAK_I_RAW_SUVR", "BRAAK_III_IV_RAW_SUVR", "BRAAK_V_VI_RAW_SUVR", "META_TEMPORAL_RAW_SUVR"]:
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
    
    # Loop through all subjects in the SUVRs_Path
    for subject in os.listdir(SUVRs_Path):
        subject = subject.strip()  # Remove any leading/trailing whitespace
        if subject.startswith('.') or 'old' in subject.lower():  # Skip hidden directories or old folders if any
            continue
        
        subject_num = int(subject)  # Convert subject to an integer
        visit_code = int(visit_code)
        # Construct file paths for each SUVR measure
        Braak_1 = f'{SUVRs_Path}/{subject}/{visit_code}/{subject}_Tau_Braak_ROI_I_v.txt'
        Braak_3_4 = f'{SUVRs_Path}/{subject}/{visit_code}/{subject}_Tau_Braak_ROI_III-IV_v.txt'
        Braak_5_6 = f'{SUVRs_Path}/{subject}/{visit_code}/{subject}_Tau_Braak_ROI_V-VI_v.txt'
        Meta_Temporal = f'{SUVRs_Path}/{subject}/{visit_code}/{subject}_Tau_Meta_Temporal_ROI_v.txt'
        
        # Check if all required files exist before proceeding
        if os.path.exists(Braak_1) and os.path.exists(Braak_3_4) and os.path.exists(Braak_5_6) \
           and os.path.exists(Meta_Temporal):
            print(f"Checking PTID: {subject_num}, Visit_Code: {visit_code}")
            # Read the SUVR values from the files
            with open(Braak_1, 'r') as f:
                Braak_1_value = float(f.readline().strip())
            with open(Braak_3_4, 'r') as f:
                Braak_3_4_value = float(f.readline().strip())
            with open(Braak_5_6, 'r') as f:
                Braak_5_6_value = float(f.readline().strip())
            with open(Meta_Temporal, 'r') as f:
                Meta_Temporal_value = float(f.readline().strip())

            # Find the matching row in the dataframe for this subject and visit
            subject_num = int(subject.strip())
            subject_row = SUVR_df.loc[(SUVR_df['PTID'] == subject_num) & (SUVR_df['Visit_Code'] == visit_code)]

            # Check if the subject row exists
            if subject_num in SUVR_df['PTID'].values:
                SUVR_df.loc[subject_row.index, 'BRAAK_I_RAW_SUVR'] = Braak_1_value
                SUVR_df.loc[subject_row.index, 'BRAAK_III_IV_RAW_SUVR'] = Braak_3_4_value
                SUVR_df.loc[subject_row.index, 'BRAAK_V_VI_RAW_SUVR'] = Braak_5_6_value
                SUVR_df.loc[subject_row.index, 'META_TEMPORAL_RAW_SUVR'] = Meta_Temporal_value
            else:
                print(f"No matching row found for PTID: {subject_num}, Visit_Code: {visit_code}")
        else:
            # print(f"No data for PTID: {subject_num}, Visit_Code: {visit_code}")
            continue
            
    SUVR_df.to_csv(SUVR_csv_path, index=False)
    print(f"PPG Tau PET SUVRs Written to: {SUVR_csv_path}\n")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Compile Tau-PET SUVR Data PPG USC Subjects - NONWEIGHTED SUVRs.")
    parser.add_argument('--PPG_Tau_Log_Summary', type=str, required=True,
                        help='Please specify the processed data csv from here: /path_to_data/PPG/Data_Pull_CSVs/PET/Processed_CSVs/{date_ran}/PPG_Tau_{date_ran}.csv (SEE OUTPUT OF SCRIPT 2_Process_PET_CSVs.py)')
    parser.add_argument('--visit_code', type=str, required=True,
                        help='Please specify the visit_code for which you want to compile Tau SUVR results (1/2/3 etc).')
    parser.add_argument('--output_csv_path', type=str, required=True,
                        help='Please specify a dated directory (MM_DD_YYYY) where you want to write SUVR data to (specify path to a new csv/ path to existing csv) located here : /path_to_data/PPG/PPG_Data_Organized/PET/Results/Tau_Latest/Tau_Nonweighted/date/Compile_SUVRs_Tau_Subjects_Latest_NonAdjusted_date.csv')
    
    args = parser.parse_args()
    tau_log_csv_path = args.PPG_Tau_Log_Summary
    visit_code = args.visit_code
    SUVR_csv_path = args.output_csv_path

    print(f"Path to latest log/summary of Tau PET imaging data csv: {tau_log_csv_path}")

    ########################################### PATHS to DATA/DERIVATIVES etc ########################################################
    TAU_json_dict = '/path_to_data/PPG/Scripts/PET_Latest/TAU_Scripts/Tau_Dictionary.json'
    organized_data_path = '/path_to_data/PPG/PPG_Data_Organized/PET/Has_Tau' 
    SUVRs_Path = '/path_to_data/PPG/PPG_Data_Organized/PET/Has_Tau_derivatives/PET_subjects_process_SUVRs'
    
    ########################################### CALL FUNCTIONS ##################################################################
    create_results_csv(organized_data_path, tau_log_csv_path, visit_code, SUVR_csv_path)
    compile_suvrs(SUVR_csv_path, SUVRs_Path, visit_code)

