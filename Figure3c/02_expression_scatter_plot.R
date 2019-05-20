####################################
# Define file paths
pathPseudotime = "data/cell_pseudotime.txt"
pathFdr = "output/00_GAM_fitting/fit_gam.txt"
pathAttr = "data/transcript_attributes.txt"
pathExpression = "data/transcript_expression_matrix.txt.gz"
list_pathClusterTranscripts = list.files("output/01_clustering_expression", "transcript_id.cluster_.+", full.names=TRUE)

odir = "output/02_expression_scatter_plot"

selGroup = c("00h", "12h", "24h", "48h", "72h")
expressionUnit = "Sailfish"

####################################
# Load libraries
library(data.table); library(dplyr); library(magrittr); library(dtplyr)
library(mgcv)

####################################
# Make output directory
if(!file.exists(odir)){
  dir.create(odir, recursive = T)
}

####################################
# Load GAM fitting data
dtFdr = fread(pathFdr, header = TRUE)
dtFdr %>% setkey(transcript_id)

####################################
# Load expression table
dtEx = fread(pathExpression, header = TRUE)
dtEx %>% setnames(colnames(dtEx)[1], "transcript_id")
dtEx %>% setkey(transcript_id)

####################################
# Load pseudotime data
dtPseudotime = fread(pathPseudotime, header = TRUE)
pseudotime = dtPseudotime[, Pseudotime]
selCol = dtPseudotime[, label]
t = dtPseudotime[, Pseudotime]

####################################
# Load transcript attribute data
dtAtrr = fread(pathAttr, header = TRUE)
dtAtrr %>% setkey(transcript_id)

####################################
# Define point color for each cell group
gg_color_hue <- function(n) {
  hues = seq(15, 375, length = n + 1)
  hcl(h = hues, l = 65, c = 100)[1:n]
}
n = length(selGroup)
cols = gg_color_hue(n)
names(cols) = selGroup


####################################
# Generate expression scatter plot for transcripts in every cluster
for(pathClusterTranscripts in list_pathClusterTranscripts){
	# Make output directories
	odir2 = paste0(odir, "/", gsub(".txt", "", gsub("transcript_id.", "", basename(pathClusterTranscripts))))
	if(!file.exists(odir2)){
	  dir.create(odir2, recursive = T)
	}

	dtTranscript = fread(pathClusterTranscripts, header = TRUE)

	tids = dtTranscript[, transcript_id]

	for(i in seq_along(tids)){
		title = sprintf("%s, %s", tids[i], dtAtrr[tids[i], gene_name])
		xlb = "Pseudotime"
		ylb = sprintf("log10(TPM+1), %s", expressionUnit)
		sub = sprintf("FDR=%0.4g, AIC=%0.3f, BIC=%0.3f", dtFdr[tids[i], fdr], dtFdr[tids[i], aic], dtFdr[tids[i], bic])

		y = log10(unlist(dtEx[tids[i], selCol, with=FALSE])+1)
		fit = gam(y~s(t), family=gaussian(link=identity))

		pdfname = sprintf("%s/fit_%s_%s.pdf", odir2, tids[i], dtAtrr[tids[i], gene_name])
		pdf(pdfname, width=7, height=4)
		plot(y ~ t, col = cols[dtPseudotime[, group]], main = title, xlab = xlb, ylab=ylb, ylim=c(0, max(y*1.1)), pch=16, sub=sub)
		lines(fitted(fit)~t, col="black")
		dev.off()
	}
}


####################################
# sessionInfo()
sessionInfo()