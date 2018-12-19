function fig = t_dependent_Nuclei_ratio_FRET_postprocess(obj,in_fig,output_directory,~) 

     if ~isdir(output_directory), disp('wrong output directory, expect no output'), end
     
     fig = single(in_fig);   

     [sX,sY,sC,sZ,nFovs] = size(fig);

% for saving - don't override!!!     
        fname = obj.current_filename;
        fname = strrep(fname,'.OME.tiff','');
        fname = strrep(fname,'.OME.tif','');
        fname = strrep(fname,'.tif','');
        fname = strrep(fname,'.lsm','');        
          
% % % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% plot intensity
d_vals = zeros(1,nFovs);
a_vals = zeros(1,nFovs);
for k=1:nFovs
    ud = fig(:,:,1,1,k);
    ua = fig(:,:,2,1,k);
    nukes = fig(:,:,3,1,k);
    d_sample = ud(nukes==1);
    d_sample = single(d_sample(:));
    a_sample = ua(nukes==1);
    a_sample = single(a_sample(:));
    d_vals(k) = median(d_sample(:));
    a_vals(k) = median(a_sample(:));
end
h = figure;
plot(1:nFovs,d_vals,'b.-',1:nFovs,a_vals,'r.-')
xlabel('frame #');
ylabel('intensity');
legend({'donor','acceptor'})
grid on;
ax_new=gca;
set(ax_new,'Position','default');
legend(ax_new,'-DynamicLegend');
saveName = [output_directory filesep fname '_segmented_intensities.fig'];
saveas(h,saveName,'fig');
close(h);

% PARAMETERS USED TO CALCULATE FRET MOLAR FRACTION
% excitation exctinction coefficient
eps_A = obj.t_dependent_Nuclei_ratio_FRET_eps_A;
eps_D = obj.t_dependent_Nuclei_ratio_FRET_eps_D;
% optical system transmission
t_A  = obj.t_dependent_Nuclei_ratio_FRET_t_A;
t_D  = obj.t_dependent_Nuclei_ratio_FRET_t_D;
% quantum yield at room temperature
Q_A = obj.t_dependent_Nuclei_ratio_FRET_Q_A; % [ns] EYFP  
Q_D = obj.t_dependent_Nuclei_ratio_FRET_Q_D; % [ns] ECFP  
% lifetimes
tau_A = obj.t_dependent_Nuclei_ratio_FRET_tau_A; % [ns] EYFP  
tau_D = obj.t_dependent_Nuclei_ratio_FRET_tau_D; % [ns] ECFP 
% FRETting donor lifetime
tau_FRET = obj.t_dependent_Nuclei_ratio_FRET_tau_FRET; % [ns] - HIGH FRET
% spectral leakage coefficients
K_DA = obj.t_dependent_Nuclei_ratio_FRET_K_DA;
K_AD = obj.t_dependent_Nuclei_ratio_FRET_K_AD;
% ratio of excitation intensities in the donor and acceptor absorption bands, phi = IexD/IexA
phi = obj.t_dependent_Nuclei_ratio_FRET_phi;
% fraction of functional donor and acceptor
b_A = obj.t_dependent_Nuclei_ratio_FRET_b_A ; 
b_D = obj.t_dependent_Nuclei_ratio_FRET_b_D;
%
E = 1 - tau_FRET/tau_D;
A = 1/phi*(b_A/b_D)*(t_A/t_D)*(eps_A/eps_D)*(Q_A/Q_D);
B = (t_A/t_D)*E/Q_D*b_A;
C = (1-(1-E)*b_A);
% then beta_FRET = (Z-A)./(B+Z*C); where Z is FRET ratio calculated with bleed-through corrected intensities
% PARAMETERS USED TO CALCULATE FRET MOLAR FRACTION

% nucleus size
% donor intensity
% acceptor intensity
% intensity ratio
% Pearson correlation
% # neighbours (by SOI)
% cell density (by Delaunay) 
% FRET molar fraction 

obj.imgdata = []; % helps with memory

use_memmap = sX*sY*8*nFovs >= 1024*1024*8*780/2;
if use_memmap   
    [mapfile_name_clc_res,memmap_clc_res] = initialize_memmap([sX,sY,8,nFovs],1,'pixels','single');                 
    clc_res = memmap_clc_res.Data.pixels; % reference
else
    clc_res = zeros(sX,sY,8,nFovs,'single');
end

% all Z calculations are bound to the frame
NUCDATA = cell(1,nFovs);

% for safety
mean_nnghbs = zeros(1,nFovs);
mean_cell_density = zeros(1,nFovs);

track_mate_input = zeros(sX,sY,1,1,nFovs);

for k=1:nFovs
    tic
    ud = single(fig(:,:,1,1,k));
    ua = single(fig(:,:,2,1,k));
    %    
    nukes = fig(:,:,3,1,k);
    %
        try                    
            nucleus_size = zeros(sX,sY);
            donor_intensity = zeros(sX,sY);
            acceptor_intensity = zeros(sX,sY);
            intensity_ratio = zeros(sX,sY);
            Pearson_correlation = zeros(sX,sY);
            %
            n_neighbours = zeros(sX,sY);
            cell_density = zeros(sX,sY);
            FRET_molar_fracton = zeros(sX,sY);
            %
            L = bwlabel(nukes);
            stats = regionprops(L,'Centroid');
            nnucs = max(L(:));
            %
            nuc_data = zeros(nnucs,11); % 11-th is molar fraction estimate 
            XC = zeros(1,nnucs);
            YC = zeros(1,nnucs);
            
            for n=1:nnucs
                sample_a = single(ua(L==n));
                sample_d = single(ud(L==n));
                %
                nuc_data(n,1)=length(sample_a(:)); % area
                nuc_data(n,2)=0;
                %
                nuc_data(n,3)=corr(sample_a(:),sample_d(:),'type','Pearson');
                    mean_sample_a = mean(sample_a(:));
                    mean_sample_d = mean(sample_d(:));
                nuc_data(n,4)=mean_sample_a/mean_sample_d;
                nuc_data(n,5)=mean_sample_a;
                nuc_data(n,6)=mean_sample_d;
                nuc_data(n,7) = stats(n).Centroid(2);
                nuc_data(n,8) = stats(n).Centroid(1);                
                %
                XC(n)=stats(n).Centroid(2);
                YC(n)=stats(n).Centroid(1);
                %
                nucleus_size(L==n)=length(sample_a(:)); % area
                donor_intensity(L==n)=mean_sample_d;
                acceptor_intensity(L==n)=mean_sample_a;
                intensity_ratio(L==n)=mean_sample_a/mean_sample_d;
                Pearson_correlation(L==n)=nuc_data(n,3); % Pearson

                % via corrected intensities
                IA = mean_sample_a - K_DA*mean_sample_d;
                ID = mean_sample_d - K_AD*mean_sample_a;
                Z = IA/ID;
                try
                    beta_FRET = (Z-A)./(B+Z*C);
                catch
                    beta_FRET = 0;
                end
                FRET_molar_fracton(L==n) = beta_FRET;
                nuc_data(n,11) = beta_FRET;                
                
                track_mate_input(round(XC(n)),round(YC(n)),1,1,k) = 1;                
            end
            
            % adjacency matrices (symmetric)
                    % FOR SPEED ONLY
                    AJM_density = adjacency_matrix(XC,YC,'Delaunay');
                    AJM_nnghb = adjacency_matrix(XC,YC,'SOI');            
            % reasonable looking, but but slow
            % AJM_density = adjacency_matrix(XC,YC,'Gabriel');
            % AJM_nnghb = AJM_density;

            % distance matrix
            DM = squareform(pdist([XC' YC']));
            % number of neighbours vector
            NNGHB = sum(AJM_density,1);
            iNNGHB = 1./NNGHB; % matrix containing inverse #nnghb
            %
            % correct AJM_density for distances that are too long...
            AJM_density_fixed = AJM_density;
            dmax = 250/obj.microns_per_pixel; % 250 microns in pixels
            for kk=1:nnucs
                for jj=1:nnucs
                    if DM(kk,jj)>dmax
                        AJM_density_fixed(kk,jj)=0;
                    end
                end
            end
%             figure(22+k);            
%             ax=gca;
%             plot(XC,YC,'r.');
%             for kk=1:nnucs
%                 for jj=1:nnucs
%                     if kk<jj && 1==AJM_density(kk,jj)
%                         v1 = [XC(kk) XC(jj)];
%                         v2 = [YC(kk) YC(jj)];
%                         h=line(v1,v2);
%                         set(h,'Color','red');
%                         set(h,'LineStyle',':');
%                         set(h,'LineWidth',1);
%                         hold(ax,'on');
%                     end
%                     if kk<jj && 1==AJM_density_fixed(kk,jj)
%                         v1 = [XC(kk) XC(jj)];
%                         v2 = [YC(kk) YC(jj)];
%                         h=line(v1,v2);
%                         set(h,'Color','blue');
%                         hold(ax,'on');
%                     end
%                     if kk<jj && 1==AJM_nnghb(kk,jj)
%                         v1 = [XC(kk) XC(jj)];
%                         v2 = [YC(kk) YC(jj)];
%                         h=line(v1,v2);
%                         set(h,'Color','black');
%                         set(h,'LineStyle',':');
%                         set(h,'LineWidth',2);
%                         hold(ax,'on');
%                     end                           
%                  end
%             end
%             plot(ax,XC,YC,'r.');
%             hold(ax,'off');
%             daspect(ax,[1 1 1]);
%             axis(ax,[1 1024 1 1024])
%             disp('');
            % correct AJM_density for distances that are too long...            
            
            % for "natural" # neighbours
            NNGHB_NNGHB = sum(AJM_nnghb,1);
            %
            for n=1:nnucs
                % # neighbours
                nnghb = NNGHB_NNGHB(n);                                
                % estimate for cell density
                dstncs = DM(n,:).*AJM_density(n,:);
                dstncs = dstncs(0~=dstncs); % no zeros
                if ~isempty(dstncs)
                    davr = mean(dstncs);
                    density = (1 + iNNGHB(n))/(pi*davr^2);
                else
                    density = 0;
                end
                % assign
                n_neighbours(L==n) = nnghb;
                cell_density(L==n) = density; 
                %
                nuc_data(n,9) = nnghb;
                nuc_data(n,10) = density;                
            end
            %
            % mean #nnghb and density - for safety
            mean_nnghbs(k) = mean(n_neighbours(0~=n_neighbours));
            mean_cell_density(k) = mean(cell_density(0~=cell_density));
            %            
            % replace binary segmentation in output for the A/D ratio multiplied by 100
            fig(:,:,3,1,k)=intensity_ratio*100;
            clc_res(:,:,1,k)=nucleus_size;
            clc_res(:,:,2,k)=donor_intensity;
            clc_res(:,:,3,k)=acceptor_intensity;
            clc_res(:,:,4,k)=intensity_ratio;
            clc_res(:,:,5,k)=Pearson_correlation;
            clc_res(:,:,6,k)=n_neighbours;
            clc_res(:,:,7,k)=cell_density;
            clc_res(:,:,8,k)=FRET_molar_fracton; 
        catch
            disp(['glitch at index ' num2str(k)]);
        end
        %
        if isempty(nuc_data), continue, end
        %
        NUCDATA{k} = nuc_data;
        disp([num2str(k) ' ' num2str(toc)]);
end
%save('NUCDATA','NUCDATA'); %??

% gather statistics on frames
% 1 nuc_size 1
% 3 Pearson 2
% 6 D 3
% 5 A 4
% 4 FRET ratio 5
% 9 nnghb 6
% 10 cell density 7
% 11 FRET fraction 8
indices = [1 3 6 5 4 9 10 11];
NUC_STATS = zeros(nFovs,8,5); % mean, std, median, 025Q, 075Q
for k=1:nFovs
    nuc_data = NUCDATA{k};
    for j=1:numel(indices)
        index = indices(j);
        s = squeeze(nuc_data(:,index)); %sample
        s = s(~isinf(s));
        s = s(~isnan(s));        
        NUC_STATS(k,j,:) = [mean(s) std(s) median(s) quantile(s,.25) quantile(s,.75)];
    end
end
% gather statistics on frames - end


% MOVIE %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% fix NUCDATA :)
%%%%%%%%%%%%%%%%%%%%%%%%%%%% that is legacy; should't happen
Z = NUCDATA;
cell_nums = zeros(1,numel(Z));
for k=1:numel(Z)
    if isempty(Z{k})
        Z{k}=Z{k-1};        
    end
    cell_nums(k)=length(Z{k});
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%

t = (0:numel(NUCDATA)-1)*obj.t_dependent_Nuclei_ratio_FRET_TIMESTEP;

% save N(t) curve
xlswrite([output_directory filesep fname ' cell numbers curve.xls'],[t' cell_nums']);

try % may fail on some versions of Matlab
    h=figure; 
    movegui(h, 'onscreen');

    vidObj = VideoWriter([output_directory filesep fname]);

    vidObj.Quality = 100;
    open(vidObj);

    % get the figure and axes handles
     hFig = gcf;
     hAx  = gca;
     % set the figure to full screen
     set(hFig,'units','normalized','outerposition',[0 0 1 1]);
     % set the axes to full screen
     set(hAx,'Unit','normalized','Position',[0 0 1 1]);
     % hide the toolbar
     set(hFig,'menubar','none')
     % to hide the title
     set(hFig,'NumberTitle','off');

    set(h,'Units','pixels'); 
    rect = get(h,'Position');
    rect(1:2) = [0 0]; 

    mean_x = [];
    std_x = [];
    cell_num = [];

    fontsize = 18;
    markersize = 12;
    linewidth = 2;

    for k = 1 : numel(NUCDATA)

        try
            nuc_data = NUCDATA{k};
            nuc_size = nuc_data(:,1);
            corr_nuc_FRET_ratio = nuc_data(:,3);
            corr_nuc_FRET_ratio = corr_nuc_FRET_ratio(~isnan(corr_nuc_FRET_ratio));        
            nuc_FRET_ratio = nuc_data(:,4);
            %        
            subplot(2,2,1);    
            histogram(nuc_FRET_ratio,200,'Normalization','probability'); % should display pdf
            xlabel('FRET ratio','fontsize',fontsize);
            ylabel('PDF value','fontsize',fontsize);
            axis([0 2 0 0.1]);        
            set(gca,'FontSize',fontsize);
            title(['frame ' num2str(k)]);
                grid on;

            subplot(2,2,3);
            cell_num = [cell_num numel(nuc_size)];
            semilogy(t(1:numel(cell_num)),cell_num,'k.-','markersize',markersize,'linewidth',linewidth); %
            xlabel('time [h]','fontsize',fontsize);
            ylabel('cell number','fontsize',fontsize);
            axis([t(1) t(numel(cell_nums)) min(cell_nums) max(cell_nums)]);
            set(gca,'FontSize',fontsize);        
                grid on;    

            subplot(2,2,4);
            mean_x = [mean_x mean(nuc_FRET_ratio)];
            std_x = [std_x std(nuc_FRET_ratio)];
            errorbar(t(1:numel(mean_x)),mean_x,std_x,'Color','red','Marker','o','MarkerFaceColor','green'); %
            %mseb(t(1:numel(mean_x)),mean_x,std_x); %
            xlabel('time [h]','fontsize',fontsize);
            ylabel('FRET ratio','fontsize',fontsize);
            set(gca,'FontSize',fontsize);        
                grid on;            

            subplot(2,2,2);
            nuc_FRET_ratio = nuc_FRET_ratio(~isnan(corr_nuc_FRET_ratio)); % because may be different size
            histogram2(nuc_FRET_ratio,corr_nuc_FRET_ratio,0:0.1:2,-1:0.1:1,'Normalization','probability','DisplayStyle','tile');
            xlabel('FRET ratio');
            ylabel('Donor-Acceptor pixel correlation (Pearson)','fontsize',fontsize);
            axis([0 2 -1 1]);
            set(gca,'FontSize',fontsize);
            title(strrep(fname,'_',' '));
                 grid on;            
        catch
            disp(['glitch at ' num2str(k)]);
        end              
        movegui(h, 'onscreen');
        hold all;
        drawnow;
        writeVideo(vidObj,getframe(gcf,rect));
    end
    close(vidObj);  
    close(h);
catch
    disp('no movie.. well, whatever.')
end
% MOVIE %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% TRACKING %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
          
     track_mate_input = track_mate_input*10000;
     smoothing_radius = 1;
     for k=1:nFovs
        track_mate_input(:,:,1,1,k)=gsderiv(squeeze(track_mate_input(:,:,1,1,k)),smoothing_radius,0);
     end                       
     imp = copytoImagePlus(track_mate_input,'dimorder','XYCZT');
        % test image
        % imp = ij.IJ.openImage('http://fiji.sc/samples/FakeTracks.tif');
     %imp.show();
     %
        % Some of the parameters we configure below need to have
        % a reference to the model at creation. So we create an
        % empty model now.
        model = fiji.plugin.trackmate.Model();

        % Send all messages to ImageJ log window.
        % model.setLogger(fiji.plugin.trackmate.Logger.IJ_LOGGER)

        %------------------------
        % Prepare settings object
        %------------------------

        settings = fiji.plugin.trackmate.Settings();
        settings.setFrom(imp)

        % Configure detector - We use a java map
        settings.detectorFactory = fiji.plugin.trackmate.detection.LogDetectorFactory();
        map = java.util.HashMap();
        map.put('DO_SUBPIXEL_LOCALIZATION', true);
        %map.put('RADIUS', obj.TrackMate_RADIUS); % parameter excessive
            map.put('RADIUS',2);
        map.put('TARGET_CHANNEL', obj.TrackMate_TARGET_CHANNEL);
        map.put('THRESHOLD', obj.TrackMate_THRESHOLD);
        map.put('DO_MEDIAN_FILTERING', obj.TrackMate_DO_MEDIAN_FILTERING);
        settings.detectorSettings = map;

        % Configure spot filters - Classical filter on quality
        filter1 = fiji.plugin.trackmate.features.FeatureFilter('QUALITY', obj.TrackMate_QUALITY, true);
        settings.addSpotFilter(filter1)

        % Configure tracker
        settings.trackerFactory  = fiji.plugin.trackmate.tracking.sparselap.SparseLAPTrackerFactory();
        settings.trackerSettings = fiji.plugin.trackmate.tracking.LAPUtils.getDefaultLAPSettingsMap(); % almost good enough
        settings.trackerSettings.put('ALLOW_TRACK_SPLITTING', obj.TrackMate_ALLOW_TRACK_SPLITTING);
        settings.trackerSettings.put('ALLOW_TRACK_MERGING', obj.TrackMate_ALLOW_TRACK_MERGING);
        %
        %https://forum.image.sc/t/trackmate-memory-issue-when-run-in-matlab/3424
        settings.trackerSettings.put('LINKING_MAX_DISTANCE',obj.TrackMate_LINKING_MAX_DISTANCE); % pixels
        settings.trackerSettings.put('GAP_CLOSING_MAX_DISTANCE',obj.TrackMate_GAP_CLOSING_MAX_DISTANCE); % pixels
        settings.trackerSettings.put('MAX_FRAME_GAP', java.lang.Integer(obj.TrackMate_MAX_FRAME_GAP)); % frames
                                        
        % Configure track analyzers - Later on we want to filter out tracks 
        % based on their displacement, so we need to state that we want 
        % track displacement to be calculated. By default, out of the GUI, 
        % not features are calculated. 
        %
        % The displacement feature is provided by the TrackDurationAnalyzer.
        settings.addTrackAnalyzer(fiji.plugin.trackmate.features.track.TrackDurationAnalyzer())
        % Configure track filters - We want to get rid of the two immobile spots at 
        % the bottom right of the image. Track displacement must be above 10 pixels.
        filter2 = fiji.plugin.trackmate.features.FeatureFilter('TRACK_DISPLACEMENT', obj.TrackMate_TRACK_DISPLACEMENT, true); % pixels
        settings.addTrackFilter(filter2)

        %-------------------
        % Instantiate plugin
        %-------------------
        trackmate = fiji.plugin.trackmate.TrackMate(model, settings);

        %--------
        % Process
        %--------
        ok = trackmate.checkInput();
        if ~ok
            display(trackmate.getErrorMessage())
        end

        ok = trackmate.process();
        if ~ok
            display(trackmate.getErrorMessage())
        else
            % Echo results
            display(model.toString());
        end
        
        %----------------
        % Display results
        %----------------
%         selectionModel = fiji.plugin.trackmate.SelectionModel(model);
%         displayer =  fiji.plugin.trackmate.visualization.hyperstack.HyperStackDisplayer(model, selectionModel, imp);
%         %displayer =  fiji.plugin.trackmate.visualization.hyperstack.HyperStackDisplayer(model, selectionModel, copytoImagePlus(dum,'dimorder','XYZCT'));        
%         displayer.render()
%         displayer.refresh()

        % fname = [tempname,'.xml'];
        fullfname = [output_directory filesep fname '_RAW_TRACKMATE_OUTPUT' '.xml'];                        
        file = java.io.File(fullfname);
        fiji.plugin.trackmate.action.ExportTracksToXML.export(model, settings, file);        
        tracks = importTrackMateTracks(file,false);         
                        
        % DEBUG
%         icyvol = fig;                
%         for k=1:numel(tracks)
%             track = tracks{k};
%             for m=1:size(track,1)
%                 frame = track(m,1)+1;
%                 x = round(track(m,2))+1;
%                 y = round(track(m,3))+1;
%                 try
%                 icyvol(x,y,3,1,frame) = 255;
%                 catch
%                     disp([x y frame]);
%                 end
%             end
%         end                
%         icy_imshow(uint16(icyvol));    

% matching
        for k=1:numel(tracks)
            track = tracks{k};
            ext_track = zeros(size(track,1),11); %frame,x,y+8 params
            for m=1:size(track,1)
                frame = track(m,1)+1;
                x = round(track(m,2))+1;
                y = round(track(m,3))+1;
                nucleus_size =          clc_res(x,y,1,frame);
                donor_intensity =       clc_res(x,y,2,frame);
                acceptor_intensity =    clc_res(x,y,3,frame);
                FRET_ratio =            clc_res(x,y,4,frame);
                Pearson_correlation =   clc_res(x,y,5,frame);
                nnghb =                 clc_res(x,y,6,frame);
                cell_density =          clc_res(x,y,7,frame);
                beta_FRET =             clc_res(x,y,8,frame);                
                %              
                try
                if 0==nucleus_size % first, try to find nearest nucleus and use it as backup
                    distance = Inf;
                    TRACK_IND = 0;
                    FRAME_IND = 0;
                    for k_b=1:numel(tracks)
                        track_b = tracks{k_b};
                        for m_b=1:size(track_b,1)
                            if ~(k_b==k && m_b==m)
                                frame_b = track_b(m_b,1)+1;
                                x_b = round(track_b(m_b,2))+1;
                                y_b = round(track_b(m_b,3))+1;
                                d_cur = norm([(x-x_b) (y-y_b)]);
                                if d_cur < distance 
                                    distance = d_cur;
                                    TRACK_IND = k_b;
                                    FRAME_IND = frame_b;
                                end
                            end
                        end
                    end
                    track_b = tracks{TRACK_IND};
                    x_b = round(track_b(FRAME_IND,2))+1;
                    y_b = round(track_b(FRAME_IND,3))+1;
                    nucleus_size =          clc_res(x_b,y_b,1,FRAME_IND);
                    donor_intensity =       clc_res(x_b,y_b,2,FRAME_IND);
                    acceptor_intensity =    clc_res(x_b,y_b,3,FRAME_IND);
                    FRET_ratio =            clc_res(x_b,y_b,4,FRAME_IND);
                    Pearson_correlation =   clc_res(x_b,y_b,5,FRAME_IND);
                    nnghb =                 clc_res(x_b,y_b,6,FRAME_IND);
                    cell_density =          clc_res(x_b,y_b,7,FRAME_IND);
                    beta_FRET =             clc_res(x_b,y_b,8,FRAME_IND);
                    disp(['missed, substituted at distance ' num2str(distance)]);
                end
                catch
                    disp('error when trying to substitute nearest');
                end
                try
                if 0==nucleus_size % last resort - safely use 5x5 vicinity of the orphan point
                    xl = max(x-2,1);
                    xr = min(x+2,sX);
                    yd = max(y-2,1);
                    yu = min(y+2,sY);
                    d_sample = fig(xl:xr,yd:yu,1,1,frame);
                    a_sample = fig(xl:xr,yd:yu,2,1,frame);
                    nucleus_size = 25; %:)         
                    donor_intensity = mean(d_sample(:));      
                    acceptor_intensity = mean(a_sample(:));       
                    FRET_ratio = acceptor_intensity/donor_intensity;                    
                    Pearson_correlation = corr(a_sample(:),d_sample(:),'type','Pearson');
                    nnghb = mean_nnghbs(frame);
                    cell_density = mean_cell_density(frame);
                    %
                    % via corrected intensities
                    IA = acceptor_intensity - K_DA*donor_intensity;
                    ID = donor_intensity - K_AD*acceptor_intensity;
                    Z = IA/ID;
                    try
                        beta_FRET = (Z-A)./(B+Z*C);
                    catch
                        beta_FRET = 0;
                    end
                    %
                    disp(['fixing orphan TrackMate point at ' num2str(x) ' ' num2str(y) ' ' num2str(frame) ' ' num2str(FRET_ratio)]);
                    %                    
                end
                    ext_track(m,1) = frame;
                    ext_track(m,2) = track(m,2);
                    ext_track(m,3) = track(m,3);
                    ext_track(m,7) = nucleus_size; 
                    ext_track(m,5) = donor_intensity;
                    ext_track(m,6) = acceptor_intensity; 
                    ext_track(m,4) = FRET_ratio; 
                    ext_track(m,8) = Pearson_correlation;
                    ext_track(m,9) = nnghb;
                    ext_track(m,10) = cell_density;
                    ext_track(m,11) = beta_FRET;                    
                catch
                    disp('glitch');
                    disp([x y frame]);
                end
            end
            tracks{k} = ext_track;
        end

fullfname = [output_directory filesep fname '_FRET_ratio_featured_TRACKMATE_OUTPUT.mat'];
dt = obj.t_dependent_Nuclei_ratio_FRET_TIMESTEP;
microns_per_pixel = obj.microns_per_pixel;
%

save(fullfname,'tracks','dt','microns_per_pixel','NUC_STATS','cell_nums');

if use_memmap
    clear('memmap_clc_res');
    delete(mapfile_name_clc_res);
end

% TRACKING %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
try
    track_breaking_flag = true;
t_dependent_Nuclei_ratio_FRET_TrackPlotter(tracks,... 
    obj.t_dependent_Nuclei_ratio_FRET_TIMESTEP, ...
    obj.microns_per_pixel, ...
    fname, ...
    track_breaking_flag);
catch
    disp('error when trying to initiate t_dependent_Nuclei_ratio_FRET_TrackPlotter');
end
        fig = uint16(reshape(fig,[sX sY sC nFovs sZ]));  % XYCTZ                      
end
