#Name: Suchita Ganesan
#Date: 16 July, 2024

import pandas as pd

#FUNCTION 1A: Clean the CSV -> Round 1
def clean_imaging_data(imaging_data_raw, scans_to_keep):
    imaging_data_raw['Subject'] = imaging_data_raw['Subject'].astype(str)

    # Keep only USC subjects
    df = imaging_data_raw[imaging_data_raw['Subject'].str.startswith('110')].copy()

    # Convert and sort by Subject and Age
    df['Age'] = df['Age'].astype(int, errors='ignore')  # Ensure Age is converted safely
    df['Subject_Temp'] = df['Subject'].str.extract(r'(\d+)').astype(float).fillna(0).astype(int)
    df_sorted = df.sort_values(by=['Subject_Temp', 'Age']).drop(columns=['Subject_Temp'])

    # Filter by scan types in 'Description'
    df_filtered = df_sorted[df_sorted['Description'].isin(scans_to_keep)]

    # Drop unnecessary columns
    df_cl = df_filtered.drop(columns=['Downloaded', 'Visit', 'Format', 'Group'], errors='ignore')

    # Convert Acquisition Date to datetime using format='mixed' with dayfirst=False
    df_cl['Acq Date'] = pd.to_datetime(df_cl['Acq Date'], format='mixed', dayfirst=False)

    return df_cl


#FUNCTION 1B: Clean to retain subs who have PET and a T1
def find_complete_data(df_cl):
    df_complete = pd.DataFrame()

    # Iterate through each unique subject
    for subject in df_cl['Subject'].unique():
        # Get all records for the current subject
        subj_data = df_cl[df_cl['Subject'] == subject]

        # Sort by the acquisition date
        df_sorted = subj_data.sort_values(by=['Acq Date'])

        pet_dataset = any(df_sorted['Modality'] == 'PET')

        has_mri = any(df_sorted['Description'] == 'Accelerated Sagittal MPRAGE')
        has_PET = any(df_sorted['Modality'] == 'PET')

        if has_mri and has_PET:
        	df_complete = pd.concat([df_complete, df_sorted])

    # Reset the index of the new dataframe
    df_complete.reset_index(drop=True, inplace=True)

    return df_complete

#FUNCTION 1c: To compare server data with IDA pull CSV data 
def update_status(df_complete, inventory_df):
    # Convert acquisition dates to datetime format
    df_complete['Acq Date'] = pd.to_datetime(df_complete['Acq Date'], format='mixed') 

    # If inventory is provided, flag rows that match previously processed data
    if inventory_df is not None:
        inventory_df['Acq Date'] = pd.to_datetime(inventory_df['Acq Date'], format='mixed')

        # Ensure 'Subject' columns are of the same type (convert to str here for example)
        df_complete['Subject'] = df_complete['Subject'].astype(str)
        inventory_df['Subject'] = inventory_df['Subject'].astype(str)

        # Merge on Subject, Description, and Acq Date
        df_complete = df_complete.merge(
            inventory_df[['Subject', 'Description', 'Acq Date', 'Image Data ID']], 
            on=['Subject', 'Acq Date', 'Description'], 
            how='left', 
            suffixes=('', '_inv')
        )

        # If ID already exists on server (ID_inv), then set Exists_on_Server to True -> we want to retain this set of IDs and not reprocess for that Acq Date
        df_complete['Exists_on_Server'] = df_complete.apply(
            lambda row: (row['Image Data ID'] == row['Image Data ID_inv']) 
                        if pd.notna(row['Image Data ID_inv']) else False, axis=1
        )

        # Drop redundant column
        df_complete.drop(columns=['Image Data ID_inv'], inplace=True)
    else:
        df_complete['Exists_on_Server'] = False  # Default flag if no inventory is given

    df_cl_no_duplicates = df_complete.copy()

    # Fill missing Exists_on_Server values with False
    df_cl_no_duplicates['Exists_on_Server'] = df_cl_no_duplicates['Exists_on_Server'].fillna(False)

    # Sort by Subject, Acquisition Date, Exists_on_Server (prioritizing True), and lowest Image ID
    df_cl_no_duplicates = df_cl_no_duplicates.sort_values(
        by=['Subject', 'Acq Date', 'Exists_on_Server', 'Image Data ID'], 
        ascending=[True, True, False, True]
    )

    # Drop duplicates, keeping the first record per Subject per Description per Acq Date
    df_cl_no_duplicates = df_cl_no_duplicates.drop_duplicates(
        subset=['Subject', 'Description', 'Acq Date'], keep='first'
    )

    df_cl_no_duplicates.reset_index(drop=True, inplace=True)

    return df_cl_no_duplicates


#FUNCTIONS 4/5-> fetch visit dates for a specific subject
def get_dates_for_PET_dataset(PET_data):

    all_scan_dates = {}

    for subject in PET_data['Subject'].unique():
        subj_df = PET_data[PET_data['Subject'] == subject]
        scan_dates = {}

        for scan in subj_df['Description'].unique():
            scan_set = subj_df[subj_df['Description'] == scan]
            # Store a list of acquisition dates for each scan
            scan_dates[scan] = list(scan_set['Acq Date'].dt.strftime('%Y-%m-%d'))

        all_scan_dates[subject] = scan_dates

    return all_scan_dates
 
"""   
Dict structure returned

all_scan_dates_dict = 

{
    "SUBJECT_1001": {
        		"Accelerated Sagittal MPRAGE": ["2022-08-01", "2023-01-15"], - all T1 scan dates
        		"AA-APOE_AMYLOID (AC)": ["2022-08-02"] - all amyloid scan dates
    		},
    "SUBJECT_1002": {
    			"Accelerated Sagittal MPRAGE": ["2021-07-01", "2023-03-07"], - all T1 scan dates
        		"AA-APOE_TAU (AC)": ["2021-07-10"], - all tau scan dates
        		"AA-APOE_AMYLOID (AC)": ["2023-03-01"] - all amyloid scan dates
    		}
}

"""

#Apply function to T1/TAU/AMYLOID --> easier to call later inside pair_imaging function (which will pair the T1-PET for amyloid and tau)
def get_visit_dates_T1(subject, all_scan_dates):
    return all_scan_dates.get(subject, {}).get('Accelerated Sagittal MPRAGE', [])

def get_visit_dates_PET_Abeta(subject, all_scan_dates):
    return all_scan_dates.get(subject, {}).get('AA-APOE_AMYLOID (AC)', [])

def get_visit_dates_PET_Tau(subject, all_scan_dates):
    return all_scan_dates.get(subject, {}).get('AA-APOE_TAU (AC)', [])

#Compare intervals and pair up
def find_nearest_img_date(img_date, PET_Abeta_dates, PET_Tau_dates):
    nearest_PET_Abeta, interval_PET_Abeta = (None, None)
    nearest_PET_Tau, interval_PET_Tau = (None, None)

    #Similary do the same for fetching the nearest Abeta and Tau dates
    if not PET_Abeta_dates.empty:
        nearest_PET_Abeta = min(PET_Abeta_dates, key=lambda x: abs(x - img_date))
        interval_PET_Abeta = round(abs(img_date - nearest_PET_Abeta) / pd.Timedelta(days=30.44), 2)

    if not PET_Tau_dates.empty:
        nearest_PET_Tau = min(PET_Tau_dates, key=lambda x: abs(x - img_date))
        interval_PET_Tau = round(abs(img_date - nearest_PET_Tau) / pd.Timedelta(days=30.44), 2)

    return nearest_PET_Abeta, interval_PET_Abeta, nearest_PET_Tau, interval_PET_Tau


def pair_imaging(Subs_with_imaging_data, all_scan_dates, filtered_imaging):
    # Dictionary to store the results
    all_date_pairs = {}
    filtered_imaging['Acq Date'] = pd.to_datetime(filtered_imaging['Acq Date'])
    filtered_imaging['Visit_Code'] = None  
    excluded_columns = ['Visit_Code', 'Subject', 'Acq Date'] #

    # Filter imaging data to include only relevant subjects
    filtered_imaging = filtered_imaging[filtered_imaging['Subject'].isin(Subs_with_imaging_data)]

    # Store image ids by grouping them, convert to tuple and assign to dict where [('Sub', 'Date')]:[('ID1', False), ('ID2', True)]
    T1_img_ids_by_date = filtered_imaging[filtered_imaging['Description'] == 'Accelerated Sagittal MPRAGE'] \
        .groupby(['Subject', 'Acq Date'])[['Image Data ID', 'Exists_on_Server']] \
        .apply(lambda x: list(x.itertuples(index=False, name=None))) \
        .to_dict()

    Abeta_img_ids_by_date = filtered_imaging[filtered_imaging['Description'] == 'AA-APOE_AMYLOID (AC)'] \
        .groupby(['Subject', 'Acq Date'])[['Image Data ID', 'Exists_on_Server']] \
        .apply(lambda x: list(x.itertuples(index=False, name=None))) \
        .to_dict()

    Tau_img_ids_by_date = filtered_imaging[filtered_imaging['Description'] == 'AA-APOE_TAU (AC)'] \
        .groupby(['Subject', 'Acq Date'])[['Image Data ID', 'Exists_on_Server']] \
        .apply(lambda x: list(x.itertuples(index=False, name=None))) \
        .to_dict()

    def select_image_id(image_list):
        """ Prioritize images with Exists_on_Server == True. If none, return the first available. """
        keep_true = [img_id for img_id in image_list if img_id[1]] # list comprehension to iterate thru image ids and assign if second element true
        if keep_true:
            return keep_true[0][0] # return first element - image id
        elif image_list:
            return sorted(image_list, key=lambda x: x[0])[0][0]  # if no Keep True, sort via ascending and return first available
        return None

    for subject in Subs_with_imaging_data:
        # Get PET Abeta, PET Tau, and image dates and convert to series
        image_dates = pd.to_datetime(pd.Series(get_visit_dates_T1(subject, all_scan_dates)))
        PET_Abeta_dates = pd.to_datetime(pd.Series(get_visit_dates_PET_Abeta(subject, all_scan_dates)))
        PET_Tau_dates = pd.to_datetime(pd.Series(get_visit_dates_PET_Tau(subject, all_scan_dates)))

        subject_date_pairs = {}
        visit_code_counter = 1
        previous_date = None

        for img_date in image_dates:
            # Check if the date has changed
            if img_date != previous_date:
                visit_code = f'{visit_code_counter}'
                visit_code_counter += 1 
            else:
                visit_code = f'{visit_code_counter - 1}' 

            nearest_PET_Abeta, interval_PET_Abeta, nearest_PET_Tau, interval_PET_Tau = find_nearest_img_date(img_date, PET_Abeta_dates, PET_Tau_dates)

            # Get image IDs for T1, Abeta, and Tau
            if (subject, img_date) in T1_img_ids_by_date:
                T1_img_ids = T1_img_ids_by_date[(subject, img_date)] #pass in dict - assign value/tuple of image_id/status to T1_img_ids 
                T1_img_id = select_image_id(T1_img_ids) # use function 
            else:
                T1_img_id = None

            if nearest_PET_Abeta and (subject, nearest_PET_Abeta) in Abeta_img_ids_by_date:
                Abeta_img_ids = Abeta_img_ids_by_date[(subject, nearest_PET_Abeta)]
                Abeta_img_id = select_image_id(Abeta_img_ids)
            else:
                Abeta_img_id = None

            if nearest_PET_Tau and (subject, nearest_PET_Tau) in Tau_img_ids_by_date:
                Tau_img_ids = Tau_img_ids_by_date[(subject, nearest_PET_Tau)]
                Tau_img_id = select_image_id(Tau_img_ids)
            else:
                Tau_img_id = None

            key = f'{visit_code}_{img_date.strftime("%Y-%m-%d")}_{len(subject_date_pairs) + 1}'

            
            subject_date_pairs[key] = {
                'T1_Date': img_date.strftime('%Y-%m-%d'),
                'Image_ID_T1': T1_img_id,
                'Visit_Code': visit_code,
                'Image_ID_Abeta': Abeta_img_id,
                'Image_ID_Tau': Tau_img_id,
                'Abeta_date': nearest_PET_Abeta.strftime('%Y-%m-%d') if nearest_PET_Abeta else None,
                'Interval_Abeta (months)': interval_PET_Abeta if nearest_PET_Abeta else None,
                'Tau_date': nearest_PET_Tau.strftime('%Y-%m-%d') if nearest_PET_Tau else None,
                'Interval_Tau (months)': interval_PET_Tau if nearest_PET_Tau else None
            }


            previous_date = img_date

        all_date_pairs[subject] = subject_date_pairs

    paired_data_all = []

    # Iterate over each subject and their respective visit details
    for subject, visit_details in all_date_pairs.items():
        # Extract APOE and APOE_complete values for the current subject
        for key, details in visit_details.items():
            row_data = {
                'Subject': subject,
                'Visit_Code': details['Visit_Code'],
                'Image_ID_T1': details['Image_ID_T1'],
                'Image_ID_Abeta': details['Image_ID_Abeta'],
                'Image_ID_Tau': details['Image_ID_Tau'],
                'T1_Date': details['T1_Date'],
                'Abeta_date': details['Abeta_date'],
                'Tau_date': details['Tau_date'],
                'Interval_Abeta (months)': details['Interval_Abeta (months)'],
                'Interval_Tau (months)': details['Interval_Tau (months)']
            }
            # Append all measure data except the excluded columns
            for key, value in details.items():
                if key not in row_data and key not in excluded_columns:
                    row_data[key] = value

            paired_data_all.append(row_data)

    return paired_data_all


def get_processed_dataframes_PET(paired_data_all):

    # Create DataFrame from the list of rows
    Paired_data = pd.DataFrame(paired_data_all)

    # Initialize DataFrames to store results
    tau_subs = pd.DataFrame()
    amyloid_subs = pd.DataFrame()
    abeta_plus_tau = pd.DataFrame()

    # Iterate over each unique subject
    for subj in Paired_data['Subject'].unique():
        sub_df = Paired_data[Paired_data['Subject'] == subj]

        # Iterate over each unique visit code
        for visit in sub_df['Visit_Code'].unique():
            visit_df = sub_df[sub_df['Visit_Code'] == visit]

        # Check if Interval_Abeta and Interval_Tau columns exist and handle NaN values
            if 'Interval_Abeta (months)' in visit_df.columns:
                visit_df.loc[:,'Interval_Abeta (months)'] = visit_df['Interval_Abeta (months)'].fillna(float('inf'))
            if 'Interval_Tau (months)' in sub_df.columns:
                visit_df.loc[:,'Interval_Tau (months)'] = visit_df['Interval_Tau (months)'].fillna(float('inf'))

        # Check the criteria for each DataFrame and append accordingly
            if (visit_df['Interval_Abeta (months)'] <= 8).any() and (visit_df['Interval_Tau (months)'] <= 8).any():
                abeta_plus_tau = abeta_plus_tau._append(visit_df, ignore_index=True)
            if (visit_df['Interval_Tau (months)'] <= 8).any():
                tau_subs = tau_subs._append(visit_df, ignore_index=True)
            if (visit_df['Interval_Abeta (months)'] <= 8).any():
                amyloid_subs = amyloid_subs._append(visit_df, ignore_index=True)

    # Drop cols
    tau_subs.drop(columns=['Interval_Abeta (months)', 'Abeta_date', 'Image_ID_Abeta'], inplace=True)
    amyloid_subs.drop(columns=['Interval_Tau (months)', 'Tau_date', 'Image_ID_Tau'], inplace=True)

    # Reset indices for all DataFrames
    tau_subs.reset_index(drop=True, inplace=True)
    amyloid_subs.reset_index(drop=True, inplace=True)
    abeta_plus_tau.reset_index(drop=True, inplace=True)


    return tau_subs, amyloid_subs, abeta_plus_tau

def reset_visit_code(df_raw):

    df = df_raw.drop(columns=['Visit_Code']) #Drop the old code

    df['Visit_Code'] = ''

    df_revised = pd.DataFrame()

    for subject in df['Subject'].unique():
        # Again, get all the records for the current subject
        subj_data = df[df['Subject'] == subject]

        # Sort by the acquisition dates
        subj_data_sorted = subj_data.sort_values(by=['T1_Date'])

        # Identify unique acquisition dates and assign visit codes
        unique_dates = subj_data_sorted['T1_Date'].unique()
        visit_codes = [f'{i}' for i in range(1, len(unique_dates) + 1)]

        # Create a dictionary to map the unique dates to the visit codes
        date_to_visit_code = {date: code for date, code in zip(unique_dates, visit_codes)}

        subj_data_sorted['Visit_Code'] = subj_data_sorted['T1_Date'].map(date_to_visit_code)

        df_revised = df_revised._append(subj_data_sorted, ignore_index=True)

    # Reorder the columns
    new_order = ['Subject', 'Visit_Code'] + [col for col in df_revised.columns if col not in ['Subject', 'Visit_Code']]
    df_revised_final = df_revised[new_order]

    return df_revised_final

#GENERATING PET_SERVER CSV 
def generate_processed_CSV_data_PET(df, tau_subs, amyloid_subs, abeta_plus_tau):
    # Create sets for each type of Image ID from all three dataframes
    tau_image_ids = set(tau_subs['Image_ID_Tau']).union(set(tau_subs['Image_ID_T1']))
    amyloid_image_ids = set(amyloid_subs['Image_ID_T1']).union(set(amyloid_subs['Image_ID_Abeta']))
    abeta_tau_image_ids = set(abeta_plus_tau['Image_ID_Tau']).union(set(abeta_plus_tau['Image_ID_T1']),set(abeta_plus_tau['Image_ID_Abeta']))

    # Combine all sets into one for easy lookup
    combined_image_ids = tau_image_ids.union(amyloid_image_ids, abeta_tau_image_ids)

    image_ids_list = []

    for image_id in df['Image Data ID']:
        if image_id in combined_image_ids:
            image_ids_list.append(image_id)

    PET_Server = df[df['Image Data ID'].isin(image_ids_list)]

    return PET_Server

#CHECKING SUBJECT COUNTS
def get_subs_and_numbers(dataframe):
    total_subs = dataframe['Subject'].nunique()
    list_subs = dataframe['Subject'].unique().tolist()
    
    return total_subs, list_subs

def get_subject_counts(tau_subs, amyloid_subs, abeta_plus_tau):

    print("\nCHECKING NUM OF SUBJECTS IN EACH GROUP")

    num_tau_subs, tau_subs_list = get_subs_and_numbers(tau_subs)
    num_amyloid_subs, amyloid_subs_list = get_subs_and_numbers(amyloid_subs)
    num_amyloid_tau_subs, amyloid_tau_list = get_subs_and_numbers(abeta_plus_tau)

    # Count number of subs in each group:
    print("Total subs tau:", num_tau_subs)
    print("Total subs amyloid:", num_amyloid_subs)
    print("Subs who have amyloid and tau:", num_amyloid_tau_subs)

#CHECKING IMAGE ID COUNTS
def check_img_id_counts_in_final_spreadsheet(PET_Server, tau_subs, amyloid_subs, abeta_plus_tau):

    print("\nCHECKING IMAGE ID TOTALS")
    # Print the number of unique Image IDs
    num_images = PET_Server['Image Data ID'].nunique() #Scan_Status_Summary sheet

    # Initialize counters
    count_in_tau_subs = 0
    count_in_amyloid_subs = 0
    count_T1 = 0

    # Create sets for fast membership testing
    tau_T1 = set(tau_subs['Image_ID_T1'])
    tau_ids = set(tau_subs['Image_ID_Tau'])
    amyloid_T1 = set(amyloid_subs['Image_ID_T1'])
    amyloid_ids = set(amyloid_subs['Image_ID_Abeta'])
    abeta_plus_tau_ids = set(abeta_plus_tau['Image_ID_T1']) #this would be the same as num of amyloid/tau scans as everything is anchored to the t1

    # Union of all T1 image IDs from tau, amyloid, and abeta_plus_tau datasets
    T1_PET_unique = tau_T1 | amyloid_T1 | abeta_plus_tau_ids

    # Iterate through each Image Data ID in PET_Server and update counters
    for img_id in PET_Server['Image Data ID']:
        if img_id in tau_ids:
            count_in_tau_subs += 1
        if img_id in amyloid_ids:
            count_in_amyloid_subs += 1
        if img_id in T1_PET_unique:
            count_T1 += 1

    # Print results
    print(f"Number of tau-PET images inside stand-alone Tau-spreadsheet: {count_in_tau_subs}")
    print(f"Number of amyloid-PET images inside stand-alone Amyloid-spreadsheet: {count_in_amyloid_subs}")
    print(f"Total number of T1 images across stand-alone-Tau + stand-alone-Amyloid + Amyloid_plus_Tau sheet: {count_T1}")
    print(f"Total number of images (sum): {count_in_tau_subs + count_in_amyloid_subs + count_T1}")
    
    print("\nNumber of images logged in PET_Server_Log_Summary spreadsheet:", num_images)


def save_image_ids_to_txt(dataframe, output_file):
    # Extract the 'Image Data ID' column as a list
    image_ids = dataframe['Image Data ID'].tolist()

    # Convert the list to a comma-separated string
    image_ids_str = ', '.join(image_ids)

    # Write the string to a text file
    with open(output_file, 'w') as f:
        f.write(image_ids_str)

    return output_file
    
def get_new_img_ids(old_txt, updated_txt, unique_txt):
    with open(old_txt, 'r') as f1:
        img_ids_1 = set(id.strip() for id in f1.read().strip().split(',') if id.strip())

    with open(updated_txt, 'r') as f2:
        img_ids_2_list = [id.strip() for id in f2.read().strip().split(',') if id.strip()]

    new_ids = [id for id in img_ids_2_list if id not in img_ids_1]

    with open(unique_txt, 'w') as output_file:
        output_file.write(','.join(new_ids))

    print(f"New image IDs written to {unique_txt}")
