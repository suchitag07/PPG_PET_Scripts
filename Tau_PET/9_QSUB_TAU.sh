#!/bin/bash

Tau_Script="/path_to_data/PPG/Scripts/PET_Latest/TAU_Scripts/8_SG_Tau_PET.sh"

subjects=()  

for subject in "${subjects[@]}"; do
    qsub -q compute9.q "$Tau_Script" "$subject"
    echo "Submitted job for $subject to compute9.q"
done
