* Generate data for 6 exams;
%macro example;
data example;
array age{*} age1-age6; array bmi{*} bmi1-bmi6; array sbp{*} sbp1-sbp6; 

* Generate sample size of 100;
do i=1 to 100;

	* Generate baseline age 45-55, SBP, BMI, and chf;
	id=i;
	age1=45 + 10*rand('uniform');
	bmi1 = min(60, 18 + (rand('lognormal')/0.1));
	if bmi1>30 then sbp1 = 125 + (rand('normal')*10);
	else sbp1 = 115 + (rand('normal')*10);

	do j=1 to 6;
		if j>1 then do;
			age{j} = age{j-1} + 4 + 4*rand('uniform');
			bmi{j} = bmi{j-1} - 2 + 4*rand('uniform');
			sbp{j} = sbp{j-1} - 2 + 4*rand('uniform');
		end;
	end;
	
	if bmi1>30 then chfage=46 + rand('weibull', 2, 25);
	else chfage=46 + rand('weibull', 2, 40);

	output;
end;
run;
%mend;
%example;

proc means data=example n min q1 median q3 max; run;

* Go from wide to long format;
data long; 
set example;
array aage{*} age1-age6; array abmi{*} bmi1-bmi6; array asbp{*} sbp1-sbp6;
do i=1 to 6;
	age=round(aage{i},1); bmi=abmi{i}; sbp=asbp{i]; exam=i; 
	output;
end;
keep id age exam bmi sbp chf chfage;
run;

proc means; run;

* Interpolate - note that chfage is fixed but carried forward to all time points, so we can apply the same code ;
data first; set long; by id; if first.id; rename age=firstage; keep id age; run;
data last; set long; by id; if last.id; rename age=lastage; keep id age; run;
data firstlast; merge first last; by id; run;


data years; set firstlast; 
do i=38 to 99;
if firstage<=i<=lastage then output; 
end;
rename i=rowage;
run;
proc sql; 
create table years2 as select * from years y left join long g on y.id=g.id and y.rowage=g.age; 
quit;


%macro first(var);
first&var=&var;
retain temp&var;
if first&var ne . then temp&var=&var;
else if first&var=. then first&var=temp&var;
%mend;
data years2; drop temp:;
set years2; 
%first(chfage); %first(exam); %first(bmi); %first(sbp); 
run;
proc sort data=years2; by id descending rowage; run;

%macro last(var);
last&var=&var;
retain temp&var;
if last&var ne . then temp&var=&var;
else if last&var=. then last&var=temp&var;
%mend;
data years2; drop temp:; 
set years2; 
%last(chfage); %last(exam); %last(bmi); %last(sbp); 
run;
proc sort data=years2; by id rowage; run;


data years3; 
set years2; 
by id firstexam;
num+1;
if first.firstexam then num=1;
run;
data years3; set years3; num=num-1; run;
proc sql;
create table denom as select id, firstexam, count(*) as denom from years3 group by id, firstexam;
create table years4 as select g.*, d.denom from years3  g left join denom d on g.id=d.id and g.firstexam=d.firstexam;
quit;
proc sort; by id rowage; run;


** LEFT OFF HERE **;
*Linear interpolation;
%macro interp(var);
new&var=&var;
if new&var=. then new&var=first&var + ((last&var-first&var)*num/denom);
%mend;
* Midpoint interpolation;
%macro mid(var);
new&var=&var;
if new&var=. and first&var = last&var then new&var=first&var;
else if new&var=. then new&var=round(first&var + ((last&var-first&var)*num/denom), 1);
%mend;

data interp; 
set years4; 
%interp(chfage); %interp(bmi); %interp(sbp);  

if .<newchfage<rowage+1 then chf=1; else chf=0;
baseage=firstage;

drop first: last: chfage age denom num bmi sbp;
run;

* Gformula macro will get an error if variables begin with new- prefix;
data interp; set interp; 
rename newchfage=chfage newbmi=bmi newsbp=sbp;
run;

* Create lagged variables for g-formula call;
data interp; set interp; 
nextage=lag1(rowage);
lagid=lag1(id);
run;

data interp; 
set interp;
if id ne lagid then do; nextage=.; lagid=.; end; 
run;
proc sort data=interp; by id rowage; run;

data interp2; set interp;
bmi_l1=lag1(bmi);
sbp_l1=lag1(sbp);
drop lagid;
run;

* Clear out rows after event and only look at 20 year risk;
data interp3; set interp2; by id chf;  if chf=1 and first.chf=0 then delete; run;
data analysis; set interp3; by id; time+1; if first.id then time=0; run;
data analysis20; set analysis; where time<20; run;

proc means data=analysis20; run;
proc freq data=analysis20; table time*chf; run;


* Run g-formula macro;

%let interv1 = intno=1 ,  nintvar=1,
	intlabel="Non-obese",
	intvar1 = bmi, inttype1 = 2, intmax1=29.9, inttimes1 = 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19; 
%let interv2 = intno=2,  nintvar=1,
	intlabel="Obese",
	intvar1 = bmi, inttype1 = 2, intmin1=30,  inttimes1 = 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19; 
	
%gformula(
data= analysis20,
id=id,
outc=chf,
outctype=binsurv,
hazardratio=1,
bootstrap_hazard=1,
intcomp=2 1,
refint=2,

time=time,
timepoints = 20,
timeptype= conspl, 
timeknots = 2 5 10 15 18 ,

fixedcov =  baseage,
ncov=2,
cov1  = sbp,    cov1otype  = 3, cov1ptype = lag1cub, 
cov2  = bmi,    cov2otype  = 3, cov2ptype = lag1cub, 
seed=20, nsimul=10000, nsamples = 5, numint=2
);

