function [ouputTextFileNumber, ouputNonBiasTextFileNumber, outputLengthTestData, ...
          outputLengthTrainData, outputAudioFileNumber, outputFullAudioMatrix, ...
          outputNumOfAudioPeriods, outputMurmurMatrix, ZcrRmse] = DataSetCleanFunction(sex,percentageOfDataSet,testPercentage,sysDys, TargetSampleRate)
%DATASETCLEANFUNCTION cleans the heart murmur dataset to train/test sets
%
%   input the sex requested "Female"/"Male"
%   input the percentage of data set from 0 to 1.00 (lower is higher speed)
%   input the test percentage from 0 to 1.00 to allocate that amount of the
%       cleaned dataset to test the model
%   input heart murmur type "Systolic"/"Diastolic" to test
%   input target sample rate for audio
%
%   outputs the number of valid text files
%   outputs the number of text files after the bias deletion
%   outputs the length of the test set (text files)
%   outputs the length of the training set (training files)
%   outputs the length of the available audio files for the training set
%   outputs a matrix of the murmur types for the full audio
%   outputs the number of the audio heart beat periods in training set
%   outputs a matrix of the murmur types for the heart beat periods
%   outputs a struct of the zcr/snr/rmse data for figure plotting

    fprintf("Starting dataset retrieval\n");    

    %set age range to child (largest age range in the dataset)
    ageRange = "Child";
    
    %get the training data directory
    DSDir = "Dataset\the-circor-digiscope-phonocardiogram-dataset-1.0.3\training_data\";
    
    %get all text files in dataset directory
    textFileStruct = dir(DSDir+"*.txt");
    
    %create a struct for the relevant data
    numRelevantData = 0;
    relevantData = struct();
    
    %%
    
    fprintf("\nGetting Relevant %s Data: %3d%%\n", sysDys, 0);
    
    %count the rejected text files
    numRejectedTextFiles = 0;
    
    %read all the text files
    for i=1:length(textFileStruct)
    
        fprintf(1,"\b\b\b\b\b%3d%%\n",ceil(i*100/length(textFileStruct)));
    
        textFile = readlines(DSDir+textFileStruct(i).name);
    
        %initialise the variables read in from the text file
        goodEntry = 0;
        tempMurmur = "\0";
        tempMurmurLocations = ["\0" "\0" "\0" "\0"];
        tempMurmurTiming = "\0";
        tempAge = "\0";
        tempSex = "\0";
    
        %loop through every line of the text file
        for j=1:length(textFile)
            lineToRead = textFile(j);
    
            if goodEntry == 0
                if contains(lineToRead, "#Age: ")
                    %get the age data
                    tempAge = erase(lineToRead, "#Age: ");
    
                elseif contains(lineToRead, "#Sex: ")
                    %get the sex data
                    tempSex = erase(lineToRead, "#Sex: ");
                    
                elseif contains(lineToRead, "#Murmur: ")&&(contains(lineToRead, "Unknown")==0)&&(contains(tempAge, ageRange)==1)&&(contains(tempSex, "Female")==(sex=="Female"))
                    %get whether the murmur is unknown, and the age/sex are
                    %what we are looking for
                    goodEntry = 1;
                    tempMurmur = erase(lineToRead, "#Murmur: ");
                
                end
            else
                if contains(lineToRead, "#Murmur locations: ")
                    %get all the murmur locations (delimited by +)
                    tempMurmurToDel = erase(lineToRead, "#Murmur locations: ");
                    tempMurmurLocations = split(tempMurmurToDel, "+");
                
                elseif (contains(sysDys, "Systolic"))&&(contains(lineToRead, "#Systolic murmur timing: "))&&(contains(tempMurmur,"Present"))
                    %get the systollic data if that has been requested
                    %check whether there is a valid entry
                    if contains(lineToRead, "nan") == 0
                        tempMurmurTiming = erase(lineToRead, "#Systolic murmur timing: ");
                    else
                        %reject entry
                        goodEntry = 0;
                    end
               elseif (contains(sysDys, "Diastolic"))&&(contains(lineToRead, "#Diastolic murmur timing: "))&&(contains(tempMurmur,"Present"))
                    %get the diastollic data if that has been requested
                    %check whether there is a valid entry
                    if contains(lineToRead, "nan") == 0
                        tempMurmurTiming = erase(lineToRead, "#Diastolic murmur timing: ");
                    else
                        %reject entry
                        goodEntry = 0;
                    end
                elseif contains(lineToRead, "#Outcome: ")
                    %get the diagnosis of the patient

                    %when using the percentageOfDataSet
                    if rand()<=percentageOfDataSet
        
                        %good entry for the training dataset
                        numRelevantData = numRelevantData+1;
            
                        %save all relevant data to the struct
                        relevantData(numRelevantData).name = erase(textFileStruct(i).name, ".txt");
                        relevantData(numRelevantData).murmur = tempMurmur;
                        relevantData(numRelevantData).locations = tempMurmurLocations;
                        relevantData(numRelevantData).timing = tempMurmurTiming;
                        relevantData(numRelevantData).age = tempAge;
                        relevantData(numRelevantData).outcome = erase(lineToRead, "#Outcome: ");
                        relevantData(numRelevantData).category = relevantData(numRelevantData).murmur+"-"+relevantData(numRelevantData).outcome;
            
                    else
                        %reject entry
                        goodEntry = 0;
                    end
    
                    break;
                end
            end
        end
    

        %if rejected, counter increases
        if goodEntry == 0
            numRejectedTextFiles = numRejectedTextFiles + 1;
        end
    end
    
    %print the relevant data number vs the rejected number 
    fprintf("Relevant Text Files: %d\n", numRelevantData);
    fprintf("Rejected Text Files: %d\n",numRejectedTextFiles);
    
    %for the output variables
    ouputTextFileNumber = numRelevantData;

    clear i j goodEntry lineToRead numRejectedTextFiles numRelevantData tempAge tempMurmurTiming tempMurmurLocations tempMurmur tempMurmurToDel textFile textFileStruct
    
    %%
    
    %count the murmur types
    fulltextMurmurMatrixCounter = table([0;0],[0;0],RowNames={'Abnormal' 'Normal'},VariableNames={'Present' 'Absent'});
    
    for i=1:length(relevantData)
        if contains(relevantData(i).category, "Present-Abnormal")
            fulltextMurmurMatrixCounter("Abnormal","Present") = fulltextMurmurMatrixCounter("Abnormal","Present")+1;
        elseif contains(relevantData(i).category, "Present-Normal")
            fulltextMurmurMatrixCounter("Normal","Present") = fulltextMurmurMatrixCounter("Normal","Present")+1;
        elseif contains(relevantData(i).category, "Absent-Abnormal")
            fulltextMurmurMatrixCounter("Abnormal","Absent") = fulltextMurmurMatrixCounter("Abnormal","Absent")+1;
        elseif contains(relevantData(i).category, "Absent-Normal")
            fulltextMurmurMatrixCounter("Normal","Absent") = fulltextMurmurMatrixCounter("Normal","Absent")+1;
        end
    end
    
    fulltextMurmurMatrixTable = table2array(fulltextMurmurMatrixCounter);
    
    %print wquantity of murmur types as a table
    fprintf("Quantity of Murmur Types in Text:\n\n");
    disp(fulltextMurmurMatrixCounter);

    %get the data's bias of classification so training and test set have a
    %similar number of normal and abnormal heart recordings each
    dataBias = (fulltextMurmurMatrixTable(1,1)+fulltextMurmurMatrixTable(1,2)+fulltextMurmurMatrixTable(2,1))/(fulltextMurmurMatrixTable(2,2));
    
    dataBiasLogic = false(1,length(relevantData));
    
    %get a random selection based on the data's bias
    if dataBias < 0
        for i=1:length(relevantData)
            if (contains(relevantData(i).category, "Absent-Normal") == 0)
                dataBiasLogic(i) = 1;
            else
                if rand <= dataBias
                    dataBiasLogic(i) = 1;
                end
            end
        end
    else
        for i=1:length(relevantData)
            if (contains(relevantData(i).category, "Absent-Normal") == 1)
                dataBiasLogic(i) = 1;
            else
                if rand <= (1/dataBias)
                    dataBiasLogic(i) = 1;
                end
            end
        end
    end
    
    %get the relevant data with bias removed
    oldLength = length(relevantData);
    relevantData = relevantData(dataBiasLogic);
    
    fprintf("Removed %d files to counter data bias (%f)\n", (oldLength-length(relevantData)), dataBias);
    
    %output the length of new data as an output variable
    ouputNonBiasTextFileNumber = length(relevantData);

    clear i dataBias dataBiasLogic oldLength fulltextMurmurMatrixCounter
    
    %%
    
    %separate the data into the test and training patient samples
    relevantDataLogic = false(1,length(relevantData));
    
    for i=1:length(relevantData)
        if rand <= testPercentage
            relevantDataLogic(i) = 1;
        end
    end
    
    %set the databases
    relevantDataTest = relevantData(relevantDataLogic);
    relevantDataTrain = relevantData(~relevantDataLogic);
    
    clear i relevantData testPercentage relevantDataLogic
    
    %get the lengths of training and test sets as outputs
    outputLengthTestData = length(relevantDataTest);
    outputLengthTrainData = length(relevantDataTrain);

    %%
    
    %clean the test set folder
    cDSDir = "CleanedTestSet\";
    delete(cDSDir+'*');
    
    %set the default locations for the recordings
    defaultLocations = ["AV" "MV" "PV" "TV"];
    
    fprintf("\nCreating Test Set: %3d%%\n", 0);
    
    %find all the recordings of the test set samples (up to 4 per patient 
    %for all the 4 possible valve recordings)
    for i=1:length(relevantDataTest)
    
        fprintf(1,"\b\b\b\b\b%3d%%\n",ceil(i*100/length(relevantDataTest)));
    
        %checks whether there is a specific location the murmur can be
        %heard, if not (or no murmur), get all the locations available
        if relevantDataTest(i).locations == "nan"
            for j=1:length(defaultLocations)
                stringToRead = DSDir + relevantDataTest(i).name + "_" + defaultLocations(j) + ".wav";
                %checks for files for the patient and copies these files to
                %the test set directory
                if isfile(stringToRead)
                    newFileName = relevantDataTest(i).name + "_" + defaultLocations(j) + "_" + relevantDataTest(i).category+"_"+ relevantDataTest(i).age + ".wav";
                    copyfile(stringToRead, cDSDir+newFileName);
                end
            end
        else
            for j=1:length(relevantDataTest(i).locations)
                stringToRead = DSDir + relevantDataTest(i).name + "_" + relevantDataTest(i).locations(j) + ".wav";
                %checks for files for the patient and copies these files to
                %the test set directory
                if isfile(stringToRead)
                    newFileName = relevantDataTest(i).name + "_" + relevantDataTest(i).locations(j) + "_" + relevantDataTest(i).category+"_"+ relevantDataTest(i).age + ".wav";
                    copyfile(stringToRead, cDSDir+newFileName);
                end
            end
        end
    end
    
    clear relevantDataTest i j status cDSDir stringToRead;
    
    %%
    
    %create an array of audio files for training set
    audioFileNumber = 1;
    audioFiles = {};
    
    fprintf("\nReading Audio: %3d%%\n", 0);
    
    %create counters for the training set
    fullaudioMurmurMatrixCounter = table([0;0],[0;0],RowNames={'Abnormal' 'Normal'},VariableNames={'Present' 'Absent'});
    fullaudioAgeConter = table(0,0,0,0,VariableNames={'Neonate' 'Infant' 'Child' 'Adult'});
    
    %iterate through whole training set of patients
    for i=1:length(relevantDataTrain)
    
        fprintf(1,"\b\b\b\b\b%3d%%\n",ceil(i*100/length(relevantDataTrain)));
    
        %checks whether there is a specific location the murmur can be
        %heard, if not (or no murmur), get all the locations available
        if relevantDataTrain(i).locations == "nan"
            for j=1:length(defaultLocations)
                stringToRead = DSDir + relevantDataTrain(i).name + "_" + defaultLocations(j) + ".wav";
                %checks for files for the patient
                if isfile(stringToRead)
                    %save the data of the audio file to the variable
                    %audioFiles
                    audioFiles.Files{audioFileNumber,1} = relevantDataTrain(i).name + "_" + defaultLocations(j)+"_"+relevantDataTrain(i).category+"_"+relevantDataTrain(i).age+"_";
                    [audioFiles.Files{audioFileNumber,2}, audioFiles.Files{audioFileNumber,3}] = audioread(stringToRead);
                    audioFiles.Files{audioFileNumber,4} = relevantDataTrain(i).age;
                    audioFileNumber = audioFileNumber+1;
    
                    %count the number of diagnosises
                    if contains(relevantDataTrain(i).category, "Present-Abnormal")
                        fullaudioMurmurMatrixCounter("Abnormal","Present") = fullaudioMurmurMatrixCounter("Abnormal","Present")+1;
                    elseif contains(relevantDataTrain(i).category, "Present-Normal")
                        fullaudioMurmurMatrixCounter("Normal","Present") = fullaudioMurmurMatrixCounter("Normal","Present")+1;
                    elseif contains(relevantDataTrain(i).category, "Absent-Abnormal")
                        fullaudioMurmurMatrixCounter("Abnormal","Absent") = fullaudioMurmurMatrixCounter("Abnormal","Absent")+1;
                    elseif contains(relevantDataTrain(i).category, "Absent-Normal")
                        fullaudioMurmurMatrixCounter("Normal","Absent") = fullaudioMurmurMatrixCounter("Normal","Absent")+1;
                    end
    
                    %count the age range of audio files for training set
                    if contains(relevantDataTrain(i).age, "Neonate")
                        fullaudioAgeConter(1,"Neonate") = fullaudioAgeConter(1,"Neonate") + 1;
                    elseif contains(relevantDataTrain(i).age, "Infant")
                        fullaudioAgeConter(1,"Infant") = fullaudioAgeConter(1,"Infant") + 1;
                    elseif contains(relevantDataTrain(i).age, "Child")
                        fullaudioAgeConter(1,"Child") = fullaudioAgeConter(1,"Child") + 1;
                    else
                        fullaudioAgeConter(1,"Adult") = fullaudioAgeConter(1,"Adult") + 1;
                    end
    
                end
            end
        else
            for j=1:length(relevantDataTrain(i).locations)
                stringToRead = DSDir + relevantDataTrain(i).name + "_" + relevantDataTrain(i).locations(j) + ".wav";
                %checks for files for the patient
                if isfile(stringToRead)
                    %save the data of the audio file to the variable
                    %audioFiles
                    audioFiles.Files{audioFileNumber,1} = relevantDataTrain(i).name + "_" + relevantDataTrain(i).locations(j)+"_"+relevantDataTrain(i).category+"_"+relevantDataTrain(i).age+"_";
                    [audioFiles.Files{audioFileNumber,2}, audioFiles.Files{audioFileNumber,3}] = audioread(stringToRead);
                    audioFiles.Files{audioFileNumber,4} = relevantDataTrain(i).age;
                    audioFileNumber = audioFileNumber+1;
    
                    %count the number of diagnosises
                    if contains(relevantDataTrain(i).category, "Present-Abnormal")
                        fullaudioMurmurMatrixCounter("Abnormal","Present") = fullaudioMurmurMatrixCounter("Abnormal","Present")+1;
                    elseif contains(relevantDataTrain(i).category, "Present-Normal")
                        fullaudioMurmurMatrixCounter("Normal","Present") = fullaudioMurmurMatrixCounter("Normal","Present")+1;
                    elseif contains(relevantDataTrain(i).category, "Absent-Abnormal")
                        fullaudioMurmurMatrixCounter("Abnormal","Absent") = fullaudioMurmurMatrixCounter("Abnormal","Absent")+1;
                    elseif contains(relevantDataTrain(i).category, "Absent-Normal")
                        fullaudioMurmurMatrixCounter("Normal","Absent") = fullaudioMurmurMatrixCounter("Normal","Absent")+1;
                    end
    
                    %count the age range of audio files for training set
                    if contains(relevantDataTrain(i).age, "Neonate")
                        fullaudioAgeConter(1,"Neonate") = fullaudioAgeConter(1,"Neonate") + 1;
                    elseif contains(relevantDataTrain(i).age, "Infant")
                        fullaudioAgeConter(1,"Infant") = fullaudioAgeConter(1,"Infant") + 1;
                    elseif contains(relevantDataTrain(i).age, "Child")
                        fullaudioAgeConter(1,"Child") = fullaudioAgeConter(1,"Child") + 1;
                    else
                        fullaudioAgeConter(1,"Adult") = fullaudioAgeConter(1,"Adult") + 1;
                    end
    
                end
            end
        end
    end
    
    %print the number of audio files found for training set
    fprintf("Audio Files found: %d\n",audioFileNumber);
    
    %print murmur types for training set audio files
    fprintf("Quantity of Murmur detection types of Dataset:\n\n");
    disp(fullaudioMurmurMatrixCounter);

    %print age ranges for training set audio files    
    fprintf("Quantity of age types of Dataset:\n\n");
    disp(fullaudioAgeConter);
    
    %save to output variables
    outputAudioFileNumber = audioFileNumber;
    outputFullAudioMatrix = table2array(fullaudioMurmurMatrixCounter);

    clear audioFileNumber defaultLocations fullaudioAgeConter fullaudioMurmurMatrixCounter i j relevantDataTrain stringToRead
    
    %%
    
    %clean the training dataset directory
    cDSDir = "CleanedDataSet\";
    delete(cDSDir+'*');
    
    %%
    
    %save all the individual heart periods from the files in audioFiles
    %into the training set directory
    [outputNumOfAudioPeriods, outputMurmurMatrix, ZcrRmse] = SeparateHeartPeriods(audioFiles,cDSDir,TargetSampleRate);

end

