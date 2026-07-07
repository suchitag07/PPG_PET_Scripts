#!/bin/bash

#NAME: Ioannis Pappas, Suchita Ganesan
#DATE CREATED: August 13th, 2024

#$ -N Amyloid_PET              
#$ -cwd                        
#$ -o /path_to_data/PPG/PPG_Data_Organized/PET/PET_Processing_Logs/Amyloid_output_logs/   
#$ -e /path_to_data/PPG/PPG_Data_Organized/PET/PET_Processing_Logs/Amyloid_error_logs/          

echo "HOSTNAME: $(hostname)"
set -x

#Edit the following:
visit_code=2
#############################

subject=$1 # input subject ID (from command line, if in batch use #subject="${SGE_TASK}")
echo -e "PROCESING VISIT CODE: $visit_code"

#Additional Anat Preprocessing Tools Directory if using synthstrip
Tools='/path_to_data/Tools'

#Freesurfer directory
fs_dir='/path_to_data/PPG/PPG_Data_Organized/PET/SG_Freesurfer_Outputs_v_7_1/AMYLOID'

# PET root directory
folder_o='/path_to_data/PPG/PPG_Data_Organized/PET/Has_Amyloid'

# Derivative directories
folder_process='/path_to_data/PPG/PPG_Data_Organized/PET/Has_Amyloid_derivatives/PET_subjects_process'
mkdir -p ${folder_process}
mkdir -p ${folder_process}/${subject}/${visit_code}

rois_dir='/path_to_data/PPG/PPG_Data_Organized/PET/Has_Amyloid_derivatives/rois'
mkdir -p ${rois_dir}
mkdir -p ${rois_dir}/${subject}/${visit_code}

out_='/path_to_data/PPG/PPG_Data_Organized/PET/Has_Amyloid_derivatives/PET_subjects_output'
mkdir -p ${out_}
out=${out_}/${subject}/${visit_code}
mkdir -p ${out}

SUVRout_='/path_to_data/PPG/PPG_Data_Organized/PET/Has_Amyloid_derivatives/PET_subjects_process_SUVRs'
mkdir -p ${SUVRout_}
SUVRout=${SUVRout_}/${subject}/${visit_code}
mkdir -p ${SUVRout}

#Set up variable to make subj dir access easy
folder=${folder_process}/${subject}/${visit_code}
anat_dir=${folder}

############################################################  PET <-> T1 Section ######################################################################


###################   Section to Preprocess Anatomical Data: 1) N4 Bias Correct Raw T1 2) Skull Strip T1   ###################



if [ ! -d ${folder_o}/NIFTIs/${subject}/${visit_code} ]; then
	echo "No amyloid PET for" $subject "at" $visit_code
	exit
else
	echo "Processing PET <-> T1 for:" $subject 
fi

#Inside PET PROCESS DIRECTORY
cd ${folder}

#Copy over and rename the raw T1 and PET
if [ ! -f ${subject}_T1_Raw.nii.gz ]; then
	cp ${folder_o}/NIFTIs/${subject}/${visit_code}/*T1*/*nii* ${folder_process}/${subject}/${visit_code}
	mv *T1*  ${subject}_T1_Raw.nii.gz
fi

if [ ! -f ${subject}_Amyloid_PET.nii.gz ]; then
	cp ${folder_o}/NIFTIs/${subject}/${visit_code}/*PET*/*nii* ${folder_process}/${subject}/${visit_code}
	mv *PET* ${subject}_Amyloid_PET.nii.gz
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
        -o ${subject}_T1.nii.gz 2>&1)
        
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


#3. Pass in N4 corrected T1 and get the mask + brain for it
if [ ! -f ${subject}_T1_brain.nii.gz ]; then

	mri_watershed ${folder}/${subject}_T1.nii.gz ${folder}/${subject}_T1_brain.nii.gz
	fslmaths ${folder}/${subject}_T1_brain.nii.gz -bin ${folder}/${subject}_T1_brain_mask.nii.gz
		
fi

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

if [ ! -f $rois_dir/${subject}/${visit_code}/ROIs/amyloid_composite_ROI.nii.gz ]; then
    cd /path_to_data/PPG/Scripts/PET_Latest/AMYLOID_Scripts/ROI_TEMP_PROCESSING
    mkdir ROI_AB_preproc_${subject}_${visit_code}
    cd ROI_AB_preproc_${subject}_${visit_code}/
    cp ${fs_dir}/${visit_code}/sub-${subject}/mri/aparc+aseg-in-rawavg.nii.gz .
    .././Create_ADNI_amyloid_ROIs_T1_space.sh $subject aparc+aseg-in-rawavg.nii.gz
	mv frontal_new.nii.gz APCC_new.nii.gz lat_parietal_new.nii.gz lat_temporal_new.nii.gz amyloid_composite_ROI.nii.gz $rois_dir/${subject}/${visit_code}/ROIs
	cd /path_to_data/PPG/Scripts/PET_Latest/AMYLOID_Scripts/ROI_TEMP_PROCESSING
	echo "Deleting temporary directory for ROI processing"
	rm -rf ROI_AB_preproc_${subject}_${visit_code}
fi

echo "Finished creating Predefined ROIs for Amyloid SUVR extraction for ${subject}"


############################################   Section to Pre-process PET Data  #########################################################

cd ${folder}

if [ -f $folder/${subject}_Amyloid_PET.nii.gz ]; then
	
	#3. Smooth image
	if [ ! -f $folder/${subject}_Amyloid_PET_sm6mm.nii.gz ]; then
		fslmaths $folder/${subject}_Amyloid_PET.nii.gz -kernel gauss 2.55 -fmean $folder/${subject}_Amyloid_PET_sm6mm.nii.gz
	fi

	#4. Mcflirt motion correct smoothed PET, then apply transformations to unsmoothed PET images
	if [ ! -f $folder/${subject}_Amyloid_PET_sm6mm_MC.nii.gz ]; then
		mcflirt -in $folder/${subject}_Amyloid_PET_sm6mm.nii.gz -meanvol -cost normmi -mats -plots
		applyxfm4D $folder/${subject}_Amyloid_PET.nii.gz $folder/${subject}_Amyloid_PET_sm6mm_mcf_mean_reg.nii.gz $folder/${subject}_Amyloid_PET_sm6mm_MC.nii.gz $folder/${subject}_Amyloid_PET_sm6mm_mcf.mat -fourdigit
	fi

	#5. Output motion parameters for QC
	if [ ! -f $folder/${subject}_Amyloid_PET_sm6mm_MC_fdrms.txt ]; then
		fsl_motion_outliers -i $folder/${subject}_Amyloid_PET_sm6mm_MC.nii.gz -o $folder/${subject}_Amyloid_PET_sm6mm_MC_mc-outliers.txt -s $folder/${subject}_Amyloid_PET_sm6mm_MC_fdrms.txt --fd --thresh=0.9 -v
	fi

	#6. Create output average image 
	if [ ! -f $folder/${subject}_Amyloid_PET_sm6mm_MC_MEAN.nii.gz ]; then
		fslmaths $folder/${subject}_Amyloid_PET_sm6mm_MC.nii.gz -Tmean $folder/${subject}_Amyloid_PET_sm6mm_MC_MEAN.nii.gz
	fi

	#7. If preprocessing steps worked, make a copy of the mean PET img and rename to ${subject}_Amyloid_PET_sm6mm_MC_MEAN_v.nii.gz
	if [ ! -f ${folder_process}/${subject}/${visit_code}/${subject}_Amyloid_PET_sm6mm_MC_MEAN_v.nii.gz ]; then cp $folder/${subject}_Amyloid_PET_sm6mm_MC_MEAN.nii.gz ${folder_process}/${subject}/${visit_code}/${subject}_Amyloid_PET_sm6mm_MC_MEAN_v.nii.gz; fi

	cd ${folder_process}/${subject}/${visit_code}

	#8. First round of registration of amyloid PET to T1
	if [ ! -f ${subject}_Amyloid_PET_sm6mm_MC_MEAN_v_1st_lin_T1_0GenericAffine.mat ]; then
		antsRegistration -d 3 -m MI[$anat_dir/${subject}_T1.nii.gz, ${subject}_Amyloid_PET_sm6mm_MC_MEAN_v.nii.gz,1,32,Regular,0.25] \
		-r [$anat_dir/${subject}_T1.nii.gz, ${subject}_Amyloid_PET_sm6mm_MC_MEAN_v.nii.gz,1] \
		-c [1000x500x250x0,1e-7,5] -t Rigid[0.1] -f 8x4x2x1 -s 4x2x1x0 -u 1 -z 1 --winsorize-image-intensities [0.005, 0.995] \
		-o ${subject}_Amyloid_PET_sm6mm_MC_MEAN_v_1st_lin_T1_ -v 
	fi

	#9. Apply linear transformation for QC check
	if [ ! -f ${subject}_Amyloid_PET_sm6mm_MC_MEAN_v_1st_lin_T1.nii.gz ]; then
		antsApplyTransforms -d 3 -i ${subject}_Amyloid_PET_sm6mm_MC_MEAN_v.nii.gz -r $anat_dir/${subject}_T1.nii.gz \
		-t ${subject}_Amyloid_PET_sm6mm_MC_MEAN_v_1st_lin_T1_0GenericAffine.mat \
		-o ${subject}_Amyloid_PET_sm6mm_MC_MEAN_v_1st_lin_T1.nii.gz
	fi

	#10. Do a second round of rigid transformation, with skull-stripped T1 and masking for both images
	if [ ! -f ${subject}_Amyloid_PET_sm6mm_MC_MEAN_v_2nd_lin_T1_0GenericAffine.mat ]; then
		antsRegistration -d 3 -m MI[$anat_dir/${subject}_T1_brain.nii.gz, ${subject}_Amyloid_PET_sm6mm_MC_MEAN_v_1st_lin_T1.nii.gz,1,32,Regular,0.25] \
		-c [1000x500x250x0,1e-7,5] -t Rigid[0.1] -f 8x4x2x1 -s 4x2x1x0 -u 1 -z 1 --winsorize-image-intensities [0.005, 0.995] \
		-x [$anat_dir/${subject}_T1_brain_mask.nii.gz, ${subject}_T1_brain_mask.nii.gz] \
		-o ${subject}_Amyloid_PET_sm6mm_MC_MEAN_v_2nd_lin_T1_ -v
	fi

	#11. Apply linear transformation for QC check
	if [ ! -f ${subject}_Amyloid_PET_sm6mm_MC_MEAN_v_2nd_lin_T1.nii.gz ]; then
		antsApplyTransforms -d 3 -i ${subject}_Amyloid_PET_sm6mm_MC_MEAN_v.nii.gz -r $anat_dir/${subject}_T1_brain.nii.gz \
		-t ${subject}_Amyloid_PET_sm6mm_MC_MEAN_v_2nd_lin_T1_0GenericAffine.mat \
		-t ${subject}_Amyloid_PET_sm6mm_MC_MEAN_v_1st_lin_T1_0GenericAffine.mat \
		-o ${subject}_Amyloid_PET_sm6mm_MC_MEAN_v_2nd_lin_T1.nii.gz
	fi

	

	#12. Move Mean PET to template space and smooth
	if [ ! -f ${subject}_Amyloid_PET_sm6mm_MC_MEAN_v_warp2_T1.nii.gz ];then
		antsApplyTransforms -d 3 -i ${subject}_Amyloid_PET_sm6mm_MC_MEAN_v.nii.gz -r $anat_dir/${subject}_T1.nii.gz \
		-t ${subject}_Amyloid_PET_sm6mm_MC_MEAN_v_2nd_lin_T1_0GenericAffine.mat \
		-t ${subject}_Amyloid_PET_sm6mm_MC_MEAN_v_1st_lin_T1_0GenericAffine.mat \
		-o ${subject}_Amyloid_PET_sm6mm_MC_MEAN_v_warp2_T1.nii.gz  -v
	fi

	if [ ! -f ${subject}_Amyloid_PET_sm6mm_MC_MEAN_v_warp2_T1_sm8mm.nii.gz ]; then
		fslmaths ${subject}_Amyloid_PET_sm6mm_MC_MEAN_v_warp2_T1.nii.gz -kernel gauss 3.4 -fmean ${subject}_Amyloid_PET_sm6mm_MC_MEAN_v_warp2_T1_sm8mm.nii.gz 
		
		rm *Stage*
	fi
	
	#Move T1 to PET Space 
	if [ ! -f ${subject}_T1_in_PET.nii.gz ]; then
        antsApplyTransforms -d 3 --float 0 \
    	-i $anat_dir/${subject}_T1.nii.gz \
    	-r ${subject}_Amyloid_PET_sm6mm_MC_MEAN.nii.gz \
    	-n BSpline \
    	-t [${subject}_Amyloid_PET_sm6mm_MC_MEAN_v_1st_lin_T1_0GenericAffine.mat,1] \
    	-t [${subject}_Amyloid_PET_sm6mm_MC_MEAN_v_2nd_lin_T1_0GenericAffine.mat,1] \
    	-o ${subject}_T1_in_PET.nii.gz 
	fi
	
	###########
	
	#13. Move cereb to PET space
	if [ ! -f ${subject}_cereb_whole_ero1_v_warp2_nsPET.nii.gz ]; then
		antsApplyTransforms -d 3 -e 0 --float 0 \
		-i ${fs_dir}/${visit_code}/sub-${subject}/mri/${subject}_cereb_whole_ero1.nii.gz \
		-r ${subject}_Amyloid_PET_sm6mm_MC_MEAN_v.nii.gz \
		-n NearestNeighbor \
		-t [${subject}_Amyloid_PET_sm6mm_MC_MEAN_v_1st_lin_T1_0GenericAffine.mat,1] \
		-t [${subject}_Amyloid_PET_sm6mm_MC_MEAN_v_2nd_lin_T1_0GenericAffine.mat,1] \
		-o ${subject}_cereb_whole_ero1_v_warp2_nsPET.nii.gz 
	fi
	

	#14. Create SUVR images and move to output directory
	if [ ! -f ${subject}_Amyloid_PET_sm6mm_MC_MEAN_v_warp2_T1_sm8mm_SUVR.nii.gz ]; then
		fslmaths ${subject}_Amyloid_PET_sm6mm_MC_MEAN_v_warp2_T1_sm8mm.nii.gz -div `fslstats ${subject}_Amyloid_PET_sm6mm_MC_MEAN_v.nii.gz -k ${subject}_cereb_whole_ero1_v_warp2_nsPET.nii.gz -M` ${subject}_Amyloid_PET_sm6mm_MC_MEAN_v_warp2_T1_sm8mm_SUVR.nii.gz
	fi

	if [ ! -f $out/${subject}_Amyloid_PET_sm6mm_MC_MEAN_v_warp2_T1_sm8mm_SUVR.nii.gz ]; then
		cp ${subject}_Amyloid_PET_sm6mm_MC_MEAN_v_warp2_T1_sm8mm_SUVR.nii.gz $out
	fi

	#15. Move composite ROIs to PET space and extract
	if [ ! -d $rois_dir/${subject}/${visit_code}/ROIs ]; then mkdir $rois_dir/${subject}/${visit_code}/ROIs; fi

	cd ${rois_dir}/${subject}/${visit_code}

	#17. Move ROIs into PET space 
	for img in frontal_new.nii.gz APCC_new.nii.gz lat_parietal_new.nii.gz lat_temporal_new.nii.gz amyloid_composite_ROI.nii.gz; do
		if [ ! -f ROIs/${img%.nii.gz}_v_warp2_AmyPET.nii.gz ]; then
			antsApplyTransforms -d 3 -e 0 --float 0 -i ROIs/$img -r ${folder_process}/${subject}/${visit_code}/${subject}_Amyloid_PET_sm6mm_MC_MEAN_v.nii.gz \
			-n NearestNeighbor \
			-t [${folder_process}/${subject}/${visit_code}/${subject}_Amyloid_PET_sm6mm_MC_MEAN_v_1st_lin_T1_0GenericAffine.mat,1] \
			-t [${folder_process}/${subject}/${visit_code}/${subject}_Amyloid_PET_sm6mm_MC_MEAN_v_2nd_lin_T1_0GenericAffine.mat,1] \
			-o ROIs/${img%.nii.gz}_v_warp2_AmyPET.nii.gz 
		fi
		if [ ! -f $SUVRout/${subject}_Amyloid_${img%.nii.gz}_v.txt ]; then
				echo "scale=4; `fslstats ${folder_process}/${subject}/${visit_code}/${subject}_Amyloid_PET_sm6mm_MC_MEAN_v.nii.gz -k ROIs/${img%.nii.gz}_v_warp2_AmyPET.nii.gz -M` / `fslstats ${folder_process}/${subject}/${visit_code}/${subject}_Amyloid_PET_sm6mm_MC_MEAN_v.nii.gz -k ${folder_process}/${subject}/${visit_code}/${subject}_cereb_whole_ero1_v_warp2_nsPET.nii.gz -M`" | bc >> $SUVRout/${subject}_Amyloid_${img%.nii.gz}_v.txt
		fi
	done
	
	echo "Amyloid PET data already processed for" $subject "at" $visit_code

else echo "Cannot find amyloid PET scan for" $subject "check NIFTI data directory"

fi


