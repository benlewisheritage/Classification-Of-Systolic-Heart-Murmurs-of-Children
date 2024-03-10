function [Accuracy, Precision, Recall, Fscore, ConfusionMatrixArray, PeriodClassArray, PeriodConfusionMatrixArray] = TestModelFunction(kValue, TargetSampleRate)
%TESTMODELFUNCTION Test the dtw model with the test set against the
%training set
%
%   input the kvalue of the K-Nearest-Neighbours algorithm
%   input the sample rate to target to for the audio
%   
%   outputs the Accuracy of the model
%   outputs the Precision of the model
%   outputs the Recall of the model
%   outputs the F-Score of the model
%   outputs the Confusion Matrix of the model in a table
%   outputs the individual period calssification array counter
%   outputs the individual period confusion matrix
    
    %set the target sample rate
    targetFS = TargetSampleRate;
    
    %get the directories of the training and testing datasets
    testDirectory = "CleanedTestSet\";
    trainDirectory = "CleanedDataSet\";
    
    fprintf("Getting Test and Train Databases\n");
    
    %store the test set and training set in datastores
    testSet = audioDatastore(testDirectory);
    trainingSet = audioDatastore(trainDirectory);

    %read all the training data
    trainingSetAudio = readall(trainingSet);
    
    %%

    %create the overall confusion matrix and period confusion matrix
    ConfusionMatrix = table([0;0],[0;0],RowNames={'Predicted Positive' 'Predicted Negative'},VariableNames={'Actual Positive' 'Actual Negative'});
    PeriodConfusionMatrix = table([0;0],[0;0],RowNames={'Predicted Positive' 'Predicted Negative'},VariableNames={'Actual Positive' 'Actual Negative'});
    
    %%
    
    fprintf("Starting Test\n");
    
    %create the period classification table
    PeriodClassTable = table(0,0,VariableNames={'Abnormal Heart' 'Normal Heart'});

    noDiagnosis = 0;

    %iterate through all test files
    for i=1:length(testSet.Files)
        
        fprintf("Test Sample %d/%d\n", i, length(testSet.Files));
        
        %read test file
        tempTestSampleName = testSet.Files{i};
        [testSample, testFs] = audioread(tempTestSampleName);
        
        %get the name of the file, without folder names
        testSampleNameMatrix = split(tempTestSampleName, "\");
        testSampleName = string(testSampleNameMatrix(length(testSampleNameMatrix)));
        
        fprintf(testSampleName+"\n");
    
        %set the threshholds for the onset detection
        startThreshold = 0.9;
        endThreshold = 0.1;
        
        %%
        
        %get heart periods
        [outputArray, numValidOnsets] = GetHeartPeriods(testSampleName, testSample, testFs, testSampleName, ...
                                                        testDirectory, startThreshold, endThreshold);
        
        %%
        
        if numValidOnsets > 0
    
            %get an odd number of onsets for voting
            if mod(numValidOnsets,2) == 0
                numValidOnsets = numValidOnsets-1;
            end
        
            %initialise the KNN classifier table
            KNNClassTable = table(0,0,VariableNames={'Abnormal Heart' 'Normal Heart'});
            
            %for all onsets (vote)
            for j=1:numValidOnsets
            
                %downsample audio to match the training set
                DSAudio = downsample(outputArray(j).audio,outputArray(j).fs/targetFS);
                DSAudio = rescale(DSAudio,-1,1);
    
                %initialisse the dtw array
                dtwArray = zeros(1,length(trainingSetAudio));
            
                fprintf("DTW %3d/%3d: %3d%%\n", j, numValidOnsets, 0);
            
                for k=1:length(trainingSetAudio)
            
                    fprintf(1,"\b\b\b\b\b%3d%%\n",ceil(k*100/length(trainingSetAudio)));
            
                    %get the dtw against the training set
                    dtwArray(k) = dtw(DSAudio, trainingSetAudio{k});
                end
                
                %get the minimum distance of the dtw array for k members
                [TestMin, TestIndex] = mink(dtwArray, kValue);
                
                votingClassTable = table(0,0,VariableNames={'Abnormal Heart' 'Normal Heart'});
            
                %for all the k nearest neighbours
                for l=1:length(TestIndex)
                    dataSetName = trainingSet.Files{TestIndex(l)};
                    
                    %find the classification for the training set file
                    if (contains(dataSetName, "Absent-Normal")==0)
                        %increment the voting classification table and the 
                        %period classification table
                        votingClassTable(1,"Abnormal Heart") = votingClassTable(1,"Abnormal Heart")+1;
                        PeriodClassTable(1,"Abnormal Heart") = PeriodClassTable(1,"Abnormal Heart")+1;
                        
                        %increment the period confusion matrix
                        if (contains(testSampleName, "Absent-Normal")==0)
                            PeriodConfusionMatrix('Predicted Positive','Actual Positive') = PeriodConfusionMatrix('Predicted Positive','Actual Positive')+1;
                        else
                            PeriodConfusionMatrix('Predicted Positive','Actual Negative') = PeriodConfusionMatrix('Predicted Positive','Actual Negative')+1;
                        end
    
                    else
                        %increment the voting classification table and the 
                        %period classification table
                        votingClassTable(1,"Normal Heart") = votingClassTable(1,"Normal Heart")+1;
                        PeriodClassTable(1,"Normal Heart") = PeriodClassTable(1,"Normal Heart")+1;
    
                        %increment the period confusion matrix
                        if (contains(testSampleName, "Absent-Normal")==0)
                            PeriodConfusionMatrix('Predicted Negative','Actual Positive') = PeriodConfusionMatrix('Predicted Negative','Actual Positive')+1;
                        else
                            PeriodConfusionMatrix('Predicted Negative','Actual Negative') = PeriodConfusionMatrix('Predicted Negative','Actual Negative')+1;
                        end
    
                    end
                end
        
                probClassArray = table2array(votingClassTable);
            
                fprintf("Prob: %d, %d\n", probClassArray(1), probClassArray(2));
        
                %increment the KNN classifier array
                if probClassArray(1) > probClassArray(2)
                    KNNClassTable(1,"Abnormal Heart") = KNNClassTable(1,"Abnormal Heart") + 1;
                else
                    KNNClassTable(1,"Normal Heart") = KNNClassTable(1,"Normal Heart") + 1;
                end
            
            end
            
            fprintf("\nKNNClassTable:\n");
            disp(KNNClassTable);
        
            KNNClassArray = table2array(KNNClassTable);
        
        %%
            %increment the confusin matrix for the KNN
            if KNNClassArray(1) > KNNClassArray(2)
                if (contains(testSampleName, "Absent-Normal")==0)
                    fprintf("'Predicted Positive','Actual Positive'\n");
                    ConfusionMatrix('Predicted Positive','Actual Positive') = ConfusionMatrix('Predicted Positive','Actual Positive')+1;
                else
                    fprintf("'Predicted Positive','Actual Negative'\n");
                    ConfusionMatrix('Predicted Positive','Actual Negative') = ConfusionMatrix('Predicted Positive','Actual Negative')+1;
                end
            elseif KNNClassArray(1) < KNNClassArray(2)
                if (contains(testSampleName, "Absent-Normal")==0)
                    fprintf("'Predicted Negative','Actual Positive'\n");
                    ConfusionMatrix('Predicted Negative','Actual Positive') = ConfusionMatrix('Predicted Negative','Actual Positive')+1;
                else
                    fprintf("'Predicted Negative','Actual Negative'\n");
                    ConfusionMatrix('Predicted Negative','Actual Negative') = ConfusionMatrix('Predicted Negative','Actual Negative')+1;
                end
            end
        else
            %increment no-diagnosis
            noDiagnosis = noDiagnosis+1;
        end
    
    %%
    
    end
    
    %%

    %print the confusion matrix of the test set
    fprintf("\nConfusionMatrix:\n");
    disp(ConfusionMatrix);
    
    %print the no-diagnosises of the test set
    fprintf("NO DIAGNOSIS: %d\n",noDiagnosis);

    %%
    
    ConfusionMatrixArray = table2array(ConfusionMatrix);
    
    %get the performance metrics of the model
    Accuracy = (ConfusionMatrixArray(1,1)+ConfusionMatrixArray(2,2))/(ConfusionMatrixArray(1,1)+ConfusionMatrixArray(1,2)+ConfusionMatrixArray(2,1)+ConfusionMatrixArray(2,2));
    Precision = ConfusionMatrixArray(1,1)/(ConfusionMatrixArray(1,1)+ConfusionMatrixArray(1,2));
    Recall = ConfusionMatrixArray(1,1)/(ConfusionMatrixArray(1,1)+ConfusionMatrixArray(2,1));
    Fscore = 2*((Precision*Recall)/(Precision+Recall));
    
    %print performance metrics of the model
    fprintf("Accuracy: %f\n", Accuracy);
    fprintf("Precision: %f\n", Precision);
    fprintf("Recall: %f\n", Recall);
    fprintf("Fscore: %f\n", Fscore);

    %get the period classification data for the output
    PeriodClassArray = table2array(PeriodClassTable);
    PeriodConfusionMatrixArray = table2array(PeriodConfusionMatrix);

end

