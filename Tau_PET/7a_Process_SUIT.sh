#!/bin/bash
#$ -N SUIT_PPG              
#$ -cwd                        
#$ -o /path_to_data/PPG/PPG_Data_Organized/PET/PET_Processing_Logs/QSUB_SUIT_output_logs/   
#$ -e /path_to_data/PPG/PPG_Data_Organized/PET/PET_Processing_Logs/QSUB_SUIT_error_logs/                      

subject=$1

visit_code=1 # Edit this

echo "HOSTNAME: $(hostname)"
matlab -nodesktop -nosplash -r "subject_in = '$subject'; visit_code = $visit_code; SG_process_SUIT_v2(subject_in, visit_code); exit;"

