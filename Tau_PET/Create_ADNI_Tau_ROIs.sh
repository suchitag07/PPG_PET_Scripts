#!/bin/bash

##Takes aparc+aseg.nii as an input, outputs Braak ROIs: I, III-IV, V-VI, and Meta temporal ROI
##Using ROI definitions from Baker et al. Data in Brief 15 (2017) 648–657

#idx=(1006 2006 17 53) -> Jagust protocol suggests removing 17 + 53 (L R Hippocampi) due to off-target binding in choroid plexus (2021 protocol)
idx=(1006 2006)
for (( i=0; i<${#idx[@]}; i++ )); do
fslmaths $1 -thr `expr ${idx[$i]} - 1`.1 -uthr ${idx[$i]}.1 temp_FS_ROI_${idx[$i]}.nii.gz
done

rois=(temp_FS*)
combine="${rois[0]}"
for (( i=1; i<${#rois[@]}; i++ )); do
combine="${combine[@]} -add ${rois[$i]}"
done

fslmaths ${combine} -bin Braak_ROI_I.nii.gz #Braak ROI I
rm temp_FS_ROI*

idx=(1016 1007 1013 18 2016 2007 2013 54 1015 1002 1026 1023 1010 1035 1009 1033 2015 2002 2026 2023 2010 2035 2009 2033)
for (( i=0; i<${#idx[@]}; i++ )); do
fslmaths $1 -thr `expr ${idx[$i]} - 1`.9 -uthr ${idx[$i]}.1 temp_FS_ROI_${idx[$i]}.nii.gz
done

rois=(temp_FS*)
combine="${rois[0]}"
for (( i=1; i<${#rois[@]}; i++ )); do
combine="${combine[@]} -add ${rois[$i]}"
done

fslmaths ${combine} -bin Braak_ROI_III-IV.nii.gz #Braak ROI III-IV
rm temp_FS_ROI*

idx=(1001 1003 1008 1011 1012 1014 1017 1018 1019 1020 1025 1027 1028 1029 1030 1031 1032 1034 2001 2003 2008 2011 2012 2014 2017 2018 2019 2020 2025 2027 2028 2029 2030 2031 2032 2034)
for (( i=0; i<${#idx[@]}; i++ )); do
fslmaths $1 -thr `expr ${idx[$i]} - 1`.9 -uthr ${idx[$i]}.1 temp_FS_ROI_${idx[$i]}.nii.gz
done

rois=(temp_FS*)
combine="${rois[0]}"
for (( i=1; i<${#rois[@]}; i++ )); do
combine="${combine[@]} -add ${rois[$i]}"
done

fslmaths ${combine} -bin Braak_ROI_V-VI.nii.gz #Braak ROI V-VI
rm temp_FS_ROI*

#Meta temporal ROI -> Latest Jagust protocol (2021)
idx=(18 1006 1007 1009 1015 54 2006 2007 2009 2015)
for (( i=0; i<${#idx[@]}; i++ )); do
fslmaths $1 -thr `expr ${idx[$i]} - 1`.9 -uthr ${idx[$i]}.1 temp_FS_ROI_${idx[$i]}.nii.gz
done

rois=(temp_FS*)
combine="${rois[0]}"
for (( i=1; i<${#rois[@]}; i++ )); do
combine="${combine[@]} -add ${rois[$i]}"
done

fslmaths ${combine} -bin Meta_Temporal_ROI.nii.gz
rm temp_FS_ROI*
