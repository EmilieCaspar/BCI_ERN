function get_online_accuracy(data_file, model_file)
    % get_online_accuracy: Get the accuracy of the online prediction
    %   threshold: The threshold for the feedback
    %   file: The file containing the data
    data_path = 'data/data/';
    model_path = 'data/models/';
    
    disp(model_file);
    init_bci_lab();
    data = io_loadset(strcat(data_path,data_file,'.xdf'));
    model = utl_loadmodel(strcat(model_path, model_file, '.mat'));
    [predictions,loss,stats,targets] = bci_predict(model, data, 'Format', 'mode');
    % Compute confusion matrix and F1 score
    confusion_matrix = confusionmat(targets, predictions);
    statsOfMeasure(confusion_matrix,1);

end

function [stats] = statsOfMeasure(confusion, verbatim)
% The input 'confusion' is the the output of the Matlab function
% 'confusionmat'
% if 'verbatim' = 1; output the generated table in the command window
% confusion: 3x3 confusion matrix
tp = [];
fp = [];
fn = [];
tn = [];
len = size(confusion, 1);
for k = 1:len                  %  predict
    % True positives           % | x o o |
    tp_value = confusion(k,k); % | o o o | true
    tp = [tp, tp_value];       % | o o o |
                                               %  predict
    % False positives                          % | o o o |
    fp_value = sum(confusion(:,k)) - tp_value; % | x o o | true
    fp = [fp, fp_value];                       % | x o o |
                                               %  predict
    % False negatives                          % | o x x |
    fn_value = sum(confusion(k,:)) - tp_value; % | o o o | true
    fn = [fn, fn_value];                       % | o o o |
                                                                       %  predict
    % True negatives (all the rest)                                    % | o o o |
    tn_value = sum(sum(confusion)) - (tp_value + fp_value + fn_value); % | o x x | true
    tn = [tn, tn_value];                                               % | o x x |
end
% Statistics of interest for confusion matrix
prec = tp ./ (tp + fp); % precision
sens = tp ./ (tp + fn); % sensitivity, recall
spec = tn ./ (tn + fp); % specificity
acc = sum(tp) ./ sum(sum(confusion));
f1 = (2 .* prec .* sens) ./ (prec + sens);
% For micro-average
microprec = sum(tp) ./ (sum(tp) + sum(fp)); % precision
microsens = sum(tp) ./ (sum(tp) + sum(fn)); % sensitivity, recall
microspec = sum(tn) ./ (sum(tn) + sum(fp)); % specificity
microacc = acc;
microf1 = (2 .* microprec .* microsens) ./ (microprec + microsens);
% Names of the rows
name = ["true_positive"; "false_positive"; "false_negative"; "true_negative"; ...
    "precision"; "sensitivity"; "specificity"; "accuracy"; "F-measure"];

name = table(name, 'VariableNames', ["name"]);
% Names of the columns
varNames = ["name", "classes", "macroAVG", "microAVG"];
% Names of the classes
classes = ["left"; "right"; "rest"];
% Values of the columns for each class
values = [tp; fp; fn; tn; prec; sens; spec; repmat(acc, 1, len); f1];
classes = array2table(values, 'VariableNames', classes);
% Macro-average
macroAVG = mean(values, 2);
% Micro-average
microAVG = [macroAVG(1:4); microprec; microsens; microspec; microacc; microf1];
% OUTPUT: final table
stats = table(name, classes, macroAVG, microAVG, 'VariableNames',varNames);
if verbatim
    stats
end
end