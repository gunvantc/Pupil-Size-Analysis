%Input: text file of framestamps from adrianscope rig video
%output: stimStartFrames, frame of the start of each trial

%located of the text file, and name of the text file
rd_dir = 'C:\Users\PorteraAdmin\Documents\MATLAB\Pupil Analysis\Ca Imaging Pupil Vids\dist';
fName = 'DistaskD3904272019_pts.txt';

fileID = fopen(fullfile(rd_dir,fName),'r');
allText = textscan(fileID,'%s','Delimiter','\n');
allText = allText{1,1};

fStamps = repmat(" ",size(allText,1)-3,2);
for x = 4:size(allText,1)
    thisF = allText{x,1};
    thisF2 = strsplit(char(thisF));
    if length(thisF2) == 4
        fStamps(x-3,2) = string(thisF2(2));
        fStamps(x-3,1) = string(thisF2(4)); 
    end
end

% LOAD in the mat file

coeffs = polyfit(1:size(META_RaspiCalib,2)/2, mean(cat(1,META_RaspiCalib(1:2:end),META_RaspiCalib(2:2:end))),1);
fOffsets = polyval(coeffs,1:size(META_RaspiCalib,2)/2);
hold on;
plot(mean(cat(1,META_RaspiCalib(1:2:end),META_RaspiCalib(2:2:end))));
plot(fOffsets);

fStampsD = [];
%sometimes gives a random error at the last frame stamp. if so, just check
%if the second to last frame of fStampsD has a value, and then only run the
%code below this for loop
for x=1:size(fStamps,1)
    fStampsD(x,1) = str2double(fStamps(x,1));
    ts = strsplit(fStamps(x,2),':');
    for y = 1:4
        fStampsD(x,y+1) = str2double(ts(y)); 
    end
    
end

fStampsD(:,6) = fStampsD(:,2)*3600 + fStampsD(:,3)*60 + fStampsD(:,4) + fStampsD(:,5)/10^6;

META_StimStart1(:,7) = META_StimStart1(:,4)*3600 + META_StimStart1(:,5)*60 + META_StimStart1(:,6);

stimTS = META_StimStart1(:,7) - fOffsets'; %frame Time Stamps for onset of stimulus

stimStartFrames = [];
for x = 1:length(stimTS)
    timeStamp = stimTS(x);
    tempArr = fStampsD(:,6)>stimTS(x);
    stimStartFrames(x) = find(tempArr,1,'first'); %doesn't work 100% of the time, not sure why
end
