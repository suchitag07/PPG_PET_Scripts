function SG_process_SUIT_v2(subject_in, visit_code)
    % Script for processing SUIT cerebellar atlas
    Tau_Data_Path = '/path_to_data/PPG/PPG_Data_Organized/PET/';
    
    % Define the path to the T1 NIfTI file within the *T1* directory
    T1_File = dir(fullfile(Tau_Data_Path, 'Has_Tau', 'NIFTIs', subject_in, sprintf('%d', visit_code), '*T1*', '*.nii.gz')); %Location of T1s
    fprintf('Checking path: %s\n', fullfile(Tau_Data_Path, 'Has_Tau', 'NIFTIs', subject_in, sprintf('%d', visit_code)));

    homedir = '/path_to_data/PPG/Scripts/PET_Latest/TAU_Scripts'; %Location of script

    antspath = '/path_to/ants-Linux-centos6_x86_64-v2.3.4/';
    cd(homedir);

    suit_dir = fullfile(Tau_Data_Path, 'Has_Tau_derivatives', 'Tau_SUIT');
    if ~exist(suit_dir, 'dir')
        mkdir(suit_dir);
    end

    % Create subject-specific directory
    subject_dir = fullfile(suit_dir, subject_in);
    if ~exist(subject_dir, 'dir')
        mkdir(subject_dir);
    end

    % Create visit code directory
    visit_dir = fullfile(subject_dir, sprintf('%d', visit_code));
    if ~exist(visit_dir, 'dir')
        mkdir(visit_dir);
    end

    addpath('/path_to_data/Tools/spm12/toolbox/suit');
    addpath(genpath('/path_to_data/Tools/spm12'));
    spm_get_defaults;

    subject = subject_in;
    
    % Check if the warped file already exists
    if ~exist(fullfile(visit_dir, sprintf('Cereb-SUIT_warp_2_%s_native_T1.nii', subject)), 'file')
        fprintf('\nWorking on subject %s, visit %d\n', subject, visit_code);

    	timestamp = datestr(now, 'yyyy-mm-dd_HH-MM-SS');  
    	log_filename = sprintf('SG_process_SUIT_v2_log_%s.txt', timestamp);

    	% Log directory inside the visit directory
    	log_directory = fullfile(visit_dir, 'Processing_Logs_SUIT');

    	if ~exist(log_directory, 'dir')
        	mkdir(log_directory);
    	end

    	log_filepath = fullfile(log_directory, log_filename);

    	% Open diary to the log file
    	diary(log_filepath);
    	diary on;

    	fprintf('\nLog started: %s\n', datestr(now));

    	fprintf('\nPath to input T1 file: %s\n', fullfile(T1_File(1).folder, T1_File(1).name));
    	t1_filename = T1_File(1).name;
    	parts = strsplit(t1_filename, '_');
    
    	subject_id = parts{1};       % Subject ID
		modality = parts{2};         % Modality
		date = parts{3};             % Date
		image_id = strrep(parts{4}, '.nii.gz', ''); % Removes nii.gz ext

		% Display the extracted information
		fprintf('\nPROCESSING PPG PET COHORT\n');
		fprintf('Subject ID: %s\n', subject_id);
		fprintf('Date: %s\n', date);
		fprintf('Image ID: %s\n', image_id);
    
        cd(visit_dir);  % Change to visit directory
        
        % Find and copy the T1 NIfTI file
        t1_files = T1_File;  
        if ~isempty(t1_files)
            t1_file_path = fullfile(t1_files(1).folder, t1_files(1).name);
            copyfile(t1_file_path, fullfile(visit_dir, sprintf('%s_T1.nii.gz', subject)));
            cd(visit_dir);
            gunzip(fullfile(visit_dir, sprintf('%s_T1.nii.gz', subject)));
            delete(fullfile(visit_dir, sprintf('%s_T1.nii.gz', subject)));
        else
            fprintf('No T1 file found for subject %s, visit %d\n', subject, visit_code);
            diary off;  
            return;  % Exit the function if no T1 file is found
        end
        
        cd(visit_dir); 
        
        % STEP 1: ISOLATE SEG 
        Source = {fullfile(visit_dir, sprintf('%s_T1.nii', subject))};  % Changed to visit_dir
        seg = fullfile(visit_dir, sprintf('c_%s_T1_pcereb.nii', subject));  % T1 space mask -> output of seg step
  
        if ~exist(seg, 'file')
            suit_isolate_seg(Source);
        end

        % STEP 2: NORMALIZATION
        norm_file = fullfile(visit_dir, sprintf('mc_%s_T1.nii', subject)); % <- resliced image
        
        if ~exist(norm_file, 'file')
            suit_normalize(sprintf('c_%s_T1.nii', subject) , 'mask', sprintf('c_%s_T1_pcereb.nii', subject)); 
        end
        
        img = niftiread(norm_file); % Read the resliced image file
		if any(isnan(img(:))) || max(img(:)) <= 1
    		fprintf('ERROR: The resliced image (%s) contains NaN values.\n', norm_file);
    		diary off;
    		return;  % Exit the function if the image is invalid
		else
    		fprintf('\nRESLICED IMAGE (%s) IS VALID.\n', norm_file); % Confirm the image is valid
		end
                
        mask_file = fullfile(visit_dir, sprintf('c_%s_T1_pcereb.nii', subject)); % T1 space mask -> output of seg step
        mat_file = fullfile(visit_dir, sprintf('mc_%s_T1_snc.mat', subject)); % Deformation field -> output of normalization step
        
        % STEP 3: RESLICE 
        suit_reslice(norm_file, mat_file, 'mask', mask_file); 
        
        % STEP 4: RESLICE INVERSE 
        atlas_dir = '/path_to_data/Tools/spm12/toolbox/suit/atlas/'
        SUIT_atlas = fullfile(atlas_dir, 'Cerebellum-SUIT.nii');
        prefix = 'iw_';
        suit_reslice_inv(SUIT_atlas, mat_file, 'prefix', prefix); % output is iw_Cerebellum-SUIT.nii (suit atlas in 'interim space' (close to T1))

        % STEP 5: ANTS -> single call 
        command_transform = sprintf('%s/antsApplyTransforms -d 3 -i %s/iw_Cerebellum-SUIT.nii -r %s/%s_T1.nii -n NearestNeighbor -o %s/Cereb-SUIT_warp_2_%s_native_T1.nii', ...
            antspath, visit_dir, visit_dir, subject, visit_dir, subject);  % Ensure paths are from visit_dir
        fprintf('\nExecuting command: %s\n', command_transform);
        [status, reorient] = system(command_transform);

        diary off;
    else
	    fprintf('\nFINAL OUTPUT ALREADY EXISTS:\n%s\n', fullfile(visit_dir, sprintf('Cereb-SUIT_warp_2_%s_native_T1.nii', subject)));
    end
end
