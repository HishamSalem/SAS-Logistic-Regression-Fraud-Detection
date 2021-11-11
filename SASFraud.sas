*Importing the files;

proc import out=providers
	datafile = "C:\Users\hisha\Desktop\College\Fall2020\DataScience1\ExcelFinal\providers.xlsx"
	dbms = xlsx replace;
run;

proc import out=outpatients
	datafile = "C:\Users\hisha\Desktop\College\Fall2020\DataScience1\ExcelFinal\outpatients.xlsx"
	dbms = xlsx replace;
run;

proc import out=inpatients
	datafile = "C:\Users\hisha\Desktop\College\Fall2020\DataScience1\ExcelFinal\inpatients.xlsx"
	dbms = xlsx replace;
run;

proc import out=beneficiary
	datafile = "C:\Users\hisha\Desktop\College\Fall2020\DataScience1\ExcelFinal\beneficiary.xlsx"
	dbms = xlsx replace;
run;

*fix providers fraud 0 and 1 instead of yes or no 1=yes 0=no;
data providersFixed;
set providers;
if fraud = 'No' Then Fraud = 0;
If Fraud = 'Yes' Then Fraud=1;
run;

*transpose and fix beneficiary  11 Chronic Conditions;
*how do i set up a transpose and subtract all values by 1;
data beneficiaryFixed;
set beneficiary;
Array Chronic{11} Chronic_:;
do  i = 1 to 11;
Chronic[i]= Chronic[i]-1;
end;
*If Gender = 1 then Gender = 'Male';
*If Gender = 2 then Gender = 'Female';
run;

/*Playing Around to see data and fraud and relationship;
data inpatientexploration;
set inpatients;
IF DeductibleAmt NE 'NA' then delete;
run;

data ProvidersExploration;
set providers;
if fraud NE 'Yes' then delete;
run;
*/

*inpatients 4 step fixing the data Aggregate date, adjusting data types from character to numeric and using nodupes to fix the merging (big prepping);
data InpatientsFixed;
set inpatients;
ProviderID = SUBSTR(PID,4,5);
NewProvider = ProviderID+0;
If DeductibleAmt = 'NA' Then DeductibleAmt='';
DeductibleAmt2 = INPUT(DeductibleAmt, 10.); 
Drop DeductibleAmt;
rename DeductibleAmt2 = DeductibleAmt;
run;
proc sort data= InpatientsFixed ; by NewProvider; run;
proc means data = InpatientsFixed; var DeductibleAmt AmtReimbursed; class PID BID; 
output out=inpatientsFixed2; run;
data InpatientsFixed3;
set inpatientsFixed2;
Where _STAT_ = 'MEAN' and _TYPE_= 1;
run;



*Merges For INPATIENTSBENEFIARCIES and sorting prep;
proc sort data =InpatientsFixed3; by BID ; run;
proc sort data =beneficiaryFixed; by BID; run;
*The Merge;
data PatientsBeneficiary;
merge beneficiaryFixed  (in = a) INPATIENTSBID (in = b); by BID;
if a and b then output;
run;


*Data Prep OutPatients prep and aggregation same like inpatients;
Data Outpatients2;
set outpatients;
ProviderID = SUBSTR(PID,4,5);
NewProvider = ProviderID+0;
run;
proc sort data= Outpatients2 ; by NewProvider; run;
proc means data = Outpatients2; var DeductibleAmt AmtReimbursed; class PID; 
output out=Outpatients3; run;
data Outpatients4;
set Outpatients3;
Where _STAT_ = 'MEAN' and _TYPE_= 1;
run;


*Merges For OUTPATIENTSPROVIDERS and sorting prep;
proc sort data =providersFixed; by PID; run;
proc sort data =outpatients4; by PID; run;
data PatientsProviders;
merge providersFixed (in = a) outpatients4 (in = b); by PID;
if a and b then output;
run;


*frequency counts to understand the problems with the data;
proc freq data= PatientsProviders; Tables Fraud; run;
proc freq data= providersFixed; Tables Fraud; run;

*2nd Step Merge so that I can connect all tables together The first merge was used to connect 2 tables together preferably patients and outer tables after merging the 2 tables we connect all the tables together while keep the correct level of analysis ;
proc sort data =PatientsProviders; by PID; run;
proc sort data =PatientsBeneficiary; by PID; run;

data MergedFilesFinals;
merge PatientsProviders (in = a) PatientsBeneficiary (in = b); by PID;
if a and b then output;
run;



*the Logistic Regressio variations for county by county base and the monteary approach would work best;
proc logistic data= MergedFilesFinals descending; 
class county;
model Fraud(event='1') = AmtReimbursed County InpatientAnnualDeductibleAmt;
run;

proc logistic data= MergedFilesFinals descending; 
model Fraud(event='1') = AmtReimbursed InpatientAnnualDeductibleAmt;
run;

*proc freq to see the data counts before and after in order to better understand the numbers and how the providers were affected;

proc freq data= MergedFilesFinals; Tables Fraud; run;
proc freq data= Providers; Tables Fraud; run;


*final fix of the data to see testing for data;
data FraudFixedMerged;
set MergedFilesFinals;
FraudNum= Fraud+0;
run;
*proc reg for more analysis with the new fraud logistics;
proc reg data = FraudFixedMerged;
model FraudNum = AmtReimbursed InpatientAnnualDeductibleAmt;
run;
proc logistic data= FraudFixedMerged descending; 
model Fraud(event='1') = AmtReimbursed InpatientAnnualDeductibleAmt OutpatientAnnualDeductibleAmt;
run;

proc logistic data= FraudFixedMerged descending; 
class Chronic_Alzheimer Chronic_Heartfailure Chronic_KidneyDisease Chronic_Cancer Chronic_ObstrPulmonary Chronic_Depression Chronic_Diabetes Chronic_IschemicHeart Chronic_Osteoporasis;
model Fraud(event='1') = AmtReimbursed Chronic_Alzheimer Chronic_Heartfailure Chronic_KidneyDisease Chronic_Cancer Chronic_ObstrPulmonary Chronic_Depression Chronic_Diabetes Chronic_IschemicHeart Chronic_Osteoporasis 
Chronic_rheumatoidarthritis Chronic_stroke;
run;


*even with output and adjustment i believe that there is not enough data to speculate that there is strong significance between the variables tested and fraud;
