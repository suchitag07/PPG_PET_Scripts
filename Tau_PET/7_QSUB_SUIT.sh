#!/bin/bash

SUIT_Script="/path_to_data/PPG/Scripts/PET_Latest/TAU_Scripts/7a_Process_SUIT.sh"

subjects=()

for subject in "${subjects[@]}"; do
    qsub -q compute9.q "$SUIT_Script" "$subject"
    echo "Submitted job for $subject to compute9.q"
done

