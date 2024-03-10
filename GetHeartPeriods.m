function [outputArray, numValidPeriods] = GetHeartPeriods(inputName, inputAudio, inputFs, inputAge, directory, startThreshold, endThreshold)
%GETHEARTPERIODS Gets valid heart beat periods for input params
%
%   input name of audio file
%   input audio array
%   input audio sample rate
%   input age range
%   input directory of output files
%   input starting threshold for onset detection
%   input ending threshold for onset detection
%
%   outputs the array of the separated audio data
%   outputs the number of valid audio periods

    %set to 1 if you wish to plot figures for extracted audio
    plotThePeriods = 0;

    %set to 1 if you wish to play the extracted audio
    playThePeriods = 0;

    fws = 10; %window size

    %set the minimum onsets per audio file (unless reaches minimum threshold)
    minValidPeriods = 5;
    
    %https://www.ucsfbenioffchildrens.org/medical-tests/pulse#:~:text=Normal%20Results&text=Newborns%200%20to%201%20month,to%20120%20beats%20per%20minute
    heartRates = struct();
    heartRates.neonate.lb = 70;
    heartRates.neonate.ub = 190;
    heartRates.infant.lb = 80;
    heartRates.infant.ub = 160;
    heartRates.child.lb = 70;
    heartRates.child.ub = 130;
    heartRates.adult.lb = 60;
    heartRates.adult.ub = 100;

    %set threshold to the starting threshhold
    threshold = startThreshold;

    %get correct valid heart period times (seconds)
    if contains(inputAge, "Neonate")
        minHB = 60/heartRates.neonate.lb;
        maxHB = 60/heartRates.neonate.ub;
    elseif contains(inputAge, "Infant")
        minHB = 60/heartRates.infant.lb;
        maxHB = 60/heartRates.infant.ub;
    elseif contains(inputAge, "Child")
        minHB = 60/heartRates.child.lb;
        maxHB = 60/heartRates.child.ub;
    else
        minHB = 60/heartRates.adult.lb;
        maxHB = 60/heartRates.adult.ub;
    end

    %create struct for output audio data
    numValidPeriods = 0;
    outputArray = struct();

    %lowpass audio at the highest heart period
    tempAudio = lowpass(inputAudio, 60/maxHB, inputFs,'Steepness',0.95);
    %rescale audio
    tempAudio = rescale(tempAudio, -1, 1);

    %get the melspectrogram data for the flux
    [tempS,tempCF,tempT] = melSpectrogram(tempAudio,inputFs);

    %get the spectral flux from the melspectrogram data
    tempFlux = spectralFlux(tempS, tempCF);

    %lowpass the flux
    tempFlux = lowpass(tempFlux, 100, inputFs);

    %remove any outliers and fill with the previous data value
    tempFlux = filloutliers(tempFlux,"previous");

    %get the absolute value of the flux
    tempFlux = abs(tempFlux);

    %rescale flux
    tempFlux = rescale(tempFlux, 0, 1);
    
    %create logic array for local maxima, using the window of 100
    lmax = islocalmax(tempFlux, "MinSeparation",fws); 
    
    %index the values at the local maxima
    lMaxValues = tempFlux(lmax);

    %index the times for the local maxima
    lMaxTimes = tempT(lmax); 

    %loop while the threshhold is above the end threshold and the period
    %number is below the minimum
    while (threshold>=endThreshold)&&(numValidPeriods<=minValidPeriods)

        %find when the local maxxima values are above the threshhold, and
        %index the onset times
        onsets = lMaxValues > threshold; 
        onsetTime = lMaxTimes(onsets);

        %for all onsets (minus the last onset)
        for j=1:length(onsetTime)-1
            %check the onsets are valid entries
            if(onsetTime(j)>0)&&(onsetTime(j+1)>0)

                %check that the onsets are valid for the typical age range
                %of heart rate periods
                if (((onsetTime(j+1)-onsetTime(j))*inputFs) <= (minHB*inputFs))&&((onsetTime(j+1)-onsetTime(j))*inputFs) >= (maxHB*inputFs)

                    %add entry and separate the audio to the length of the
                    %extracted audio
                    numValidPeriods = numValidPeriods+1;
                    newAudio = inputAudio(ceil(onsetTime(j)*inputFs):ceil(onsetTime(j+1)*inputFs));
                    %rescale audio
                    newAudio = rescale(newAudio,-1,1);

                    %save audio data to output array
                    newName = directory + inputName + numValidPeriods + ".wav";
                    outputArray(numValidPeriods).filename = newName;
                    outputArray(numValidPeriods).audio = newAudio;
                    outputArray(numValidPeriods).fs = inputFs;
    
                    %plot the audio data if the variable to plot is true
                    if plotThePeriods == 1
                        figure(1);
                        clf;
                        subplot(3,1,1);
                        plot(inputAudio);
                        title("Whole audio");
                        xlabel("Samples");

                        subplot(3,1,2);
                        plot(tempFlux);
                        title("Flux of whole audio");
                        xlabel("Samples");

                        subplot(3,1,3);
                        plot(newAudio);
                        title("Chopped audio: "+inputName);
                        xlabel("Samples: "+ceil(onsetTime(j)*inputFs)+" to "+ceil(onsetTime(j+1)*inputFs));
                        pause();
                    end

                    %play the audio
                    if playThePeriods == 1
                        soundsc(newAudio, inputFs);
                        pause(1);
                    end

                end
            end
        end

        %decrease threshhold
        threshold = threshold-0.1;
    end
    
end

