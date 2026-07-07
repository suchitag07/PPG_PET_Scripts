import os
import csv
import pandas as pd
import numpy as np
import json
import re
import argparse

def parse_visit_codes(s):
    return [int(x) for x in s.split(",")]

def text_to_csv(input_text_file, output_csv_file, delimiter=' '):
    """Reads in txt outsputs from fs asegstatscheat script and converts them to csv files.
    eg:
        input_text_file: eg 'fs_suvrs.txt'
        output_csv_file eg fs_suvrs.csv
        delimiter= ','
    """
    try:
        with open(input_text_file, 'r') as txt_file, open(output_csv_file, 'w', newline='') as csv_file:
            reader = csv.reader(txt_file, delimiter=delimiter)
            writer = csv.writer(csv_file)
            writer.writerows(reader)
        print(f"Successfully converted '{input_text_file}' to '{output_csv_file}'")
    except Exception as e:
        print(f"Error: {e}")
        
def convert_all_txt_to_csv(base_dir, visit_codes, delimiter=' '):
    """Loops through visit codes, finds txt files, and converts them to CSV in a separate CSV directory."""
    for visit_code in visit_codes:
        txt_dir = os.path.join(base_dir, "TXT_files", str(visit_code))
        csv_dir = os.path.join(base_dir, "CSV", str(visit_code))
        os.makedirs(csv_dir, exist_ok=True)  # make sure CSV directory exists

        suvr_txt = os.path.join(txt_dir, f"fs_suvrs_tau_Visit_{visit_code}.txt")
        volume_txt = os.path.join(txt_dir, f"fs_volume_tau_Visit_{visit_code}.txt")

        suvr_csv = os.path.join(csv_dir, f"fs_suvrs_tau_Visit_{visit_code}.csv")
        volume_csv = os.path.join(csv_dir, f"fs_volume_tau_Visit_{visit_code}.csv")

        if os.path.exists(suvr_txt):
            text_to_csv(suvr_txt, suvr_csv, delimiter)
        else:
            print(f"Missing SUVR txt file for visit {visit_code}")

        if os.path.exists(volume_txt):
            text_to_csv(volume_txt, volume_csv, delimiter)
        else:
            print(f"Missing Volume txt file for visit {visit_code}")


def sort_n_merge_suvr_vol_data(base_dir, visit_codes):
    """Reads in the suvr and volume csv's, cleans up the columns, merges the 2 metrics into a single csv, and reformats them."""
    for visit_code in visit_codes:
        # Construct file paths for each visit
        SUVR_file = os.path.join(base_dir, str(visit_code), f"fs_suvrs_tau_Visit_{visit_code}.csv")
        Volume_file = os.path.join(base_dir, str(visit_code), f"fs_volume_tau_Visit_{visit_code}.csv")

        # Reads in the suvr and volume csv's
        SUVR = pd.read_csv(SUVR_file)
        volume = pd.read_csv(Volume_file)
        
        # Cleans up the columns
        SUVR.columns = SUVR.columns.str.strip()
        volume.columns = volume.columns.str.strip()
        
        SUVR.rename(columns={'Measure:mean': 'PTID'}, inplace=True)
        volume.rename(columns={'Measure:volume': 'PTID'}, inplace=True)
        
        SUVR.drop(columns=['Unknown'], errors='ignore', inplace=True)  
        volume.drop(columns=['Unknown'], errors='ignore', inplace=True)
        
        # append prefixes
        SUVR.columns = [
            col + '_SUVR' if col != 'PTID' and '_SUVR' not in col else col
            for col in SUVR.columns
        ]
        
        volume.columns = [
            col + '_volume' if col != 'PTID' and '_volume' not in col else col
            for col in volume.columns
        ]
        
        # Merge the dataframes
        merged_df = pd.merge(SUVR, volume, on='PTID', how='outer')
        # Insert Visit_Code column
        merged_df['Visit_Code'] = visit_code
        
        # Rearrange columns _SUVR, _volume etc
        column_names = [col for col in merged_df.columns if col not in ['PTID', 'Visit_Code']]
        interleaved_columns = []
        for col in column_names:
            if col.endswith('_SUVR'):
                interleaved_columns.append(col)
                matching_col = col[:-5] + '_volume'  # Match '_SUVR' with '_volume'
                if matching_col in column_names:
                    interleaved_columns.append(matching_col)
        
        sorted_columns = ['PTID'] + ['Visit_Code'] + interleaved_columns
        merged_df = merged_df[sorted_columns]
        
        # Save the merged dataframe
        output_file = os.path.join(base_dir, str(visit_code), f"FS_SUVR_Vol_Merged_{visit_code}.csv")
        merged_df.to_csv(output_file, index=False)
        print(f"Merged CSV saved to {output_file} for {visit_code}")

def merge_SUVR_Vol_csv_across_visits(base_dir, visit_codes):
    """Stack all FS_SUVR_Vol_Merged_{v}.csv into one across visits."""
    files = [os.path.join(base_dir, str(v), f"FS_SUVR_Vol_Merged_{v}.csv") 
             for v in visit_codes if os.path.exists(os.path.join(base_dir, str(v), f"FS_SUVR_Vol_Merged_{v}.csv"))]

    if not files:
        print("No per-visit merged CSVs found.")
        return

    merged = pd.concat((pd.read_csv(f) for f in files), ignore_index=True)
    if 'Visit_Code' in merged.columns:
        merged['Visit_Code'] = merged['Visit_Code'].astype(int)
    merged.to_csv(os.path.join(base_dir, "FS_SUVR_Vol_Merged_All_Visits.csv"), index=False)
    print(f"Merged {len(files)} files into FS_SUVR_Vol_Merged_All_Visits.csv")
    
def get_image_details(csv_file, fs_dir, visit_codes):
    """
    B4 I merge our FS_SUVR_Vol_Merged_All_Visits.csv (i.e., Weighted SUVR results) with our Nonweighted SUVR results, 
    I like to extract the T1_date and image ID from the recon log input line and append those details to the FS_SUVR_Vol_Merged_All_Visits file.
    This serves as a sanity check (ensure we ran FS on the correct T1 that is matched to the sub's Tau-PET).
    We will then merge the Weighted + Non-Weighted sheets via PTID IMAGE_ID_T1 and Visit_Code.
    """

    data = pd.read_csv(csv_file)
    subject_list = data['PTID'].unique().tolist()
    
    subject_data_dict = {}

    for visit_code in visit_codes:
        visit_fs_dir = os.path.join(fs_dir, str(visit_code))
        
        for sub in subject_list:
            sub_fs_dir = os.path.join(visit_fs_dir, f"sub-{sub}")
            recon_log = os.path.join(sub_fs_dir, 'scripts', 'recon-all.log')
            
            if os.path.exists(recon_log):
                with open(recon_log, 'r') as log_file:
                    log_lines = log_file.readlines()
                    
                    for line in log_lines:
                        if '/usr/local/freesurfer-7.1.1/bin/recon-all' in line and '-i' in line:
                            # extract the T1 file path after the '-i' argument
                            t1_full_path = line.split('-i ')[1].split(' ')[0]
                            
                            # extract the image ID from the filename (drop .nii.gz extension)
                            t1_nifti_name = os.path.basename(t1_full_path)
                            image_id = t1_nifti_name.split('_')[-1].replace('.nii.gz', '')

                            # update dictionary: {subject: {visit_code: {date: image_id}}}
                            if sub not in subject_data_dict:
                                subject_data_dict[sub] = {}
                            if visit_code not in subject_data_dict[sub]:
                                subject_data_dict[sub][visit_code] = {}
                            subject_data_dict[sub][visit_code]= image_id

    # insert new columns 'IMAGE_ID_T1'
    for col in ['IMAGE_ID_T1']:
        if col not in data.columns:
            data[col] = ''

    # populate the dataframe
    for idx, row in data.iterrows():
        sub = row['PTID']
        visit_id = row['Visit_Code']
        if sub in subject_data_dict and visit_id in subject_data_dict[sub]:
            image_id = subject_data_dict[sub][visit_id]
            data.at[idx, 'IMAGE_ID_T1'] = image_id
            print(f"Updated Subject {sub}: Visit {visit_id}, Image_ID={image_id}")

    data.to_csv(csv_file, index=False)
    print(f"Updated data saved to '{csv_file}'")

        
def calculate_vol_weighted_suvrs(SUVR_Volume_data, missing_rois_file, output_file):
    df = pd.read_csv(SUVR_Volume_data)  # Merged fs suvr and volume stats
    
    # load Tau_ROIs.json into a dictionary
    with open('/path_to_data/PPG/Scripts/PET_Latest/TAU_Scripts/Tau_ROIs.json', 'r') as file:
        tau_rois = json.load(file)
    with open(missing_rois_file, 'w') as missing_file: # this is useful for subs with pathological issues/fs might have errored out on computing stats for a regipn, this missing text should catch those rois

        # insert Braak composite columns at the beginning 
        for idx, composite_name in enumerate(tau_rois):
            composite_total_volume = f"{composite_name}_volume"
            composite_sum_vol_weighted = f"{composite_name}_sum_vol_weighted"
            composite_vol_weighted_suvr = f"{composite_name}_weighted_SUVR"
        
            df.insert(1, composite_vol_weighted_suvr, 0.0)  
            df.insert(2, composite_sum_vol_weighted, 0.0)  
            df.insert(3, composite_total_volume, 0.0)  

            # calculate metrics for each component of that braak/meta region
            for roi_code, roi_name in tau_rois[composite_name].items():
                volume_col = f"{roi_name}_volume"
                suvr_col = f"{roi_name}_SUVR"
                vol_weighted_col = f"{roi_name}_v_wted"
                df[vol_weighted_col] = 0.0 

                if volume_col and suvr_col in df.columns:
                    # calculate vol_weighted suvr for that component
                    df.loc[:, vol_weighted_col] = df.apply(lambda row: row[volume_col] * row[suvr_col], axis=1).round(8)
                    # update the total volume and total vol_weighted data
                    df.loc[:, composite_total_volume] = df.apply(lambda row: row[composite_total_volume] + row[volume_col], axis=1)
                    df.loc[:, composite_sum_vol_weighted] = df.apply(lambda row: row[composite_sum_vol_weighted] + row[vol_weighted_col], axis=1).round(8)
                else:
                    missing_file.write(f"Missing ROI: {roi_code}, {roi_name}\n")

            # final vol weighted suvr for that entire composite roi
            df.loc[:, composite_vol_weighted_suvr] = df.apply(
                lambda row: row[composite_sum_vol_weighted] / row[composite_total_volume] if row[composite_total_volume] != 0 else 0, 
                axis=1
            ).round(8)

    df.to_csv(output_file, index=False)


def merge_Nonweighted_n_Weighted_results(non_weighted_results_csv, vol_weighted_results_csv, output_file):
    """
    Merge the Weighted (FS_SUVR_Vol_Merged_All_Visits.csv) 
    and Non-Weighted SUVR results via PTID, T1_DATE, IMAGE_ID_T1, and Visit_Code.
    """

    df_nonweighted = pd.read_csv(non_weighted_results_csv)
    df_weighted = pd.read_csv(vol_weighted_results_csv)

    merged_df = pd.merge(
        df_nonweighted,
        df_weighted,
        on=['PTID','IMAGE_ID_T1', 'Visit_Code'],
        how='outer'
    )

    merged_df.to_csv(output_file, index=False)
    print(f"Merged weighted + nonweighted SUVR results n saved to: {output_file}")


def clean_final_csv(input_csv, TAU_json_dict, output_file):
    df = pd.read_csv(input_csv)

    # drop intermediate columns based on patterns
    columns_to_drop = [
        col for col in df.columns 
        if '_v_wted' in col or '_sum_vol_weighted' in col or 'Interval_Tau (months)' in col or 'Left-vessel_' in col
    ]
    df.drop(columns=columns_to_drop, inplace=True)

    # convert all column names to uppercase and replace "_TOTAL_VOLUME" with "_VOLUME"
    df.columns = [
        col.upper().replace('_TOTAL_VOLUME', '_VOL').replace('_VOLUME', '_VOL').replace('-','_')
        for col in df.columns
    ]

    # add QC_RESULT column
    df["QC_RESULT"] = None

    standard_columns = ['PTID', 'VISIT_CODE', 'IMAGE_ID_T1', 'IMAGE_ID_TAU_PET', 'T1_DATE', 'TAU_PET_DATE', 'QC_RESULT']
    braaks = ['Braak_I_SUVR', 'Braak_III_IV_SUVR', 'Braak_V_VI_SUVR', 'Meta_Temporal_SUVR']

    # Interleave ROI columns: RAW_SUVR, WEIGHTED_SUVR, VOLUME
    interleaved_columns = []
    for col in braaks:
        region_base = col.replace('-', '_').split('_SUVR')[0].upper()
        unweighted_col = f"{region_base}_RAW_SUVR"
        weighted_col = f"{region_base}_WEIGHTED_SUVR"
        volume_col = f"{region_base}_VOL"
        if all(c in df.columns for c in [unweighted_col, weighted_col, volume_col]):
            interleaved_columns.extend([unweighted_col, weighted_col, volume_col])

    # other ROI columns
    other_roi_columns = [
        col for col in df.columns if col not in standard_columns + interleaved_columns
    ]
    sorted_columns = standard_columns + interleaved_columns + other_roi_columns

    df = df[[col for col in sorted_columns if col in df.columns]]
    
    with open(TAU_json_dict, "r") as f:
        column_map = json.load(f)
        df.rename(columns=column_map, inplace=True)
    
    df.to_csv(output_file, index=False)
    print(f"Cleaned data saved to {output_file}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Compile Tau-PET SUVR Data PPG USC Subjects - FREESURFER VOLUME WEIGHTED SUVRs."
    )
    parser.add_argument(
        '--date_ran',
        type=str,
        required=True,
        help='Please enter a date string for output folder/file names (format: MM_DD_YYYY).'
    )
    parser.add_argument(
    "--visit_code_list",
    type=parse_visit_codes,
    help="Comma-separated visit codes (format: --visit_code_list 1,2,3)",
	)
    
    args = parser.parse_args()
    date_ran = args.date_ran
    visit_code_list = args.visit_code_list
    
    fs_raw_stats_compiled_dir = f"/path_to_data/PPG/PPG_Data_Organized/PET/Results/Tau_Latest/Tau_Volume_Weighted/{date_ran}"
    fs_raw_stats_compiled_txt = f"/path_to_data/PPG/PPG_Data_Organized/PET/Results/Tau_Latest/Tau_Volume_Weighted/{date_ran}/TXT_files"
    fs_raw_stats_compiled_csv = f"/path_to_data/PPG/PPG_Data_Organized/PET/Results/Tau_Latest/Tau_Volume_Weighted/{date_ran}/CSV"
    non_weighted_results_csv = f"/path_to_data/PPG/PPG_Data_Organized/PET/Results/Tau_Latest/Tau_Nonweighted/{date_ran}/Compile_SUVRs_Tau_Subjects_Latest_NonAdjusted_{date_ran}.csv"
    vol_weighted_results_csv = f"/path_to_data/PPG/PPG_Data_Organized/PET/Results/Tau_Latest/Tau_Volume_Weighted/{date_ran}/CSV/FS_SUVR_Vol_Weighted.csv"
    TAU_4_IDA_To_be_cleaned = os.path.join(fs_raw_stats_compiled_csv, f"TAU_4_IDA_To_be_cleaned_{date_ran}.csv")
    TAU_READY_4_IDA_cleaned = os.path.join(fs_raw_stats_compiled_csv, f"TAU_READY_4_IDA_cleaned_{date_ran}.csv")
    fs_dir = "/path_to_data/PPG/PPG_Data_Organized/PET/SG_Freesurfer_Outputs_v_7_1/TAU"
    TAU_json_dict= "/path_to_data/PPG/Scripts/PET_Latest/TAU_Scripts/Tau_Dictionary.json"
	
    # Step 1: Convert txt → csv
    if os.path.exists(fs_raw_stats_compiled_dir):
        convert_all_txt_to_csv(fs_raw_stats_compiled_dir, visit_code_list, delimiter='\t')
    else:
        print(f"FS txt directory not found: {fs_raw_stats_compiled_dir}")

    # Step 2: Merge SUVR + Volume for each visit
    if os.path.exists(fs_raw_stats_compiled_csv):
        sort_n_merge_suvr_vol_data(fs_raw_stats_compiled_csv, visit_code_list)
    else:
        print(f"FS csv directory not found: {fs_raw_stats_compiled_csv}")

    # Step 3: Merge across visits
    merged_all_visits_file = os.path.join(fs_raw_stats_compiled_csv, "FS_SUVR_Vol_Merged_All_Visits.csv")
    if all(os.path.exists(os.path.join(fs_raw_stats_compiled_csv, str(v), f"FS_SUVR_Vol_Merged_{v}.csv")) for v in visit_code_list):
        merge_SUVR_Vol_csv_across_visits(fs_raw_stats_compiled_csv, visit_code_list)
    else:
        print("Not all per-visit merged CSVs exist, skipping merge across visits.")

    # Step 4: Extract T1 image details
    if os.path.exists(merged_all_visits_file) and os.path.exists(fs_dir):
        get_image_details(merged_all_visits_file, fs_dir, visit_code_list)
    else:
        print(f"Cannot get image details: {merged_all_visits_file} or FS dir {fs_dir} not found")

    # Step 5: Calculate volume-weighted SUVRs
    missing_rois_txt = os.path.join(fs_raw_stats_compiled_txt, "Missing_ROIs.txt")
    if os.path.exists(merged_all_visits_file):
        calculate_vol_weighted_suvrs(merged_all_visits_file, missing_rois_txt, vol_weighted_results_csv)
    else:
        print(f"Cannot calculate volume-weighted SUVRs: {merged_all_visits_file} not found")

    # Step 6: Merge Nonweighted + Weighted results
    if os.path.exists(non_weighted_results_csv) and os.path.exists(vol_weighted_results_csv):
        merge_Nonweighted_n_Weighted_results(non_weighted_results_csv, vol_weighted_results_csv, TAU_4_IDA_To_be_cleaned)
    else:
        print("Cannot merge Weighted + Nonweighted results: one or both CSVs missing")

    # Step 7: Clean final CSV
    if os.path.exists(TAU_4_IDA_To_be_cleaned):
        clean_final_csv(TAU_4_IDA_To_be_cleaned, TAU_json_dict, TAU_READY_4_IDA_cleaned)
    else:
        print(f"Cannot clean final CSV: {TAU_4_IDA_To_be_cleaned} not found")
