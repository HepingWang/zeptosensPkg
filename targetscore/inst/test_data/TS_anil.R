library(plyr)
library(targetscore)
library(data.table)
library(RColorBrewer)
library(gplots)
library(matrixStats)
library(ggplot2)
library(glasso)
library(metap)
library(ggrepel)
library(pheatmap)

rm(list = ls(all.names = TRUE))
set.seed(1)

# SET PARAMETERS ----
# data_dir <- "../data(ts)/ts_anil"
# protein_list_dir <- "../data(ts)/Protein_Name_List"
data_dir <- "inst/test_data"
resource_dir <- "inst/target_score_data"
output_dir <- "inst/test_data/output3"

n_prot <- 100
max_dist <- 1 # changing this value requires additional work to compute product(wk). This is not a priority
verbose <- FALSE

# READ ANTIBODY FILE ----
mab_to_genes <- read.csv(file.path(resource_dir, "antibody_map.csv"),
  header = TRUE,
  stringsAsFactors = FALSE
)

# READ IN DATA ----
# Read proteomic response for cellline1
proteomic_responses <- read.csv(file.path(data_dir, "BT474.csv"), row.names = 1) # n_prot=100

# Read in functional scores
fs_dat <- read.csv(file.path(data_dir, "fs.csv"), header = TRUE, stringsAsFactors = FALSE)

# Extract network
network <- targetscore::predict_bio_network(
  n_prot = n_prot,
  proteomic_responses = proteomic_responses,
  max_dist = max_dist,
  mab_to_genes = mab_to_genes
)

saveRDS(network, file.path(output_dir, "bt474_network.rds"))

# BT474 ----
## Calculate Target Score
wk <- network$wk
wks <- network$wks
dist_ind <- network$dist_ind
inter <- network$inter

n_prot <- ncol(proteomic_responses)
n_cond <- nrow(proteomic_responses)

ts <- array(0, dim = c(n_cond, n_prot))
ts_p <- array(0, dim = c(n_cond, n_prot))
ts_q <- array(0, dim = c(n_cond, n_prot))

n_perm <- 25

for (i in 1:n_cond) {
  results <- targetscore::get_target_score(
    wk = wk,
    wks = wks,
    dist_ind = dist_ind,
    inter = inter,
    n_dose = 1,
    n_prot = n_prot,
    proteomic_responses = proteomic_responses[i, ],
    n_perm = n_perm,
    verbose = verbose,
    fs_dat = fs_dat
  )

  ts[i, ] <- results$ts
  ts_p[i, ] <- results$pts
  ts_q[i, ] <- results$q
}

ts_cond1 <- targetscore::get_target_score(
  wk = wk,
  wks = wks,
  dist_ind = dist_ind,
  inter = inter,
  n_dose = 1,
  n_prot = n_prot,
  proteomic_responses = proteomic_responses[1, ],
  n_perm = n_perm,
  verbose = verbose,
  fs_dat = fs_dat
)

## Set column and rownames to results
colnames(ts) <- colnames(proteomic_responses)
rownames(ts) <- rownames(proteomic_responses)

colnames(ts_p) <- colnames(proteomic_responses)
rownames(ts_p) <- rownames(proteomic_responses)

colnames(ts_q) <- colnames(proteomic_responses)
rownames(ts_q) <- rownames(proteomic_responses)

overall_results <- list(ts = ts, ts_p = ts_p, ts_q = ts_q)
saveRDS(overall_results, file.path(output_dir, "bt474_results.rds"))

# PLOT ----
## Heatmap
results <- readRDS(file.path(output_dir, "bt474_results.rds"))
data <- results$ts

bk <- c(seq(-4, -0.1, by = 0.01), seq(0, 5.5, by = 0.01))

filename <- file.path(output_dir, "heatmap_BT474.pdf")
pdf(filename)
pheatmap(data,
  scale = "none",
  color = c(
    colorRampPalette(colors = c("navy", "white"))(length(seq(-4, -0.1, by = 0.01))),
    colorRampPalette(colors = c("white", "firebrick3"))(length(seq(0, 5.5, by = 0.01)))
  ),
  legend_breaks = seq(-4, 5.5, 2), cellwidth = 1, cellheight = 1, fontsize = 1, fontsize_row = 1,
  breaks = bk
)
dev.off()

## Volcano Plot
tmp <- readRDS(file.path(output_dir, "bt474_results.rds"))
data <- tmp$ts
data_p <- tmp$ts_p

for (i in 1:nrow(data)) {
  get_volcano_plot(ts = data[i, ], q_value = data_p[i, ], filename = rownames(data)[i], path = output_dir)
}

# Subnetwork for Top 30 Proteins Under Different Conditions ----
tmp <- readRDS(file.path(output_dir, "bt474_results.rds"))
bt474_ts <- tmp$ts

## MCL1
data <- sort(bt474_ts["BT474_MCL1", ], decreasing = TRUE)
data_30 <- head(data, 30)

wk <- network$wk
index <- which(colnames(wk) %in% names(data_30))
subnet <- wk[index, index]
edgelist_subnet <- targetscore::create_sif_from_matrix(t_net = subnet, genelist = colnames(subnet))
write.table(edgelist_subnet,
  file.path(output_dir, "signed_pc_BT474_MCL1_TOP30_positive_subnet.txt"),
  quote = FALSE,
  row.names = FALSE
)

data_30 <- tail(data, 30)

wk <- network$wk
index <- which(colnames(wk) %in% names(data_30))
subnet <- wk[index, index]
edgelist_subnet <- targetscore::create_sif_from_matrix(t_net = subnet, genelist = colnames(subnet))
write.table(edgelist_subnet,
  file.path(output_dir, "signed_pc_BT474_MCL1_TOP30_negative_subnet.txt"),
  quote = FALSE,
  row.names = FALSE
)

## Combination (COMB)
data <- sort(bt474_ts["BT474_comb", ], decreasing = TRUE)
data_30 <- head(data, 30)

wk <- network$wk
index <- which(colnames(wk) %in% names(data_30))
subnet <- wk[index, index]
edgelist_subnet <- targetscore::create_sif_from_matrix(t_net = subnet, genelist = colnames(subnet))
write.table(edgelist_subnet,
  file.path(output_dir, "signed_pc_BT474_COMB_TOP30_positive_subnet.txt"),
  quote = FALSE,
  row.names = FALSE
)

data_30 <- tail(data, 30)

index <- which(colnames(wk) %in% names(data_30))
subnet <- wk[index, index]
edgelist_subnet <- targetscore::create_sif_from_matrix(t_net = subnet, genelist = colnames(subnet))
write.table(edgelist_subnet,
  file.path(output_dir, "signed_pc_BT474_COMB_TOP30_negative_subnet.txt"),
  quote = FALSE,
  row.names = FALSE
)
