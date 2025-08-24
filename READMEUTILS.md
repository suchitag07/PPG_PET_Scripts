# PET Imaging Data Pipeline for USC PPG

## INTRODUCTION

This pipeline processes and organizes PET imaging data for the USC PPG cohort.  
It uses a series of data-cleaning functions to match MRI/PET scans, generate tracking logs, and produce summary CSVs and text files for further manual review and data management.

**PET_CSV_Wrangling_Functions** is a Python module (located in the `utils` subdirectory) containing all key functions for this pipeline. These functions are imported and used under the alias `execute`.

This section explains each function step by step.

**Please read this carefully:**
- If you plan to revise any function, please understand the current explained logic and dependencies.
- If you want to write your own scripts that build upon or append to the PET data already processed and stored in `/ifs/loni/faculty/old.ipappas/pappaslab/suchita/PPG`.

---

### IMPORTANT

If you change any of the core logic in these functions, you must reprocess all data and carefully report that change.  
This is because the pipeline selects and organizes subjects and IMAGE IDs based on what data already exists inside the specified directory, and relies on that structure for accurate outputs.

A key detail: sometimes the IDA will contain duplicate scans under the same subject and timepoint, but with different IMAGE IDs. This can lead to discrepancies, especially if an existing subject/timepoint is later reprocessed with different IMAGE IDs across data pulls.  
For subjects already processed/existing, my code continually matches and uses the same IMAGE ID when new IDA CSVs are downloaded/read, preventing accidental reprocessing of an old subject/timepoint under a new IMAGE ID.

This logic—maintaining IMAGE ID consistency and preventing unwanted reprocessing—is carefully handled in:
```bash
- `1_Check_Inventory.py`
- Module functions: `update_status` and `pair_imaging`
```
Always ensure any modification maintains this behavior, unless you intentionally want to change it (in which case, report and reprocess all affected data).

---

## EXPLANATION OF ALL FUNCTIONS

### Data Cleaning and Filtering

**`execute.clean_imaging_data(Imaging_Data_Raw, keep_scans_PET)`**  
- Removes irrelevant scans from the raw IDA CSV.
- Retains only entries with a scan description that matches T1 or PET (using the `keep_scans_PET` list).
- Returns a cleaned dataframe for further analysis.

**`execute.find_complete_data(cleaned_imaging)`**  
- Filters subjects who have at least one MRI (T1) and one PET scan.
- Does _not_ apply any timing constraints on the MRI-PET interval; this is handled later.
- Returns only those subjects that have both modalities present (at least 1 T1 and 1 PET scan)

**`execute.update_status(complete_imaging, inventory_df)`**  
- Compares the inventory CSV (list of files actually available on the server) against the filtered raw data.
- Updates a status column labeled as TRUE (image ID present) or FALSE (image ID absent - ie represents new data).

---

### Data Pairing and Summary

**`execute.get_dates_for_PET_dataset(filtered_imaging)`**  
- Returns a nested dictionary containing scan dates for each subject and scan type.
- **Structure example:**

```bash

all_scan_dates_dict = {
    "SUBJECT_1001": {
        "Accelerated Sagittal MPRAGE": ["2022-08-01", "2023-01-15"],    # all T1 scan dates
        "AA-APOE_AMYLOID (AC)": ["2022-08-02"]                          # all amyloid scan dates
    },
    "SUBJECT_1002": {
        "Accelerated Sagittal MPRAGE": ["2021-07-01", "2023-03-07"],    # all T1 scan dates
        "AA-APOE_TAU (AC)": ["2021-07-10"],                             # all tau scan dates
        "AA-APOE_AMYLOID (AC)": ["2023-03-01"]                          # all amyloid scan dates
    }
}
```
- **Outer keys:** Subject IDs (as strings).
- **Inner keys:** Scan descriptions (T1, Tau, Amyloid, etc).
- **Values:** List of acquisition dates as strings.

**`execute.pair_imaging(Subs_PET_Data, all_scan_dates, filtered_imaging)`**  
- Accepts the full subject list, the scan dates dictionary, and the filtered dataframe.
- Returns a new dataframe with each PET scan linked to its closest T1.

**How `execute.pair_imaging` matches T1 and PET via date comparison:**  
- Loops through series of T1 dates, for each T1 date, the subfunction `find_nearest_img_date(img_date, PET_Abeta_dates, PET_Tau_dates)` finds minimum abs diff between T1 date and Amyloid/Tau pet date series
- Returns nearest abeta/tau pet date along with pet-t1 interval in months

**How `execute.pair_imaging` Retains Existing Image IDs:**
- For each T1, and the nearest matched Abeta/Tau scan, if more than one image ID is available for a scan/date, the function always selects the image ID already existing on the server via the row value `Exists_on_Server == True`.
- First stores all image ids found for the T1 date, matched Tau date, matched Amyloid date as a dictionary of tuples.

Eg Dict:

```bash
T1_img_ids_dict = {('SUBJECT_1002', '2021-07-01'): [('ID1', False), ('ID2', True)]}
Tau_img_ids_dict = {('SUBJECT_1002', '2021-07-10'): [('ID1', False), ('ID2', False)]}
```

- Value in dictionary consists of tuple where the first part of each element is the img ID, and the second part represents the status from `Exists_on_Server == True/False`.

- The function uses the subfunction `select_image_id`, which loops through each element in the tuple and retrieves image IDs marked as existing/True (i.e., if `img_id[1]`), and only falls back to the next available (sorted by ID) if none exist (all False).
- This logic ensures that subsequent data pulls do not inadvertently change which image ID is used for a given subject/timepoint.

Eg Result:

```bash
T1_img_id_selected = 'ID2'
Tau_img_id_selected = 'ID1'
```

---

### Dataframe Creation and Export

**`execute.get_processed_dataframes_PET(paired_data)`**  
- Splits the paired dataframe into:
    - Tau subjects (`tau_subs`)
    - Amyloid subjects (`amyloid_subs`)
    - Those with both (`abeta_plus_tau`)
- Returns three dedicated dataframes for summary and tracking.

**`execute.generate_processed_CSV_data_PET(filtered_imaging, tau_subs, amyloid_subs, abeta_plus_tau)`**  
- Subsets the full dataframe based on image IDs in the Tau/Amyloid/both dataframes.
- Produces a complete server log dataframe (`PET_Server_Log`) for available/desired images.
- Useful for data tracking and re-downloading.

---

### Quality Checks

**`execute.get_subject_counts(tau_subs, amyloid_subs, abeta_plus_tau)`**  
- Reports the total number of usable subjects per category (Tau, Amyloid, Both).
- Use these counts for reporting or cohort summaries.

**`execute.check_img_id_counts_in_final_spreadsheet(PET_Server_Log, tau_subs, amyloid_subs, abeta_plus_tau)`**  
- Double-checks that the PET_Server_Log contains _all_ expected image IDs for each group.
- Ensures tracking logs are accurate and complete.

---

### OUTPUTS

**`PET_Server_Log.to_csv(f'{output_dir}/PET_Server_Log_Summary_{date_ran}.csv')`**  
- Exports the paired data for all subjects.
- Filtering via the column `[Exists_on_Server]:'FALSE'` gives details of every new image needing download.

**NEW Image ID extraction:**

- `execute.save_image_ids_to_txt(PET_Server_Log,Extracted_Image_IDs)`
    - Outputs all image IDs (existing ones or those new to the server) to a text file.

- `execute.get_new_img_ids(Existing_PET_Image_IDs, Extracted_Image_IDs, ...)`
    - Outputs only the new image IDs (not previously downloaded); use this for new IDA download requests. The new IDs here will correspond with all under `PET_Server_Log_Summary_{date_ran}.csv -> [Exists_on_Server]:'FALSE'`

**Final Outputs of Each Data Frame:**
- Tau: `PPG_Tau_{date_ran}.csv`
- Amyloid: `PPG_Amyloid_{date_ran}.csv`
- Both (Amyloid+Tau): `PPG_ABETA_PLUS_TAU_{date_ran}.csv`

---

## FINAL NOTES

- You should run each step in order without skipping.
- All file naming (and date stamping) is controlled by your initial script arguments or prompts.
- Intermediate files are preserved for reproducibility and error correction.
