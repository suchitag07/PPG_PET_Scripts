#NAME: Suchita Ganesan
#DATE: March 11, 2025

import os
import pandas as pd
from pathlib import Path


# Map scan type names
SCAN_TYPE_MAP = {
    "Accelerated_Sagittal_MPRAGE": "Accelerated Sagittal MPRAGE",
    "AA-APOE_TAU__AC_": "AA-APOE_TAU (AC)",
    "AA-APOE_AMYLOID__AC_": "AA-APOE_AMYLOID (AC)"
}

def map_scan_type(scan_type_name):
    return SCAN_TYPE_MAP.get(scan_type_name, scan_type_name)

def get_date_from_folder(folder_name):
    return folder_name[:10] if len(folder_name) >= 10 else "Unknown"


def check_inventory(input_dir, output_csv):
    # Assumes structure: subject/scan_type/date/image_id/
    input_dir = Path(input_dir)
    rows = []

    # Only look for directories that are 4 levels below the input_dir (subject/scan_type/date/image_id)
    for image_id_path in input_dir.glob('*/*/*/*'):
        if not image_id_path.is_dir():
            continue
        subject_id = image_id_path.parents[2].name  # up 2: image_id/date/scan_type/subject
        scan_type_name = image_id_path.parents[1].name
        date_folder = image_id_path.parent.name
        image_id = image_id_path.name

        scan_type = map_scan_type(scan_type_name)
        scan_date = get_date_from_folder(date_folder)

        rows.append([subject_id, scan_type, scan_date, image_id])

    df = pd.DataFrame(rows, columns=['Subject', 'Description', 'Acq Date', 'Image Data ID'])
    df.to_csv(output_csv, index=False)
    print(f"CSV file has been saved to {output_csv}")
    return df

def save_image_ids_to_txt(dataframe, output_file):
    """Extract and save Image Data IDs to a text file."""
    image_ids = dataframe['Image Data ID'].tolist()
    image_ids_str = ', '.join(image_ids)

    with open(output_file, 'w') as f:
        f.write(image_ids_str)

    print(f"Image IDs saved to {output_file}")

if __name__ == "__main__":

	INPUT_BASE_DIR = "/path_to_data/Raw_IDA_Downloads/PET/PPG"
	output_csv = "/path_to_data/Data_Pull_CSVs/PET/Existing_Data/PET_Inventory.csv"
	output_txt = "/path_to_data/Data_Pull_CSVs/PET/Existing_Data/Existing_PET_Image_IDs.txt"
	print(f"Checking existing data inside: {INPUT_BASE_DIR}")
	df = check_inventory(INPUT_BASE_DIR, output_csv)
	save_image_ids_to_txt(df, output_txt)
                                        
                                        