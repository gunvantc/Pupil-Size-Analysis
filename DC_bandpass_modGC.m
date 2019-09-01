function [filter_video, noise_initial, noise_end] = DC_bandpass_modGC(video,cutoff_low,cutoff_high,confidence,save_row,name_rows,compression,rate,pass_type,filter_order,dispGraphs)
%Bandpass filter for videos
%
%filter_video is the output filtered video
%
%video is a video matrix
%
%cuttoff_low is the low end cutoff (in Hz) of where you want the filter
%   applied.
%
%cutoff_high is the high end cutoff (in Hz) of where you want the filter
%   applied. This value is not used if doing a low-pass filter.
%
%confidence = percent confidence of low pass filter (for example, 0.95).
%   Intended for use in automatic detection, but CURRENTLY UNUSED
%
%save_row is a toggle for whether or not a video of just the averaged rows
%   saved. 0=don't save. 1=save.
%
%name_rows is the string name of the video to be saved
%
%compression is the compression type used in the saved videos. 'lzw' recommended for
%   lossless compression, or 'none' for no compression
%
%rate is the framerate of the acquired video, in Hz (for example, 15.9).
%
%pass_type is the type of pass used. 'low' for a lowpass filter, 'stop' for
%	a bandstop filter.
%
%filter_order is the order (magnitude, or how sharply the filter is
%   applied) of the filter. Typical values are 3-5.

%dispGraphs: 1=display graphs before/after filtering; 0=don't display
%graphs


%-------Detect video-wide artifacts-------

video=double(video);

%XXXXXXX------Collapse video for row-based detection of noise------XXX
    mean_rows=mean(video,2);
    %Save video file, count as 20% of progress

    if save_row==1
        imwrite(mean_rows(:,:,1),[name_rows '_rows'],'tiff','Compression',compression,'WriteMode','overwrite');
        for imagedex = 2:size(video,3); %start at frame two and append to first image
            imwrite(mean_rows(:,:,imagedex),[name_rows '_rows'],'tiff','Compression',compression,'WriteMode','append');
        end
    end


%b_vector=zeros(size(video,3))+1;
% b_vector=1;


L=size(video,3);
Fs=rate;
T=1/Fs;
t=(0:L-1)*T;
cutoff_low_position=round(cutoff_low*L/Fs);
cutoff_high_position=round(cutoff_high*L/Fs);

mean_rows=squeeze(mean_rows);

f = Fs*(0:(L/2))/L;
P1=zeros(size(mean_rows,1),size(f,2));
Y=(fft(mean_rows,L,2));
fft_peaks=zeros(size(Y,1),1);

for i=1:size(Y,1)
    P2 = abs(Y(i,:)/L);
    P1(i,:) = P2(1:L/2+1);
    P1(i,2:end-1) = 2*P1(i,2:end-1);
    %Find max P for given values of f
    [~,fft_peaks(i)]=max(P1(i,(cutoff_low_position:cutoff_high_position)));
end

if dispGraphs == 1
    %Plot mean FFT for all rows
    figure
    gcf;
    plot(f,mean(P1,1))
    title('Mean Single-Sided Amplitude Spectrum of X(t) - Before')
    xlabel('f (Hz)')
    ylabel('|P1(f)|')
    drawnow;
end

noise_initial = mean(P1,1);

fft_peaks=fft_peaks+cutoff_low_position-1;

stop_low_hz=round(quantile(fft_peaks,(1-confidence)/2));
stop_high_hz=round(quantile(fft_peaks,1-(1-confidence)/2));

filter_cutoff=[f(stop_low_hz) f(stop_high_hz)]; %extract frequency

%normalize frequency
filter_cutoff_norm=filter_cutoff/(Fs/2);



%-----Auto-detect cut-off for filter------ %Doesn't work yet


% for i=1:size(video,1)
%     for j=1:size(video,2)
%         fft_video(i,j,:)=fftfilt(b_vector,video(i,j,:));
%     end
% end

%Find max in freq domain
%peaks=zeros(size(video,1),size(video,2));
% 
% 
% peaks=fft(video(256,:,:),2100,3); %2100=video length, choose middle row for horizontal filter
% 
% [~,peaks]=max(peaks(:,:,2:end),[],3); %skip the first, very low freq noise
% 
% % for i=1:size(video,1)
% %     parfor j=1:size(video,2)
% %         [~,peaks(i,j)]=max(fft(video(i,j,:)));
% %     end
% % end
% 
% %Find Cut-off confidence (95%, for example)
% peaks=sort(peaks,'ascend');
% 
% %Find limit for filter
% filter_cutoff=quantile(peaks,1-confidence); %Gets a low value to filter below

%Design low-pass filter
%[b_filt,a_filt]=butter(3,filter_cutoff_norm(1),'low');

if strcmp(pass_type,'stop')==1
    [b_filt,a_filt]=butter(filter_order,[cutoff_low/(Fs/2) cutoff_high/(Fs/2)],'stop'); 
elseif strcmp(pass_type,'low')==1
    [b_filt,a_filt]=butter(filter_order,cutoff_low/(Fs/2),'low');
elseif strcmp(pass_type,'high')==1
    [b_filt,a_filt]=butter(filter_order,cutoff_high/(Fs/2),'high');
end


disp('    Starting frame filtering...');
time1 = clock;
%Apply filter
for i=1:size(video,1)
    parfor j=1:size(video,2)
        filter_video(i,j,:)=filtfilt(b_filt,a_filt,video(i,j,:));
    end
    if mod(i,100)==0
        disp(['     ' num2str(i)]);
    end
end
time2 = clock;
% timeTaken2 = time2(4)*3600+time2(5)*60+time2(6)-time1(4)*3600-time1(5)*60-time1(6)

disp('    Finished filtering!');

clearvars video
%===================Plot filtered video FFT=========================
L=size(filter_video,3);
Fs=rate;
T=1/Fs;
t=(0:L-1)*T;
cutoff_low_position=round(cutoff_low*L/Fs);
cutoff_high_position=round(cutoff_high*L/Fs);

mean_rows=mean(filter_video,2);
mean_rows=squeeze(mean_rows);

% Y=zeros(size(mean_rows,1));
% P2=zeros(size(mean_rows,1));
f = Fs*(0:(L/2))/L;
P1=zeros(size(mean_rows,1),size(f,2));
Y=(fft(mean_rows,L,2));
fft_peaks=zeros(size(Y,1),1);

for i=1:size(Y,1)
    P2 = abs(Y(i,:)/L);
    P1(i,:) = P2(1:L/2+1);
    P1(i,2:end-1) = 2*P1(i,2:end-1);
    %Find max P for given values of f
    [~,fft_peaks(i)]=max(P1(i,(cutoff_low_position:cutoff_high_position)));
end

if dispGraphs == 1
    %Plot mean FFT for all rows
    figure
    gcf;
    plot(f,mean(P1,1))
    title('Mean Single-Sided Amplitude Spectrum of X(t) - Filtered')
    xlabel('f (Hz)')
    ylabel('|P1(f)|')
end

noise_end = mean(P1,1);

%==================================================================

%normalize values before saving
scale_video_black=min(min(min(filter_video)));
filter_video=filter_video-scale_video_black;

scale_video_max=max(max(max(filter_video)));
filter_video=filter_video/scale_video_max;
% 
% imwrite(filter_video(:,:,1),name_rows,'tiff','Compression',compression,'WriteMode','overwrite');
% for imagedex = 2:size(video,3); %start at frame two and append to first image
%     imwrite(filter_video(:,:,imagedex),name_rows,'tiff','Compression',compression,'WriteMode','append');
% end  

end 

