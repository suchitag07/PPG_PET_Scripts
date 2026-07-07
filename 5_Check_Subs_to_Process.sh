#!/bin/bash

read -p $'\nEnter Date (format: MM_DD_YYYY):' DATE_RAN
LOG_FILE="/path_to_data/PPG/Data_Pull_CSVs/PET/Processed_CSVs/${DATE_RAN}/Subjects_to_Process_$(date +%m-%d-%Y_%H%M%S).txt"

if [ ! -d "/path_to_data/PPG/Data_Pull_CSVs/PET/Processed_CSVs/${DATE_RAN}" ]; then
    echo "DIRECTORY /path_to_data/PPG/Data_Pull_CSVs/PET/Processed_CSVs/${DATE_RAN} does not exist, check your DATE"
    exit 
fi

INPUT_BASE_DIR="/path_to_data/PPG/PPG_Data_Organized/PET"       
SUVRs_Base_Path="/path_to_data/PPG/PPG_Data_Organized/PET"
FS_Base_Path="/path_to_data/PPG/PPG_Data_Organized/PET/SG_Freesurfer_Outputs_v_7_1"
SUIT_Base_Path="/path_to_data/PPG/PPG_Data_Organized/PET/Has_Tau_derivatives/Tau_SUIT"
# Initialize the log file
echo -e "\nLogging new subjects and visits missing from PET_Outputs (SUVR) Directory" > "$LOG_FILE"
echo "Date ran: $DATE_RAN" >> "$LOG_FILE"
echo "-------------------------------" >> "$LOG_FILE"

for modality_dir in "$INPUT_BASE_DIR/Has_Amyloid" "$INPUT_BASE_DIR/Has_Tau"*; do
    modality=$(basename "$modality_dir")

    for sub_group in "$modality_dir/NIFTIs"; do
        for subject_dir in "$sub_group/"*; do
            if [ -d "$subject_dir" ]; then
                subject_id=$(basename "$subject_dir")

                for visit_dir in "$subject_dir"/*; do
                    if [ -d "$visit_dir" ]; then
                        visit=$(basename "$visit_dir")

                        SUVRs_Path="${SUVRs_Base_Path}/${modality}_derivatives/PET_subjects_process_SUVRs/${subject_id}/${visit}/"
                        FS_TAU_SUVRs_Path="${SUVRs_Base_Path}/${modality}_derivatives/FS_SUVR_stats/${visit}/${subject_id}"

                        if [ "$modality" = "Has_Amyloid" ] && [ ! -d "$SUVRs_Path" ]; then
                        	#Check if Freesurfer prerequisite exists 
                        		if [ -f "${FS_Base_Path}/AMYLOID/${visit}/sub-${subject_id}/mri/aparc+aseg.mgz" ]; then
                        			FS_status="Prerequisite Ready"
                        		else
                        			FS_status="Prerequisite MISSING"
                        		fi
                        	
                            echo "$modality : New Subject: $subject_id Visit: $visit, FreeSufer_Status: $FS_status" >> "$LOG_FILE"

                        elif [ "$modality" = "Has_Tau" ] && { [ ! -d "$SUVRs_Path" ] || [ ! -d "$FS_TAU_SUVRs_Path" ]; }; then
                        
                        		if [ -f "${FS_Base_Path}/TAU/${visit}/sub-${subject_id}/mri/aparc+aseg.mgz" ]; then
                        			FS_status="Prerequisite Ready"
                        		else
                        			FS_status="Prerequisite MISSING"
                        		fi
                        		
                        		if [ -f "${SUIT_Base_Path}/${subject_id}/${visit}/Cereb-SUIT_warp_2_${subject_id}_native_T1.nii" ]; then
                        			SUIT_status="Prerequisite Ready"
                        		else
                        			SUIT_status="Prerequisite MISSING"
                        		fi
                        		
                            echo "$modality : New Subject: $subject_id Visit: $visit, FreeSufer_Status: $FS_status, SUIT_status: $SUIT_status" >> "$LOG_FILE"
                        fi
                    fi
                done
            fi
        done
    done
done

echo -e "Check $LOG_FILE for subjects and visits to process.\n"
