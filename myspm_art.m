function EXP = myspm_art(EXP)
% EXP = myspm_art(EXP)
%
% performs ART to find outliers (Z>3.0, motion>0.6mm)
%
% EXP requires:
%  .global_threshold
%  .motion_threshold
%  .subjID
%  .dir_base
%  .name_epi
%
% (cc) 2015, sgKIM.  solleo@gmail.com  https://ggooo.wordpress.com

global overwrite; if isempty(overwrite), overwrite=0; end
output_suffix='';

%%%%%%%%%%%% ART PARAMETERS (edit to desired values) %%%%%%%%%%%%
global_mean=1;                % global mean type (1: Standard 2: User-defined Mask)
motion_file_type=0;           % motion file type (0: SPM .txt file 1: FSL .par file 2:Siemens .txt file)
if ~isfield(EXP,'global_threshold')
  global_threshold=3.0;         % threshold for outlier detection based on global signal
else
  global_threshold=EXP.global_threshold;
  %   output_suffix=[output_suffix 'z',num2str(global_threshold,1)];
end
if ~isfield(EXP,'motion_threshold')
  motion_threshold=0.5;         % threshold for outlier detection based on motion estimates
else
  motion_threshold=EXP.motion_threshold;
  %   output_suffix=[output_suffix 'm',num2str(motion_threshold,1)];
end
use_diff_motion=1;            % 1: uses scan-to-scan motion to determine outliers; 0: uses absolute motion
use_diff_global=1;            % 1: uses scan-to-scan global signal change to determine outliers; 0: uses absolute global signal values
use_norms=1;                  % 1: uses composite motion measure (largest voxel movement) to determine outliers; 0: uses raw motion measures (translation/rotation parameters)
mask_file=[];                 % set to user-defined mask file(s) for global signal estimation (if global_mean is set to 2)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

path0=pwd;
subjID = fsss_subjID(EXP.subjID);
output_suffix=sprintf('_%0.1fstd_%0.1fmm', global_threshold, motion_threshold);
numSubj=numel(subjID);
numOut=zeros(1,numSubj);
for i=1:numSubj
  subjid = subjID{i};
  path1=fullfile(EXP.dir_base,subjid);
  [~,name1,~]=fileparts(EXP.name_epi);
  
  cd(path1);
  EXP.fname_epi = fullfile(path1, EXP.name_epi);
  if isfield(EXP,'name_rp')
    EXP.fname_rp = fullfile(path1, EXP.name_rp);
  else
    EXP.fname_rp = fullfile(path1, ['rp_',name1(2:end),'.txt']);
  end
  
  fname_art=[path1,'/art_regression_outliers_',name1,output_suffix,'.mat'];
  
  if ~exist(fname_art,'file') || ~~overwrite
    fname_cfg = fullfile(EXP.dir_base, subjid, 'art_cfg.txt');
    fid = fopen(fname_cfg,'w');
    fprintf(fid,'# Automatic script generated by %s\n',mfilename);
    fprintf(fid,'# Users can edit this file and use\n');
    fprintf(fid,'#   art(''sess_file'',''%s'');\n',fname_cfg);
    fprintf(fid,'# to launch art using this configuration\n');
    
    fprintf(fid,'sessions: %d\n',1);
    fprintf(fid,'global_mean: %d\n',global_mean);
    fprintf(fid,'global_threshold: %f\n',global_threshold);
    fprintf(fid,'motion_threshold: %f\n',motion_threshold);
    fprintf(fid,'motion_file_type: %d\n',motion_file_type);
    fprintf(fid,'motion_fname_from_image_fname: 1\n');
    fprintf(fid,'use_diff_motion: %d\n',use_diff_motion);
    fprintf(fid,'use_diff_global: %d\n',use_diff_global);
    fprintf(fid,'use_norms: %d\n',use_norms);
    fprintf(fid,'output_dir: %s\n',path1);
    if ~isempty(mask_file),fprintf(fid,'mask_file: %s\n',deblank(mask_file(n1,:)));end
    fprintf(fid,'end\n');
    
    fprintf(fid,'session 1 image %s\n', EXP.fname_epi);
    fprintf(fid,'session 1 motion %s\n', EXP.fname_rp);
    
    fprintf(fid,'end\n');
    fclose(fid);
    
    art('sess_file',fname_cfg);
    
    % rename
    movefile([path1,'/art_regression_outliers_',name1,'.mat'], ...
      [path1,'/art_regression_outliers_',name1,output_suffix,'.mat']);
    movefile([path1,'/art_regression_outliers_and_movement_',name1,'.mat'], ...
      [path1,'/art_regression_outliers_and_movement_',name1,output_suffix,'.mat']);
    
    
    % copy figures
    if isfield(EXP,'dir_figure')
      screen2png([path1,'/art_plot',output_suffix,'.png'],72);
      
      [~,~]=mkdir(EXP.dir_figure);
      copyfile([path1,'/art_plot',output_suffix,'.png'], ...
        [EXP.dir_figure,'/art_plot',output_suffix,'_',subjid,'.png']);
    end
    close(gcf);
    
  end
  % count outliers
  load(fname_art);
  numOut(i)=size(R,2);
end

disp('## Number of outliers ##');
for i=1:numSubj
  disp([subjID{i},': ',num2str(numOut(i))]);
end

if isfield(EXP,'dir_figure')
  hf=figure;
  barh(numOut);
  P = spm_vol(EXP.fname_epi);
  xlim([0 numel(P)]); xlabel('# of scans'); ylabel('Subj#');
  set(gca,'ytick',[1:numSubj],'yticklabel',subjID,'ydir','rev')
  legend('Outliers');
  title(['ART-detected outliers with threshold of ',output_suffix(2:end)],'interp','none')
  screen2png([EXP.dir_figure,'/art_outliers',output_suffix,'.png']);
end
cd(path0);
end