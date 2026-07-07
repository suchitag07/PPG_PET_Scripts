#!/bin/bash

VISIT_CODE_LIST=""
DATE_RAN=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --visits)
            VISIT_CODE_LIST="$2"
            shift 2
            ;;
        --date)
            DATE_RAN="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 --visits \"1, 2\" --date MM_DD_YYYY"
            exit 0
            ;;
        *)
            echo "Unknown option $1"
            exit 1
            ;;
    esac
done

if [[ -z "$VISIT_CODE_LIST" || -z "$DATE_RAN" ]]; then
    echo "Error: --visits and --date are required"
    exit 1
fi

VISIT_CODE_LIST="${VISIT_CODE_LIST// /}"     
IFS=',' read -r -a VISITS_ARRAY <<< "$VISIT_CODE_LIST"

# Loop over visits
for visit_code in "${VISITS_ARRAY[@]}"; do
    subjects=$(cat "/path_to_data/PPG/PPG_Data_Organized/PET/Results/Tau_Latest/Tau_Volume_Weighted/Subject_Lists/subjects_${visit_code}.txt")
    out_dir="/path_to_data/PPG/PPG_Data_Organized/PET/Results/Tau_Latest/Tau_Volume_Weighted/${DATE_RAN}/TXT_files/${visit_code}"
    export SUBJECTS_DIR="/path_to_data/PPG/PPG_Data_Organized/PET/Has_Tau_derivatives/FS_SUVR_stats/${visit_code}"

    echo "SUBJECTS_DIR=$SUBJECTS_DIR"
    mkdir -p "$out_dir"

    asegstats2table --subjects $subjects --meas mean --tablefile "${out_dir}/fs_suvrs_tau_Visit_${visit_code}.txt" --common-segs --skip
    asegstats2table --subjects $subjects --meas volume --tablefile "${out_dir}/fs_volume_tau_Visit_${visit_code}.txt" --common-segs --skip
done
