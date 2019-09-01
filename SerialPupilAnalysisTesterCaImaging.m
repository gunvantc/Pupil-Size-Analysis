RD_DIR = 'C:\Users\PorteraAdmin\Documents\MATLAB\Pupil Analysis\Ca Imaging Pupil Vids\dist';
A_VID_NAME = 'Distask2D3904272019';
%A_EYE_CENTER = [];
A_OFFSET_THRESH = 0.55;
%A_CROP_RECT = [];
A_FILTER = 1;
A_FILTER_ORDER = 3;
A_DISCREP_THRESH = 1.8;



scale_factor = 1;

%Loads video file
if ~exist('video','var') | ~(video.Name == [A_VID_NAME '.mp4'])
        video = VideoReader(fullfile(RD_DIR, [A_VID_NAME '.mp4']));
end
number_of_frames = video.NumberOfFrames;

%number_of_frames = 1500;

diameter_data1 = zeros(number_of_frames,1);
diameter_data2 = zeros(number_of_frames,1);
diameter_quality = zeros(number_of_frames,1);
trend = zeros(number_of_frames,1);
totalTimeStart = clock;

if exist('eye_center_orig')==0
    %User selects region of interest on 100th frame
    single_frame_no_crop = read(video,1000);
    [single_frame_cropped, A_CROP_RECT] = imcrop(single_frame_no_crop);

    %User selects center of eye
    [x_center,y_center] = ginput(1);
    eye_center_orig = [x_center,y_center];

    A_EYE_CENTER = eye_center_orig - A_CROP_RECT(1:2);
    A_EYE_CENTER = A_EYE_CENTER * scale_factor;
end

FRAME_STEP=1000;
SETUP = 0;
dimIm = imresize(single_frame_cropped, scale_factor);
visFrameCirs = zeros(number_of_frames,size(dimIm,1),size(dimIm,2),2,'uint8');


%----------------------------------------------------------------------------------

% if SETUP == 1
%     V = VideoWriter('myfile');
%     open(V);
%     figure
% end
    
figure;
%Processes 1000 frames at a time to increase speed and decrease memory load
for i = 100:FRAME_STEP:(number_of_frames+FRAME_STEP-1)
    j=i+FRAME_STEP-1;
    if i+FRAME_STEP-1>number_of_frames
        j = number_of_frames;
    end
    
    %Array to hold frames that will be passed to denoising function
    disp('Loading frames...');
    loadFrames = imresize(zeros(size(single_frame_cropped,1),size(single_frame_cropped,2),FRAME_STEP,'uint8') , scale_factor);
    for curF=i:j
        loadFrames(:,:,curF-i+1)=imresize(imcrop(rgb2gray(read(video,curF)),A_CROP_RECT) , scale_factor);
        if mod(curF,FRAME_STEP/2)==0
            disp(curF);
        end
    end
    disp('Frames loaded!');
    
    % Filters using bandStop filter
    if A_FILTER == 1
        bandStop_frames = DC_bandpass_modGC(loadFrames,4,9,.95,0,'myvid','none',80,'low',A_FILTER_ORDER,0);
    else
        bandStop_frames = loadFrames;
    end

    %Pupil processing code below
    startt = clock;
%    parfor (cnt=i:j)

    disp('Calculating pupil size...');
    for cnt=i:j
        try
            clf
            %Crops original input video
            frameOrig = imadjust(bandStop_frames(:,:,cnt-i+1));
%            frameOrig = bandStop_frames(:,:,cnt-i+1);   
%            frame = imgaussfilt(frameOrig,2);
            frame = frameOrig;
            frameOrig = loadFrames(:,:,cnt-i+1);
            frameDraw = cat(3,im2uint8(frame),im2uint8(frame));
%            % Applies 10x10 Average Filter to "smooth" the image. Also known as "blurring"
%             average_filter = ones(10,10) / 100; % Change this line to increase/decrease smoothing
%             frame = imfilter(frame,average_filter);

%------------------------------------------------------------------------------
%1
            grayT = graythresh(frame);
            circles = zeros(15,4);
            circles2 = zeros(15,3);
                       
%            for a = 1:14
             a = 0;
             repeat = 1;
             max_distance2 = 0;
             
             while repeat == 1
                repeat = 1;
                a = a+1;
                if a > 10
                    repeat = 0;
                    break;
                end
                try %in case no circle can be found at one of the 5 thresholds
            
                    %Converts to binary black and white                   
                    %adaptive_threshold = grayT-(OFFSET_THRESH+a/100);
                    adaptive_threshold = A_OFFSET_THRESH+a/100;
                    adaptive_threshold = max(adaptive_threshold,0.01);
                    frame_binary_inverted = im2bw(frame, adaptive_threshold);            
%                     frame_binary = 1 - frame_binary_inverted;
                    frame_binary_filled = imfill(frame_binary_inverted, 'holes');


                    %Labels each found blob with a numerical value, plots each blob with a different color
                    frame_labeled = bwlabel(frame_binary_filled);
                    frame_colored = label2rgb(frame_labeled,'hsv','k','shuffle');

                    %Removes blobs with fewer than 300 pixels
                    large_blobs = bwareaopen(frame_binary_filled,200*scale_factor);

                    %Finds centroids of each blob
                    centroid_finder = regionprops(large_blobs,'centroid');
                    centroids = cat(1, centroid_finder.Centroid);
                        
                    distances = sqrt(sum(bsxfun(@minus, centroids, A_EYE_CENTER).^2,2));

                    [closest,closest_index] = min(distances);
                    connected_components = bwconncomp(large_blobs); 
                    isolated_blob = large_blobs;
                    isolated_blob(isolated_blob==1) = 0;
                    isolated_blob(connected_components.PixelIdxList{closest_index}) = 1;
                    
                    stats = regionprops(isolated_blob,'Centroid','MajorAxisLength','MinorAxisLength');
                    centers2 = stats.Centroid;
                    radii2 = (stats.MajorAxisLength)/2;
                    circles2(a,1:3) = [centers2,radii2];                 
                    
                    %try hough transform to map circles
                    [centers,radii,metric] = imfindcircles(isolated_blob,[10*scale_factor,100*scale_factor],'ObjectPolarity','bright','sensitivity',0.95);
                    if ~(isempty(radii)) %i.e. if a circle was found using hough transform
                        circles(a,1:4) = [centers(1,1:2),radii(1),metric(1)];
                        
                        %setting code to repeat or not
                        if radii2(1) > A_DISCREP_THRESH*radii(1) || radii2(1) < radii(1)/A_DISCREP_THRESH %if the regionprops radius is too big or too small
                            repeat = 1;                         
                        else
                            max_distance2 = radii2(1);
                            repeat = 0;
                        end
                    end
                    
                    if SETUP == 1
                        %code to display 4x4 plots
                        colored_image_plot = subplot(4,4,a+2);
                        image(frame_colored);
                        set(gca,'YDir','reverse');
                        axis equal tight;
                        viscircles(centers,radii,'EdgeColor','red');
                        viscircles(centers2,radii2,'EdgeColor','green');
                        if ~(isempty(metric))
                            title(strcat(num2str(a),'-',num2str(metric(1)),'-', num2str(adaptive_threshold)));
                            viscircles(centers(1,1:2),radii(1),'EdgeColor','blue');
                        else
                            title(strcat(num2str(a),'-', num2str(adaptive_threshold)));
                        end
                    end

                    
                catch e
                    fprintf(1,'The identifier was:\n%s',e.identifier);
                    fprintf(1,' Likley no cirlce found! The message was:\n%s',e.message);
                    disp(e.stack);  
                end
             end
 %           end  %for commented out for loop
            [max_metric,index] = max(circles(:,4));
            max_distance1 = circles(index,3);
                              
            trend(cnt,:) = grayT-(A_OFFSET_THRESH+index/100);
            
%             %code to draw circles onto frame
%             theta = linspace(0, 2*pi, round(4 * pi * circles2(a,3))); % Define angles
%             x = circles2(a,3) * cos(theta) + circles2(a,1);
%             y = circles2(a,3) * sin(theta) + circles2(a,2);
%             for k = 1 : length(x)
%                 row = round(y(k));
%                 col = round(x(k));
%                 frameDraw(row, col,2) = uint8(255); %white = regionprops
%             end
%             
%             theta = linspace(0, 2*pi, round(4 * pi * circles(index,3))); % Define angles
%             x = circles(index,3) * cos(theta) + circles(index,1);
%             y = circles(index,3) * sin(theta) + circles(index,2);
%             for k = 1 : length(x)
%                 row = round(y(k));
%                 col = round(x(k));
%                 frameDraw(row, col,2) = uint8(140); %gray = hough transform
%             end
                       
            %frameDraw = insertShape(frameDraw,'circle',[circles2(a,1:2),circles2(a,3); circles(index,1:2),circles(index,3)], 'Color', {'green','red'});
%             visFrameCirs(cnt,:,:,:) =  frameDraw;
            
            if SETUP == 1
                %code to display 4x4 plots
                filtered_image_plot = subplot(4,4,2);
                imshow(frame);
                set(gca,'YDir','reverse');
                axis equal tight;
                title('Original Image');
                %viscircles(circles(index,1:2),circles(index,3),'LineWidth',0.5);
                viscircles(circles2(a,1:2),circles2(a,3),'LineWidth',0.5,'EdgeColor','green');
                filtered_image_plot = subplot(4,4,1);
                imshow(frameOrig);
                set(gca,'YDir','reverse');
                axis equal tight;
                title('Original Image');
                viscircles(circles(index,1:2),circles(index,3),'LineWidth',0.5);
                
                drawnow;
                
%                [myF, Map] = frame2im(getframe(gcf));
%                writeVideo(V,myF);
            end
            
        catch e
            disp('error');
            fprintf(1,'The identifier was:\n%s',e.identifier);
            fprintf(1,'There was an error! The message was:\n%s',e.message);
            disp(e.stack);
            max_distance1 = -1;
            max_distance2 = -1;
            max_metric = -1;
            
        end
       
        diameter_data1(cnt,:) = max_distance1;
        diameter_data2(cnt,:) = max_distance2;
        diameter_quality(cnt,:) = max_metric;
        
        if mod(cnt,500)==0
            display(['Frame Number: ',num2str(cnt)]);
        end
        
        
    end
    
    clearvars bandStop_frames
    
    endt = clock;
    pupilProcessingTimeTaken = endt(4)*3600+endt(5)*60+endt(6)-startt(4)*3600-startt(5)*60-startt(6)
       
end

%combine data2 and data 1
diameter_data3 = zeros(number_of_frames,1);
num_subs = 0;

for (iter = 1:size(diameter_data3,1))
   
   if (diameter_data2(iter) == 0 || diameter_data2(iter) > A_DISCREP_THRESH*diameter_data1(iter))
       diameter_data3(iter) = diameter_data1(iter);
       num_subs = num_subs+1;
   else
       diameter_data3(iter) = diameter_data2(iter);
   end
end
num_subs


%Plot Frame vs Pupil Diameter with Moving Average Line
figure
scatter(1:number_of_frames, diameter_data3);
hold on;
mov_avg = filter( (1/5)*ones(1,5), 1, diameter_data3);
plot(1:length(mov_avg),mov_avg);


totalTimeEnd = clock;
totalTimeTaken = totalTimeEnd(4)*3600+totalTimeEnd(5)*60+totalTimeEnd(6)-totalTimeStart(4)*3600-totalTimeStart(5)*60-totalTimeStart(6)
    
save([RD_DIR '\data\' A_VID_NAME '_PupilData.mat']);

