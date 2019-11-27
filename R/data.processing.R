# functions for data processing

covsum <- function(rl.table, region, ws=1){
  # caculate cumulative coverage based on a sliding window in a region

  cov.table <-rl.table[[which(names(rl.table) %in% region[1])]]
  region.pos <- seq(region[2], region[3])
  cov <- rep(0, length(region.pos))
  names(cov) <- region.pos

  cov.pos <- intersect(dimnames(cov.table)[[1]], region.pos)
  cov.pos.table <- cov.table[which(as.numeric(dimnames(cov.table)[[1]]) %in% cov.pos)]
  cov[names(cov) %in% cov.pos] <- cov.pos.table
  return(cov)
}

getCoverage <- function(bamfile, region, flanking.ws = 150, read.tag.names=F){
  # caculate read coverage in the flanking region of target exons
  # input: bamfile - bam file of chip-seq data (bowtie alignment)
  #        region - a dataframe indicate chromosome, target exon start and target exon end position
  #        flanking.ws - window size to look at exon flanking region
  # returns: list contain: 1. vector of read coverage of each individual position in the left flanking region
  #                        2. vector of read coverage of each individual position in the right flanking region
  #                        3. total library size of bam file

  if(!is.element("Rsamtools", installed.packages()[, 1])) {
    stop("Rsamtools Bioconductor package is now required for BAM file support. Please install")
  }
  ww <- c("flag","rname","pos","isize","strand","mapq","qwidth"); if(read.tag.names) { ww <- c(ww,"qname") }
  bam <- Rsamtools::scanBam(bamfile, param=Rsamtools::ScanBamParam(what=ww,tag="XC",
                                                                   flag=Rsamtools::scanBamFlag(isUnmappedQuery=FALSE)))[[1]]
  # get read position for each chromosome
  strm <- as.integer(bam$strand=="+")
  rl <- list(chr=tapply(1:length(bam$pos),bam$rname,
                        function(ii) bam$pos[ii]*strm[ii] + (1-strm[ii])*(bam$pos[ii]+bam$qwidth[ii])))
  library.size <- sum(unlist(lapply(rl$chr, length)))

  rl.table <- lapply(rl$chr, table)
  # flanking region of left exons
  exon.left.flanking.start <- region[, 2] - flanking.ws
  exon.left.flanking.end <- region[, 2] + flanking.ws
  left.flanking.region <-data.frame(chr=region$chr, start=exon.left.flanking.start, end=exon.left.flanking.end)
  # flanking region of right exons
  exon.right.flanking.start <- region[, 3] - flanking.ws
  exon.right.flanking.end <- region[, 3] + flanking.ws
  right.flanking.region <-data.frame(chr=region$chr, start=exon.right.flanking.start, end=exon.right.flanking.end)

  cov.left<- apply(left.flanking.region, 1, function(x) covsum(rl.table, region=x))
  cov.right <- apply(right.flanking.region, 1, function(x) covsum(rl.table, region=x))


  return(list(left.flanking=t(cov.left), right.flanking=t(cov.right), size=library.size))
}

as_ave_chip_signal <- function(HM_file, total_reads){

  # This function returns mean HM signal in the flanking regions of alternative spliced exons
  #
  # Args:
  #  HM_file: processed HM rMAST file with one splice code category
  #  total_reads: total number of aligned reads
  #
  # Returns:
  #  Mean HM signal in the flanking regions

  left_signal <- list()
  right_signal <- list()
  for(i in 1:nrow(HM_file)){
    if(HM_file[i,]$strand == "+"){
      # get chip-seq signal in the flanking region
      left_region <- as.numeric(unlist(strsplit(as.character(HM_file[i,]$chip_left), ",")))
      right_region <- as.numeric(unlist(strsplit(as.character(HM_file[i,]$chip_right), ",")))
    } else {
      # if in minus strand, reverse the flanking region
      left_region <- as.numeric(unlist(strsplit(as.character(HM_file[i,]$chip_left), ",")))
      left_region <- rev(left_region)
      right_region <- as.numeric(unlist(strsplit(as.character(HM_file[i,]$chip_right), ",")))
      right_region <- rev(right_region)
    }
    left_signal[[i]] <- as.data.frame(left_region)
    right_signal[[i]] <- as.data.frame(right_region)
  }

  left_region_signal <- dplyr::bind_cols(left_signal)
  right_region_signal <- dplyr::bind_cols(right_signal)

  left_region_mean = rowMeans(left_region_signal / total_reads) * 1e6
  right_region_mean = rowMeans(right_region_signal / total_reads) * 1e6
  return(c(left_region_mean, right_region_mean))
}

canonical_ave_chip_signal <- function(HM_file, total_reads){

  # This function returns mean HM signal in the flanking regions of canonical exons
  #
  # Args:
  #  HM_file: processed HM rMAST file with one splice code category
  #  total_reads: total number of aligned reads
  #
  # Returns:
  #  Mean HM signal in the flanking regions

  left_signal <- list()
  right_signal <- list()
  for(i in 1:nrow(HM_file)){
    if(HM_file[i, 4] == "+"){
      left_reads <- as.numeric(unlist(strsplit(as.character(HM_file[i, 6]), ",")))
      right_reads <- as.numeric(unlist(strsplit(as.character(HM_file[i, 7]), ",")))

    } else {
      left_reads <- as.numeric(unlist(strsplit(as.character(HM_file[i, 6]), ",")))
      left_reads <- rev(left_reads)
      right_reads <- as.numeric(unlist(strsplit(as.character(HM_file[i, 7]), ",")))
      right_reads <- rev(right_reads)
    }
    left_signal[[i]] <- as.data.frame(left_reads)
    right_signal[[i]] <- as.data.frame(right_reads)
  }
  left_signal <- dplyr::bind_cols(left_signal)
  right_signal <- dplyr::bind_cols(right_signal)

  left_region_mean = rowMeans(left_signal / total_reads) * 1e6
  right_region_mean = rowMeans(right_signal / total_reads) * 1e6
  return(c(left_region_mean, right_region_mean))
}

getSampleInfo <- function(sample_file_name){
  sample_info <- unlist(strsplit(sample_file_name, split = "[.]"))
  tissue <- sample_info[1]
  histone_marker <- sample_info[5]
  time_point <- paste(sample_info[3], sample_info[4], sep = ".")
  return(c(tissue, histone_marker, time_point))
}

getTotalReads <- function(sample_file_name){
  #input.dir <- file.path("data", "processed", "different_timepoints")
  sample_reads <- read.table("allsample.reads.txt", sep = "\t", header = FALSE)
  sample <- gsub(".1.bam.sam.hm.signal", "", sample_file_name)
  total_reads <- sample_reads[sample_reads[ ,1] == sample, 2]
  return(total_reads)
}

classify_splicing_code <- function(SE_file){

  # This function take the input of rMATS (http://rnaseq-mats.sourceforge.net/user_guide.htm#output)
  # or rMATS HM files and calssify alternative spliced exons into different
  # categories (splicing codes): gain (0), loss (1), High (2) and Low (3)
  #
  # Args:
  #  SE_file: rMAT result or rMAST result with HM signal at the end
  #
  # Returns:
  #  File with a class label indicates splicing codes

  inclevel <- colsplit(as.character(SE_file$IncLevel2), split = ",", names = c("s1", "s2"))
  ave_inclevel <- rowMeans(inclevel, na.rm = T)
  SE_file$ave_inclevel <- ave_inclevel
  gain <- SE_file[SE_file$PValue <= 0.05 & SE_file$FDR <= 0.1
                  & SE_file$IncLevelDifference >= 0.1, ]
  gain <- as.data.frame(gain)
  gain$class <- 0
  loss <- SE_file[SE_file$PValue <= 0.05 & SE_file$FDR <= 0.1
                  & SE_file$IncLevelDifference <= -0.1, ]
  loss <- as.data.frame(loss)
  loss$class = 1
  High <- SE_file[SE_file$PValue > 0.5 & abs(SE_file$IncLevelDifference) < 0.1
                  & SE_file$ave_inclevel >= quantile(ave_inclevel, 0.75, na.rm = T), ]
  High <- as.data.frame(High)
  High$class <- 2
  Low <- SE_file[SE_file$PValue > 0.5 & abs(SE_file$IncLevelDifference) < 0.1
                 & SE_file$ave_inclevel <= quantile(ave_inclevel, 0.25, na.rm = T), ]
  Low <- as.data.frame(Low)
  Low$class <- 3
  out_file <- rbind(gain, loss, High, Low)
  return(out_file)
}


