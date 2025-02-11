% demo file for applying the NoRMCorre motion correction algorithm on 
% 1-photon widefield imaging data
% Example file is provided from the miniscope project page
% www.miniscope.org

clear;
gcp;

% file initialization
foldername = '';
filetype = 'avi';   % type of files to be processe - types currently supported .tif/.tiff, .h5/.hdf5, .raw, .avi, and .mat files
files = dir(['*vid_neur*.',filetype]);   % list of filenames (will search all subdirectories)
FOV = size(read_file(files(1).name,1,1));
numFiles = length(files);

output_type = 'tiff';                               % format to save registered files

non_rigid = false;                                 % flag for non-rigid motion correction
if non_rigid; append = '_nr'; else; append = '_rig'; end        % use this to save motion corrected files

options_mc = NoRMCorreSetParms('d1',FOV(1),'d2',FOV(2),'grid_size',[128,128],'init_batch',200,...
                'overlap_pre',32,'mot_uf',4,'bin_width',200,'max_shift',24,'max_dev',8,'us_fac',50,...
                'output_type',output_type);

template = [];
col_shift = [];
            
for i = 1:numFiles            
    
    % load next file
    disp('loading data...')
    fullname = files(i).name;
    [folder_name,file_name,ext] = fileparts(fullname);
    output_filename = fullfile(folder_name,[file_name,append,'.',output_type])
    
    Yf = read_file(fullname);
    Yf = single(Yf);
    [d1,d2,T] = size(Yf);
    
    disp('loaded.')
    
    % apply high pass spatial filtering
    disp('applying high pass spatial filtering...')
    gSig = 7;
    gSiz = 3*gSig;
    psf = fspecial('gaussian', round(2*gSiz), gSig);
    ind_nonzero = (psf(:)>=max(psf(:,1)));
    psf = psf-mean(psf(ind_nonzero));
    psf(~ind_nonzero) = 0;   % only use pixels within the center disk
    %Y = imfilter(Yf,psf,'same');
    %bound = 2*ceil(gSiz/2);
    Y = imfilter(Yf,psf,'symmetric');
    bound = 0;
    disp('done.')
    
    % apply rigid motion correction
    disp('starting motion correction...')   
         
%     % exclude boundaries due to high pss filtering effects
%     options_r = NoRMCorreSetParms('d1',d1-bound,'d2',d2-bound,'bin_width',200,'max_shift',20,'iter',1,'correct_bidir',false);
    
    % register using the high pass filtered data and apply shifts to original data
    %tic; [M1,shifts1,template1] = normcorre_batch(Y(bound/2+1:end-bound/2,bound/2+1:end-bound/2,:),options_r); toc % register filtered data
    options_mc = NoRMCorreSetParms(options_mc,'output_filename',output_filename,'h5_filename','','tiff_filename',''); % update output file name
    tic; 
    [M,shifts,template,options_mc,col_shift] = normcorre_batch(Y(bound/2+1:end-bound/2,bound/2+1:end-bound/2,:),options_mc, template); 
    toc % register filtered data
    % exclude boundaries due to high pass filtering effects
    tic; 
    Mr = apply_shifts(Yf,shifts,options_mc,bound/2,bound/2); 
    toc % apply shifts to full dataset
    
    whos Mr
    
    make_avi = true; % save a movie
    if make_avi
        disp('writing results to disk...')
        Mr = uint8(Mr);
        vidObj = VideoWriter('allCatReg.avi','Grayscale AVI');
        set(vidObj,'FrameRate',30);
        open (vidObj);
        writeVideo(vidObj,Mr);
        close (vidObj);
        disp('done.')
    end
 
end


disp('all done.')


