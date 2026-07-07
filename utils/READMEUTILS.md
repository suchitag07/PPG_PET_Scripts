# PET_CSV_Wrangling Module

## INTRODUCTION

**PET_CSV_Wrangling** is a module (located here: `utils`). It contains all key functions necessary for processing the RAW IDA data sheet. We utilize these functions to identify which PET-T1 scans match up and are available to process. These functions are imported and used under the alias `execute` inside the script ***`2_Process_PET_CSVs.py`***

This section explains each function called in `2_Process_PET_CSVs.py`, step by step.

**This information is relevant IF:**
- If you are running into major errors with ***`2_Process_PET_CSVs.py`***
- If you want to revise any functions here to keep up with changes in IDA metadata format (changes in reported column names, IMAGE ID format, or Subject ID format). 

---

### IMPORTANT

**The core logic in these functions should not be edited.** This is because the pipeline selects and organizes subjects and IMAGE IDs based on what already exists inside the this folder (`PPG`).

**A key detail: Sometimes the IDA will contain duplicate scans under the same subject and timepoint, but with different IMAGE IDs. This can lead to discrepancies, especially if an existing subject/timepoint is later reprocessed with different IMAGE IDs across data pulls.  
For subjects already processed, my code matches and uses the same IMAGE ID when new IDA CSVs are downloaded, preventing accidental reprocessing of an old subject/timepoint under a new IMAGE ID.**

This logic—maintaining IMAGE ID consistency and preventing unwanted reprocessing—is carefully handled in:
```bash
- `1_Check_Inventory.py`
- PET_CSV_Wrangling.py Module functions: `update_status` and `pair_imaging`
```
**If you want to change any core functions/adapt these scripts differently, please make your dedicated scripts in a separate user directory and discontinue all processing for the Amyloid and Tau data under `PPG` ). Update reports accordingly.**

---

## EXPLANATION OF FUNCTIONS

### Data Cleaning and Filtering

**`execute.clean_imaging_data(Imaging_Data_Raw, keep_scans_PET)`**  
- Removes irrelevant scans from the raw IDA CSV.
- Retains only entries with a scan description that matches T1 or PET (using the `keep_scans_PET` list).
- Returns a cleaned dataframe for further analysis.

```bash
# Current Scans Being Processed for USC Subjects 

keep_scans_PET = [
    'Accelerated Sagittal MPRAGE',		# T1 scan
    'AA-APOE_TAU (AC)',					# Tau-PET scan (FTP)
    'AA-APOE_AMYLOID (AC)'				# Amyloid-PET scan (FBB)
]

```
**`execute.find_complete_data(cleaned_imaging)`**  
- Filters subjects who have at least one MRI (T1) and one PET scan.
- Does _not_ apply any timing constraints on the MRI-PET interval; this is handled later.

**`execute.update_status(complete_imaging, inventory_df)`**  
- Compares the inventory CSV (list of files actually available on the server) against the filtered raw data.
- Updates a status column labeled as TRUE (image ID present) or FALSE (image ID absent - ie represents new data).

---

### PET-T1 Data Pairing 

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
- For each modality (Amyloid and Tau), the function:
- Identifies the PET scan date that minimizes the absolute time difference (min(abs(x - img_date))), where x is each available PET scan date, and img_date refers to the T1_date.
- Calculates the PET-MRI pairing interval in months.

The function returns:
- The date of the nearest Amyloid PET and its interval (months)
- The date of the nearest Tau PET and its interval (months)
- If no PET scan is present, both fields are assigned None

**How `execute.pair_imaging` Retains Existing Image IDs:**
- For each subject:
- All available image IDs for each scan modality and date are stored as a `dictionary` where:

    - Key: (Subject ID, Acq Date)
    - Value: A list of tuples, where each tuple contains the image ID and its Exists_on_Server status (True/False).

Eg Dict:

```bash
T1_img_ids_dict = {('SUBJECT_1002', '2021-07-01'): [('ID1', False), ('ID2', True), ('ID3', False), ('ID4', False)]}
```
- Each scan-date may be linked with multiple image IDs associated with a given (subject, date) `tuple`, as shown above.
- To ensure consistency across repeated runs and avoid accidental reassignment, the function always attempts to select the image ID that is already present on the server—determined by the Boolean value in the Exists_on_Server column (second part of tuple element).

- The sub-function `select_image_id` iterates through all tuples for a given scan and:
    - Prioritizes and returns the image ID with Exists_on_Server == True (ie present on the server).
    - If none are marked as existing, it returns the image ID that is first in lexicographical order.

This logic guarantees that, after initial processing, subsequent runs will always prefer the established image ID for each scan session—even if new IDs appear for the same scan date.

Eg Dict:

```bash
T1_img_ids_dict = {('SUBJECT_1002', '2021-07-01'): [('ID1', False), ('ID2', True), ('ID3', False), ('ID4', False)]}
Tau_img_ids_dict = {('SUBJECT_1002', '2021-07-10'): [('ID1', False), ('ID2', False)]}
```
Eg Result:

```bash
# _For_Example_SUBJECT_1002
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
- Subsets the initial cleaned dataframe 'filtered_imaging` based on the available image IDs in the Tau/Amyloid/Joint dataframes.
- Writes this to (`PET_Server_Log`).

---

### Quality Checks

**`execute.get_subject_counts(tau_subs, amyloid_subs, abeta_plus_tau)`**  
- Reports the total number of usable subjects per category (Tau, Amyloid, Both).
- Use these counts for reporting or summaries.

**`execute.check_img_id_counts_in_final_spreadsheet(PET_Server_Log, tau_subs, amyloid_subs, abeta_plus_tau)`**  
- Double-checks that the PET_Server_Log contains _all_ expected image IDs for each group.
- Ensures tracking logs are accurate and complete.

---
