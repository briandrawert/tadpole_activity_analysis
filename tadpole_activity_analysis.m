close all;clear all;clc;
%
function tadpole_1(varargin)
    close all;
    %filename = '/Users/brian/Desktop/tadpole_activity_video/DSCF0001.AVI';
    filename = uigetfile('*.avi;*.AVI','Select Video File','MultiSelect', 'off');
    chng_v_time = [];
    param_window_size = 5;
    param_floor = 0;
    crop_rect = [];
    show_plots = 1;
    circ_bounds = struct('X',0,'y',0,'h',0,'w',0);
    %num_frames = 0;
    fig=[];
    VidObj = [];
    playback_continue = 1;
    frameObj = struct('f',[],'f2',[],'f3',[],'f4',[],'f5',[],'d',[],...
        'lastFrame',[],'ndx',0);
    step_delta = 5;
    circle_mask = [];
    
    
    % Run
    get_cropping_rect()

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function get_cropping_rect()
        fprintf('Get cropping rectangle\n')
        fig=figure(1);clf;set(fig,'MenuBar','none');
        v =  VideoReader(filename);
        f = readFrame(v);
        imshow(f)
        cur_pos = get(fig,'Position');
        set(fig,'Position',[ 31 31 cur_pos(3) cur_pos(4)]);
        uiwait(msgbox('Draw rectangle around area to analyze'))
        crop_rect = getrect;
        circ_bounds.x = 0;
        circ_bounds.y = 0;
        circ_bounds.h = crop_rect(3);
        circ_bounds.w = crop_rect(4);
        %fprintf('\t%g\n',crop_rect)
        initialize_analysis_window()
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%                
    function draw_play_button()
        uicontrol(fig,'Style','pushbutton','String','Play','Position',[150 380 200 20],'Callback',@callback__play_button_pushed);
        uicontrol(fig,'Style','pushbutton','String','Reset','Position',[350 380 200 20],'Callback',@callback__reset_button_pushed);
        uicontrol(fig,'Style','pushbutton','String','Start Over','Position',[550 380 200 20],'Callback',@callback__start_over_button_pushed);

        %uicontrol(fig,'Style','text','String','Use arrow keys to move image around, hold shift to change size','Position',[800 380 400 20]);
        %set(fig,'KeyPressFcn',@draw_play_button__keydown);
        uicontrol(fig,'Style','text','String','Adjust Blue Clipping Region','Position',[800 400 200 20]);
        uicontrol(fig,'Style','text','String','X','Position',[800 380 20 20]);
        uicontrol(fig,'Style','pushbutton','String','<','Position',[820 380 20 20],'Callback',@callback__X_dec_button_pushed);
        uicontrol(fig,'Style','pushbutton','String','>','Position',[840 380 20 20],'Callback',@callback__X_inc_button_pushed);
        uicontrol(fig,'Style','text','String','Y','Position',[860 380 20 20]);
        uicontrol(fig,'Style','pushbutton','String','^','Position',[880 380 20 20],'Callback',@callback__Y_inc_button_pushed);
        uicontrol(fig,'Style','pushbutton','String','v','Position',[900 380 20 20],'Callback',@callback__Y_dec_button_pushed);
        uicontrol(fig,'Style','text','String','W','Position',[920 380 20 20]);
        uicontrol(fig,'Style','pushbutton','String','<','Position',[940 380 20 20],'Callback',@callback__W_dec_button_pushed);
        uicontrol(fig,'Style','pushbutton','String','>','Position',[960 380 20 20],'Callback',@callback__W_inc_button_pushed);
        uicontrol(fig,'Style','text','String','H','Position',[980 380 20 20]);
        uicontrol(fig,'Style','pushbutton','String','^','Position',[1000 380 20 20],'Callback',@callback__H_inc_button_pushed);
        uicontrol(fig,'Style','pushbutton','String','v','Position',[1020 380 20 20],'Callback',@callback__H_dec_button_pushed);
        uicontrol(fig,'Style','text','String',sprintf('dx: %g',step_delta),'Position',[1050 380 40 20]);
        uicontrol(fig,'Style','pushbutton','String','^','Position',[1090 380 20 20],'Callback',@callback__step_delta_inc_button_pushed);
        uicontrol(fig,'Style','pushbutton','String','v','Position',[1110 380 20 20],'Callback',@callback__step_delta_dec_button_pushed);

        uicontrol(fig,'Style','pushbutton','String','Save Data','Position',[1150 380 100 20],'Callback',@callback__save_data_button_pushed);
    end%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function draw_stop_button()
        uicontrol(fig,'Style','pushbutton','String','Stop','Position',[150 380 200 20],'Callback',@callback__stop_button_pushed);   
        uicontrol(fig,'Style','pushbutton','String','FF Processing','Position',[350 380 200 20],'Callback',@callback__FF_processing_button_pushed);   
    end
    function callback__save_data_button_pushed(h,event)
        [~,infile_name,~] = fileparts(filename);
        crop_name = sprintf('%g_%g_%g_%g',crop_rect(1),crop_rect(2),crop_rect(3),crop_rect(4));
        [fname,path,filterindex] = uiputfile({'*-dataset.mat';'*.mat'},'Save Data Set',sprintf('Tadpole_Analysis-%s-%s.mat',infile_name,crop_name));
        if(filterindex>0)
            savefile=strcat(path,fname);
            s.filename = filename;
            s.crop_rect = crop_rect;
            s.chng_v_time = chng_v_time;
            s.smoothed_chng_v_time = smooth(chng_v_time,param_window_size); %#ok<STRNU>
            save(savefile,'-STRUCT','s');
        end
    end
    function callback__step_delta_dec_button_pushed(h,event)
        step_delta = step_delta - 1;
        run_analysis__draw()
        draw_play_button()
    end
    function callback__step_delta_inc_button_pushed(h,event)
        step_delta = step_delta + 1;
        run_analysis__draw()
        draw_play_button()
    end
    function callback__X_dec_button_pushed(h,event)
        circ_bounds.y = circ_bounds.y +step_delta;
        run_analysis__draw()
        draw_play_button()
    end
    function callback__X_inc_button_pushed(h,event)
        circ_bounds.y = circ_bounds.y -step_delta;
        run_analysis__draw()
        draw_play_button()
    end
    function callback__Y_dec_button_pushed(h,event)
        circ_bounds.x = circ_bounds.x -step_delta;
        run_analysis__draw()
        draw_play_button()
    end
    function callback__Y_inc_button_pushed(h,event)
        circ_bounds.x = circ_bounds.x +step_delta;
        run_analysis__draw()
        draw_play_button()
    end
    function callback__W_dec_button_pushed(h,event)
        circ_bounds.w = circ_bounds.w -step_delta;
        run_analysis__draw()
        draw_play_button()
    end
    function callback__W_inc_button_pushed(h,event)
        circ_bounds.w = circ_bounds.w +step_delta;
        run_analysis__draw()
        draw_play_button()
    end
    function callback__H_dec_button_pushed(h,event)
        circ_bounds.h = circ_bounds.h -step_delta;
        run_analysis__draw()
        draw_play_button()
    end
    function callback__H_inc_button_pushed(h,event)
        circ_bounds.h = circ_bounds.h +step_delta;
        run_analysis__draw()
        draw_play_button()
    end
    function plot_circle()
        %fprintf('circ_bounds = [%g,%g,%g,%g]\n',circ_bounds.x,circ_bounds.y,circ_bounds.w,circ_bounds.h)
        f5sz = size(frameObj.f5);
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
        Z2 = frameObj.f5;
        %fprintf('size(Z2) = %g\n',size(Z2))
        circle_mask = Z>40;
        Z2(circle_mask) = 150;
        OUTPUT(:,:,1) = frameObj.f5;
        OUTPUT(:,:,2) = frameObj.f5;
        OUTPUT(:,:,3) = Z2;
        imshow(OUTPUT)
    end
    function callback__start_over_button_pushed(h,event)
        playback_continue=0;
        get_cropping_rect()
    end
    function callback__play_button_pushed(h,event)
        playback_continue=1;
        show_plots = 1;
        run_analysis()
    end
    function callback__stop_button_pushed(h,event)
        playback_continue=0;
        pause(0.2)
        run_analysis__draw()
        draw_play_button()
    end
    function callback__reset_button_pushed(h,event)
        playback_continue=0;
        initialize_analysis()
        run_analysis__draw()
        draw_play_button()
    end
    function callback__FF_processing_button_pushed(h,event)
        show_plots = 0;
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%                
    function initialize_analysis_window()
        initialize_analysis()
        run_analysis__read_frame()
        run_analysis__plot()
        draw_play_button()
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    function initialize_analysis()
        VidObj =  VideoReader(filename);
        frameObj.ndx = 0;
        frameObj.d = zeros(crop_rect(4),crop_rect(3));
        chng_v_time = [];
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%                
    function run_analysis__crop_frame()
        frameObj.f2 = frameObj.f(crop_rect(2):(crop_rect(2)+crop_rect(4)),crop_rect(1):(crop_rect(1)+crop_rect(3)),:);
        frameObj.f3 = rgb2gray(frameObj.f2);
        frameObj.f4 = imcomplement(frameObj.f3);
        frameObj.f5 = frameObj.f4;
        frameObj.f5(frameObj.f5<200) = 0;
    end
    function success = run_analysis__read_frame()
        %fprintf('run_analysis__read_frame()');
        try
            frameObj.f = readFrame(VidObj);
        catch
            warning('Unexpected End of file'); 
            success = 0;
            return
        end
        run_analysis__crop_frame()
        success = 1;
        return
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%                
    function run_analysis__draw()
        fig=figure(1);clf;set(fig,'MenuBar','none');
        run_analysis__plot()
        draw_stop_button()
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%                
    function run_analysis__plot()
        subplot(2,3,1)
        imshow(frameObj.f2)
        subplot(2,3,2)
        %imshow(frameObj.f5)
        %hold on
        %zeros(crop_rect(4),crop_rect(3));
        plot_circle()
        %hold off
        subplot(2,3,3)
        imshow(frameObj.d)
        subplot(2,3,[4 5 6])
        plot(chng_v_time, '-b')
        if frameObj.ndx>param_window_size
            hold on
            plot(smooth(chng_v_time,param_window_size),'-r')
            hold off
        end
        %subplot(2,3,6)
        %histogram(chng_v_time)
        drawnow
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%                
    function run_analysis()
        run_analysis__draw()
        last_reported_precent = 0;
        while playback_continue && hasFrame(VidObj)
            if VidObj.CurrentTime/VidObj.Duration*100 > last_reported_precent
                fprintf('Progress %g%%\n',floor(VidObj.CurrentTime/VidObj.Duration*100))
                last_reported_precent = last_reported_precent + 1;
            end
            
            if ~run_analysis__read_frame()
                fprintf('stopping\n');
                break
            end

            if frameObj.ndx>0
                frameObj.d = frameObj.last_frame-frameObj.f5;
                frameObj.d(circle_mask) = 0;
                chng = nnz(frameObj.d);
                if chng == 0
                    continue
                end
                %fprintf('t=%i\t\tchange=%i\n',frameObj.ndx,chng)
                chng_v_time(frameObj.ndx) = chng;

                if show_plots
                    run_analysis__plot()
                    %draw_stop_button()
                end
            end
            frameObj.last_frame = frameObj.f5;
            frameObj.ndx = frameObj.ndx + 1;

        end
        run_analysis__plot()
        draw_play_button()
        
    end%run_analysis()
end



