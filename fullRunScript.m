clear all;
clc;

%BEWARE THIS TAKES FOREVER TO RUN

%full run variables

%samle rate of all audio for classification and training set
TargetSampleRate = 250;

%for design of the model use less than 100% of dataset
percentageOfDataSet = 1.00;

%set percentage of patients to test
testPercentage = 0.15;

%number of runs for an average
numberOfRuns = 5;

%set the output directory for the text files and clear the folder
outputDirectory = "fullScriptOutputs\";
delete(outputDirectory+'*');

%set "Systolic"/"Diastolic" to check which type of murmur to test against
sysDys = ["Systolic"];

%set the sexes to test against separately
sexToTest = ["Female" "Male"];

%set the k-values to test against
kValue = [3 5 7 9];

%set this to 1 to create figures for the cleaned datasets
getZCRSNRRMSEFigures = 0;

for sysDysNo = 1:length(sysDys)
    
    for sexNo = 1:length(sexToTest)
        
        for runNo = 1:numberOfRuns
    
            %clean the dataset 
            [ouputTextFileNumber, ouputNonBiasTextFileNumber, outputLengthTestData, ...
              outputLengthTrainData, outputAudioFileNumber, outputFullAudioMatrix, ...
              outputNumOfAudioPeriods, outputAudioPeriodMatrix, zcrrmse] = DataSetCleanFunction(sexToTest(sexNo), percentageOfDataSet, testPercentage, sysDys(sysDysNo),TargetSampleRate);
        
            if getZCRSNRRMSEFigures == 1
            
                %convert zcr/nsr/rmse data to table for plotting
                zcrTable = struct2table(zcrrmse);

                %get the labels and separate for plotting with different
                %color markers to indicated Normal/Abnormal Heart
                zcrLogic = true(1,length(zcrrmse));
    
                for zcrNo=1:length(zcrrmse)
                    if(contains(zcrrmse(zcrNo).label,"Abnormal Heart")==0)
                        zcrLogic(zcrNo) = 0;
                    end
                end
    
                %separate the abnormal/normal heart data
                AbnormalHeartZcrTable = struct2table(zcrrmse(zcrLogic));
                NormalHeartZcrTable = struct2table(zcrrmse(~zcrLogic));
    
                %plot zcr against rmse for cleaned dataset
                figure(1);
                clf;
                scatter(AbnormalHeartZcrTable,"zcr","rmse",'ColorVariable',"color","Marker","+");
                hold on;
                scatter(NormalHeartZcrTable,"zcr","rmse",'ColorVariable',"color","Marker","+");
                legend("Abnormal Heart", "Normal Heart");
    
                %plot zcr against snr for cleaned dataset
                figure(2);        
                clf;
                scatter(AbnormalHeartZcrTable,"zcr","snr",'ColorVariable',"color","Marker","+");
                hold on;
                scatter(NormalHeartZcrTable,"zcr","snr",'ColorVariable',"color","Marker","+");
                legend("Abnormal Heart", "Normal Heart");
    
                %plot snr against rmse for cleaned dataset
                figure(3);        
                clf;
                scatter(AbnormalHeartZcrTable,"snr","rmse",'ColorVariable',"color","Marker","+");
                hold on;
                scatter(NormalHeartZcrTable,"snr","rmse",'ColorVariable',"color","Marker","+");
                legend("Abnormal Heart", "Normal Heart");
            end
    

            %create a text file and write all the relevant information from
            %the cleaned dataset
            diary(outputDirectory+'DataSet-'+sysDys(sysDysNo)+'-'+int2str(runNo)+'-'+sexToTest(sexNo)+'.txt')
            
            fprintf("Valid Text File Number: %d\n", ouputTextFileNumber);
            fprintf("Bias-Removed Text File Number: %d\n", ouputNonBiasTextFileNumber);
            fprintf("Test Data File Nuber: %d\n", outputLengthTestData);
            fprintf("Train Data File Nuber: %d\n", outputLengthTrainData);
            fprintf("Full Audio Training File Number: %d\n", outputAudioFileNumber);
            fprintf("Quantity of Murmur detection types For full audio of Dataset:\n%d, %d\n%d, %d\n", ...
                outputFullAudioMatrix(1,1), outputFullAudioMatrix(1,2), outputFullAudioMatrix(2,1), outputFullAudioMatrix(2,2));
            fprintf("Number of Heart Beat Periods in Training Data: %d\n", outputNumOfAudioPeriods);
            fprintf("Quantity of Murmur detection types For snippets of Dataset:\n%d, %d\n%d, %d\n", ...
                outputAudioPeriodMatrix(1,1), outputAudioPeriodMatrix(1,2), outputAudioPeriodMatrix(2,1), outputAudioPeriodMatrix(2,2));
               
            diary off;
    
            %loop for all k values to test
            for kNo = 1:length(kValue)
        
                clc;
    
                %get model metrics from classifying test samples
                [A, P, R, F, CM, PCl, PCM] = TestModelFunction(kValue(kNo),TargetSampleRate);
                
                %create a text file for the test outputs and write all of 
                %the test metrics to it
                diary(outputDirectory+'Run-'+sysDys(sysDysNo)+'-'+int2str(runNo)+'-'+sexToTest(sexNo)+'-k'+int2str(kValue(kNo))+'.txt')
                
                fprintf("Accuracy: %f\n", A);
                fprintf("Precision: %f\n", P);
                fprintf("Recall: %f\n", R);
                fprintf("Fscore: %f\n", F);
                fprintf("Confusion Matrix: \n%d, %d\n%d, %d\n", CM(1,1), CM(1,2), CM(2,1), CM(2,2));
                fprintf("Period Classification: \n%d, %d\n%d, %d\n", PCl(1,1), PCl(1,2));
                fprintf("Period Confusion Matrix: \n%d, %d\n%d, %d\n", PCM(1,1), PCM(1,2), PCM(2,1), PCM(2,2));
                
                diary off;
    
            end
    
        end
         
    end

end

%%

%delete the cleaned dataset and the test set
delete("CleanedDataSet\"+'*');
delete("CleanedTestSet\"+'*');
