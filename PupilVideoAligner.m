%FRAMES = 73726;


AlignMethodUsed = 1;
fudgefactor = 117;
pupilStartconv = 3600*pupilStart(4) + 60*pupilStart(5) + pupilStart(6);
pupilEndconv = 3600*pupilEnd(4) + 60*pupilEnd(5) + pupilEnd(6);
stimStartconv = (3600*META_stimstart(:,4) + 60*META_stimstart(:,5) + META_stimstart(:,6))-pupilStartconv;
fps = (number_of_frames+fudgefactor)/(pupilEndconv-pupilStartconv);
% fps= 30.6;
stimStartFrames = stimStartconv*fps-fudgefactor/2;

%or:

% AlignMethodUsed = 2;
% 
% firstFrameStart = 349; %CHANGE
% lastFrameStart = 59371; %CHANGE
% stimStartconv = (3600*META_stimstart(:,4) + 60*META_stimstart(:,5) + META_stimstart(:,6)) - (3600*META_stimstart(1,4) + 60*META_stimstart(1,5) + META_stimstart(1,6));
% fps = (lastFrameStart-firstFrameStart)/( (3600*META_stimstart(size(META_stimstart,1),4) + 60*META_stimstart(size(META_stimstart,1),5) + META_stimstart(size(META_stimstart,1),6)) -  (3600*META_stimstart(1,4) + 60*META_stimstart(1,5) + META_stimstart(1,6)));
% stimStartFrames = stimStartconv*fps+firstFrameStart;


%or:

% AlignMethodUsed = 3;
% fps = 30.45;



AlignMethodUsed = 4;

firstFrameStart = 349; %CHANGE
lastFrameStart = 59371; %CHANGE
convFac = (lastFrameStart-firstFrameStart)/( length(stimStarts));
stimStartFrames = stimStarts*convFac+firstFrameStart;


%-----------------------------------------------------------------------
%backup diameter data and convert all NaNs to zero
diameter_data3_edited = diameter_data3;
diameter_data3_edited(isnan(diameter_data3)) = 0;

diameter_data3_edited = diameter_data3_edited.*(diameter_quality>0.5);

%bin for 3 seconds before and after each trial
timeBins = zeros(size(stimStartFrames,1),60);
timeBinsSize = zeros(size(stimStartFrames,1),60);
oneBin = fps/10; %time bins every 0.1s
for x = 2:size(stimStartFrames,1)
% for x = 2:100
    thisF = stimStartFrames(x);
    for y = 1:60
        %rounding starting and end frames of bin
        binStart = round(thisF - (3*fps+oneBin) + y*oneBin);
        binEnd = round(thisF - (3*fps) + y*oneBin);
        
        binList = nonzeros(diameter_data3_edited(binStart:binEnd));
        if size(binList,1)>0
            timeBins(x,y)=mean(binList);
        end
        timeBinsSize(x,y)=size(binList,1);
        %else it stays 0 as initialized
    end
end

%average all the non-zero time bins 3s before and after each trial
avgBins = zeros(60,1);
for i =1:60
    avgBins(i) = mean(nonzeros(timeBins(:,i)),1);
end
figure
plot(avgBins);
