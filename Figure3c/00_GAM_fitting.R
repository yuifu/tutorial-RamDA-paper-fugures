####################################
# Define File paths
pathPseudotime = "data/cell_pseudotime.txt"
pathExpression = "data/transcript_expression_matrix.txt.gz"
odir = "output/00_GAM_fitting"

####################################
# Load libraries
library(data.table); library(dplyr); library(magrittr); library(dtplyr)
library(mgcv)

####################################
# Define functions
extractPvalue = function (fit) {
    (summary(fit)$s.table)[4]
}
extractFittedValue = function (fit) {
    fit$fitted.values
}

####################################
# Make output directory
if(!file.exists(odir)){
  dir.create(odir, recursive = T)
}

####################################
# Load gene expression data
dtEx = fread(pathExpression, header = TRUE)
dtEx %>% setnames(colnames(dtEx)[1], "transcript_id")
dtEx %>% setkey(transcript_id)

####################################
# Load pseudotime data
dtPseudotime = fread(pathPseudotime, header = TRUE)
pseudotime = dtPseudotime[, Pseudotime]
selCol = dtPseudotime[, label]

####################################
# Define expression matrix (Select cells (columns) in ES-PrE differentiation timecourse dataset)
matEx = dtEx[, selCol, with=FALSE]
matEx = log10(matEx+1)

####################################
# Fit generalized addive model (GAM) for each gene
idx = 1:nrow(matEx)

listFit0 = lapply(idx, function(i){
		y = matEx[i,]
		gam(y~1, family=gaussian(link=identity))
	})

listFit = lapply(idx, function(i){
		y = matEx[i,]
		gam(y~s(pseudotime), family=gaussian(link=identity))
	})

####################################
# Calculate false discovery rate (FDR)
resP = sapply(listFit, extractPvalue)
fdr = p.adjust(resP, method = "BH")

####################################
# Calculate AIC and BIC
aic = sapply(listFit, AIC)
bic = sapply(listFit, BIC)

aic = sapply(listFit, AIC)
bic = sapply(listFit, BIC)

aic0 = sapply(listFit0, AIC)
bic0 = sapply(listFit0, BIC)

####################################
# Extract fitted expression levels
fittedValues = sapply(listFit, extractFittedValue) %>% t
colnames(fittedValues) = selCol

####################################
# Save fitting results (p-value, FDR, AIC, BIC)
dtRes = dtEx[idx, "transcript_id", with=FALSE]

dtRes[, pvalue := resP]
dtRes[, fdr := fdr]
dtRes[, aic := aic]
dtRes[, bic := bic]
dtRes[, aic0 := aic0]
dtRes[, bic0 := bic0]

ofile = sprintf("%s/%s", odir, "fit_gam.txt")
write.table(dtRes, ofile, row.names = F, quote = F, sep = "\t")

####################################
# Save fitted values
dtRes2 = dtEx[idx, "transcript_id", with=FALSE]
dtRes2 = cbind(dtRes2, fittedValues)

ofile = sprintf("%s/%s", odir, "fittedValues.txt")
write.table(dtRes2, ofile, row.names = F, quote = F, sep = "\t")

####################################
# Save fitting results as Rdata
ofile = sprintf("%s/%s", odir, "listFit.Rdata")
save(listFit, file = ofile)

####################################
# sessionInfo()
sessionInfo()