#!/bin/bash
#$ -N Tau_PET              
#$ -cwd                        
#$ -o /path_to_data/PPG/PPG_Data_Organized/PET/PET_Processing_Logs/Tau_output_logs/   
#$ -e /path_to_data/PPG/PPG_Data_Organized/PET/PET_Processing_Logs/Tau_error_logs/                      

echo "HOSTNAME: $(hostname)"
set -x

#Edit the following:
visit_code=2 # (1 or 2 etc)
#######################

subject=$1 # input subject ID (from command line, if in batch use #subject="${SGE_TASK}")

#Additional Anat Preprocessing Tools Directory if using synthstrip
Tools='/path_to_data/Tools'

#Freesurfer directory 
fs_dir='/path_to_data/PPG/PPG_Data_Organized/PET/SG_Freesurfer_Outputs_v_7_1/TAU'

#Tau_SUIT directory
SUIT_dir='/path_to_data/PPG/PPG_Data_Organized/PET/Has_Tau_derivatives/Tau_SUIT'

# PET root directory
folder_o='/path_to_data/PPG/PPG_Data_Organized/PET/Has_Tau' 

# Derivative directories
folder_process='/path_to_data/PPG/PPG_Data_Organized/PET/Has_Tau_derivatives/PET_subjects_process' 
mkdir -p ${folder_process}
mkdir -p ${folder_process}/${subject}/${visit_code}

rois_dir='/path_to_data/PPG/PPG_Data_Organized/PET/Has_Tau_derivatives/rois'
mkdir -p ${rois_dir}
mkdir -p ${rois_dir}/${subject}/${visit_code}

out_='/path_to_data/PPG/PPG_Data_Organized/PET/Has_Tau_derivatives/PET_subjects_output'
mkdir -p ${out_}
out=${out_}/${subject}/${visit_code}
mkdir -p ${out}

SUVRout_='/path_to_data/PPG/PPG_Data_Organized/PET/Has_Tau_derivatives/PET_subjects_process_SUVRs'
mkdir -p ${SUVRout_}
SUVRout=${SUVRout_}/${subject}/${visit_code}
mkdir -p ${SUVRout}

FSout_='/path_to_data/PPG/PPG_Data_Organized/PET/Has_Tau_derivatives/PET_subjects_process_FSout'
mkdir -p ${FSout_}
FSout=${FSout_}/${subject}/${visit_code}
mkdir -p ${FSout}

FS_cheat_dir='/path_to_data/PPG/PPG_Data_Organized/PET/Has_Tau_derivatives/FS_SUVR_stats'
FS_cheat_subdir=${FS_cheat_dir}/${visit_code}/${subject}/stats
mkdir -p ${FS_cheat_subdir}

#Set up variable to make subj dir access easy
folder=${folder_process}/${subject}/${visit_code}
anat_dir=${folder}

############################################################  PET <-> T1 Section ######################################################################

###################   Section to Preprocess Anatomical Data: 1) N4 Bias Correct Raw T1 2) Skull Strip T1   ###################


if [ ! -d ${folder_o}/NIFTIs/${subject}/${visit_code} ]; then
	echo "No Tau PET for" $subject "at" $visit_code
	exit
else
	echo "Processing PET <-> T1 for:" $subject 
fi



#Inside PET PROCESS DIRECTORY
cd ${folder}

#Copy over and rename the raw T1 and PET
if [ ! -f ${subject}_T1_Raw.nii.gz ]; then
	cp ${folder_o}/${timepoint}/NIFTIs/${subject}/${visit_code}/*T1*/*nii* ${folder_process}/${subject}/${visit_code}
	mv *T1*  ${subject}_T1_Raw.nii.gz
fi

if [ ! -f ${subject}_Tau_PET.nii.gz ]; then
	cp ${folder_o}/${timepoint}/NIFTIs/${subject}/${visit_code}/*PET*/*nii* ${folder_process}/${subject}/${visit_code}
	mv *PET* ${subject}_Tau_PET.nii.gz
fi

#Masking 1: N4 Bias correction can overcorrect/introduce outside brain areas, obtaining a mask first and applying it helps avoid such issues
#1. Get initial raw mask - needed for bias correction
if [ ! -f ${subject}_T1_raw_brain_mask.nii.gz ]; then

	#mri_watershed
	mri_watershed ${folder}/${subject}_T1_Raw.nii.gz ${folder}/${subject}_T1_raw_brain.nii.gz
	fslmaths ${folder}/${subject}_T1_raw_brain.nii.gz -bin ${folder}/${subject}_T1_raw_brain_mask.nii.gz

fi

#2. N4 bias correct the Raw T1 
if [ ! -f ${subject}_T1.nii.gz ]; then
    echo "Running N4BiasFieldCorrection for ${subject}..."
    error_message=$( /usr/local/ANTs/bin/N4BiasFieldCorrection -d 3 \
        -i ${subject}_T1_Raw.nii.gz \
        -x ${subject}_T1_raw_brain_mask.nii.gz \
        -b [100] \
        -s 2 \
        -o ${subject}_T1.nii.gz 2>&1 )

    # Check if the error message contains "Inputs do not occupy the same physical space"
    if echo "$error_message" | grep -q "Inputs do not occupy the same physical space"; then
        echo "Error detected: Inputs do not occupy the same physical space. Attempting to resample mask..."
        antsApplyTransforms -d 3 \
            -i ${subject}_T1_raw_brain_mask.nii.gz \
            -r ${subject}_T1_Raw.nii.gz \
            -o ${subject}_T1_resampled_brain_mask.nii.gz \
            --float
        
        echo "Retrying N4BiasFieldCorrection with resampled mask..."
        /usr/local/ANTs/bin/N4BiasFieldCorrection -d 3 \
            -i ${subject}_T1_Raw.nii.gz \
            -x ${subject}_T1_resampled_brain_mask.nii.gz \
            -b [100] \
            -s 2 \
            -o ${subject}_T1.nii.gz
    fi
fi

#fslview_deprecated ${subject}_T1.nii.gz ${subject}_T1_Raw.nii.gz

#3. Pass in N4 corrected T1 and get the mask + brain for it
if [ ! -f ${subject}_T1_brain.nii.gz ]; then

	mri_watershed ${folder}/${subject}_T1.nii.gz ${folder}/${subject}_T1_brain.nii.gz
	fslmaths ${folder}/${subject}_T1_brain.nii.gz -bin ${folder}/${subject}_T1_brain_mask.nii.gz
		
fi

############################################################  FreeSurfer Section ######################################################################

###################   Section to Process Freesurfer Segmentations and bring then to T1 Space  ###################

#Cd to FREESURFER SUBJECTS DIRECTORY

cd ${fs_dir}/${visit_code}/sub-${subject}/mri

#1. FS: Register Freesurfer segmentations to T1 space (rawavg)

#Bring Destrieux atlas to T1 space
if [ ! -f aparc2009aseg-in-rawavg.nii.gz ]; then
	mri_label2vol --seg aparc.a2009s+aseg.mgz --temp rawavg.mgz --o aparc2009aseg-in-rawavg.mgz --regheader aparc.a2009s+aseg.mgz 
	mri_convert aparc2009aseg-in-rawavg.mgz aparc2009aseg-in-rawavg.nii.gz #Destrieux atlas in T1 space, nifti file
fi

#Bring Desikan-Killiany atlas  to T1 space
if [ ! -f aparc+aseg-in-rawavg.nii.gz ]; then
	mri_label2vol --seg aparc+aseg.mgz --temp rawavg.mgz --o aparc+aseg-in-rawavg.mgz --regheader aparc+aseg.mgz 
	mri_convert aparc+aseg-in-rawavg.mgz aparc+aseg-in-rawavg.nii.gz #Desikan-Killiany atlas  in T1 space, nifti file
fi

#2. Extract Reference Region Mask using Destrieux atlas in T1 space
if [ ! -f ${subject}_cereb_whole_ero1.nii.gz ]; then

	fslmaths aparc2009aseg-in-rawavg.nii.gz -thr 6.9 -uthr 7.1 -bin L_cereb_WM.nii.gz
	fslmaths aparc2009aseg-in-rawavg.nii.gz -thr 7.9 -uthr 8.1 -bin L_cereb_GM.nii.gz
	fslmaths aparc2009aseg-in-rawavg.nii.gz -thr 45.9 -uthr 46.1 -bin R_cereb_WM.nii.gz
	fslmaths aparc2009aseg-in-rawavg.nii.gz -thr 46.9 -uthr 47.1 -bin R_cereb_GM.nii.gz
	fslmaths L_cereb_WM.nii.gz -add L_cereb_GM.nii.gz -add R_cereb_WM.nii.gz -add R_cereb_GM.nii.gz ${subject}_cereb_whole.nii.gz
	fslmaths L_cereb_GM.nii.gz -add R_cereb_GM.nii.gz ${subject}_cereb_GM.nii.gz
	mri_binarize --i ${subject}_cereb_GM.nii.gz --erode 1 --match 1 --o ${subject}_cereb_GM_ero1.nii.gz
	mri_binarize --i ${subject}_cereb_whole.nii.gz --erode 1 --match 1 --o ${subject}_cereb_whole_ero1.nii.gz
	
fi

#3. Extract Predefined ROI Masks using Desikan-Killiany atlas in T1 space
if [ ! -d $rois_dir/${subject}/${visit_code}/ROIs ]; then mkdir $rois_dir/${subject}/${visit_code}/ROIs; fi

if [ ! -f $rois_dir/${subject}/${visit_code}/ROIs/Braak_ROI_V-VI.nii.gz  ]; then
	cd /path_to_data/PPG/Scripts/PET_Latest/TAU_Scripts/ROI_TEMP_PROCESSING
	mkdir ROI_Tau_preproc_${subject}_${visit_code}
	cd ROI_Tau_preproc_${subject}_${visit_code}/
    cp ${fs_dir}/${visit_code}/sub-${subject}/mri/aparc+aseg-in-rawavg.nii.gz .
	.././Create_ADNI_Tau_ROIs.sh aparc+aseg-in-rawavg.nii.gz
	mv Braak*.nii.gz $rois_dir/${subject}/${visit_code}/ROIs
	mv Meta_Temporal_ROI.nii.gz $rois_dir/${subject}/${visit_code}/ROIs
	cd /path_to_data/PPG/Scripts/PET_Latest/TAU_Scripts/ROI_TEMP_PROCESSING
	echo "Deleting temporary directory for ROI processing"
	rm -rf ROI_Tau_preproc_${subject}_${visit_code}
fi

cd $rois_dir/${subject}/${visit_code}/ROIs

if [ ! -f $rois_dir/${subject}/${visit_code}/ROIs/Braak_composite_ROI.nii.gz ]; then
	fslmaths Braak_ROI_I.nii.gz -add Braak_ROI_III-IV.nii.gz -add Braak_ROI_V-VI.nii.gz Braak_composite_ROI.nii.gz
fi

echo "Finished creating Predefined ROIs for Tau SUVR extraction for ${subject}"

############################################################  SUIT Section ######################################################################

cd ${SUIT_dir}/${subject}/${visit_code}

if [ ! -f ${SUIT_dir}/${subject}/${visit_code}/Cereb-SUIT_warp_2_${subject}_native_T1.nii ]; then 
	echo "SUIT data is missing, exiting program"
	exit
fi

if [ ! -f ${SUIT_dir}/${subject}/${visit_code}/Inf_cereb-SUIT.nii.gz ] && [ -d ${SUIT_dir}/${subject}/${visit_code} ]; then

    #For Inferior cerebellar inclusion mask: SUIT codes 6, 8-28, 33, 34
	fslmaths Cereb-SUIT_warp_2_${subject}_native_T1.nii -thr 5.9 -uthr 6.1 -bin Cereb-SUIT_6.nii.gz
	fslmaths Cereb-SUIT_warp_2_${subject}_native_T1.nii -thr 7.9 -uthr 28.1 -bin Cereb-SUIT_8-28.nii.gz
	fslmaths Cereb-SUIT_warp_2_${subject}_native_T1.nii -thr 32.9 -uthr 33.1 -bin Cereb-SUIT_33.nii.gz
	fslmaths Cereb-SUIT_warp_2_${subject}_native_T1.nii -thr 33.9 -uthr 34.1 -bin Cereb-SUIT_34.nii.gz
	
	#For Superior cerebellar exclusion mask (bilateral lobules I-VI): SUIT codes 1-5, 7
	fslmaths Cereb-SUIT_warp_2_${subject}_native_T1.nii -thr 0.9 -uthr 5.1 -bin Cereb-SUIT_1-5.nii.gz
	fslmaths Cereb-SUIT_warp_2_${subject}_native_T1.nii -thr 6.9 -uthr 7.1 -bin Cereb-SUIT_7.nii.gz
	
	#Concatenate to get Inferior cereb inclusion mask and same for Sup cereb exclusion mask
	fslmaths Cereb-SUIT_34.nii.gz -add Cereb-SUIT_33.nii.gz -add Cereb-SUIT_8-28.nii.gz -add Cereb-SUIT_6.nii.gz Inf_cereb-SUIT.nii.gz
	fslmaths Cereb-SUIT_7.nii.gz -add Cereb-SUIT_1-5.nii.gz Sup_cereb-SUIT.nii.gz
	
	rm Cereb-SUIT_34.nii.gz Cereb-SUIT_33.nii.gz Cereb-SUIT_8-28.nii.gz Cereb-SUIT_7.nii.gz Cereb-SUIT_6.nii.gz Cereb-SUIT_1-5.nii.gz
fi

#2. SUIT ROI contains some extra-brain ROIs, so we'll restrict it with the FS derived cereb mask and then  subtract out superior cerebellum. 
#Note the FS derived cerebellum is already in T1 space here
if [ ! -f ${SUIT_dir}/${subject}/${visit_code}/Inf_cereb-SUIT_mask_ero1.nii.gz ]; then

	#Get Intersection between FS and Inf Cereb
	fslmaths Inf_cereb-SUIT.nii.gz -mas ${fs_dir}/${visit_code}/sub-${subject}/mri/${subject}_cereb_GM.nii.gz Inf_cereb-SUIT_mask_temp.nii.gz
	
	#Subtract out superior cerebellum
	fslmaths Inf_cereb-SUIT_mask_temp.nii.gz -sub Sup_cereb-SUIT.nii.gz -thr 0 Inf_cereb-SUIT_mask.nii.gz
	rm Inf_cereb-SUIT_mask_temp.nii.gz 
	
	#Binarize and erode 1 voxel to reduce partial volume effects
	mri_binarize --i Inf_cereb-SUIT_mask.nii.gz --erode 1 --match 1 --o Inf_cereb-SUIT_mask_ero1.nii.gz
fi


############################################   Section to Process PET Data  #########################################################


cd ${folder}

if [ -f $folder/${subject}_Tau_PET.nii.gz ]; then

	#3. Smooth image
	if [ ! -f $folder/${subject}_Tau_PET_sm6mm.nii.gz ]; then
		fslmaths $folder/${subject}_Tau_PET.nii.gz -kernel gauss 2.55 -fmean $folder/${subject}_Tau_PET_sm6mm.nii.gz
	fi

	#4. Mcflirt motion correct smoothed PET, then apply transformations to unsmoothed PET images
	if [ ! -f $folder/${subject}_Tau_PET_sm6mm_MC.nii.gz ]; then
		mcflirt -in $folder/${subject}_Tau_PET_sm6mm.nii.gz -meanvol -cost normmi -mats -plots
		applyxfm4D $folder/${subject}_Tau_PET.nii.gz $folder/${subject}_Tau_PET_sm6mm_mcf_mean_reg.nii.gz $folder/${subject}_Tau_PET_sm6mm_MC.nii.gz $folder/${subject}_Tau_PET_sm6mm_mcf.mat -fourdigit
	fi

	#5. Output motion parameters for QC
	if [ ! -f $folder/${subject}_Tau_PET_sm6mm_MC_fdrms.txt ]; then
		fsl_motion_outliers -i $folder/${subject}_Tau_PET_sm6mm_MC.nii.gz -o $folder/${subject}_Tau_PET_sm6mm_MC_mc-outliers.txt -s $folder/${subject}_Tau_PET_sm6mm_MC_fdrms.txt --fd --thresh=0.9 -v
	fi

	#6. Create output average image 
	if [ ! -f $folder/${subject}_Tau_PET_sm6mm_MC_MEAN.nii.gz ]; then
		fslmaths $folder/${subject}_Tau_PET_sm6mm_MC.nii.gz -Tmean $folder/${subject}_Tau_PET_sm6mm_MC_MEAN.nii.gz
	fi

	#7. If preprocessing steps worked, make a copy of the mean PET img and rename to ${subject}_Tau_PET_sm6mm_MC_MEAN_v.nii.gz
	if [ ! -f ${folder_process}/${subject}/${visit_code}/${subject}_Tau_PET_sm6mm_MC_MEAN_v.nii.gz ]; then cp $folder/${subject}_Tau_PET_sm6mm_MC_MEAN.nii.gz ${folder_process}/${subject}/${visit_code}/${subject}_Tau_PET_sm6mm_MC_MEAN_v.nii.gz; fi

	cd ${folder_process}/${subject}/${visit_code}

	#8. First round of registration of Tau PET to T1
	if [ ! -f ${subject}_Tau_PET_sm6mm_MC_MEAN_v_1st_lin_T1_0GenericAffine.mat ]; then
		antsRegistration -d 3 -m MI[$anat_dir/${subject}_T1.nii.gz, ${subject}_Tau_PET_sm6mm_MC_MEAN_v.nii.gz,1,32,Regular,0.25] \
		-r [$anat_dir/${subject}_T1.nii.gz, ${subject}_Tau_PET_sm6mm_MC_MEAN_v.nii.gz,1] \
		-c [1000x500x250x0,1e-7,5] -t Rigid[0.1] -f 8x4x2x1 -s 4x2x1x0 -u 1 -z 1 --winsorize-image-intensities [0.005, 0.995] \
		-o ${subject}_Tau_PET_sm6mm_MC_MEAN_v_1st_lin_T1_ -v 
	fi

	#9. Apply linear transformation for QC check
	if [ ! -f ${subject}_Tau_PET_sm6mm_MC_MEAN_v_1st_lin_T1.nii.gz ]; then
		antsApplyTransforms -d 3 -i ${subject}_Tau_PET_sm6mm_MC_MEAN_v.nii.gz -r $anat_dir/${subject}_T1.nii.gz \
		-t ${subject}_Tau_PET_sm6mm_MC_MEAN_v_1st_lin_T1_0GenericAffine.mat \
		-o ${subject}_Tau_PET_sm6mm_MC_MEAN_v_1st_lin_T1.nii.gz
	fi

	#10. Do a second round of rigid transformation, with skull-stripped T1 and masking for both images
	if [ ! -f ${subject}_Tau_PET_sm6mm_MC_MEAN_v_2nd_lin_T1_0GenericAffine.mat ]; then
		antsRegistration -d 3 -m MI[$anat_dir/${subject}_T1_brain.nii.gz, ${subject}_Tau_PET_sm6mm_MC_MEAN_v_1st_lin_T1.nii.gz,1,32,Regular,0.25] \
		-c [1000x500x250x0,1e-7,5] -t Rigid[0.1] -f 8x4x2x1 -s 4x2x1x0 -u 1 -z 1 --winsorize-image-intensities [0.005, 0.995] \
		-x [$anat_dir/${subject}_T1_brain_mask.nii.gz, ${subject}_T1_brain_mask.nii.gz] \
		-o ${subject}_Tau_PET_sm6mm_MC_MEAN_v_2nd_lin_T1_ -v
	fi

	#11. Apply linear transformation for QC check
	if [ ! -f ${subject}_Tau_PET_sm6mm_MC_MEAN_v_2nd_lin_T1.nii.gz ]; then
		antsApplyTransforms -d 3 -i ${subject}_Tau_PET_sm6mm_MC_MEAN_v.nii.gz -r $anat_dir/${subject}_T1_brain.nii.gz \
		-t ${subject}_Tau_PET_sm6mm_MC_MEAN_v_2nd_lin_T1_0GenericAffine.mat \
		-t ${subject}_Tau_PET_sm6mm_MC_MEAN_v_1st_lin_T1_0GenericAffine.mat \
		-o ${subject}_Tau_PET_sm6mm_MC_MEAN_v_2nd_lin_T1.nii.gz
	fi

	#12. Move Mean PET to T1 space and smooth
	if [ ! -f ${subject}_Tau_PET_sm6mm_MC_MEAN_v_warp2_T1.nii.gz ];then
		antsApplyTransforms -d 3 -i ${subject}_Tau_PET_sm6mm_MC_MEAN_v.nii.gz -r $anat_dir/${subject}_T1.nii.gz \
		-t ${subject}_Tau_PET_sm6mm_MC_MEAN_v_2nd_lin_T1_0GenericAffine.mat \
		-t ${subject}_Tau_PET_sm6mm_MC_MEAN_v_1st_lin_T1_0GenericAffine.mat \
		-o ${subject}_Tau_PET_sm6mm_MC_MEAN_v_warp2_T1.nii.gz  -v
	fi

	if [ ! -f ${subject}_Tau_PET_sm6mm_MC_MEAN_v_warp2_T1_sm8mm.nii.gz ]; then
		fslmaths ${subject}_Tau_PET_sm6mm_MC_MEAN_v_warp2_T1.nii.gz -kernel gauss 3.4 -fmean ${subject}_Tau_PET_sm6mm_MC_MEAN_v_warp2_T1_sm8mm.nii.gz 
		rm *Stage*
	fi
	
	#Move T1 to PET Space 
	if [ ! -f ${subject}_T1_in_PET.nii.gz ]; then
        antsApplyTransforms -d 3 --float 0 \
    	-i $anat_dir/${subject}_T1.nii.gz \
    	-r ${subject}_Tau_PET_sm6mm_MC_MEAN.nii.gz \
    	-n BSpline \
    	-t [${subject}_Tau_PET_sm6mm_MC_MEAN_v_1st_lin_T1_0GenericAffine.mat,1] \
    	-t [${subject}_Tau_PET_sm6mm_MC_MEAN_v_2nd_lin_T1_0GenericAffine.mat,1] \
    	-o ${subject}_T1_in_PET.nii.gz 
	fi
	
	###########
	
	#13. Move cereb to PET space
	if [ ! -f ${subject}_inf-cereb_ero1_v_warp2_nsPET.nii.gz ]; then
		antsApplyTransforms -d 3 -e 0 --float 0 \
		-i ${SUIT_dir}/${subject}/${visit_code}/Inf_cereb-SUIT_mask_ero1.nii.gz \
		-r ${subject}_Tau_PET_sm6mm_MC_MEAN_v.nii.gz \
		-n NearestNeighbor \
		-t [${subject}_Tau_PET_sm6mm_MC_MEAN_v_1st_lin_T1_0GenericAffine.mat,1] \
		-t [${subject}_Tau_PET_sm6mm_MC_MEAN_v_2nd_lin_T1_0GenericAffine.mat,1] \
		-o ${subject}_inf-cereb_ero1_v_warp2_nsPET.nii.gz 
	fi
	
	
	###########

	#Create SUVR images and move to output directory
	if [ ! -f ${subject}_Tau_PET_sm6mm_MC_MEAN_v_warp2_T1_sm8mm_SUVR.nii.gz ]; then
		fslmaths ${subject}_Tau_PET_sm6mm_MC_MEAN_v_warp2_T1_sm8mm.nii.gz -div `fslstats ${subject}_Tau_PET_sm6mm_MC_MEAN_v.nii.gz -k ${subject}_inf-cereb_ero1_v_warp2_nsPET.nii.gz -M` ${subject}_Tau_PET_sm6mm_MC_MEAN_v_warp2_T1_sm8mm_SUVR.nii.gz
	fi

	if [ ! -f $out/${subject}_Tau_PET_sm6mm_MC_MEAN_v_warp2_T1_sm8mm_SUVR.nii.gz ]; then
		cp ${subject}_Tau_PET_sm6mm_MC_MEAN_v_warp2_T1_sm8mm_SUVR.nii.gz $out
	fi

	#Move composite ROIs to PET space and extract
	if [ ! -d $rois_dir/${subject}/${visit_code}/ROIs ]; then mkdir $rois_dir/${subject}/${visit_code}/ROIs; fi

	cd ${rois_dir}/${subject}/${visit_code}

	#Move ROIs into PET space 
	for img in Braak_ROI_I.nii.gz Braak_ROI_III-IV.nii.gz Braak_ROI_V-VI.nii.gz Braak_composite_ROI.nii.gz Meta_Temporal_ROI.nii.gz; do
		if [ ! -f ROIs/${img%.nii.gz}_v_warp2_TauPET.nii.gz ]; then
			antsApplyTransforms -d 3 -e 0 --float 0 -i ROIs/$img -r ${folder_process}/${subject}/${visit_code}/${subject}_Tau_PET_sm6mm_MC_MEAN_v.nii.gz \
			-n NearestNeighbor \
			-t [${folder_process}/${subject}/${visit_code}/${subject}_Tau_PET_sm6mm_MC_MEAN_v_1st_lin_T1_0GenericAffine.mat,1] \
			-t [${folder_process}/${subject}/${visit_code}/${subject}_Tau_PET_sm6mm_MC_MEAN_v_2nd_lin_T1_0GenericAffine.mat,1] \
			-o ROIs/${img%.nii.gz}_v_warp2_TauPET.nii.gz 
		fi
		if [ ! -f $SUVRout/${subject}_Tau_${img%.nii.gz}_v.txt ]; then
				echo "scale=4; `fslstats ${folder_process}/${subject}/${visit_code}/${subject}_Tau_PET_sm6mm_MC_MEAN_v.nii.gz -k ROIs/${img%.nii.gz}_v_warp2_TauPET.nii.gz -M` / `fslstats ${folder_process}/${subject}/${visit_code}/${subject}_Tau_PET_sm6mm_MC_MEAN_v.nii.gz -k ${folder_process}/${subject}/${visit_code}/${subject}_inf-cereb_ero1_v_warp2_nsPET.nii.gz -M`" | bc >> $SUVRout/${subject}_Tau_${img%.nii.gz}_v.txt
		fi
	done
	echo "Tau PET Processing Complete for" $subject "at visit code" $visit_code

else echo "No Tau PET for" $subject 

fi

############################################################  PET <-> Freesurfer Space Section ######################################################################

echo "Processing PET <-> Freesurfer for:" $subject 

#Inside PET PROCESS DIRECTORY
cd ${folder}

#Copy over and rename the T1 mgz
if [ ! -f ${subject}_FS_T1.nii.gz ]; then
	cp $fs_dir/${visit_code}/sub-${subject}/mri/T1.mgz ${folder_process}/${subject}/${visit_code}
	mv T1.mgz  ${subject}_FS_T1_Raw.mgz
	mri_convert ${subject}_FS_T1_Raw.mgz ${subject}_FS_T1_Raw.nii.gz
	fslreorient2std ${subject}_FS_T1_Raw.nii.gz ${subject}_FS_T1.nii.gz
	rm ${subject}_FS_T1_Raw.mgz ${subject}_FS_T1_Raw.nii.gz
fi

#Copy over and rename the brain (skull strip) mgz
if [ ! -f ${subject}_FS_brain.nii.gz ]; then
	cp $fs_dir/${visit_code}/sub-${subject}/mri/brain.mgz ${folder_process}/${subject}/${visit_code}
	mv brain.mgz ${subject}_FS_brain_Raw.mgz
	mri_convert ${subject}_FS_brain_Raw.mgz ${subject}_FS_brain_Raw.nii.gz
	fslreorient2std ${subject}_FS_brain_Raw.nii.gz ${subject}_FS_brain.nii.gz
	rm ${subject}_FS_brain_Raw.mgz ${subject}_FS_brain_Raw.nii.gz
	
fi

#The T1 and brain.mgz (skullstrip) are already bias corrected, just obtain the brain mask using fslmaths
if [ ! -f ${subject}_FS_brain_mask.nii.gz ]; then
	fslmaths ${subject}_FS_brain.nii.gz -bin ${subject}_FS_brain_mask.nii.gz
fi

############################################################  Freesurfer Section ######################################################################

#Inside FREESURFER DIRECTORY

cd ${fs_dir}/${visit_code}/sub-${subject}/mri

if [ ! -f aparc.a2009s+aseg.nii.gz ]; then
	mri_convert aparc.a2009s+aseg.mgz aparc.a2009s+aseg_raw.nii.gz
	fslreorient2std aparc.a2009s+aseg_raw.nii.gz aparc.a2009s+aseg.nii.gz  
	rm aparc.a2009s+aseg_raw.nii.gz
	
	mri_convert aparc+aseg.mgz aparc+aseg_raw.nii.gz
	fslreorient2std aparc+aseg_raw.nii.gz aparc+aseg.nii.gz
	rm aparc+aseg_raw.nii.gz
fi


#Extract ref region mask in Freesurfer space from aparc.a2009s+aseg.nii.gz
if [ ! -f ${subject}_cereb_whole_ero1_FS.nii.gz ]; then
	fslmaths aparc.a2009s+aseg.nii.gz -thr 6.9 -uthr 7.1 -bin L_cereb_WM_FS.nii.gz
	fslmaths aparc.a2009s+aseg.nii.gz -thr 7.9 -uthr 8.1 -bin L_cereb_GM_FS.nii.gz
	fslmaths aparc.a2009s+aseg.nii.gz -thr 45.9 -uthr 46.1 -bin R_cereb_WM_FS.nii.gz
	fslmaths aparc.a2009s+aseg.nii.gz -thr 46.9 -uthr 47.1 -bin R_cereb_GM_FS.nii.gz
	fslmaths L_cereb_WM_FS.nii.gz -add L_cereb_GM_FS.nii.gz -add R_cereb_WM_FS.nii.gz -add R_cereb_GM_FS.nii.gz ${subject}_cereb_whole_FS.nii.gz
	fslmaths L_cereb_GM_FS.nii.gz -add R_cereb_GM_FS.nii.gz ${subject}_cereb_GM_FS.nii.gz
	mri_binarize --i ${subject}_cereb_GM_FS.nii.gz --erode 1 --match 1 --o ${subject}_cereb_GM_ero1_FS.nii.gz
	mri_binarize --i ${subject}_cereb_whole_FS.nii.gz --erode 1 --match 1 --o ${subject}_cereb_whole_ero1_FS.nii.gz	
	rm L_* R_*
fi



############################################################  SUIT-Freesurfer Section ######################################################################

cd ${SUIT_dir}/${subject}/${visit_code}

#BRING SUIT MAP TO FREESURFER SPACE
if [ ! -f ${SUIT_dir}/${subject}/${visit_code}/Cereb-SUIT_warp_2_${subject}_FS.nii ]; then
    antsApplyTransforms \
        -d 3 \
        --float 0 \
        -i Cereb-SUIT_warp_2_${subject}_native_T1.nii \
        -r ${folder}/${subject}_FS_T1.nii.gz \
        -n NearestNeighbor \
        -o Cereb-SUIT_warp_2_${subject}_FS.nii \
        -m ${subject}_cereb_whole_ero1_FS.nii.gz
fi

if [ ! -f ${SUIT_dir}/${subject}/${visit_code}/Inf_cereb-SUIT_FS.nii.gz ] && [ -d ${SUIT_dir}/${subject}/${visit_code} ]; then

    #For Inferior cerebellar inclusion mask: SUIT codes 6, 8-28, 33, 34
	fslmaths Cereb-SUIT_warp_2_${subject}_FS.nii -thr 5.9 -uthr 6.1 -bin Cereb-SUIT_6.nii.gz
	fslmaths Cereb-SUIT_warp_2_${subject}_FS.nii -thr 7.9 -uthr 28.1 -bin Cereb-SUIT_8-28.nii.gz
	fslmaths Cereb-SUIT_warp_2_${subject}_FS.nii -thr 32.9 -uthr 33.1 -bin Cereb-SUIT_33.nii.gz
	fslmaths Cereb-SUIT_warp_2_${subject}_FS.nii -thr 33.9 -uthr 34.1 -bin Cereb-SUIT_34.nii.gz
	
	#For Superior cerebellar exclusion mask (bilateral lobules I-VI): SUIT codes 1-5, 7
	fslmaths Cereb-SUIT_warp_2_${subject}_FS.nii -thr 0.9 -uthr 5.1 -bin Cereb-SUIT_1-5.nii.gz
	fslmaths Cereb-SUIT_warp_2_${subject}_FS.nii -thr 6.9 -uthr 7.1 -bin Cereb-SUIT_7.nii.gz
	
	#Concatenate to get Inferior cereb inclusion mask and same for Sup cereb exclusion mask
	fslmaths Cereb-SUIT_34.nii.gz -add Cereb-SUIT_33.nii.gz -add Cereb-SUIT_8-28.nii.gz -add Cereb-SUIT_6.nii.gz Inf_cereb-SUIT_FS.nii.gz
	fslmaths Cereb-SUIT_7.nii.gz -add Cereb-SUIT_1-5.nii.gz Sup_cereb-SUIT_FS.nii.gz
	
	rm Cereb-SUIT_34.nii.gz Cereb-SUIT_33.nii.gz Cereb-SUIT_8-28.nii.gz Cereb-SUIT_7.nii.gz Cereb-SUIT_6.nii.gz Cereb-SUIT_1-5.nii.gz
fi

#2. SUIT ROI contains some extra-brain ROIs, so we'll restrict it with the FS derived cereb mask and then subtract out superior cerebellum. 
if [ ! -f ${SUIT_dir}/${subject}/${visit_code}/Inf_cereb-SUIT_FS_mask_ero1.nii.gz ]; then

	#Get Intersection between FS and Inf Cereb
	fslmaths Inf_cereb-SUIT_FS.nii.gz -mas ${fs_dir}/${visit_code}/sub-${subject}/mri/${subject}_cereb_GM_FS.nii.gz Inf_cereb-SUIT_FS_mask_temp.nii.gz
	
	#Subtract out superior cerebellum
	fslmaths Inf_cereb-SUIT_FS_mask_temp.nii.gz -sub Sup_cereb-SUIT_FS.nii.gz -thr 0 Inf_cereb-SUIT_FS_mask.nii.gz
	rm Inf_cereb-SUIT_FS_mask_temp.nii.gz 
	
	#Binarize and erode 1 voxel to reduce partial volume effects
	mri_binarize --i Inf_cereb-SUIT_FS_mask.nii.gz --erode 1 --match 1 --o Inf_cereb-SUIT_FS_mask_ero1.nii.gz
fi

############################################################  TAU PET Section ######################################################################

#Inside PET PROCESS DIRECTORY

cd ${folder}

if [ -f $folder/${subject}_Tau_PET.nii.gz ]; then

	#1. First round of registration of Tau PET to Freesurfer space
	if [ ! -f ${subject}_Tau_PET_sm6mm_MC_MEAN_v_1st_lin_Freesurfer_0GenericAffine.mat ]; then
		antsRegistration -d 3 -m MI[$anat_dir/${subject}_FS_T1.nii.gz, ${subject}_Tau_PET_sm6mm_MC_MEAN_v.nii.gz,1,32,Regular,0.25] \
		-r [$anat_dir/${subject}_FS_T1.nii.gz, ${subject}_Tau_PET_sm6mm_MC_MEAN_v.nii.gz,1] \
		-c [1000x500x250x0,1e-7,5] -t Rigid[0.1] -f 8x4x2x1 -s 4x2x1x0 -u 1 -z 1 --winsorize-image-intensities [0.005, 0.995] \
		-o ${subject}_Tau_PET_sm6mm_MC_MEAN_v_1st_lin_Freesurfer_ -v 
	fi

	#9. Apply linear transformation for QC check
	if [ ! -f ${subject}_Tau_PET_sm6mm_MC_MEAN_v_1st_lin_Freesurfer.nii.gz ]; then
		antsApplyTransforms -d 3 -i ${subject}_Tau_PET_sm6mm_MC_MEAN_v.nii.gz -r $anat_dir/${subject}_FS_T1.nii.gz \
		-t ${subject}_Tau_PET_sm6mm_MC_MEAN_v_1st_lin_Freesurfer_0GenericAffine.mat \
		-o ${subject}_Tau_PET_sm6mm_MC_MEAN_v_1st_lin_Freesurfer.nii.gz
	fi

	#10. Do a second round of rigid transformation, with skull-stripped T1 and masking for both images
	if [ ! -f ${subject}_Tau_PET_sm6mm_MC_MEAN_v_2nd_lin_Freesurfer_0GenericAffine.mat ]; then
		antsRegistration -d 3 -m MI[$anat_dir/${subject}_FS_brain.nii.gz, ${subject}_Tau_PET_sm6mm_MC_MEAN_v_1st_lin_Freesurfer.nii.gz,1,32,Regular,0.25] \
		-c [1000x500x250x0,1e-7,5] -t Rigid[0.1] -f 8x4x2x1 -s 4x2x1x0 -u 1 -z 1 --winsorize-image-intensities [0.005, 0.995] \
		-x [$anat_dir/${subject}_FS_brain_mask.nii.gz, ${subject}_FS_brain_mask.nii.gz] \
		-o ${subject}_Tau_PET_sm6mm_MC_MEAN_v_2nd_lin_Freesurfer_ -v
	fi

	#11. Apply linear transformation for QC check
	if [ ! -f ${subject}_Tau_PET_sm6mm_MC_MEAN_v_2nd_lin_Freesurfer.nii.gz ]; then
		antsApplyTransforms -d 3 -i ${subject}_Tau_PET_sm6mm_MC_MEAN_v.nii.gz -r $anat_dir/${subject}_FS_brain.nii.gz \
		-t ${subject}_Tau_PET_sm6mm_MC_MEAN_v_2nd_lin_Freesurfer_0GenericAffine.mat \
		-t ${subject}_Tau_PET_sm6mm_MC_MEAN_v_1st_lin_Freesurfer_0GenericAffine.mat \
		-o ${subject}_Tau_PET_sm6mm_MC_MEAN_v_2nd_lin_Freesurfer.nii.gz
	fi
	
	cd $FSout
        
	#18. Extract Tau PET values for FS ROIs
	if [ ! -f $FSout/${subject}_Tau_SUVR.aparc_aseg.stats_v ]; then
	
		#Move PET image into FS space 
		if [ ! -f ${subject}_Tau_rs2_FS_v.nii.gz ]; then
			antsApplyTransforms -d 3 -i $folder/${subject}_Tau_PET_sm6mm_MC_MEAN_v.nii.gz -r $anat_dir/${subject}_FS_T1.nii.gz \
			-t $folder/${subject}_Tau_PET_sm6mm_MC_MEAN_v_2nd_lin_Freesurfer_0GenericAffine.mat \
			-t $folder/${subject}_Tau_PET_sm6mm_MC_MEAN_v_1st_lin_Freesurfer_0GenericAffine.mat \
			-o ${subject}_Tau_rs2_FS_v.nii.gz
		fi
		
		#Smooth PET in FS Space
		if [ ! -f ${subject}_Tau_rs2_FS_v_sm8mm.nii.gz ]; then
			fslmaths ${subject}_Tau_rs2_FS_v.nii.gz -kernel gauss 3.4 -fmean ${subject}_Tau_rs2_FS_v_sm8mm.nii.gz
			rm *Stage*
		fi
		
		
		#Move FS to PET Space -> for visual check of PET<->FS registration
		if [ ! -f ${subject}_FS_in_PET.nii.gz ]; then
        	antsApplyTransforms -d 3 --float 0 \
    		-i $anat_dir/${subject}_FS_T1.nii.gz \
    		-r $folder/${subject}_Tau_PET_sm6mm_MC_MEAN_v.nii.gz \
    		-n BSpline \
    		-t [$folder/${subject}_Tau_PET_sm6mm_MC_MEAN_v_1st_lin_Freesurfer_0GenericAffine.mat,1] \
    		-t [$folder/${subject}_Tau_PET_sm6mm_MC_MEAN_v_2nd_lin_Freesurfer_0GenericAffine.mat,1] \
    		-o ${subject}_FS_in_PET.nii.gz 
		fi
		
		#13. Move cereb to PET space
		if [ ! -f ${subject}_inf-cereb_ero1_FS_warp2_nsPET.nii.gz ]; then
			antsApplyTransforms -d 3 -e 0 --float 0 \
			-i ${SUIT_dir}/${subject}/${visit_code}/Inf_cereb-SUIT_FS_mask_ero1.nii.gz \
			-r $folder/${subject}_Tau_PET_sm6mm_MC_MEAN_v.nii.gz \
			-n NearestNeighbor \
			-t [$folder/${subject}_Tau_PET_sm6mm_MC_MEAN_v_1st_lin_Freesurfer_0GenericAffine.mat,1] \
    		-t [$folder/${subject}_Tau_PET_sm6mm_MC_MEAN_v_2nd_lin_Freesurfer_0GenericAffine.mat,1] \
			-o ${subject}_inf-cereb_ero1_FS_warp2_nsPET.nii.gz
		fi
	
		#Create SUVR in FS space
		if [ ! -f ${subject}_Tau_rs2_FS_v_sm8mm_SUVR.nii.gz ]; then
			fslmaths ${subject}_Tau_rs2_FS_v_sm8mm.nii.gz -div `fslstats $folder/${subject}_Tau_PET_sm6mm_MC_MEAN_v.nii.gz -k ${subject}_inf-cereb_ero1_FS_warp2_nsPET.nii.gz -M` ${subject}_Tau_rs2_FS_v_sm8mm_SUVR.nii.gz
		fi

		#Extract all FS ROIs - smoothed 8mm
		if [ ! -f ${subject}_Tau_SUVR.aparc_aseg.stats_v ]; then
			mri_segstats --seg $fs_dir/${visit_code}/sub-${subject}/mri/aparc+aseg.nii.gz \
			--ctab $FREESURFER_HOME/FreeSurferColorLUT.txt \
			--i ${subject}_Tau_rs2_FS_v_sm8mm_SUVR.nii.gz \
			--sum $FSout/${subject}_Tau_SUVR.aparc_aseg.stats_v
		fi
		
		#Copy over to cheat directory
		if [ ! -f ${FS_cheat_subdir}/aseg.stats ]; then
			echo "Copying and Renaming Stats file to ${FS_cheat_subdir}"
			cp $FSout/${subject}_Tau_SUVR.aparc_aseg.stats_v $FS_cheat_subdir/aseg.stats
		fi
		

		#Extract all FS ROIs - unsmoothed -- some protocols use the unsmoothed image - optional (we did not upload this in the previous release)
		#if [ ! -f ${subject}_Tau_SUVR_unsmoothed.aparc_aseg.stats_v ]; then
			#mri_segstats --seg $fs_dir/${visit_code}/sub-${subject}/mri/aparc+aseg.nii.gz \
			#--ctab $FREESURFER_HOME/FreeSurferColorLUT.txt \
			#--i ${subject}_Tau_rs2_FS_v.nii.gz \
			#--sum $FSout/${subject}_Tau_SUVR_unsmoothed.aparc_aseg.stats_v
		#fi
		
		#Extract all FS ROIs - unsmoothed -- some protocols use the unsmoothed image - uncomment and create dedicated directory to store this result
		#if [ ! -f ${FS_cheat_dir_unsmoothed_tau}/aseg.stats ]; then
			#FS_cheat_dir_unsmoothed_tau='/path_to_data/PPG/PPG_Data_Organized/PET/Has_Tau_derivatives/FS_SUVR_stats_unsmoothed'
			#FS_cheat_unsmoothed_subdir=${FS_cheat_dir_unsmoothed_tau}/${visit_code}/${subject}/stats
			#mkdir -p ${FS_cheat_unsmoothed_subdir}
			#echo "Copying and Renaming Stats file to ${FS_cheat_unsmoothed_subdir}"
			#cp $FSout/${subject}_Tau_SUVR_unsmoothed.aparc_aseg.stats_v $FS_cheat_unsmoothed_subdir/aseg.stats
		#fi

		
	fi
echo "Tau PET Processing Complete for" $subject "at visit code" $visit_code
else echo "Missing Tau PET for" $subject 

fi
