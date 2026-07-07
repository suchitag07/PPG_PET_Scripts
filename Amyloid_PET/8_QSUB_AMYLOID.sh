#!/bin/bash

Amyloid_Script="/path_to_data/PPG/Scripts/PET_Latest/AMYLOID_Scripts/7_SG_Amyloid_PET.sh"

subjects=()  # enter complete list here, after you have gotten their prerequisites ready (ie freesurfer)

for subject in "${subjects[@]}"; do
    qsub -q compute9.q "$Amyloid_Script" "$subject"
    echo "Submitted job for $subject to compute9.q"
done

