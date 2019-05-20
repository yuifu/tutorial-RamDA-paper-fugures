####################################
# Define File paths
pathPseudotime = "data/cell_pseudotime.txt"
pathFdr = "output/00_GAM_fitting/fit_gam.txt"
pathVal = "output/00_GAM_fitting/fittedValues.txt.gz"
pathNonpolyA = "data/list_nonpolyA_transcript_id.txt"

odir = "output/01_clustering_expression" #  "../171106/products/b00_hierarchicalClustering/170817/products/_01_gam_destiny_hvAcrossAllCells_01/clustering_03/selectByAic"

threshold_fdr = 0.01
threshold_detection = log10(10+1)
nCellRatio = 0.1

nCluster = 7

####################################
# Load libraries
library(data.table); library(dplyr); library(magrittr); library(dtplyr)
library(flashClust)
library(ggplot2)

####################################
# Make output directory
if(!file.exists(odir)){
  dir.create(odir, recursive = T)
}

####################################
# Load pseudotime data
dtPseudotime = fread(pathPseudotime, header = TRUE)
pseudotime = dtPseudotime[, Pseudotime]
selCol = dtPseudotime[, label]

####################################
# Load GAM fitting data
dtFdr = fread(pathFdr, header = TRUE)

####################################
# Load fitted expression value data
dtEx = fread(pathVal, header = TRUE)
dtEx %>% setkey(transcript_id)

####################################
# Load non-polyA transcript list
dtNon = fread(pathNonpolyA, header = TRUE)
dtNon %>% setkey(transcript_id)

##########################################
# Select genes used for clustering
## Select genes whose AIC value was lower than that of intercept model (aic0)
## Filter low-expressed genes. Note that dtEx value in this time is fitted value of log10(TPM+1)
nCell = round(length(dtPseudotime[,label]) * nCellRatio)
print(sprintf("nCell: %d", nCell))
selRowPre = dtEx[rowSums( as.matrix(dtEx[, dtPseudotime[,label], with=FALSE]) >= threshold_detection) >=nCell, transcript_id]
print(length(selRowPre))
selRow = dtFdr[fdr < threshold_fdr & transcript_id %in% selRowPre & aic < aic0, transcript_id]
print(length(selRow))

## Fitted values have been log-transformed. Therefore, no log-transformation is required!!
matEx = dtEx[selRow, selCol, with=FALSE]  %>% as.matrix()
print(dim(matEx))

##########################################
# Calculate Pearson distance between transcripts
d = as.dist((1 - cor(t(matEx)))/2)

##########################################
# Perform clustering
clusters = flashClust(d, method = "ward", members=NULL)
clusterCut <- cutree(clusters, nCluster)

##########################################
# Save clustering results
dtClust = data.table( transcript_id = selRow, cluster = clusterCut)
dtClust %>% setkey(transcript_id)
ofile = sprintf("%s/%s", odir, "dtClust.txt")
write.table(dtClust, ofile, row.names = F, quote = F, sep = "\t")

##########################################
# Save cluster members for each cluster
lapply(dtClust[, unique(cluster)], function(cl){
    ofile = sprintf("%s/transcript_id.cluster_%d.txt", odir, cl)
    write.table(dtClust[cluster == cl, .(transcript_id)], ofile, row.names = F, quote = F, sep = "\t")
}) %>% invisible()

##########################################
# Count how many Non-polyA transcripts were included for each cluster
dtClust2 = copy(dtClust)
dtClust2[, rd := transcript_id %in% dtNon[, transcript_id]]
## Totaling
dtClust2N = dtClust2[, .N, by=.(cluster, rd)]
dtClust2N[, ratio := N/sum(N), by = cluster]
dtClust2N[, NN := sum(N), by = cluster]
ofile = sprintf("%s/%s", odir, "dtClust2N.txt")
write.table(dtClust2N, ofile, sep = "\t", quote=FALSE, row.names=FALSE)

##########################################
# Define facet labels to be used in ggplot
dtClust2N[, facetLabel := sprintf("Cluster %d (%d/%d)", cluster, N, NN)]
labe2 = dtClust2N[rd == TRUE, facetLabel]
names(labe2) = sprintf("cluster_%d", dtClust2N[rd == TRUE, cluster])
labe2
labeller <- as_labeller(labe2)

##############################################
# Calculate mean and sd (standard deviation) of expression values for each cluster
colMeansWithScaling = sapply(unique(clusterCut), function(cl){
    colMeans(t(scale(t(matEx[clusterCut==cl,]))))
})
colSdWithScaling = sapply(unique(clusterCut), function(cl){
    apply(t(scale(t(matEx[clusterCut==cl,]))), 2, sd) %>% t
}) 

colnames(colMeansWithScaling) = sprintf("cluster_%d", unique(clusterCut))
colnames(colSdWithScaling) = sprintf("cluster_%d", unique(clusterCut))
rownames(colSdWithScaling) = rownames(colMeansWithScaling)

dtCluterMeanWithScaling = as.data.table(colMeansWithScaling, keep.rownames = TRUE)
dtCluterMeanWithScaling %>% setnames("rn", "label")

dtTmp = as.data.table(colSdWithScaling, keep.rownames = TRUE)
dtTmp %>% setnames("rn", "label")
dtTmp = dtTmp  %>% melt(id.vars = c("label"), value.name = "sd")

dtClustRowMeans = merge(dtPseudotime[, .(label, group, Pseudotime)], dtCluterMeanWithScaling, by = "label")
dtClustRowMeans = dtClustRowMeans %>% melt(id.vars = c("label", "group", "Pseudotime"))
dtClustRowMeans = merge(dtClustRowMeans, dtTmp, by=c("label", "variable"))

ofile = sprintf("%s/%s", odir, "cluster_mean_withScaling_withSd.txt")
write.table(dtClustRowMeans, ofile, row.names = F, quote = F, sep = "\t")

##############################################
# Plot mean and sd (standard deviation) of expression values for each cluster along pseudotime
g = ggplot(dtClustRowMeans, aes(Pseudotime, value))
g = g + facet_wrap(~variable, ncol=1, scale = "free_y", labeller = labeller)
g = g + geom_ribbon(aes(ymax = value + sd, ymin = value - sd), alpha = 0.8, fill = "skyblue")
g = g + geom_line()
g = g + theme_bw()
g = g + theme(aspect.ratio = 1/3)
g = g + theme(panel.grid.minor = element_blank())
# print(g)

pdfname = sprintf("%s/%s", odir, "plot_cluster_mean_withSd.withNonpolyaNumber.pdf")
pdf(pdfname)
print(g)
dev.off()

####################################
# sessionInfo()
sessionInfo()