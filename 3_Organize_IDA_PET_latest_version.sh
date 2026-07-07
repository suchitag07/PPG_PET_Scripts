#!/bin/bash

show_help() {
    echo "Usage: $0"
    echo ""
    echo "Follow the prompts"
    echo "Raw IDA data directory should be located here: /path_to_data/PPG/Raw_IDA_Downloads/PET/PPG"
    echo "Organized PET data directory should be located here: /path_to_data/PPG/PPG_Data_Organized/PET"
    echo "Options:"
    echo "  -h, --help"
    echo ""
    echo "Example Call:"
    echo "  ./3_Organize_IDA_PET_lastest_version.sh"
    exit 0
}

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
fi

#!/bin/bash

# Ask once for root_dir and out_dir
read -p "Enter the path to your Raw IDA data directory: " root_dir
if [[ ! -d "$root_dir" ]]; then
    echo "Error: Directory does not exist. Exiting."
    exit 1
fi

read -p "Enter the path to your Organized PET data directory: " out_dir
if [[ ! -d "$out_dir" ]]; then
    echo "Error: Directory does not exist. Exiting."
    exit 1
fi

echo -e "\nPath to Raw IDA data is: $root_dir"
echo -e "Path to Organized PET data is: $out_dir"



# Function to map scan type names
map_scan_type() {
    local scan_type_name="$1"
    case "$scan_type_name" in
        "Accelerated_Sagittal_MPRAGE")
            echo "T1"
            ;;
        "AA-APOE_TAU__AC_")
            echo "Tau-PET"
            ;;
        "AA-APOE_AMYLOID__AC_")
            echo "Amyloid-PET"
            ;;
        *)
            echo "$scan_type_name"  # Return as is if no match
            ;;
    esac
}

# Function to calculate the signed month difference between two dates (in format YYYYMMDD)
month_diff() {
    local date1=$(date -d "$1" +%Y%m)
    local date2=$(date -d "$2" +%Y%m)
    echo $(( (date1 / 100 - date2 / 100) * 12 + (date1 % 100 - date2 % 100) ))
}

# Function to count the number of date folders in a given scan type directory
count_date_folders() {
    local scan_dir="$1"
    if [ -d "$scan_dir" ]; then
        find "$scan_dir" -mindepth 1 -maxdepth 1 -type d | wc -l
    else
        echo 0
    fi
}

# Function to get date from folder name
get_date_from_folder() {
    local folder="$1"
    basename "$folder" | cut -c1-10
}

# Function to copy scan data only if the destination directory is empty
copy_scan_data() {
    local source_dir="$1"
    local dest_dir="$2"
    mkdir -p "$dest_dir"
    
    # Only copy if destination directory is empty
    if [ -z "$(ls -A "$dest_dir")" ]; then
        cp -r "$source_dir"/* "$dest_dir/"
    else
        echo "Destination $dest_dir already has files. Skipping copy."
    fi
}

# Set path
cd "$root_dir" || { echo "[ERROR] cd into $root_dir failed"; exit 1; }

echo " Starting subject loop..."


# Process each subject
for subject_path in "$root_dir"/*; do
    if [ -d "$subject_path" ]; then
        subject=$(basename "$subject_path")
        echo " Found subject: $subject"
        t1_dir=""
        tau_dir=""
        amyloid_dir=""

        # Find directories for each scan type
        for scan_type_dir in "$subject_path"/*; do
            if [ -d "$scan_type_dir" ]; then
                scan_type_base=$(basename "$scan_type_dir")
                scan_type=$(map_scan_type "$scan_type_base")

                case "$scan_type" in
                    "T1")
                        t1_dir="$scan_type_dir"
                        ;;
                    "Tau-PET")
                        tau_dir="$scan_type_dir"
                        ;;
                    "Amyloid-PET")
                        amyloid_dir="$scan_type_dir"
                        ;;
                esac
            fi
        done

        # Count the number of date folders in each directory
        t1_count=$(count_date_folders "$t1_dir")
        tau_count=$(count_date_folders "$tau_dir")
        amyloid_count=$(count_date_folders "$amyloid_dir")

        if [[ "$tau_count" -ge 1 ]]; then
            set_dir="$out_dir/Has_Tau/NIFTIs/$subject"
            for i in $(seq 1 "$tau_count"); do
                tau_folder=$(ls -1 "$tau_dir" | sed -n "${i}p")
                nearest_tau_date=$(get_date_from_folder "$tau_dir/$tau_folder")
                visit_dir="$set_dir/$i"

                # Get the date from the i-th folder in the Tau directory
                nearest_t1_folder=""
                while IFS= read -r t1_folder; do
                    t1_date=$(get_date_from_folder "$t1_dir/$t1_folder")
                    diff=$(month_diff "$nearest_tau_date" "$t1_date")
                    if (( diff >= -8 && diff <= 8 )); then
                        nearest_t1_folder="$t1_dir/$t1_folder"
                        nearest_t1_date="$t1_date"
                        break
                    fi
                done < <(ls -1 "$t1_dir")

                copy_scan_data "$nearest_t1_folder" "$visit_dir/T1_${nearest_t1_date}"
                copy_scan_data "$tau_dir/$tau_folder" "$visit_dir/Tau-PET_${nearest_tau_date}"
            done
        fi

        if [[ "$amyloid_count" -ge 1 ]]; then
            set_dir="$out_dir/Has_Amyloid/NIFTIs/$subject"
            for i in $(seq 1 "$amyloid_count"); do
                amyloid_folder=$(ls -1 "$amyloid_dir" | sed -n "${i}p")
                nearest_amyloid_date=$(get_date_from_folder "$amyloid_dir/$amyloid_folder")
                visit_dir="$set_dir/$i"

                # Get the date from the i-th folder in the Amyloid directory
                nearest_t1_folder=""
                while IFS= read -r t1_folder; do
                    t1_date=$(get_date_from_folder "$t1_dir/$t1_folder")
                    diff=$(month_diff "$nearest_amyloid_date" "$t1_date")
                    if (( diff >= -8 && diff <= 8 )); then
                        nearest_t1_folder="$t1_dir/$t1_folder"
                        nearest_t1_date="$t1_date"
                        break
                    fi
                done < <(ls -1 "$t1_dir")

                copy_scan_data "$nearest_t1_folder" "$visit_dir/T1_${nearest_t1_date}"
                copy_scan_data "$amyloid_dir/$amyloid_folder" "$visit_dir/Amyloid-PET_${nearest_amyloid_date}"
            done
        fi

    fi
done
