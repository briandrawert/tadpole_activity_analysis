%close all;clear all;clc;
%
function tadpole_activity_analysis(varargin)
    close all;
    %filename = '/Users/brian/Desktop/tadpole_activity_video/DSCF0001.AVI';
    %filename = uigetfile('*.avi;*.AVI','Select Video File','MultiSelect', 'off');
    [fpart, ppart, filterindex] = uigetfile('*.avi;*.AVI','Select Video File','MultiSelect', 'off');
    if filterindex == 0
        return
    end
    filename = fullfile(ppart,fpart);
    fprintf('filename = %s\n',filename)
    
    chng_v_time = [];
    time_v_time = [];
    param_window_size = 15;
    crop_rect = [];
    show_plots = 1;
    circ_bounds = struct('X',0,'y',0,'h',0,'w',0);
    %num_frames = 0;
    fig=[];
    VidObj = [];
    VidPlayBackObj = [];
    processing_continue = 1;
    playback_continue = 1;
    frameObj = struct('f',[],'f2',[],'f3',[],'f4',[],'f5',[],'d',[],...
        'lastFrame',[],'ndx',0);
    PlaybackFrameObj = struct('f',[],'f2',[],'f3',[],'f4',[],'f5',[],'d',[],...
        'lastFrame',[],'ndx',0);
    step_delta = 5;
    circle_mask = [];
    analysis.wnsz_x=30;
    analysis.threshold= 30;
    movement_detected = [];
    total_movement_time = '';
    movement_AUC = '';
    analysis_startstop = struct('start',0,'stop',0);
    screen_size = [];
    
    
    % Run
    get_cropping_rect()

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%     function get_volume_measurement__reset()
%         run_analysis__draw()
%         draw_play_button()
%     end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function get_volume_measurement__step1()
        set(0,'DefaultFigureVisible','off');
        fig=figure(1);clf;set(fig,'MenuBar','none');
        plot_circle(frameObj)
        screen_size = get(0,'screensize');
        set(fig,'Position',[1,55,screen_size(3),screen_size(4)-99])        
        set(fig,'Visible','on')
        vol_crop_rect = floor(getrect);
        fprintf('\tvol_crop_rect: %g\n',vol_crop_rect)
        get_volume_measurement__step2(vol_crop_rect)
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function get_volume_measurement__step2(vol_crop_rect)
        set(0,'DefaultFigureVisible','off');
        fig=figure(1);clf;set(fig,'MenuBar','none');
        img = frameObj.f5(vol_crop_rect(2):(vol_crop_rect(2)+vol_crop_rect(4)),vol_crop_rect(1):(vol_crop_rect(1)+vol_crop_rect(3)),:);
        imshow(img)
        screen_size = get(0,'screensize');
        set(fig,'Position',[1,55,screen_size(3),screen_size(4)-99])        
        set(fig,'Visible','on')
        
        %uiwait(msgbox('Draw a line clicking on "snout" and then "vent", then hit return.  If you click an extra time, hit delete.'))
        snout_to_vent_length = inputdlg('Enter the "snout" to "vent" length measurment here, and Click OK.  Next draw a line clicking on "snout" and then "vent", then hit return.');
        
        if ~isempty(snout_to_vent_length)
            
            snout_to_vent_length = str2num(cell2mat(snout_to_vent_length(1)));
            keep_going=1;
            while(keep_going)
                [x,y] = getline(fig);
                fprintf('getline: x,y = %g %g\n',x,y)
                if length(x) == 2
                    keep_going=0;
                else
                    uiwait(msgbox('Wrong number of points clicked for the line.  Please try again.  Click twice, then hit the return key.'))
                end
            end

            line_length = sqrt((x(2)-x(1))^2 + (y(2)-y(1))^2);
            
            area_px2 = nnz(img);
            area_mm2 = area_px2 * (snout_to_vent_length/line_length) * (snout_to_vent_length/line_length);

            %uiwait(msgbox(sprintf('Snout to Vent length=%g (mm)\n\nLine length=%g (pixels)\n\ncross-sectional area=%g (pixels^2)\n\ncross-sectional area=%g (mm^2)',snout_to_vent_length, line_length,area_px2, area_mm2)));


        end
        get_volume_measurement__step3(x,y,img, snout_to_vent_length, line_length,area_px2, area_mm2);
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function get_volume_measurement__step3(line_x,line_y,img, snout_to_vent_length, line_length,area_px2, area_mm2)
        function d = distance_to_line(x0,y0)
            %cite: wikipedia/Distance_from_a_point_to_a_line
            % "line defined by two points"
            d = abs(...
                (line_y(2)-line_y(1))*x0 ...
               -(line_x(2)-line_x(1))*y0 ...
               +line_x(2)*line_y(1) - line_y(2)*line_x(1) ...
            )/sqrt((line_y(2)-line_y(1))^2 + (line_x(2)-line_x(1))^2);
        end
        %%%%%
        function p = projection_along_line(x0,y0,d)
            % distance_to_line^2 + projection_along_line^2 = dist(p0,p1)^2
            p = sqrt( (line_x(1)-x0)^2 + (line_y(1)-y0)^2 - d^2 );
        end
        %%%%%
        pts = [];
        szimg = size(img);
        for x=1:szimg(2)
            for y=1:szimg(1)
                %fprintf('img(%g,%g)=%g\n',y,x,img(y,x))
                if img(y,x) > 0
                    d = distance_to_line(x,y);
                    p = projection_along_line(x,y,d);
                    pts(end+1,:) = [x,y,d*(snout_to_vent_length/line_length),p*(snout_to_vent_length/line_length)];
                end
            end
        end
        
        [~,idx4] = sort(pts(:,4));
        [~,edges] = histcounts(pts(:,4));
        e_ndx=1;
        bin_max=0;
        radius_vec = zeros(1,length(edges-1));
        for i_ndx = 1:length(idx4)
            if e_ndx > length(edges) || pts(idx4(i_ndx),4) > edges(e_ndx)
                radius_vec(e_ndx) = bin_max;
                e_ndx = e_ndx + 1;
                bin_max = 0;
                if e_ndx > length(edges)
                    break
                end
            end
            if bin_max < pts(idx4(i_ndx),3)
                bin_max = pts(idx4(i_ndx),3);
            end
        end
        
        
%         pts
%         
%         set(0,'DefaultFigureVisible','off');
%         fig=figure(1);clf;set(fig,'MenuBar','none');
%         imshow(img)
%         screen_size = get(0,'screensize');
%         set(fig,'Position',[1,55,screen_size(3),screen_size(4)-99])        
%         set(fig,'Visible','on')        
%         
%         uiwait(msgbox(sprintf('Next')));
            
        set(0,'DefaultFigureVisible','off');
        fig=figure(1);clf;set(fig,'MenuBar','none');
        %imshow(img)
        subplot(2,2,1)
        plot(pts(:,1),pts(:,2),'.')
        hold on
        plot(line_x,line_y)
        hold off
        title('Tadpole position')
        xlabel('x position (pixels)')
        xlabel('y position (pixels)')
        subplot(2,2,2)
        plot(pts(:,4),pts(:,3),'.')
        title('points transformed along line')
        xlabel('transformed x (mm)')
        ylabel('transformed y (mm)')
        subplot(2,2,3)
        %histogram(pts(:,4));
        bar(edges,radius_vec,1.0)
        title('radius of disc at each x-value')
        xlabel('distance along tadpole lenght (mm)')
        ylabel('radius of tadople (mm)')
        screen_size = get(0,'screensize');
        set(fig,'Position',[1,55,screen_size(3),screen_size(4)-99])        
        set(fig,'Visible','on')
        
        h = edges(2)-edges(1);
        volume_vec = h*pi*radius_vec.^2;
        rev_volume = sum(volume_vec);
        
        pow_volume = area_mm2^(1.5);
        test_str = sprintf('Volume (area^1.5 method): %g mm^3',pow_volume);
        
        p0 = uipanel('Position',[0.5 0.05 0.4 0.4]);%,'BorderType','none');
        uicontrol(fig,'Parent',p0,'Style','pushbutton','String','Back to Main Screen','Position',[0 50 400 20],'Callback',@callback__calculate_tadpole_volume__reset);
        uicontrol(fig,'Parent',p0,'Style','text','String',test_str,'Position',[0 75 400 20]);
        uicontrol(fig,'Parent',p0,'Style','text','String',sprintf('Volume (rotation method): %g mm^3',rev_volume),'Position',[0 100 400 20]);        
        
        uicontrol(fig,'Parent',p0,'Style','text','String',sprintf('Snout to Vent length=%g (mm)\n\nLine length=%g (pixels)\n\ncross-sectional area=%g (pixels^2)\n\ncross-sectional area=%g (mm^2)',...
            snout_to_vent_length, line_length,area_px2, area_mm2),'Position',[0 125 400 100]);
        
        % go back
        %uiwait(msgbox(sprintf('done')));
        %get_volume_measurement__reset()
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function get_cropping_rect()
        set(0,'DefaultFigureVisible','off');
        fig=figure(1);clf;set(fig,'MenuBar','none');
        v =  VideoReader(filename);
        f = readFrame(v);
        imh = imshow(f);
        screen_size = get(0,'screensize');
        set(fig,'Position',[1,55,screen_size(3),screen_size(4)-99])        
        hsp = imscrollpanel(fig,imh);
        set(hsp,'Units','normalized','Position',[0 0 1 1])
        set(fig,'Visible','on')
  
        %uiwait(msgbox('Draw rectangle around area to analyze'))
        choice = questdlg('Draw rectangle around area to analyze', ...
            'Tadpole Activity Analysis', ...
            'Ok','Load Data','Ok');
        % Handle response
        switch choice
            case 'Ok'
                fprintf('Get cropping rectangle\n')
                crop_rect = floor(getrect);
                circ_bounds.x = 0;
                circ_bounds.y = 0;
                circ_bounds.h = crop_rect(3);
                circ_bounds.w = crop_rect(4);
                fprintf('\t%g\n',crop_rect)
                initialize_analysis_window()
            case 'Load Data'
                load_data_file()
                %initialize_analysis_window()
                VidObj =  VideoReader(filename,'CurrentTime',time_v_time(end));
                run_analysis__read_frame();
                frameObj.ndx = length(time_v_time);
                frameObj.d = zeros(crop_rect(4)+1,crop_rect(3)+1);
                run_analysis__draw()
                draw_play_button()
        end
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function load_data_file()
        [fpart, ppart, filterindex] = uigetfile('*.mat','Select Data File','MultiSelect', 'off');
        if filterindex == 0
            return
        end
        data_filename = fullfile(ppart,fpart);
        fprintf('data_filename = %s\n',data_filename)
        s = load(data_filename);
        if s.filename ~= filename
            error('Filenames do not match.  This saved data file can not be used with this video file')
        end
        crop_rect = s.crop_rect;
        chng_v_time = s.chng_v_time;
        time_v_time = s.time_v_time;
        movement_detected = s.movement_detected;
        total_movement_time = s.total_movement_time;
        movement_AUC = s.movement_AUC;
        if isfield(s,'circ_bounds')
            circ_bounds = s.circ_bounds;
        else
            circ_bounds.x = 0;
            circ_bounds.y = 0;
            circ_bounds.h = crop_rect(3);
            circ_bounds.w = crop_rect(4);
        end
        if isfield(s,'analysis_startstop')
            analysis_startstop = s.analysis_startstop;
        else
            analysis_startstop = struct('start',0,'stop',0);
        end
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%                
    function draw_play_button()
        p0 = uipanel('Position',[0.05 0.95 0.5 0.05],'BorderType','none');
        uicontrol(fig,'Parent',p0,'Style','pushbutton','String','Select New Region','Position',[0 0 200 20],'Callback',@callback__start_over_button_pushed);
        uicontrol(fig,'Parent',p0,'Style','pushbutton','String','Calculate Tadpole Volume','Position',[220 0 200 20],'Callback',@callback__calculate_tadpole_volume);
        
        p1 = uipanel('Position',[0.05 0.465 0.35 0.05],'BorderType','none');
        uicontrol(fig,'Parent',p1,'Style','pushbutton','String','Start Processing','Position',[0 10 200 20],'Callback',@callback__play_button_pushed);
        uicontrol(fig,'Parent',p1,'Style','pushbutton','String','Reset Processing','Position',[200 10 200 20],'Callback',@callback__reset_button_pushed);

        %uicontrol(fig,'Style','text','String','Adjust Blue Clipping Region','Position',[800 400 200 20]);
        panel = uipanel('Title','Adjust Blue Clipping Region','FontSize',12,...
             'Position',[0.4 0.465 0.25 0.07]);
        uicontrol(fig,'Parent',panel,'Style','text','String','X','Position',[0 10 20 20]);
        uicontrol(fig,'Parent',panel,'Style','pushbutton','String','<','Position',[20 10 20 20],'Callback',@callback__X_dec_button_pushed);
        uicontrol(fig,'Parent',panel,'Style','pushbutton','String','>','Position',[40 10 20 20],'Callback',@callback__X_inc_button_pushed);
        uicontrol(fig,'Parent',panel,'Style','text','String','Y','Position',[60 10 20 20]);
        uicontrol(fig,'Parent',panel,'Style','pushbutton','String','^','Position',[80 10 20 20],'Callback',@callback__Y_inc_button_pushed);
        uicontrol(fig,'Parent',panel,'Style','pushbutton','String','v','Position',[100 10 20 20],'Callback',@callback__Y_dec_button_pushed);
        uicontrol(fig,'Parent',panel,'Style','text','String','W','Position',[120 10 20 20]);
        uicontrol(fig,'Parent',panel,'Style','pushbutton','String','<','Position',[140 10 20 20],'Callback',@callback__W_dec_button_pushed);
        uicontrol(fig,'Parent',panel,'Style','pushbutton','String','>','Position',[160 10 20 20],'Callback',@callback__W_inc_button_pushed);
        uicontrol(fig,'Parent',panel,'Style','text','String','H','Position',[180 10 20 20]);
        uicontrol(fig,'Parent',panel,'Style','pushbutton','String','^','Position',[200 10 20 20],'Callback',@callback__H_inc_button_pushed);
        uicontrol(fig,'Parent',panel,'Style','pushbutton','String','v','Position',[220 10 20 20],'Callback',@callback__H_dec_button_pushed);
        uicontrol(fig,'Parent',panel,'Style','text','String',sprintf('dx: %g',step_delta),'Position',[250 10 40 20]);
        uicontrol(fig,'Parent',panel,'Style','pushbutton','String','^','Position',[290 10 20 20],'Callback',@callback__step_delta_inc_button_pushed);
        uicontrol(fig,'Parent',panel,'Style','pushbutton','String','v','Position',[310 10 20 20],'Callback',@callback__step_delta_dec_button_pushed);
        
        if frameObj.ndx > 0
            p2 = uipanel('Position',[0.05 0.03 0.9 0.055]);
            uicontrol(fig,'Parent',p2,'Style','pushbutton','String','Analyze Movement','Position',[10 10 100 20],'Callback',@callback__analyze_movement_button_pushed);
            uicontrol(fig,'Parent',p2,'Style','text','String',sprintf('Smooth (red): %g',param_window_size),'Position',[125 10 90 20]);
            uicontrol(fig,'Parent',p2,'Style','slider','Min',1,'Max',50,'Value',param_window_size,'Position', [215 10 100 20],'Callback', @callback__slider_smooth_button_pushed); 
            uicontrol(fig,'Parent',p2,'Style','text','String',sprintf('Window: %g',analysis.wnsz_x),'Position',[315 10 80 20]);
            uicontrol(fig,'Parent',p2,'Style','slider','Min',1,'Max',50,'Value',analysis.wnsz_x,'Position', [390 10 100 20],'Callback', @callback__slider_window_x_button_pushed); 
            uicontrol(fig,'Parent',p2,'Style','text','String',sprintf('Threshold: %g',analysis.threshold),'Position',[490 10 80 20]);
            uicontrol(fig,'Parent',p2,'Style','slider','Min',0,'Max',50,'Value',analysis.threshold,'Position', [570 10 100 20],'Callback', @callback__slider_threshold_button_pushed); 
            uicontrol(fig,'Parent',p2,'Style','text','String',sprintf('Total Movement time: %g',total_movement_time),'Position',[685 0 100 35]);
            uicontrol(fig,'Parent',p2,'Style','text','String',sprintf('Movement AUC: %g',movement_AUC),'Position',[785 0 100 35]);
            uicontrol(fig,'Parent',p2,'Style','pushbutton','String','Save Data','Position',[885 10 100 20],'Callback',@callback__save_data_button_pushed);

            uicontrol(fig,'Parent',p2,'Style','text','String','Start/End Time:','Position',[1000 10 75 20]);
            uicontrol(fig,'Parent',p2,'Style','edit','String',analysis_startstop.start,'Position',[1075 10 50 20],'Callback',@callback__start_time_changed);
            uicontrol(fig,'Parent',p2,'Style','edit','String',analysis_startstop.stop,'Position',[1125 10 50 20],'Callback',@callback__stop_time_changed);
            
            p3 = uipanel('Position',[0.7 0.465 0.25 0.05],'BorderType','none');
            uicontrol(fig,'Parent',p3,'Style','pushbutton','String','Start Playback','Position',[0 10 200 20],'Callback',@callback__start_playback_button_pushed);
        end
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function callback__start_time_changed(h,~)
        analysis_startstop.start = str2double(h.String);
        fprintf('callback__start_time_changed(%g)\n',analysis_startstop.start)
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function callback__stop_time_changed(h,~)
        analysis_startstop.stop = str2double(h.String);
        fprintf('callback__stop_time_changed(%g)\n',analysis_startstop.stop)
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function callback__start_playback_button_pushed(~,~)
        run_analysis__draw() %HERE
        uiwait(msgbox('Click on the plot at the time to start playback'))
        [x,~] = ginput(1);
        fprintf('start playback t=%g\n',x)
        playback_continue=1;
        run_playback(x)
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function callback__slider_smooth_button_pushed(h,~)
        if param_window_size > h.Value
            param_window_size = floor(h.Value);
        else
            param_window_size = ceil(h.Value);
        end
        run_analysis__analyze_movement__draw()
    end
    function callback__slider_window_x_button_pushed(h,~)
        if analysis.wnsz_x > h.Value
            analysis.wnsz_x = floor(h.Value);
        else
            analysis.wnsz_x = ceil(h.Value);
        end
        run_analysis__analyze_movement__draw()
    end
    function callback__slider_threshold_button_pushed(h,~)
        if analysis.threshold > h.Value
            analysis.threshold = floor(h.Value);
        else
            analysis.threshold = ceil(h.Value);
        end
        run_analysis__analyze_movement__draw()
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function draw_stop_playback_button()
        p1 = uipanel('Position',[0.05 0.465 0.35 0.05],'BorderType','none');
        uicontrol(fig,'Parent',p1,'Style','pushbutton','String','Stop Playback','Position',[0 10 200 20],'Callback',@callback__stop_playback_button_pushed);   
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function draw_stop_button()
        p1 = uipanel('Position',[0.05 0.465 0.35 0.05],'BorderType','none');
        uicontrol(fig,'Parent',p1,'Style','pushbutton','String','Pause Processing','Position',[0 10 200 20],'Callback',@callback__stop_button_pushed);   
        uicontrol(fig,'Parent',p1,'Style','pushbutton','String','FF Processing to End','Position',[200 10 200 20],'Callback',@callback__FF_processing_button_pushed);   
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function callback__analyze_movement_button_pushed(~,~)
        run_analysis__analyze_movement__draw()
    end
    function callback__save_data_button_pushed(~,~)
        [~,infile_name,~] = fileparts(filename);
        crop_name = sprintf('%g_%g_%g_%g',crop_rect(1),crop_rect(2),crop_rect(3),crop_rect(4));
        [fname,path,filterindex] = uiputfile({'*-dataset.mat';'*.mat'},'Save Data',sprintf('Tadpole_Analysis-%s-%s.mat',infile_name,crop_name));
        if(filterindex>0)
            savefile=strcat(path,fname);
            s.filename = filename;
            s.crop_rect = crop_rect;
            s.chng_v_time = chng_v_time;
            s.time_v_time = time_v_time;
            s.smoothed_chng_v_time = smooth(chng_v_time,param_window_size); 
            s.movement_detected = movement_detected;
            s.total_movement_time = total_movement_time;
            s.circ_bounds = circ_bounds;
            s.analysis_startstop = analysis_startstop;
            s.movement_AUC = movement_AUC;                      %#ok<STRNU>
            save(savefile,'-STRUCT','s');
        end
    end
    function callback__step_delta_dec_button_pushed(~,~)
        step_delta = step_delta - 1;
        run_analysis__draw()
        draw_play_button()
    end
    function callback__step_delta_inc_button_pushed(~,~)
        step_delta = step_delta + 1;
        run_analysis__draw()
        draw_play_button()
    end
    function callback__X_dec_button_pushed(~,~)
        circ_bounds.y = circ_bounds.y +step_delta;
        run_analysis__draw()
        draw_play_button()
    end
    function callback__X_inc_button_pushed(~,~)
        circ_bounds.y = circ_bounds.y -step_delta;
        run_analysis__draw()
        draw_play_button()
    end
    function callback__Y_dec_button_pushed(~,~)
        circ_bounds.x = circ_bounds.x -step_delta;
        run_analysis__draw()
        draw_play_button()
    end
    function callback__Y_inc_button_pushed(~,~)
        circ_bounds.x = circ_bounds.x +step_delta;
        run_analysis__draw()
        draw_play_button()
    end
    function callback__W_dec_button_pushed(~,~)
        circ_bounds.w = circ_bounds.w -step_delta;
        run_analysis__draw()
        draw_play_button()
    end
    function callback__W_inc_button_pushed(~,~)
        circ_bounds.w = circ_bounds.w +step_delta;
        run_analysis__draw()
        draw_play_button()
    end
    function callback__H_dec_button_pushed(~,~)
        circ_bounds.h = circ_bounds.h -step_delta;
        run_analysis__draw()
        draw_play_button()
    end
    function callback__H_inc_button_pushed(~,~)
        circ_bounds.h = circ_bounds.h +step_delta;
        run_analysis__draw()
        draw_play_button()
    end
    function plot_circle(f)
        %fprintf('circ_bounds = [%g,%g,%g,%g]\n',circ_bounds.x,circ_bounds.y,circ_bounds.w,circ_bounds.h)
        f5sz = size(f.f5);
        %fprintf('size(frameObj.f5) = %g\n',size(frameObj.f5))
        x1 = -1*ceil(f5sz(1)/2) + circ_bounds.x;
        x2 = x1+f5sz(1)-1;
        y1 = -1*ceil(f5sz(2)/2) + circ_bounds.y;
        y2 = y1+f5sz(2)-1;
        %fprintf('circ dims = [%g,%g,%g,%g]\n',x1,x2,y1,y2)
        [X,Y] = meshgrid(y1:y2,x1:x2);
        Z = (X.^2)/circ_bounds.w + (Y.^2)/circ_bounds.h;
        %fprintf('size(Z) = %g\n',size(Z))
        OUTPUT = zeros(f5sz(1),f5sz(2),3);
        Z2 = f.f5;
        %fprintf('size(Z2) = %g\n',size(Z2))
        circle_mask = Z>40;
        Z2(circle_mask) = 150;
        OUTPUT(:,:,1) = f.f5;
        OUTPUT(:,:,2) = f.f5;
        OUTPUT(:,:,3) = Z2;
        imshow(OUTPUT)
    end
    function plot_difference(f)
        Z2 = f.d;
        Z2(circle_mask) = 150;
        OUTPUT(:,:,1) = f.d;
        OUTPUT(:,:,2) = f.d;
        OUTPUT(:,:,3) = Z2;
        imshow(OUTPUT)
    end
    function callback__start_over_button_pushed(~,~)
        processing_continue=0;
        get_cropping_rect()
    end
    function callback__calculate_tadpole_volume(~,~)
        get_volume_measurement__step1();
    end
    function callback__calculate_tadpole_volume__reset(~,~)
        % when done, reset
        run_analysis__draw()
        draw_play_button()
    end
    function callback__play_button_pushed(~,~)
        processing_continue=1;
        show_plots = 1;
        total_movement_time = '';
        movement_AUC = '';
        run_analysis()
    end
    function callback__stop_playback_button_pushed(~,~)
        playback_continue=0;
        pause(0.2)
        run_analysis__draw()
        draw_play_button()
    end
    function callback__stop_button_pushed(~,~)
        processing_continue=0;
        pause(0.2)
        run_analysis__draw()
        draw_play_button()
    end
    function callback__reset_button_pushed(~,~)
        processing_continue=0;
        initialize_analysis()
        run_analysis__draw()
        draw_play_button()
    end
    function callback__FF_processing_button_pushed(~,~)
        show_plots = 0;
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%                
    function initialize_analysis_window()
        fprintf('initialize_analysis_window\n')
        initialize_analysis()
        run_analysis__read_frame();
        run_analysis__draw()
        draw_play_button()
        fprintf('initialize_analysis_window ...  done\n')
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function initialize_playback(start_time)
        VidPlayBackObj =  VideoReader(filename,'CurrentTime',start_time);
        fprintf('initializing playback to %g (start_time=%g)\n',VidPlayBackObj.CurrentTime,start_time)
        PlaybackFrameObj.d = zeros(crop_rect(4)+1,crop_rect(3)+1);
        PlaybackFrameObj.ndx = 0;
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function initialize_analysis()
        VidObj =  VideoReader(filename);
        frameObj.ndx = 0;
        frameObj.d = zeros(crop_rect(4)+1,crop_rect(3)+1);
        chng_v_time = [];
        time_v_time = [];
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%                
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%                
    function success = run_analysis__read_frame()
        try
            frameObj.f = readFrame(VidObj);
        catch
            warning('Unexpected End of file'); 
            success = 0;
            return
        end
        success = 1;
        
        frameObj.f2 = frameObj.f(crop_rect(2):(crop_rect(2)+crop_rect(4)),crop_rect(1):(crop_rect(1)+crop_rect(3)),:);
        frameObj.f3 = rgb2gray(frameObj.f2);
        frameObj.f4 = imcomplement(frameObj.f3);
        frameObj.f5 = frameObj.f4;
        frameObj.f5(frameObj.f5<200) = 0;
        
        if frameObj.ndx>1
            frameObj.d = frameObj.last_frame-frameObj.f5;
            frameObj.d(circle_mask) = 0;
            chng = nnz(frameObj.d);
            % if frame is the same, read the next frame.
            if chng == 0
                try
                    frameObj.f = readFrame(VidObj);
                catch
                    warning('Unexpected End of file'); 
                    success = 0;
                    return
                end
                frameObj.f2 = frameObj.f(crop_rect(2):(crop_rect(2)+crop_rect(4)),crop_rect(1):(crop_rect(1)+crop_rect(3)),:);
                frameObj.f3 = rgb2gray(frameObj.f2);
                frameObj.f4 = imcomplement(frameObj.f3);
                frameObj.f5 = frameObj.f4;
                frameObj.f5(frameObj.f5<200) = 0;
                frameObj.d = frameObj.last_frame-frameObj.f5;
                frameObj.d(circle_mask) = 0;
            end
        end
        frameObj.ndx = frameObj.ndx + 1;
        frameObj.last_frame = frameObj.f5;
        return
    end    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%                
    function success = run_playback__read_frame()
        try
            PlaybackFrameObj.f = readFrame(VidPlayBackObj);
        catch
            warning('Unexpected End of file'); 
            success = 0;
            return
        end
        success = 1;
        
        PlaybackFrameObj.f2 = PlaybackFrameObj.f(crop_rect(2):(crop_rect(2)+crop_rect(4)),crop_rect(1):(crop_rect(1)+crop_rect(3)),:);
        PlaybackFrameObj.f3 = rgb2gray(PlaybackFrameObj.f2);
        PlaybackFrameObj.f4 = imcomplement(PlaybackFrameObj.f3);
        PlaybackFrameObj.f5 = PlaybackFrameObj.f4;
        PlaybackFrameObj.f5(PlaybackFrameObj.f5<200) = 0;
        
        if PlaybackFrameObj.ndx>1
            PlaybackFrameObj.d = PlaybackFrameObj.last_frame-PlaybackFrameObj.f5;
            PlaybackFrameObj.d(circle_mask) = 0;
            chng = nnz(PlaybackFrameObj.d);
            %if chng == 0
            %    return
            %end
        end
        PlaybackFrameObj.ndx = PlaybackFrameObj.ndx + 1;
        PlaybackFrameObj.last_frame = PlaybackFrameObj.f5;
        return
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%                
    function run_analysis__draw()
        fig=figure(1);clf;set(fig,'MenuBar','none');
        run_analysis__plot()
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%                
    function run_analysis__analyze_movement__draw()
        fig=figure(1);clf;set(fig,'MenuBar','none');
        run_analysis__plot()
        %%%%%
        fprintf('analysis_startstop = %g/%g\n',analysis_startstop.start, analysis_startstop.stop)
        %%%%%
        smoothed_chng_v_time = smooth(chng_v_time,param_window_size);
        movement_detected = zeros(size(smoothed_chng_v_time));
        %%%%%
        for i=1:size(smoothed_chng_v_time)-analysis.wnsz_x
            if analysis_startstop.start > time_v_time(i)
                continue;
            elseif analysis_startstop.stop < time_v_time(i)
                continue;
            end
            variation =  max(smoothed_chng_v_time(i:i+analysis.wnsz_x)) - min(smoothed_chng_v_time(i:i+analysis.wnsz_x));
            if variation > analysis.threshold
                movement_detected(i) = variation;
            end
        end
        %%%%%
        hold on
        yl = ylim();
        if analysis_startstop.start > 0
            fprintf('start: bar(%g,%g,%g)\n',analysis_startstop.start/2,yl(2),analysis_startstop.start)
            bar(analysis_startstop.start/2,yl(2),analysis_startstop.start,'FaceColor',[0.7,0,0],'FaceAlpha',0.2)
        end
        plot(time_v_time,movement_detected,'-g')
        if analysis_startstop.stop < time_v_time(end)
            w = time_v_time(end) - analysis_startstop.stop;
            fprintf('stop: bar(%g,%g,%g)\n',time_v_time(end) - w/2,yl(2),w)
            bar(time_v_time(end) - w/2,yl(2),w,'FaceColor',[0.7,0,0],'FaceAlpha',0.2)
        end
        hold off
        %%%%%%
        diff_time = diff(time_v_time);
        total_movement_time = sum(diff_time(movement_detected > 0));
        movement_AUC = trapz(time_v_time,movement_detected);
        %%%%%%
        draw_play_button()
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%                
    function run_analysis__plot()
        subplot(2,3,1)
        imshow(frameObj.f2)
        subplot(2,3,2)
        plot_circle(frameObj)
        subplot(2,3,3)
        plot_difference(frameObj)
        subplot(2,3,[4 5 6])
        plot(time_v_time,chng_v_time, '-b')
        if frameObj.ndx>param_window_size
            hold on
            plot(time_v_time,smooth(chng_v_time,param_window_size),'-r')
            hold off
        end
        drawnow
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%                
    function run_playback__plot(x)
        subplot(2,3,1)
        imshow(PlaybackFrameObj.f2)
        subplot(2,3,2)
        plot_circle(PlaybackFrameObj)
        subplot(2,3,3)
        plot_difference(PlaybackFrameObj)
        subplot(2,3,[4 5 6])
        plot(time_v_time,chng_v_time, '-b')
        hold on
        if frameObj.ndx>param_window_size
            plot(time_v_time,smooth(chng_v_time,param_window_size),'-r')
        end
        yl = ylim();
        plot([x,x],[yl(1),yl(2)],'-k')
        hold off
        drawnow
        draw_stop_playback_button()
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%                
    function run_playback(start_time)
        initialize_playback(start_time)
        while playback_continue && hasFrame(VidPlayBackObj)
            if ~run_playback__read_frame()
                fprintf('stopping\n');
                break
            end
            run_playback__plot(VidPlayBackObj.CurrentTime)
        end
        
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%                
    function run_analysis()
        run_analysis__draw()
        draw_stop_button()
        last_reported_precent = 0;
        while processing_continue && hasFrame(VidObj)
            if VidObj.CurrentTime/VidObj.Duration*100 > last_reported_precent
                if ~isempty(time_v_time)
                    fprintf('Progress %g%%\t\t vid:%g rec:%g ndx=%g\n',floor(VidObj.CurrentTime/VidObj.Duration*100),VidObj.CurrentTime, time_v_time(end),frameObj.ndx)
                else
                    fprintf('Progress %g%%\t\t vid:%g rec:%g ndx=%g\n',floor(VidObj.CurrentTime/VidObj.Duration*100),VidObj.CurrentTime, 0,frameObj.ndx)
                end
                last_reported_precent = last_reported_precent + 1;
            end
            
            if ~run_analysis__read_frame()
                fprintf('stopping\n');
                break
            end
            if frameObj.ndx>1
                chng = nnz(frameObj.d);
                %if chng == 0
                %    continue
                %end
                %fprintf('t=%i\t\tchange=%i\n',frameObj.ndx,chng)
                chng_v_time(frameObj.ndx) = chng;
                time_v_time(frameObj.ndx) = VidObj.CurrentTime;
                analysis_startstop.stop = VidObj.CurrentTime;

                if show_plots
                    run_analysis__plot()
                    %draw_stop_button()
                end
            end
        end
        run_analysis__plot()
        draw_play_button()
        
    end%run_analysis()
end



