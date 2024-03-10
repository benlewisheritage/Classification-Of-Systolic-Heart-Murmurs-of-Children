clear all;
clc;

%get the training data directory
DSDir = "Dataset\the-circor-digiscope-phonocardiogram-dataset-1.0.3\training_data\";

%get all text files in dataset directory
textFileStruct = dir(DSDir+"*.txt");

%create counters
AgeCounter = table(0,0,0,0,VariableNames={'Neonate' 'Infant' 'Child' 'Adult'});
SexCounter = table(0,0,VariableNames={'Female' 'Male'});
MurmurMatrixCounter = table([0;0],[0;0],RowNames={'Abnormal' 'Normal'},VariableNames={'Present' 'Absent'});
UnclassifiedMurmurs = 0;
  

fprintf("\nGetting quantities in dataset %3d%%\n", 0);

%read all the text files
for i=1:length(textFileStruct)

    fprintf(1,"\b\b\b\b\b%3d%%\n",ceil(i*100/length(textFileStruct)));

    textFile = readlines(DSDir+textFileStruct(i).name);

    %initialise the variables read in from the text file
    tempAge = "\0";
    tempSex = "\0";
    tempMurmur = "\0";

    %loop through every line of the text file
    for j=1:length(textFile)

        lineToRead = textFile(j);

        if contains(lineToRead, "#Age: ")
            %get the age data
            tempAge = erase(lineToRead, "#Age: ");
            
            %count the age range of audio files for training set
            if contains(tempAge, "Neonate")
                AgeCounter(1,"Neonate") = AgeCounter(1,"Neonate") + 1;
            elseif contains(tempAge, "Infant")
                AgeCounter(1,"Infant") = AgeCounter(1,"Infant") + 1;
            elseif contains(tempAge, "Child")
                AgeCounter(1,"Child") = AgeCounter(1,"Child") + 1;
            else
                AgeCounter(1,"Adult") = AgeCounter(1,"Adult") + 1;
            end

        elseif contains(lineToRead, "#Sex: ")
            %get the sex data
            tempSex = erase(lineToRead, "#Sex: ");
            
            if contains(tempSex, "Female")
                SexCounter(1,"Female") = SexCounter(1,"Female") + 1;
            else
                SexCounter(1,"Male") = SexCounter(1,"Male") + 1;
            end

        elseif contains(lineToRead, "#Murmur: ")
            %get the murmur data
            tempMurmur = erase(lineToRead, "#Murmur: ");
        
        elseif contains(lineToRead, "#Outcome: ")
            %get the diagnosis of the patient
             tempOutcome = tempMurmur+"-"+erase(lineToRead, "#Outcome: ");
            
            if contains(tempOutcome, "Present-Abnormal")
                MurmurMatrixCounter("Abnormal","Present") = MurmurMatrixCounter("Abnormal","Present")+1;
            elseif contains(tempOutcome, "Present-Normal")
                MurmurMatrixCounter("Normal","Present") = MurmurMatrixCounter("Normal","Present")+1;
            elseif contains(tempOutcome, "Absent-Abnormal")
                MurmurMatrixCounter("Abnormal","Absent") = MurmurMatrixCounter("Abnormal","Absent")+1;
            elseif contains(tempOutcome, "Absent-Normal")
                MurmurMatrixCounter("Normal","Absent") = MurmurMatrixCounter("Normal","Absent")+1;
            else
                UnclassifiedMurmurs = UnclassifiedMurmurs + 1;
            end

        end
    end
end

%%

AgeTable = table2array(AgeCounter);

%print quantity of ages types as a table
fprintf("\nQuantity of Ages in Text:\n\n");
disp(AgeTable);


SexTable = table2array(SexCounter);

%print wquantity of sex types as a table
fprintf("\nQuantity of Sex in Text:\n\n");
disp(SexTable);


MurmurMatrixTable = table2array(MurmurMatrixCounter);

%print wquantity of murmur types as a table
fprintf("\nQuantity of Murmur types in Text:\n\n");
disp(MurmurMatrixTable);

fprintf("\nQuantity of Unclassified murmur types in Text: %d\n\n",UnclassifiedMurmurs);
