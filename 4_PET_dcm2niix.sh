#!/bin/bash

#NAME: Suchita Ganesan
#DATE: Aug 16, 2024

# Define the base paths
INPUT_BASE_DIR="/path_to_data/PPG/PPG_Data_Organized/PET"       #EDIT AS NEEDED
echo -e "\nPath to PET data is: $INPUT_BASE_DIR"
  
cd $INPUT_BASE_DIR

# Define the dcm2niix command
DCM2NIIX_CMD="/usr/local/dcm2niix-master/build/bin/dcm2niix"
echo ${DCM2NIIX_CMD}
process_image_dir() {
    image_id_dir="$1"
    IFS='/' read -ra PARTS <<< "$image_id_dir"
	subject_id="${PARTS[12]}"         
	scan_type_base="${PARTS[14]}"       
	image_id="${PARTS[15]}"  
	scan_type="${scan_type_base::-3}"  
	output_dir="$(dirname "$image_id_dir")"
	output_prefix="${output_dir}/${subject_id}_${scan_type}_${image_id}"

    if [ -f "${output_prefix}.nii.gz" ]; then
        echo "Skipping $image_id_dir, ${output_prefix}.nii.gz NIfTI file already exists."
        return
    else
    	cmd="${DCM2NIIX_CMD} -z y -o ${output_dir} ${image_id_dir}"
    	echo "Running: $cmd"
    	if eval ${cmd}; then
        	echo "Conversion successful."

        	for ext in nii.gz json; do
            	for file in "$output_dir"/*."$ext"; do
                	[ -e "$file" ] || continue
                	mv "$file" "${output_prefix}.${ext}"
            	done
        	done
    	else
        	echo "Conversion failed for $image_id_dir"
    	fi    
    fi
}

export -f process_image_dir

find "$INPUT_BASE_DIR"/Has_Amyloid "$INPUT_BASE_DIR"/Has_Tau \
    -type d -path '*/NIFTIs/*/*/*/*' \
    -exec bash -c 'DCM2NIIX_CMD="$1"; process_image_dir "$0"' {} "$DCM2NIIX_CMD" \;

echo "dcm2niix processing completed."
