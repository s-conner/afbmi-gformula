# Interpolating annual data and applying the GFORMULA SAS Macro

This project contains SAS code to interpolate data between examinations at yearly increments. Modifications can be made to account for other units, i.e. months, weeks, etc. Unequal intervals between examinations poses an issue when deriving the restricted mean survival time (RMST), because RMST is in the time domain. The RMST is interpreted as the mean event-free life expectancy up to a given time point.

We thank the authors of the original GFORMULA SAS Macro (Roger W. Logan, Jessica  G. Young, Sarah L. Taubman, Sally Picciotto, Goodarz Danaei, Miguel A. Hernan) for programming this extensive algorithm. We only present our code to be transparent and do not take credit for their original code. The full GFORMULA SAS Macro doucumentation can be found here: https://www.hsph.harvard.edu/causal/software/

example.SAS
```
This code demonstrates how to apply linear interpolation and midpoint interpolation to unequally 
measured risk factors, i.e. measurements at examinations of unequal intervals. The example 
includes simulated data to try the interpolation, and finally apply the GFORMULA macros.
```


gformula modified.SAS
```
We made slight modifications to the original GFORMULA SAS Macro to extract results, which was 
needed when we performed multiple imputation.  We share this version here. 
We added two macro arguments

resultsrmst=
resultshr=

for the user to save RMST and HR output to a SAS dataset. This facilitates combining 
results from multiple imputation with Rubin's rule.
```

gformula negbin.SAS
```
Per an anonymous reviewer's suggestion, we also modified the SAS macro to fit a pooled 
negative binomial model for the outcome hazard. This model was included as a 
sensitivity analysis.
```

