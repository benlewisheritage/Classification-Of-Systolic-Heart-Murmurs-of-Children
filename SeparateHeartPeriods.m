function [outputNumPeriods, outputMurmurMatrixCounter, ZcrRmse] = SeparateHeartPeriods(audioFiles, directory, TargetSampleRate)
%SEPARATEHEARTPERIODS Saves all heart periods to selected directory
%
%   input audio file struct containing all relevant audio data
%   input directory for the audio files to be saved to
%   input the sample rate to target to for the audio
%   
%   outputs the number of periods
%   outputs the murmur matrix of the periods
%   outputs the zcr-rmse-snr of the data

    %sample rate to downsample to
    targetFS = TargetSampleRate;

    %onset detection threshhold (start and end)
    startThreshold = 0.8; 
    endThreshold = 0.5;
    
    fprintf("\nGetting Valid Offsets: %3d%%, %5d\n", 0, 0);
    
    %create counters
    numPeriodsForWholeDB = 0;
    numRejectedAudioFiles = 0;
    
    %create murmur matrix counter and age counter
    murmurMatrixCounter = table([0;0],[0;0],RowNames={'Abnormal' 'Normal'},VariableNames={'Present' 'Absent'});
    fullaudioAgeConter = table(0,0,0,0,VariableNames={'Neonate' 'Infant' 'Child' 'Adult'});
    
    %create the zcr-rmse-snr struct
    ZcrRmse = struct();

    %for number of audio files in training set
    for i=1:length(audioFiles.Files)
    
        fprintf(1,"\b\b\b\b\b\b\b\b\b\b\b\b%3d%%, %5d\n",ceil(i*100/length(audioFiles.Files)),numPeriodsForWholeDB);
    
        %separate the full audio into periods
        outputArray = struct();
        [outputArray, numValidPeriods] = GetHeartPeriods(audioFiles.Files{i,1}, audioFiles.Files{i,2}, audioFiles.Files{i,3}, audioFiles.Files{i,4}, ...
                                        directory, startThreshold, endThreshold);

        %check if there were any valid onsets
        if numValidPeriods == 0
            numRejectedAudioFiles = numRejectedAudioFiles + 1;
        else
            %add number of periods from audio file to the number of total
            %periods
            numPeriodsForWholeDB = numPeriodsForWholeDB + length(outputArray);

            %for all the periods in audio file
            for k=1:length(outputArray)
   
                %downsample the audio and rescale to normalise
                DSAudio = downsample(outputArray(k).audio,outputArray(k).fs/targetFS);
                DSAudio = rescale(DSAudio,-1,1);

                %write the audio to a wav file
                audiowrite(outputArray(k).filename,DSAudio,targetFS);

                %get index for zcr-rmse-snr data
                zcrIndex = numPeriodsForWholeDB - length(outputArray)+k;

                %get filename for zcr-rmse-snr data
                ZcrRmse(zcrIndex).filename = outputArray(k).filename; 

                %get the correct label for the zcr-rmse-snr data
                if contains(outputArray(k).filename, "Absent-Normal") == 1
                    ZcrRmse(zcrIndex).label = "Normal Heart";
                    ZcrRmse(zcrIndex).color = [0 0 1];
                else
                    ZcrRmse(zcrIndex).label = "Abnormal Heart";
                    ZcrRmse(zcrIndex).color = [0 1 0];
                end

                %find the metrics of zcr-rmse-snr for the period
                ZcrRmse(zcrIndex).zcr = zerocrossrate(DSAudio);
                ZcrRmse(zcrIndex).rmse = rms(DSAudio);
                ZcrRmse(zcrIndex).snr = snr(DSAudio);

                %count the murmur types in the matrix for the periods
                if contains(outputArray(k).filename, "Present-Abnormal")
                    murmurMatrixCounter("Abnormal","Present") = murmurMatrixCounter("Abnormal","Present")+1;
                elseif contains(outputArray(k).filename, "Present-Normal")
                    murmurMatrixCounter("Normal","Present") = murmurMatrixCounter("Normal","Present")+1;
                elseif contains(outputArray(k).filename, "Absent-Abnormal")
                    murmurMatrixCounter("Abnormal","Absent") = murmurMatrixCounter("Abnormal","Absent")+1;
                elseif contains(outputArray(k).filename, "Absent-Normal")
                    murmurMatrixCounter("Normal","Absent") = murmurMatrixCounter("Normal","Absent")+1;
                end
        
                %count the age ranges for the periods
                if contains(outputArray(k).filename, "Neonate")
                    fullaudioAgeConter(1,"Neonate") = fullaudioAgeConter(1,"Neonate") + 1;
                elseif contains(outputArray(k).filename, "Infant")
                    fullaudioAgeConter(1,"Infant") = fullaudioAgeConter(1,"Infant") + 1;
                elseif contains(outputArray(k).filename, "Child")
                    fullaudioAgeConter(1,"Child") = fullaudioAgeConter(1,"Child") + 1;
                else
                    fullaudioAgeConter(1,"Adult") = fullaudioAgeConter(1,"Adult") + 1;
                end 
            end
        end

        clear outputArray numValidPeriods;
    end
    
    %print rejected files
    fprintf("Rejected Valid Audio Files: %d\n",numRejectedAudioFiles);
    
    %print murmur types in a table
    fprintf("Quantity of Murmur detection types For snippets of Dataset:\n\n");
    disp(murmurMatrixCounter);
    
    %printf age ranges in a table
    fprintf("Quantity of age types For snippets of Dataset:\n\n");
    disp(fullaudioAgeConter);

    %set the output variables for function
    outputNumPeriods = numPeriodsForWholeDB;
    outputMurmurMatrixCounter = table2array(murmurMatrixCounter);

end

