% Clear the workspace and the screen
close all;
clear;
sca;

data_path = 'data/data/';
model_path = 'data/models/';
result_path = 'data/results/';
resource_path = 'data/resources/';


global_model_file = 'P9FH_HB_T3_model.mat';


% Ask for participant number
participant_number = input('Participant number: ', 's');

filename = strcat(result_path, 'P_', participant_number, '.mat');

% Generate the flanker stimuli
nTrials = 60;
rCongruent = 0.05;
rIncongruent = 0.45;
rRandom = 0.5;
rNeutral = 0.0;
trials = flankersCloud(rCongruent, rIncongruent, rRandom, rNeutral, nTrials);

cap = 64;
prediction_frequency = 0.3;

is_test = false;

% BioSemi triggers
% 120: left good
% 122: right good
% 150: left bad
% 155: right bad
% 200: cross
% 201: stim
% 202: decision
% 203: feedback

% load BCILAB
init_bci_lab;
% Open Biosemi to LSL connection
LibHandle = lsl_loadlib();
[Streaminfos] = lsl_resolve_all(LibHandle);

if ~is_test
    % Init BCI
    
    
    if isempty(Streaminfos)
        cd BioSemi
        system(strcat('BioSemi.exe -c my_config',num2str(cap),'.cfg &'));
        cd ..
        disp('Waiting for you to connect the BioSemi to LSL...');
    end
    while isempty(Streaminfos)
        [Streaminfos] = lsl_resolve_all(LibHandle);
    end
    disp('The BioSemi is linked to LSL');

    %% Visualization
    vis_stream('BioSemi',10,5,150,1:1+cap+8,100,10);

    %% Loading files
    disp('Loading model...')
    global_file = io_load(strcat(model_path,global_model_file));

    disp("Starting the outlet...");
    [bci_outlet,  opts] = init_outlet_global('GlobalModel',global_file.model, 'SourceStream','BioSemi','LabStreamName','BCI','OutputForm','mode','UpdateFrequency',prediction_frequency);


    disp('Initializing the robotic hands...');
    hands = init_hands();
    run_readlsl('new_stream', 'BioSemi','marker_query', '');
    onl_write_background( ...
    'ResultWriter',@(y)action(hands, y),...
    'MatlabStream',opts.in_stream, ...
    'Model',global_file.model, ...
    'OutputFormat',opts.out_form, ...
    'UpdateFrequency',opts.update_freq, ...
    'PredictorName',opts.pred_name, ...
    'PredictAt',opts.predict_at, ...
    'Verbose',opts.verbose, ...
    'StartDelay',0,...
    'EmptyResultValue',[]);

end

% Initialize the marker stream
info = lsl_streaminfo(LibHandle,'MyMarkerStream','Markers',1,0,'cf_string','myuniquesourceid23443');
trigger_outlet = lsl_outlet(info);
disp('Marker stream initialized');

% Open recorder
cd LabRecorder
system('LabRecorder.exe -c my_config.cfg &');
cd ..;
pause(5);


% Set up the keyboard
KbName('UnifyKeyNames');
escapeKey=KbName('ESCAPE');
leftKey=KbName('Space');
rightKey=KbName('RightArrow');

% PTB setup for flankersCloud task

Screen('Preference', 'SkipSyncTests', 0);

opacity = 1;
PsychDebugWindowConfiguration([], opacity)

% Initialize grey
white = WhiteIndex(0);
black = BlackIndex(0);
grey = white / 2;
% Open the screen
[window, windowRect] = PsychImaging('OpenWindow', 1, grey);
Screen('BlendFunction', window, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');


% Get the size of the on screen window
[width, height]= Screen('WindowSize', window);
margin = 300;

% Query the frame duration
ifi = Screen('GetFlipInterval', window);

topPriorityLevel = MaxPriority(window);
Priority(topPriorityLevel);
% Get the centre coordinate of the window
[xCenter, yCenter] = RectCenter(windowRect);

% Set the text size
Screen('TextSize', window, 50);

% Set the duration of the stimuli
cross_duration = round(1.5/ifi);
level_up_duration = round(1/ifi);
flanker_duration = round(0.2/ifi);
decision_duration = round(5/ifi);
check_decision_duration = round(2/ifi);
feedback_duration = round(1/ifi);
press_duration = 6;
afterTrialInterval = round(2/ifi);

% Set up the timing
interTrialInterval=1;

% Set up the data
data=nan(nTrials, 4);

% make textures
% Fixation cross
[img, ~, alpha]=imread(strcat(resource_path,'cross.png'));
img(:,:,4) = alpha;
cross = Screen('MakeTexture', window, img);

% Arrows
[img, ~, alpha]=imread(strcat(resource_path,'left.png'));
img(:,:,4) = alpha;
left_arrow = Screen('MakeTexture', window, img);

[img, ~, alpha]=imread(strcat(resource_path,'right.png'));
img(:,:,4) = alpha;
right_arrow = Screen('MakeTexture', window, img);

[img, ~, alpha]=imread(strcat(resource_path,'neutral.png'));
img(:,:,4) = alpha;
neutral_arrow = Screen('MakeTexture', window, img);

% feedback
[img, ~, alpha]=imread(strcat(resource_path,'check.png'));
img(:,:,4) = alpha;
check = Screen('MakeTexture', window, img);

[img, ~, alpha]=imread(strcat(resource_path,'wrong.png'));
img(:,:,4) = alpha;
wrong = Screen('MakeTexture', window, img);

% level up
[img, ~, alpha]=imread(strcat(resource_path,'level_up.png'));
img(:,:,4) = alpha;
level_up = Screen('MakeTexture', window, img);

DrawFormattedText(window, 'Ready?', 'center', 'center', [54,54,54]);
Screen('Flip', window);
[secs, keyCode, deltaSecs] = KbWait;
while ~strcmp(strcat(KbName(keyCode)),'Return')
    [secs, keyCode, deltaSecs] = KbWait; 
end


vbl = Screen('Flip', window); % initial flip
% Run the flankers tasks
error_rate = 0.0;
level = 0;
for trial = 1:nTrials

    % Update the error rate
    error_rate = update_error_rate(error_rate, data, trial);
    if trial >= 10 && error_rate < 0.35 && mod(trial, 5) == 0
        % Display level up screen
        level = level+1;
        Screen('DrawTexture', window, level_up, [],[],0);
        vbl = Screen('Flip', window, vbl + (level_up_duration - 0.5) * ifi);
    end
    disp(level);
    % Fixation cross and level
    DrawFormattedText(window, ['Level' ' ' num2str(level)], 'center', height*0.1, white);
    Screen('DrawTexture', window, cross, [],[],0);
    

    nArrows = randi([8,15]);
    arrowSizes = randperm(15, nArrows)*10;
    arrowSizes = sort(arrowSizes, 'descend');
    margin=300;
    indices = randperm(20,nArrows);

    % Initializing the positions of the arrows
    positions = zeros(nArrows, 2);
    for j=1:nArrows
        r = mod(indices(j), 5);
        q = floor(indices(j)/5);
        positions(j, 1)=r*(width-2*margin)/4 + margin;
        positions(j, 2)=q*(height-2*margin)/3 + margin;
    end

    % Initializing the directions of the arrows
    random=randi(2);
    if trials(trial)==1
        arrowDirections=random*ones(1, nArrows); % All arrows in the same direction / Congruent
    elseif trials(trial)==2
        if random==1
            arrowDirections=[1 2*ones(1, nArrows-1)]; % All arrows in the same direction except the first one / Incongruent
        else
            arrowDirections=[2 1*ones(1, nArrows-1)];
        end
    elseif trials(trial)==3
        arrowDirections=randi(2, 1, nArrows); % Random directions / Random
    elseif trials(trial)==4
        arrowDirections=[randi(2) 3*ones(1, nArrows-1)]; % Random direction for the middle arrow, other arrows will be replaced by neutral symbols
    end

    % initializing contrasts
    if level >= 1 && level <= 4
        contrasts = rand(1,nArrows)+0.3;
    elseif level > 4
        contrasts = rand(1,nArrows)+0.1;
    else
        contrasts = ones(1,nArrows);
    end

    vbl = Screen('Flip', window, vbl + (afterTrialInterval - 0.5) * ifi);
    % Send cross trigger
    trigger_outlet.push_sample({'cross'});

    % Flanker stimuli
    for j=1:nArrows
        if arrowDirections(j)==1
            Screen('DrawTexture', window, left_arrow, [], [positions(j, 1)-arrowSizes(j)/2, positions(j, 2)-arrowSizes(j)/2, positions(j, 1)+arrowSizes(j)/2, positions(j, 2)+arrowSizes(j)/2], 0, [], contrasts(j));
        elseif arrowDirections(j)==2
            Screen('DrawTexture', window, right_arrow, [], [positions(j, 1)-arrowSizes(j)/2, positions(j, 2)-arrowSizes(j)/2, positions(j, 1)+arrowSizes(j)/2, positions(j, 2)+arrowSizes(j)/2], 0, [], contrasts(j));
        else
            Screen('DrawTexture', window, neutral_arrow, [], [positions(j, 1)-arrowSizes(j)/2, positions(j, 2)-arrowSizes(j)/2, positions(j, 1)+arrowSizes(j)/2, positions(j, 2)+arrowSizes(j)/2], 0, [], contrasts(j));
        end
    end



    vbl = Screen('Flip', window, vbl + (cross_duration - 0.5) * ifi);
    % Send stimulus trigger
    trigger_outlet.push_sample({'stim'});

    % Wait for the hand activation
    Screen('FillRect', window, grey);
    vbl = Screen('Flip', window, vbl + (flanker_duration - 0.5) * ifi);

    % Ask for the decision
    Screen('TextSize', window, 70);
    DrawFormattedText(window, 'Make your move!', 'center',...
        height * 0.50, white);
    
    vbl = Screen('Flip', window, vbl + (flanker_duration - 0.5) * ifi);
    if ~is_test
        activate(hands);
    end
    tStart=GetSecs;
    response = 0;
    while GetSecs-tStart<press_duration
        [keyIsDown, tEnd, keyCode]=KbCheck;
        if keyIsDown
            if keyCode(escapeKey)
                onl_clear;
                if ~is_test
                    deactivate(hands);
                end
                save_data(data, filename);
                sca;
                close all;
                return
            elseif keyCode(leftKey)
                response=1;
                break
            elseif keyCode(rightKey)
                response=2;
                break
            end
        end
    end
    if ~is_test
        buffers = [];
        for l = 1:floor(press_duration*prediction_frequency)
            buffer = readline(hands);
            if ~isempty(buffer)
                buffers = [buffers buffer];
            end
        end
        response = 3;
        if ~isempty(buffers)
            for k = 1:length(buffers)        
                result = splitlines(buffers(k));
                if strcmp(result(1),'left')
                    response = 1;
                elseif strcmp(result(1),'right')
                    response = 2;
                end
            end
        end
    else
        response = 3;
    end
    if ~is_test
        deactivate(hands);
    end
    % Send triggers
    if response==1
        if arrowDirections(1)==1
            outcome = 120;
            trigger_outlet.push_sample({'left_good'});
        else
            outcome = 150;
            trigger_outlet.push_sample({'left_bad'});
        end
    elseif response==2
        if arrowDirections(1)==2
            outcome = 122;
            trigger_outlet.push_sample({'right_good'});
        else
            outcome = 155;
            trigger_outlet.push_sample({'right_bad'});
        end
    else
        outcome = 130;
        trigger_outlet.push_sample({'no_response'});
    end
    
    % Ask if it was the decision they wanted to take
    Screen('TextSize', window, 70);
    if outcome == 120 || outcome == 150
        arrow = left_arrow;
        DrawFormattedText(window, 'You chose', 'center',...
            height * 0.25, white);
    elseif outcome == 122 || outcome == 155
        arrow = right_arrow;
        DrawFormattedText(window, 'You chose', 'center',...
            height * 0.25, white);
    elseif outcome == 130
        DrawFormattedText(window, 'No response', 'center',...
            height * 0.25, white);
    end
    DrawFormattedText(window, 'Was it the decision you wanted to make?', 'center',...
        height * 0.50, white);
    DrawFormattedText(window, 'Yes (y) or No (n)', 'center',...
        height * 0.75, white);
    if outcome ~= 130
        Screen('DrawTexture', window, arrow, [], [width/2 + 200, height * 0.25 - 75, width/2+300, height * 0.25 + 25]);
    end
    Screen('Flip', window, vbl + (decision_duration - 0.5) * ifi);


    while true
        [keyIsDown, tEnd, keyCode]=KbCheck;
        if keyIsDown
            if keyCode(escapeKey)
                onl_clear;
                if ~is_test
                    deactivate(hands);
                end
                save_data(data, filename);
                sca;
                close all;
                return
            elseif keyCode(KbName('y'))
                break
            elseif keyCode(KbName('n'))
                break
            end
        end
    end

    % Fixation cross

    Screen('DrawTexture', window, cross, [],[],0);    
    vbl = Screen('Flip', window);
    

    % Show feedback
    if outcome == 120 || outcome == 122
        Screen('DrawTexture', window, check, [],[],0);
    elseif outcome == 150 || outcome == 155
        Screen('DrawTexture', window, wrong, [],[],0);
    else
        DrawFormattedText(window, 'No response', 'center',...
            height * 0.50, white);
    end
    

    vbl = Screen('Flip', window, vbl + (cross_duration - 0.5) * ifi);
    % Send trigger for feedback
    trigger_outlet.push_sample({'feedback'});
    
    %% Show the arrows and circle the biggest one
    for j=1:nArrows
        if arrowDirections(j)==1
            Screen('DrawTexture', window, left_arrow, [], [positions(j, 1)-arrowSizes(j)/2, positions(j, 2)-arrowSizes(j)/2, positions(j, 1)+arrowSizes(j)/2, positions(j, 2)+arrowSizes(j)/2], 0, [], contrasts(j));
        elseif arrowDirections(j)==2
            Screen('DrawTexture', window, right_arrow, [], [positions(j, 1)-arrowSizes(j)/2, positions(j, 2)-arrowSizes(j)/2, positions(j, 1)+arrowSizes(j)/2, positions(j, 2)+arrowSizes(j)/2], 0, [], contrasts(j));
        else
            Screen('DrawTexture', window, neutral_arrow, [], [positions(j, 1)-arrowSizes(j)/2, positions(j, 2)-arrowSizes(j)/2, positions(j, 1)+arrowSizes(j)/2, positions(j, 2)+arrowSizes(j)/2], 0, [], scontrasts(j));
        end
    end
    % Circle the biggest arrow, the first one
    Screen('FrameOval', window, white, [positions(1, 1)-arrowSizes(1)/2 - 20, positions(1, 2)-arrowSizes(1)/2 - 20, positions(1, 1) + arrowSizes(1)/2 + 20, positions(1, 2)+ arrowSizes(1)/2 + 20], 10);

    vbl = Screen('Flip', window, vbl + (feedback_duration - 0.5) * ifi);

    % Store the data
    data(trial, 1) = trials(trial);
    data(trial, 2) = response;
    data(trial, 3) = arrowDirections(1);
    data(trial, 4) = outcome;
    
    flush(hands);
end

% save the data

save_data(data, filename);
onl_clear;
sca;
close all;

function save_data(data, filename)
    save(filename, 'data');
end

function error_rate = update_error_rate(error_rate, data, trial)
    if trial == 1
        error_rate = 0.0;
    elseif trial <= 11
        error_rate = (error_rate*(trial-2) + 1*(1-(data(trial-1,2) == data(trial-1, 3))))/(trial-1);
    else
        error_rate = (error_rate*10 - 1*(1-(data(trial - 11, 2) == data(trial-11,3))) + 1*(1-(data(trial-1,2) == data(trial-1, 3))))/10;
    end 
 end