function test_activation()
    % Test the activation and deactivation of the hands
    hands  = init_hands();
    disp(readline(hands));
    
    activate(hands);
    action(hands, 1);
    pause(5);
    action(hands, 2);
    pause(5);
    deactivate(hands);
    pause(0.5);
    
    disp("Testing if the action is possible when deactivated: should do nothing");
    write(hands, 'c', "char"); % Checks if the hands are activated
    disp(readline(hands))
    action(hands, 1);
    pause(1);  
    action(hands, 2);
    clear hands;
end 





