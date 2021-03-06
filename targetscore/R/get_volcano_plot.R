#' Plot volcano plot of Target Score Result.
#' As Significant Proteins (p value< Defalut or Manually set value) will show in red.
#' The inverse log 10 of Target Score q value and Target Score calculated were shown.
#'
#' @param ts input Target Score calculated for each antibody data frame.
#' Gene in coloumns and samples in row. With colnames as gene tags and rownames as sample tags.
#' @param q_value input Target Score q value calculated for each antibody data frame.
#' Gene in coloumns and samples in row. With colnames as gene tags and rownames as sample tags.
#' @param filename Manually set filename of volcano plot.
#' @param path Plot Store path. Default at working environment.
#' @param sig_value  Manually set significant cut-off value for log10(q_value). (Default at 0.4)
#' @param sig_TS Manually set significant cut-off value for calculated Target Score Value. (Default at 0.5)
#' @param x_min Manually set minimum value for x lab. (Default at -2)
#' @param x_max Manually set maximum value for x lab. (Default at 2)
#' @param include_labels a boolean whether to point labels
#' @param save_output a boolean whether to save plots and point data to file
#'
#' @return volcano plots as ggplot object; plots and data maybe be saved as well
#'
#' @importFrom ggplot2 ggsave ggplot aes xlab theme_bw ggtitle xlab ylab geom_point scale_color_manual
#' @importFrom ggrepel geom_label_repel
#' @importFrom utils write.csv
#'
#' @concept targetscore
#' @export
get_volcano_plot <- function(ts, q_value,
                             filename,
                             path = getwd(),
                             sig_value = 0.4,
                             sig_TS = 0.5,
                             include_labels = TRUE,
                             save_output = TRUE,
                             x_min = -2,
                             x_max = 2) {
  ts <- as.matrix(ts)
  p_adj <- as.matrix(q_value)

  if (nrow(p_adj) != nrow(ts)) {
    stop("ERROR: Tag of ts and q_value does not match.")
  }

  tmp_dat <- data.frame(cbind(ts, -1 * log10(p_adj)))
  colnames(tmp_dat) <- c("ts", "neglogQ")

  color <- ifelse(p_adj > sig_value, "not significant", "significant")
  rownames(color) <- rownames(ts)
  tmp_dat$labelnames <- row.names(tmp_dat)
  sig01 <- subset(tmp_dat, tmp_dat$neglogQ > -1 * log10(sig_value))
  sig001<- subset(sig01, abs(sig01$ts) > sig_TS )
  siglabel <- sig001$labelnames
  tmp_dat$color <- color

  p <- ggplot() +
    geom_point(data = tmp_dat, aes(text = tmp_dat$labelnames, x = ts, y = tmp_dat$neglogQ, color = color), alpha = 0.4, size = 2) +
    xlab("<ts>") +
    ylab("-log10 (Q-Value)") +
    ggtitle("") +
    scale_color_manual(name = "", values = c("black", "red")) +
    theme_bw()

  if (include_labels) {
    p <- p + geom_label_repel(data = sig001, aes(x = sig001$ts, y = sig001$neglogQ, label = siglabel), size = 5)
  }

  if (save_output) {
    plotname <- file.path(path, paste0(filename, ".pdf"))
    ggplot2::ggsave(plotname, p)
    tmp_dat_f <- cbind(tmp_dat$ts, tmp_dat$neglogQ)
    colnames(tmp_dat_f) <- c("ts", "neglogQ")
    csvname <- file.path(path, paste0(filename, ".csv"))
    write.csv(tmp_dat_f, file = csvname)
  }

  return(p)
}
