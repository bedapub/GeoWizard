GeoWizard <- "~/GeoWizard/"
GeoRepo <- "~/GeoWizard/GEORepo/"
setwd(GeoWizard)
source("ShinyApp-Dashboard/global.R")


if(!file.exists('GEOmetadb.sqlite')) getSQLiteFile()
con <- dbConnect(SQLite(), 'GEOmetadb.sqlite')
message(paste('\nConnected Database Tables:', dbListTables(con)))

MolQuery = c("Mycophenolate mofetil")
MolQuery = c("GSE69967")



GseTable <- MultiGSEQuery(MolQuery)
GsmTable <- SqlQueryMain(GseTable)
GseGsmTable <- GseTable %>% dplyr::select(-one_of("GPL")) %>% 
  dplyr::inner_join(GsmTable, "series_id")
  

# Select Single GSE from GSE-GSM Table
gseList <- unique(GseGsmTable[,'series_id'])
selectedGse <- 1
selectedGse <- gseList[selectedGse]

# Filter Selected GSE
Step_1 <- GseGsmTable %>% filter(series_id %in% selectedGse) 
# Classify the Summary and Return the FIltered GSE GSM DF
Step_2 <- ClassSummary(GsmDesignDF = Step_1)

# Expands Character Column 
CharInputs <- c("characteristics_ch1", "gsm.title","description")
Step_3 <- GseGsmCharExpand(GseGsmTable = Step_2, CharInputs)
# Function to Reccomend which of the three to use

Step_3_colnames <- grep(pattern = "ExpVar[[:digit:]]", x = colnames(Step_3), value = T)
Step_3B <- data.frame(Step_3[,Step_3_colnames])
colnames(Step_3B) <- Step_3_colnames

# Classify All the Column in the DF
Step_4 <- ClassGsmText(Step_3B)

# Find the Useful Factors
Step_5A <- DescerningClassDF(ClassListDF = Step_4) # waring this funciton passes 1st factor DF if non found
Step_5B <- AddSeriesDFs(ClassDFList = Step_4, "time")
Step_5C <- AddSeriesDFs(ClassDFList = Step_4, "titration")

Step_5 <- c(Step_5A, Step_5B, Step_5C)
Step_6 <- DesignLabs(data.frame(Step_5))


######### Function to Download File
GSE <- "GSE69967"
GPL <- "GPL570"
source("GeoFileHandling.R")
GSEeset <- LoadGEOFiles(GSE, GPL, GeoRepo)
GSEeset <- readRDS(file = "GeoWizard/GEORepo/GSE69967-GPL570.rds")
GSEeset <- GSEeset[[1]]
FactorDF <- readRDS(file = "~/GeoWizard/TestObjects/GSE69967_FactorDF.rds")


colnames(FactorDF) <- c("GSM", "Treatment", "Tissue")

ExpressionMatrix <- exprs(GSEeset)

########## Convert to Gene Symbol
ExpressionMatrix.GeneSymbol <- ConvertGSEAnnotations(GSEeset = GSEeset, Annotation = "Gene Symbol")
saveRDS(object = ExpressionMatrix.GeneSymbol, "~/GeoWizard/TestObjects/ExpressionMatrix.GeneSymbol.rds")
FactorGMT <- GenFactorGMT(ExpressionMatrix = ExpressionMatrix.GeneSymbol, FactorDF)

DesignMatrix <- model.matrix( ~ Treatment + Tissue, FactorDF)
colnames(DesignMatrix) <- c("Control.Lesion","Treatment.Lesion","Control.Healthy","Treatment.Healthy")
colnames(DesignMatrix) <- c("Intercept","Treatment.Disease","Treatment.Healthy")

ContrastString <- ConTextInput(DesignMatrix, "Treatment.Healthy")
ContrastMatrix <- GenContrastMatrix(ContrastString)
ContrastMatrix <- makeContrasts(ContrastString, levels = DesignMatrix)
#if 0 in formula
ContrastMatrix[1,] <- 0

######### Limma
res <- LimmaOutput(ExpressionMatrix.GeneSymbol, DesignMatrix, ContrastMatrix)
