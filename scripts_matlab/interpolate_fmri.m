function [ output ] = interpolate_fmri( volname, outvolname, QC_name, censor_type )
%
% INTERPOLATE_FMRI:  This script reads in fMRI 4D dataset, and "censor" files created 
% by the DIAGNOSTIC_FMRI_PCA.m script. It removes suggested outliers, then replaces 
% them with an interpolated value, based on remaining data. The resulting data should be 
% less sensitive to outlier "spikes". This can be done on whole volume, or slice-by-slice basis.
%
% Syntax:
%           interpolate_fmri( volname, outvolname, QC_name, censor_type )
% Input:
%           volname     = string, giving path/name of fMRI data (NIFTI or ANALYZE format)
%           outvolname  = string, giving path/name of output, interpolated fMRI data
%           QC_name     = string, giving path/name of QC structure,
%                         containing 'censor' information (produced by DIAGNOSTIC_FMRI_PCA step)
%
%          censor_type  = string, specifying how we choose outliers to remove. Options include:
%
%                     'motion'       : outlier in motion parameter estimates (MPEs)
%                     'volume'       : outlier in full-volume fMRI data
%                     'volume+motion': outlier in both full-volume fMRI and MPEs
%                     'slice'        : outlier in individual fMRI axial slices
%                     'slice+motion' : outlier in both fMRI slice and MPEs
%
% Output:
%          -creates a new fMRI data volume, with name "outvolname", where
%           outlier scans have been removed and interpolated
%
% ------------------------------------------------------------------------%
% Author: Nathan Churchill, University of Toronto
%  email: nathan.churchill@rotman.baycrest.on.ca
% ------------------------------------------------------------------------%
% version history: May 5 2013
% ------------------------------------------------------------------------%
% ------------------------------------------------------------------------%
% Authors: Nathan Churchill, University of Toronto
%          email: nathan.churchill@rotman.baycrest.on.ca
%          Babak Afshin-Pour, Rotman reseach institute
%          email: bafshinpour@research.baycrest.org
% ------------------------------------------------------------------------%
% CODE_VERSION = '$Revision: 158 $';
% CODE_DATE    = '$Date: 2014-12-02 18:11:11 -0500 (Tue, 02 Dec 2014) $';
% ------------------------------------------------------------------------%


% load output .mat file, created as output in DIAGNOSTIC_FMRI_PCA.m
load(QC_name);
% determine what criterion is used to choose outliers
% X_cens = the binary design matrix/vector, where 1=non-outlier, 0=significant outlier
% byslice= flag specifying 0=replace whole brain volumes that are outliers, or
%                          1=replace individual slices that are outliers
if    ( strcmp(censor_type, 'motion' ) )        X_cens = output.censor_mot;    byslice=0;
elseif( strcmp(censor_type, 'volume' ) )        X_cens = output.censor_vol;    byslice=0;
elseif( strcmp(censor_type, 'slice' ) )         X_cens = output.censor_slc;    byslice=1;
elseif( strcmp(censor_type, 'volume+motion' ) ) X_cens = output.censor_volmot; byslice=0;
elseif( strcmp(censor_type, 'slice+motion' ) )  X_cens = output.censor_slcmot; byslice=1;
else
    disp('ERROR: censoring format not recognized!');
    return;
end

% load fMRI NIFTI-format data into MatLab
VV = load_untouch_nii(volname);
VV.img = double(VV.img); %% format as double, for compatibility

%% NOW BEGIN INTERPOLATION

if( byslice==0 ) % If we are replacing whole brain volumes...

    % if there are no outliers (nothing to interpolate)...
    if( isempty(find(X_cens==0,1,'first')) )

        disp('No outlier points to remove.');
        % just re-save the input volume
        save_untouch_nii(VV,outvolname);
        
    else % if there are outliers...
        
        disp('Removing outliers.');
        % get matrix dimensions, and list of timepoints
        [Nx Ny Nz Nt] = size(VV.img);
        TimeList      = 1:Nt;
        
        % Extra step for outliers at beginning/end of the run, to avoid extrapolation
        %
        idx  = find(X_cens>0); % index uncensored points
        %
        % if point 1=outlier, make it same as first non-outlier
        if( X_cens(1) == 0 ) 
            X_cens(1)  = 1;
            VV.img(:,:,:,1)  = VV.img(:,:,:,idx(1)  );
        end
        % if endpoint=outlier, make it same as last non-outlier
        if( X_cens(Nt)== 0 )
            X_cens(Nt) = 1;
            VV.img(:,:,:,Nt) = VV.img(:,:,:,idx(end));
        end
        
        for( z=1:Nz ) % for each slice...
            %
            % take slice from 4D fMRI volumes; convert to vox x time matrix
            slcmat = reshape( VV.img(:,:,z,:), [],Nt );
            % get list of non-outlier timepoints, and image vectors
            subTimeList = TimeList(X_cens>0);
            submat     = slcmat(:,X_cens>0)';
            % interpolation -> reconstruct the full data matrix for all timepoints in (TimeList), 
            % based on the non-outlier input data (subTimeList, subvolmat)
            interpmat = interp1( subTimeList, submat, TimeList,'cubic' );
            % flip the volumes, so that it is (voxels x time)
            interpmat = interpmat';
            %
            VV.img(:,:,z,:) = reshape( interpmat, Nx,Ny,1,Nt );
        end

        % save the output results
        save_untouch_nii(VV,outvolname);   
    end
%%
elseif( byslice==1 ) % If we replace individual outlier slices

    % if there are no outliers (nothing to interpolate)...
    if( isempty(find(X_cens(:)==0,1,'first')) )

        disp('No outlier points to remove.');
        % just re-save the input volume
        save_untouch_nii(VV,outvolname);
        
    else % if there are outliers...
        
        disp('Removing outliers.');
        % get matrix dimensions, and list of timepoints
        [Nx Ny Nz Nt] = size(VV.img);
        TimeList      = 1:Nt;
        
        for( z=1:Nz ) % for each slice...
            
            % get the 'censor' vector corresponding to this slice
            X_slcCens = X_cens(:,z);
            % IF there are outliers in (X_slcCens), THEN we do slice interpolation
            if( ~isempty(find(X_slcCens==0,1,'first')) )
            
                % Extra step for outliers at beginning/end of the run, to avoid extrapolation
                %
                idx  = find(X_slcCens>0); % index uncensored points
                %
                % if point 1=outlier, make it same as first non-outlier
                if( X_slcCens(1) == 0 ) 
                    X_slcCens(1)  = 1;
                    VV.img(:,:,z,1)  = VV.img(:,:,z,idx(1)  );
                end
                % if endpoint=outlier, make it same as last non-outlier
                if( X_slcCens(Nt)== 0 )
                    X_slcCens(Nt) = 1;
                    VV.img(:,:,z,Nt) = VV.img(:,:,z,idx(end));
                end
                %
                % take slice from 4D fMRI volumes; convert to vox x time matrix
                slcmat = reshape( VV.img(:,:,z,:), [],Nt );
                % get list of non-outlier timepoints, and image vectors
                subTimeList = TimeList(X_slcCens>0);
                submat     = slcmat(:,X_slcCens>0)';
                % interpolation -> reconstruct the full data matrix for all timepoints in (TimeList), 
                % based on the non-outlier input data (subTimeList, subvolmat)
                interpmat = interp1( subTimeList, submat, TimeList,'cubic' );
                % flip the volumes, so that it is (voxels x time)
                interpmat = interpmat';
                %
                VV.img(:,:,z,:) = reshape( interpmat, Nx,Ny,1,Nt );            
            end
        end

        % save the output results
        save_untouch_nii(VV,outvolname);   
    end
end
