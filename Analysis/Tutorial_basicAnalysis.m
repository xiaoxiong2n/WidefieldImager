% This example code demonstrates how to analyze raw imaging data by spatial
% downsampling and baseline-correction. It shows the results by plotting a
% map of stimulus-triggered activity and a trace of fluorescence change
% over all pixels.
%
% You can test this on either behavioral or mapping example data. Just
% change the variable 'fPath' to the datapath that contains the imaging
% data. The settings below are adjusted to produce an example map for
% somatosensory hindpaw stimulation, when using the dataset
% 'dataset3_tactile_hindpawMap'. It can be downloaded from the CSHL
% reposotory: http://labshare.cshl.edu/shares/library/repository/38599/
%
% For questions, contact simon.musall@gmail.com

%% construct path to data folder and give some basic info
opts.fPath = dataPath; %path to imaging data
opts.fName = 'corrFrames_1_640_540_uint16'; %name of imaging data files.
opts.stimLine = 4; %analog line that contains stimulus trigger.
opts.trigLine = [2 3]; %analog lines for blue and violet light triggers.
opts.preStim = 0.5; %pre-stimulus duration in seconds
opts.postStim = 1; %post-stimulus duration in seconds
opts.plotChans = false; %flag to show separate channels when loading data
opts.sRate = 30; %sampling rate in Hz
opts.downSample = 4; %spatial downsampling factor
opts.hemoCorrect = false; %hemodynamic correction is optional (this only works with dual-color data in datasets 1,2 and 4).
opts.fileExt = '.dat'; %type of video file. Use '.dat' for binary files (also works for .tif or .mj2 files)
opts.preProc = true; %case if data is single channel and can be loaded directly (this is only true for example dataset 3).

%% load imaging data
rawFiles = dir([opts.fPath filesep opts.fName '*']); %find data files
load([opts.fPath filesep 'frameTimes_0001.mat'], 'imgSize') %get size of imaging data
dataSize = floor(imgSize ./ opts.downSample); %adjust for downsampling
stimOn = (opts.preStim*opts.sRate); %frames before stimulus onset
baselineDur = 1 : min([opts.sRate stimOn]); %use the first second or time before stimulus as baseline

nrFrames = (opts.preStim + opts.postStim) * opts.sRate; %frames per trial

nrTrials = length(rawFiles); %nr of trials
% nrTrials = 5; %make this quicker to run by using only a part of all trials

allData = NaN(dataSize(1),dataSize(2),nrFrames, nrTrials, 'single'); %pre-allocate data array for all trials
for trialNr = 1 : nrTrials
    
    [~,~,a] = fileparts(rawFiles(trialNr).name); %get data type (should be .dat or .tif for raw. also works with .mj2 for compressed data)
    
    if opts.hemoCorrect %perform hemodynamic correction
        [bData,~,vData] = splitChannels(opts,trialNr,a);
        data = Widefield_HemoCorrect(bData,vData,baselineDur,5); %hemodynamic correction
    
    else
        
        if ~opts.preProc %skip hemodynamic correction but assuming two channels. 
            
            data = splitChannels(opts, trialNr, a); %split channels and use blue data
            
        elseif opts.preProc %pre-processed data. simply load all available data.
            
            cFile = [opts.fPath filesep 'frameTimes_' num2str(trialNr, '%04i') '.mat']; %need size of imaging data
            load(cFile, 'imgSize');
            
            cFile = [opts.fPath filesep opts.fName '_' num2str(trialNr, '%04i') opts.fileExt]; %current file to be read
            [~, data] = loadRawData(cFile, 'Frames', 'uint16', imgSize); %load imaging data

        else
            error('Could not read number of channels from filename or channelnumber is >2.'); %for this to work filenames should contain the channelnumber after a _ delimiter
        end
    end
            
    %spatially downsample imaging data
    data = arrayResize(data, 4); %this reduces resolution to ~80um / pixel
    if imgSize(end) < nrFrames
        allData(:,:,1:imgSize(end),trialNr) = data;
    else
        allData(:,:,:,trialNr) = data(:,:,1:nrFrames);
    end
    
    if rem(trialNr,floor(nrTrials / 5)) == 0
        fprintf('%d / %d files loaded\n', trialNr, nrTrials)
    end
end
clear data bData vData

if ~opts.hemoCorrect %this step is automatically done during hemodynamic correction
    
    % compute dF/F by subtracting and dividing the pre-stimulus baseline
    baselineAvg = nanmean(nanmean(allData(:,:, baselineDur, :),3), 4);
    allData = reshape(allData, dataSize(1),dataSize(2), []); %merge all frames to subtract and divide baseline
    allData = bsxfun(@minus, allData, baselineAvg); % subtract baseline
    allData = bsxfun(@rdivide, allData, baselineAvg); % divide baseline
    allData = reshape(allData, dataSize(1),dataSize(2),nrFrames,nrTrials); %shape back to initial form
    
end

%% show an example figure for stimulus triggered activity
figure

%show an activity map
colorRange = 0.03; %range of colorscale for dF/F

subplot(1,2,1);
avgMap = nanmean(nanmean(allData(:,:, stimOn + 1 : end, :),3),4); %show average activity after stimulus onset
imageScale(avgMap, colorRange); %show average activity after stimulus onset
colormap(colormap_blueblackred(256)); colorbar
title('Stimulus-triggered activity')

%show an activity trace
subplot(1,2,2); hold on;
meanTrace = squeeze(allData(105,75,:,:)); %average from an interesting pixel (this one is for hindpaw area)
% meanTrace = squeeze(nanmean(reshape(allData,[], size(allData,3), size(allData,4)),1)); %average activity over all pixels
timeTrace = ((1:nrFrames) ./ opts.sRate) - opts.preStim; %time in seconds
plotLine = stdshade(meanTrace', 0.5, 'r', timeTrace); %plot average activity
plot([0 0], plotLine.Parent.YLim, '--k'); %show stimulus onset
plot(plotLine.Parent.XLim, [0 0], '--k'); %show zero line
xlim([min(timeTrace) max(timeTrace)])
axis square; xlabel('time after stimulus (s)'); ylabel('fluorescence change (dF/F)');
title('Average change over all pixels')

%% explore average data stack
avgData = squeeze(nanmean(allData,4)); %show average over all trials
compareMovie(avgData); %use this GUI to browse the widefield data stack
