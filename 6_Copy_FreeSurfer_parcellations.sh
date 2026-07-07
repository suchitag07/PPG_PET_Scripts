#!/bin/bash

#NAME: Suchita Ganesan
#DATE: Jan 05, 2025

FreeSurfer_Pull_Directory='/path_to_data/PPG_VCD_T1s/Freesurfer_v_7_1' # All FreeSurfer Data
PET_Data_Directory='/cfs/loni/faculty/ipappas/pappaslab/suchita/PPG/PPG_Data_Organized/PET' # All Input PET Data
PET_FreeSurfer_Data='/cfs/loni/faculty/ipappas/pappaslab/suchita/PPG/PPG_Data_Organized/PET/SG_Freesurfer_Outputs_v_7_1' # PET FS Outputs

read -p $'\nWhat modality are you processing (Has_Tau or Has_Amyloid): ' PET_modality_directory
read -p $'\nWhat is the visit code (1, 2, etc.): ' visit_code

if [[ "$PET_modality_directory" == "Has_Amyloid" ]]; then
    PET_FS_directory="AMYLOID"
elif [[ "$PET_modality_directory" == "Has_Tau" ]]; then
    PET_FS_directory="TAU"
else
    echo "Invalid modality. Please enter 'Has_Tau' or 'Has_Amyloid'."
    exit 1
fi

echo -e "\nModality: $PET_modality_directory"
echo "Visit Code: $visit_code"
echo -e "PET_FS_directory: $PET_FS_directory\n"

# Iterate through subjects
for subject_path in "${PET_Data_Directory}/${PET_modality_directory}/NIFTIs/"*; do
    subject=$(basename "$subject_path")
	
	if [[ -d "$subject_path/$visit_code" ]]; then
    	# Find the T1 directory (T1_{YYYY-MM-DD})
    	T1_dir=$(find "$subject_path/$visit_code/" -maxdepth 1 -type d -name "T1_*" | head -n 1)

    	if [[ -n "$T1_dir" ]]; then
        	# Extract date from the folder name
        	date=$(basename "$T1_dir" | sed 's/T1_//')

        	# Find the T1 .nii.gz file
        	T1_file=$(find "$T1_dir" -type f -name "*.nii.gz" | head -n 1)

        	
            # Extract Image ID from filename
            filename=$(basename "$T1_file")
            image_id=$(echo "$filename" | rev | cut -d'_' -f1 | rev | sed 's/.nii.gz//')

            # Check if FreeSurfer output already exists
            subject_fs_path="${PET_FreeSurfer_Data}/${PET_FS_directory}/${visit_code}/sub-${subject}"
            if [[ ! -f "$subject_fs_path/mri/aparc+aseg.mgz" ]]; then
                # Check if the corresponding FreeSurfer directory exists
                fs_source="${FreeSurfer_Pull_Directory}/${subject}_${date}_${image_id}"
                if [[ -f "$fs_source/mri/aparc+aseg.mgz" ]]; then
                    echo "[[ NEW SUBJECT - COPYING OVER ${subject}_${date}_${image_id} ]]"
                    mkdir -p $subject_fs_path/mri
                    mkdir -p $subject_fs_path/scripts
                    cp -r "$fs_source/mri/aparc+aseg.mgz" "$subject_fs_path/mri/"
                    cp -r "$fs_source/mri/aparc.a2009s+aseg.mgz" "$subject_fs_path/mri/"
                    cp -r "$fs_source/mri/rawavg.mgz" "$subject_fs_path/mri/"
                    cp -r "$fs_source/mri/brain.mgz" "$subject_fs_path/mri/"
                    cp -r "$fs_source/mri/T1.mgz" "$subject_fs_path/mri/"
                    cp -r "$fs_source/scripts/recon-all.log" "$subject_fs_path/scripts/"
                else
                    echo "FreeSurfer output not currently available for ${subject} at Visit Code: $visit_code with ID ${image_id}. Download ${image_id} from IDA and run Freesurfer first"
                fi
            else
                echo "FreeSurfer data already exists for ${subject} at Visit Code: $visit_code with ID ${image_id}."
            fi
    	else
        	echo "No T1 data for ${subject} at Visit Code: $visit_code - check T1 nifti directory."
    	fi
    else
    	echo "No data for ${subject} at Visit Code: $visit_code yet."
    fi
done

echo -e "\nOnly process subjects that DO HAVE the necessary FreeSurfer directories!\n"