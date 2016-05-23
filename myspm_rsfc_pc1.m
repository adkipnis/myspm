function EXP = myspm_rsfc_pc1 (EXP)
% computes connectivity (cor/coh) between PC1's in 3-D space
%
% EXP = myspm_rsfc_pc1 (EXP)
%
% EXP requires:
%  .subjID
%  .seedname
%  .pc1_query
%  .dir_base
%  .fwhm
%  .epi_query (requires y_t1w.nii in the same directory)
%  .subcortthres
%
%
% (cc) sgKIM, 2015. solleo@gmail.com

if ~isfield(EXP,'overwrite'), overwrite=0; else overwrite=EXP.overwrite; end;
subjID = fsss_subjID(EXP.subjID);
disp(['# seed: ',EXP.seedname]);
[~,~]=mkdir(EXP.dir_base);
if ~isfield(EXP,'subcortthres'), EXP.subcortthres=50; end
subcortthres = EXP.subcortthres;

for i=1:numel(subjID)
  subjid = subjID{i};
  disp(['# subject: ',subjid]);
  
  if ~isfield(EXP,'fast_query') && isfield(EXP,'epi_query')
    % 1. normalize residual images:
    exp1=[];
    exp1.fname_moving = fname_subj(EXP.epi_query, subjid);
    [p1,f1,e1]= fileparts_gz(exp1.fname_moving);
    exp1.fname_def   =[p1,'/y_t1w.nii'];
    exp1.vox_mm=2.3;
    Im = [p1,'/w',f1,e1];
    if ~exist(Im,'file') || overwrite
      myspm_deform(exp1);
    end
    
    % 2. find mask
    fname_mask = find_mask(EXP.dir_base, Im, subcortthres);
    
    % 3. Do masked smoothing
    [p1,f1,e1] = fileparts_gz(Im);
    sIm = [p1,'/ms',num2str(EXP.fwhm),'.',f1,e1];
    if EXP.fwhm
    if ~exist(sIm,'file') || overwrite
      disp ('# masked-smoothing..');
      maskedsmoothing(Im, fname_mask, EXP.fwhm);
    end
    else
      unix(['ln -s ',Im,' ',sIm]);
    end
  else
    sIm = fname_subj(EXP.fast_query, subjid);
  end
  
  % 4. read the pc1
  fname = fname_subj(EXP.pc1_query, subjid);
  x = load_mgh(fname);
  
  % 5. read smoothed data
  nii=load_untouch_nii(sIm);
  d=size(nii.img);
  
  % 6. compute corr or coh
  if strcmpi(EXP.rsfc, 'corr')
    [~,f1,e1]=fileparts_gz(sIm);
    fname_out = [EXP.dir_base,'/',EXP.seedname,'-corr.',f1,'.',subjid,e1];
    if ~exist(fname_out,'file') || overwrite
      y=reshape(nii.img,[],d(4))';
      R   = corr(x,y);
      R = reshape(R, d(1:3));
      nii.img=R;
      nii.hdr.dime.dim(5)=1;
      nii.hdr.dime.dim(1)=3;
      nii.hdr.dime.pixdim(5)=0;
      save_untouch_nii(nii,fname_out);
    end
    
  elseif strcmpi(EXP.rsfc, 'coh')
    [~,f1,e1]=fileparts_gz(sIm);
    fname_out = [EXP.dir_base,'/',EXP.seedname,'-coh.',f1,'.',subjid,'-allFreq',e1];
    fname_mHz = [EXP.dir_base,'/NFFT256_all_mHz.txt'];
    mask = load_untouch_nii([EXP.dir_base,'/mask.nii']);
    idx = find(~~mask.img(:)); % 11697 voxels...
    NFFT=256*2
    TR = 1.4
    
    if ~exist(fname_out,'file') || overwrite
      y=reshape(nii.img,[],d(4))';
      [~,Hz] = mscohere (x, y(:,idx(1)), [], [], NFFT, 1/TR);
      mHz=Hz*1000;
      dlmwrite(fname_mHz, mHz);
      numf = numel(mHz);
      numv = numel(idx);
      R = zeros(prod(d(1:3)), numel(Hz));
      disp('# computing coherence...');
      tic
      for v=1:numv
        u = idx(v);
        Cxy = mscohere (x, y(:,u), [], [], NFFT, 1/TR);
        R(u,:) = Cxy;
      end
      toc
      R = reshape(R, [d(1:3), numf]);
      nii.img=R;
      nii.hdr.dime.dim(5)=numf;
      nii.hdr.dime.dim(1)=3;
      nii.hdr.dime.pixdim(5)=1;
      
      disp(['> saving coherence: ',fname_out]);
      save_untouch_nii(nii,fname_out);
    end
    
    % averaging squared magnitude of coherence within a given band
    mHz = dlmread(fname_mHz);
    
    for b=1:numel(EXP.cohbands_mHz)
      idx1=find(mHz>EXP.cohbands_mHz{b}(1),1,'first');
      idx2=find(mHz<EXP.cohbands_mHz{b}(2),1,'last');
      if isfield(EXP,'band_idx')
        idx1=EXP.band_idx(b,1);
        idx2=EXP.band_idx(b,2);
      end
      EXP.actual_cohbands_mHz{b}=[round(mHz(idx1)), round(mHz(idx2))];
      %[round(mHz(idx1)), round(mHz(idx2))]
      EXP.freq_bin_num(b) = idx2-idx1+1;
      bandstr=[pad(round(mHz(idx1)),3),'-',pad(round(mHz(idx2)),3),'mHz'];
      fname_fc_band = [EXP.dir_base,'/',EXP.seedname,'-coh.',f1,'.',subjid,'.',bandstr,e1];
      
      if ~exist(fname_fc_band,'file')
        numf = numel(mHz);
        nii = load_untouch_nii(fname_out);
        R = reshape(nii.img, [], numf)';
        R = mean(R([idx1:idx2],:));
        R = reshape(R, d(1:3));
        nii.img=R;
        nii.hdr.dime.dim(5)=1;
        nii.hdr.dime.dim(1)=3;
        nii.hdr.dime.pixdim(5)=0;
        save_untouch_nii(nii,fname_fc_band);
      end
    end
  end
end
end


function fname_mask = find_mask(dir1,fname1,subcortthres)

% find a good mask for subcortical structures:
fname_mask=[dir1,'/mask.nii'];

if ~exist(fname_mask,'file')
  thres = num2str(subcortthres);
  fname_ho=([getenv('FSLDIR'), ...
    '/data/atlases/HarvardOxford/HarvardOxford-sub-maxprob-thr',thres,'-2mm.nii.gz']);
  fname_myatlas=['/tmp/HarvardOxford-sub-maxprob-thr',thres,'-2mm.nii'];
  unix(['mri_convert ',fname_ho,' ',fname_myatlas]);
  nii = load_untouch_nii(fname_myatlas);
  % <label index="0" x="58" y="37" z="50">Left Cerebral White Matter</label>
  % <label index="1" x="70" y="63" z="35">Left Cerebral Cortex </label>
  % <label index="2" x="57" y="40" z="41">Left Lateral Ventrical</label>
  % <label index="3" x="51" y="51" z="39">Left Thalamus</label>
  % <label index="4" x="51" y="71" z="38">Left Caudate</label>
  % <label index="5" x="56" y="67" z="34">Left Putamen</label>
  % <label index="6" x="54" y="62" z="35">Left Pallidum</label>
  % <label index="7" x="44" y="49" z="18">Brain-Stem</label>
  % <label index="8" x="59" y="54" z="27">Left Hippocampus</label>
  % <label index="9" x="57" y="61" z="27">Left Amygdala</label>
  % <label index="10" x="50" y="70" z="33">Left Accumbens</label>
  % <label index="11" x="29" y="38" z="51">Right Cerebral White Matter</label>
  % <label index="12" x="25" y="42" z="61">Right Cerebral Cortex </label>
  % <label index="13" x="35" y="45" z="44">Right Lateral Ventricle</label>
  % <label index="14" x="38" y="51" z="39">Right Thalamus</label>
  % <label index="15" x="39" y="72" z="37">Right Caudate</label>
  % <label index="16" x="34" y="68" z="34">Right Putamen</label>
  % <label index="17" x="35" y="61" z="35">Right Pallidum</label>
  % <label index="18" x="31" y="57" z="25">Right Hippocampus</label>
  % <label index="19" x="32" y="63" z="25">Right Amygdala</label>
  % <label index="20" x="40" y="69" z="32">Right Accumbens</label>
  % cortex: 1,2,12,13
  % ventricle: 3,14
  nii.img(ismember(nii.img,[1,2,3,12,13,14]))=0;
  nii.img=~~nii.img;
  save_untouch_nii(nii, fname_mask);
  unix(['mri_convert --like ',fname1,' ',fname_mask,' ',fname_mask]);
  unix(['fslmaths ',fname_mask,' -bin ',fname_mask]);
end
end