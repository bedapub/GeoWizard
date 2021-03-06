#' Generate a BioQC Heatmap from Eset
#' @param GeneExpressionInput eset or matrtix file with gene row names and column sample names
#' @param nTopSignatures number of top scoring signatures to show
#' BioQCRes <- RunBioQC(GeneExpressionInput = GSEeset, nTopSignatures = 10)

RunBioQC <- function(GeneExpressionInput){
    # Function to determine if GeneSymbol
    message("Loading BioQC Panels")
    gmtFile <- system.file("extdata/exp.tissuemark.affy.roche.symbols.gmt", package="BioQC")
    gmt <- readGmt(gmtFile)
    
    if (class(GeneExpressionInput) == "ExpressionSet") {
    GeneSymbols <- fData(ExpressSetInput)$`Gene Symbol`    
    } else if (class(GeneExpressionInput) == "matrix") {
    GeneSymbols <- rownames(GeneExpressionInput)
    } else { stop("Error in RunBioQC input must be matrix or ExpressionSet")}
    
    genesets <- BioQC::readGmt(gmtFile)
    testIndex <- BioQC::matchGenes(gmt, GeneSymbols)
     
    wmwResult.greater <- wmwTest(GeneExpressionInput, testIndex, valType="p.greater")
    #wmwResult.less <- wmwTest(GeneExpressionInput, testIndex, valType="p.less")
    #wmwResult.Q <- wmwTest(GeneExpressionInput, testIndex, valType="Q")
    
    bioqcResFil <- filterPmat(wmwResult.greater, 1E-8)
    bioqcAbsLogRes <- absLog10p(bioqcResFil)
    return(bioqcAbsLogRes)
}

#' 
#'
#'
#'
#BioQCHeatmap(BioQCRes)
BioQCHeatmap <- function(BioQCRes){
        message("Generating BioQC HeatMap")
        message(class(BioQCRes))
        heatmap.2(x = BioQCRes, Colv=TRUE, Rowv=TRUE,
               cexRow=1, cexCol = 1, dendrogram = "both",
               col=rev(brewer.pal(11, "RdBu")),
               labCol=1:ncol(bioqcAbsLogRes),
               main = "BioQC results for GSE",
               xlab = "Sample Number",
               key = T,
               lmat = rbind(c(4,3,0),c(2,1,0),c(0,0,0)),
               lwid = c(1.5,4,1),
               lhei = c(1.5,4,1),
               trace = 'none')
}

#'
#'
#'
#'
#'

BioQCProfile <- function(BioQCRes, TissueSelection){
        BioQCDataSelection <- BioQCRes[c(TissueSelection),]
        BioQCDataMelt <- melt(BioQCDataSelection) 
        colnames(BioQCDataMelt) <- c("tissue", "sample", "bioqc")
        p <- 
            ggplot(data = BioQCDataMelt, aes(x = sample,y = bioqc, group = tissue, color = tissue)) + 
            geom_point() + geom_line() + 
            labs(x ="Sample GSM Acession", y = "BioQC Score", color = "BioQC Tissue Score") + 
            theme(legend.position="bottom") + 
            theme(axis.text.x = element_text(vjust = 1, angle = 90, size = 12)) + 
            theme(legend.text = element_text(size = 12))
        return(p)
}


#' @param ExpressionMatrix eset of GSE being processed
#' @param FactorDF DF - each column a vectors #' experimental factor found in the title, 
#' characterisitcs and descriptions of the GSMs in the GSE
#'
#'
#'
GenFactorGMT <- function(ExpressionMatrix, FactorDF){
  if (ncol(ExpressionMatrix) == nrow(FactorDF)) { ExpressionMatrix <- t(ExpressionMatrix) }
  
  if (nrow(ExpressionMatrix) == nrow(FactorDF)) {
    GSM <- rownames(ExpressionMatrix)
    GSMFactorDF <- cbind.data.frame(GSM, FactorDF)
    FactorGMT <- cbind.data.frame(GSMFactorDF, ExpressionMatrix)
    } else { stop("Array data and Factor DF dimensions not compatible")}
  
  return(FactorGMT)
}

GenFactorGMTMeltDF <- function(GSEeset, FactorDF){
     ArrayAndFactorDataDF <- GenFactorGMT(GSEeset, FactorDF)
     GSEgmtDF <- melt(ArrayAndFactorDataDF)
     return(GSEgmtDF)
}


#' GMT Boxplot
#'
#' Generate Boxplots of GMT files on the basis on factors or samples
#' @param FactorGMTMelt - DF with columns GSM, ExpVars, variable(gene ids), value(gene number, counts, RPKM etc.)
#' @param BoxPlotType - Plot GMT boxplots by "Sample" or "Factor"
#' @param PlotFactor - Colnumer of Factorcolumn in GSEgmtDF to fill and group boxplot with


GMTBoxplot <- function(FactorGMTMelt, BoxPlotType = "Sample", PlotBy = "Overall", PlotFactor, SampleSize){
     if (BoxPlotType == "Sample") { 
          
          if (PlotBy == "Overall") { 
               GeneSample <- sample(x = FactorGMTMelt$GSM, size = SampleSize)
               FactorGMTMelt <- FactorGMTMelt %>% filter(GSM %in% GeneSample)
               AesX <- FactorGMTMelt$GSM
               
               AesFill <- factor(FactorGMTMelt[,PlotFactor])
               xlabtext <- "GSMs in Dataset"
               legPos <- "top"
               
          } else if (PlotBy == "Factor") {;message("Factor")
               AesX <- FactorGMTMelt[,PlotFactor]
               AesFill <- factor(FactorGMTMelt[,PlotFactor])
               xlabtext <- "Experimental Factors"
               legPos <- "top"
          }
          
     } else if (BoxPlotType == "Gene") {
          GeneSample <- sample(x = FactorGMTMelt$variable, size = SampleSize)
          FactorGMTMelt <- FactorGMTMelt %>% filter(variable %in% GeneSample)
          
          if (PlotBy == "Overall") {
               AesX <- FactorGMTMelt$variable
               FactorGMTMelt <- FactorGMTMelt
               AesFill <- "red"
               xlabtext <- "Assayed Genes"
               legPos <- "none"
               
          } else if (PlotBy == "Factor") {
               AesX <- FactorGMTMelt$variable
               AesFill <- factor(FactorGMTMelt[,PlotFactor])
               xlabtext <- "Assayed Genes"
               legPos <- "top"
          }
     }
     
     pBox <- 
       ggplot(data = FactorGMTMelt, aes(y = FactorGMTMelt$value, x = AesX, fill = AesFill)) +
       theme(legend.position = legPos) +  
       ylab(label = "Expression Level") +
       xlab(label = xlabtext) +
       guides(fill=guide_legend(title="Experimental Factor Groups")) +
       theme(axis.text.x = element_text(angle = 90)) + 
       theme(axis.text = element_text(size = 14)) +
       theme(axis.title = element_text(size = 14)) 
          
     
     return(pBox)
     
     }
     

#'
#'
#'
#'
#'

GMTHistPlot <- function(FactorGMTMelt, HistPlotType = "Sample", PlotFactor, SampleSize) {
  
     if (HistPlotType == "Factor") {
          AesFill = FactorGMTMelt[,PlotFactor]
          guideTxt <- "Experimental Factors"
          
     } else if(HistPlotType == "Gene"){
          GeneSample <- sample(x = FactorGMTMelt$variable, size = SampleSize)
          FactorGMTMelt <- FactorGMTMelt %>% filter(variable %in% GeneSample)
          AesFill = FactorGMTMelt$variable
          guideTxt <- "Randomly Sampled Genes"
          
     } else if(HistPlotType == "Sample"){
          GeneSample <- sample(x = FactorGMTMelt$GSM, size = SampleSize)
          FactorGMTMelt <- FactorGMTMelt %>% filter(GSM %in% GeneSample)
          AesFill = FactorGMTMelt$GSM
          guideTxt <- "Randomly Sampled GSMs"
     }
     
     pHist <- ggplot(data = FactorGMTMelt, aes(x = value, fill = AesFill)) + 
          geom_histogram(position="dodge") + 
          guides(fill=guide_legend(title=guideTxt)) 
     
     if (SampleSize > 20) { pHist <- pHist + theme(legend.position = "none")
     } else { pHist <- pHist + theme(legend.position = "top") }
     
     return(pHist)
}


#' PCA Function
#' 
#' @param GSEeset eset from which the expression Matrix is as such: Rows are Genes and Columns GSMs 
#'
#' @example 
#'ArrayData <- exprs(GSEeset)
#'x <- PlotPCA(ArrayData = ArrayData)
#'class(x)
#'x$PCA

PlotPCA <- function(ArrayData){
     
     rownames(ArrayData) = make.names(rownames(ArrayData), unique=TRUE)
     TArrayData <- t(ArrayData)
     ResPCA <- PCA(TArrayData, graph = F, scale.unit = T)
     
     PCAPlot <- fviz_pca_ind(ResPCA, col.ind = "cos2", gradient.cols = c("#00AFBB", "#E7B800", "#FC4E07"), repel = F)
     ScreePlot <- fviz_eig(ResPCA, ddlabels = TRUE, ylim = c(0, 50)) # ScreePlot
     
     #Correspondence Analysis (CA) is performed using the function CA() [in FactoMineR] 
     res.ca <- CA(ArrayData, graph=FALSE)
     CorrespondenceAnalysis <- fviz_ca_row(res.ca, select.row = list(contrib = 20), col.row="cos2") +
          scale_color_gradient2(low="white", mid="blue", high="red", midpoint=0.5) + 
          theme_minimal()
     
     # Contributions of variables to PC1
     ContributionPC1 <- fviz_contrib(ResPCA, choice = "var", axes = 1, top = 10) 
     
     
     PanelPlots <- list("PCA" = PCAPlot,
                        "CA" = CorrespondenceAnalysis,
                        "Scree" = ScreePlot,
                        "Cont" = ContributionPC1)
     
     return(PanelPlots)
}

#'
#'
#'
#'
#'

# ClusteringAnalysis <- function(ArrayData, 
#                                distMethod = "manhattan", 
#                                clustMethod = c("complete", "ward.D2"), 
#                                MultiClust = T){
#      
#      res.dist <- dist(df, method = distMethod) # Compute distance matrix
#      hc1 <- hclust(res.dist, method = clustMethod[1])
#      
#      dend1 <- as.dendrogram (hc1) # Create two dendrograms
#      
#      if (MultiClust == T) {
#           dend2 <- as.dendrogram (hc2)
#           hc2 <- hclust(res.dist, method = method = clustMethod[2])
#           Tangle <- tanglegram(dend1, dend2)
#           
#      }
#      
#      
# 
#      }


