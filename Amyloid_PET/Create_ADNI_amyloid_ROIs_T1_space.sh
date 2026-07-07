#!/bin/bash
#Creating new amyloid composite SUVR based on Landau et al J Nucl Med 2015; 56:567–574

##Inputs are subject and aparc+aseg-in-rawavg.nii.gz in T1 space

subject=$1

echo "Creating ROIs for Amyloid SUVR extraction for ${subject}"

#Frontal regions
fslmaths aparc+aseg-in-rawavg.nii.gz -thr 1002.9 -uthr 1003.1 -bin L_caudmidfront.nii.gz
fslmaths aparc+aseg-in-rawavg.nii.gz -thr 1011.9 -uthr 1012.1 -bin L_latorbfront.nii.gz
fslmaths aparc+aseg-in-rawavg.nii.gz -thr 1013.9 -uthr 1014.1 -bin L_medorbfront.nii.gz
fslmaths aparc+aseg-in-rawavg.nii.gz -thr 1017.9 -uthr 1018.1 -bin L_parsoperc.nii.gz
fslmaths aparc+aseg-in-rawavg.nii.gz -thr 1018.9 -uthr 1019.1 -bin L_parsorb.nii.gz
fslmaths aparc+aseg-in-rawavg.nii.gz -thr 1019.9 -uthr 1020.1 -bin L_parstriang.nii.gz
fslmaths aparc+aseg-in-rawavg.nii.gz -thr 1026.9 -uthr 1027.1 -bin L_rostmidfront.nii.gz
fslmaths aparc+aseg-in-rawavg.nii.gz -thr 1027.9 -uthr 1028.1 -bin L_supfront.nii.gz
fslmaths aparc+aseg-in-rawavg.nii.gz -thr 1031.9 -uthr 1032.1 -bin L_frontpole.nii.gz
fslmaths aparc+aseg-in-rawavg.nii.gz -thr 2002.9 -uthr 2003.1 -bin R_caudmidfront.nii.gz
fslmaths aparc+aseg-in-rawavg.nii.gz -thr 2011.9 -uthr 2012.1 -bin R_latorbfront.nii.gz
fslmaths aparc+aseg-in-rawavg.nii.gz -thr 2013.9 -uthr 2014.1 -bin R_medorbfront.nii.gz
fslmaths aparc+aseg-in-rawavg.nii.gz -thr 2017.9 -uthr 2018.1 -bin R_parsoperc.nii.gz
fslmaths aparc+aseg-in-rawavg.nii.gz -thr 2018.9 -uthr 2019.1 -bin R_parsorb.nii.gz
fslmaths aparc+aseg-in-rawavg.nii.gz -thr 2019.9 -uthr 2020.1 -bin R_parstriang.nii.gz
fslmaths aparc+aseg-in-rawavg.nii.gz -thr 2026.9 -uthr 2027.1 -bin R_rostmidfront.nii.gz
fslmaths aparc+aseg-in-rawavg.nii.gz -thr 2027.9 -uthr 2028.1 -bin R_supfront.nii.gz
fslmaths aparc+aseg-in-rawavg.nii.gz -thr 2031.9 -uthr 2032.1 -bin R_frontpole.nii.gz

fslmaths L_caudmidfront.nii.gz -add L_latorbfront.nii.gz -add L_medorbfront.nii.gz -add L_parsoperc.nii.gz -add L_parsorb.nii.gz -add L_parstriang.nii.gz -add L_rostmidfront.nii.gz -add L_supfront.nii.gz -add L_frontpole.nii.gz -add R_caudmidfront.nii.gz -add R_latorbfront.nii.gz -add R_medorbfront.nii.gz -add R_parsoperc.nii.gz -add R_parsorb.nii.gz -add R_parstriang.nii.gz -add R_rostmidfront.nii.gz -add R_supfront.nii.gz -add R_frontpole.nii.gz frontal_new.nii.gz

#Anterior/posterior cingulate regions:
fslmaths aparc+aseg-in-rawavg.nii.gz -thr 1001.9 -uthr 1002.1 -bin L_caudACC.nii.gz
fslmaths aparc+aseg-in-rawavg.nii.gz -thr 1009.9 -uthr 1010.1 -bin L_isthACC.nii.gz
fslmaths aparc+aseg-in-rawavg.nii.gz -thr 1022.9 -uthr 1023.1 -bin L_postCC.nii.gz
fslmaths aparc+aseg-in-rawavg.nii.gz -thr 1025.9 -uthr 1026.1 -bin L_rostACC.nii.gz
fslmaths aparc+aseg-in-rawavg.nii.gz -thr 2001.9 -uthr 2002.1 -bin R_caudACC.nii.gz
fslmaths aparc+aseg-in-rawavg.nii.gz -thr 2009.9 -uthr 2010.1 -bin R_isthACC.nii.gz
fslmaths aparc+aseg-in-rawavg.nii.gz -thr 2022.9 -uthr 2023.1 -bin R_postCC.nii.gz
fslmaths aparc+aseg-in-rawavg.nii.gz -thr 2025.9 -uthr 2026.1 -bin R_rostACC.nii.gz

fslmaths L_caudACC.nii.gz -add L_isthACC.nii.gz -add L_postCC.nii.gz -add L_rostACC.nii.gz -add R_caudACC.nii.gz -add R_isthACC.nii.gz -add R_postCC.nii.gz -add R_rostACC.nii.gz APCC_new.nii.gz

#Lateral parietal regions:
fslmaths aparc+aseg-in-rawavg.nii.gz -thr 1007.9 -uthr 1008.1 -bin L_infpar.nii.gz
fslmaths aparc+aseg-in-rawavg.nii.gz -thr 1024.9 -uthr 1025.1 -bin L_precuneus.nii.gz
fslmaths aparc+aseg-in-rawavg.nii.gz -thr 1028.9 -uthr 1029.1 -bin L_suppar.nii.gz
fslmaths aparc+aseg-in-rawavg.nii.gz -thr 1030.9 -uthr 1031.1 -bin L_SMG.nii.gz
fslmaths aparc+aseg-in-rawavg.nii.gz -thr 2007.9 -uthr 2008.1 -bin R_infpar.nii.gz
fslmaths aparc+aseg-in-rawavg.nii.gz -thr 2024.9 -uthr 2025.1 -bin R_precuneus.nii.gz
fslmaths aparc+aseg-in-rawavg.nii.gz -thr 2028.9 -uthr 2029.1 -bin R_suppar.nii.gz
fslmaths aparc+aseg-in-rawavg.nii.gz -thr 2030.9 -uthr 2031.1 -bin R_SMG.nii.gz

fslmaths L_infpar.nii.gz -add L_precuneus.nii.gz -add L_suppar.nii.gz -add L_SMG.nii.gz -add R_infpar.nii.gz -add R_precuneus.nii.gz -add R_suppar.nii.gz -add R_SMG.nii.gz lat_parietal_new.nii.gz

#Lateral temporal regions:
fslmaths aparc+aseg-in-rawavg.nii.gz -thr 1014.9 -uthr 1015.1 -bin L_MTG.nii.gz
fslmaths aparc+aseg-in-rawavg.nii.gz -thr 1029.9 -uthr 1030.1 -bin L_STG.nii.gz
fslmaths aparc+aseg-in-rawavg.nii.gz -thr 2014.9 -uthr 2015.1 -bin R_MTG.nii.gz
fslmaths aparc+aseg-in-rawavg.nii.gz -thr 2029.9 -uthr 2030.1 -bin R_STG.nii.gz

fslmaths L_MTG.nii.gz -add L_STG.nii.gz -add R_MTG.nii.gz -add R_STG.nii.gz lat_temporal_new.nii.gz

fslmaths frontal_new.nii.gz -add APCC_new.nii.gz -add lat_parietal_new.nii.gz -add lat_temporal_new.nii.gz amyloid_composite_ROI.nii.gz

#Add this back in to get rid of individual ROIs
rm L_* R_*


