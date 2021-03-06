# readHeaderXLS()
# read header information from XLS exported file.
readHeaderXLS <- function(file, dec = FALSE) {
	nlines <- grep("Idx", scan(file, flush = TRUE, what = "",
		blank.lines.skip = F, quiet = TRUE))
	nlines <- nlines-1
	head <- list()
	if(!any(nlines)) stop("Not a Codelink XLS exported file.")
	head$header <- scan(file, nlines = nlines, sep = "\t", what = "",
		quiet = TRUE)
	head$nlines <- nlines
	if(any(foo <- grep("Product:", head$header)))
		head$product <- head$header[foo + 1] else head$product <- "Unknown"
	if(any(foo <- grep("Sample Name", head$header)))
		head$sample <- head$header[foo + 1] else head$sample <- file
	head$size <- arraySize(file, nlines)
	head$size <- head$size - 1
	if(dec) head$dec <- decDetect(file, nlines)
	head$columns <- scan(file, skip = nlines, nlines = 1, sep = "\t",
		what = "", quiet = TRUE)
	return(head)
}

# readHeader()
# read header information from codelink file.
readHeader <- function(file, dec = FALSE) {
	foo <- grep("-{80}", scan(file, nlines = 30, flush = T, quiet = TRUE,
		what = ""))
	if(!any(foo)) stop("Not a Codelink exported file.")
	nlines <- foo
	# Return list:
	head <- list(header = NULL, nlines = NULL, product = NULL, sample = NULL,
		size = NULL, dec = NULL, columns = NULL)
	head$header <- scan(file, nlines = nlines, sep = "\t", what = "",
		quiet = TRUE)
	head$nlines <- nlines
	if(any(foo <- grep("PRODUCT", head$header)))
		head$product <- head$header[foo + 1] else head$product <- "Unknown"
	if(any(foo <- grep("Sample Name", head$header)))
		head$sample <- head$header[foo + 1] else head$sample <- file
	head$size <- arraySize(file, nlines)
	if(dec) head$dec <- decDetect(file, nlines)
	head$columns <- scan(file, skip = nlines, nlines = 1, sep = "\t",
		what = "", quiet = TRUE)
	return(head)
}
# decDetect()
# detect decimal point.
decDetect <- function(file, nlines) {
	foo <- read.table(file, skip = nlines, nrows = 1, header = TRUE,
		sep = "\t", na.strings = "", comment.char = "", fill = TRUE)
        val <- NULL
        if(!is.null(foo$Spot_mean)) val <- foo$Spot_mean
        if(!is.null(foo$Raw_intensity) && is.null(val))
			val <- foo$Raw_intensity
        if(!is.null(foo$Normalized_intensity) && is.null(val))
			val <- foo$NormalNormalized_intensity
        if(is(val, "numeric")) dec <- "." else dec <- ","
	return(dec)
}
# arraySize()
# calculate chip size.
arraySize <- function(file, nlines) {
        data <- scan(file, skip = nlines + 1, sep = "\t", what = "integer",
			flush = TRUE, na.strings = "", quiet = TRUE)
        #ngenes <- length(data)  # number of genes.
		# Codelink exporter is buggy.
        ngenes <- length(data[!is.na(data)])
}
# checkColumns()
# check vector consistency.
checkColumns <- function(x, y)
{
	for(n in 1:length(x))
		if(x[n] != y[n]) return(FALSE)
	return(TRUE)
}

# .checkType()
# checks valid type with current file.
.checkType <- function(h, type, types) {
	any(h$columns %in% types[type])
}
# readCodelink()
# read of codelink data.
readCodelink = function(files=list.files(pattern = "TXT"), sample.name=NULL, flag, flag.weights, type.weights, dec=NULL, type="Spot", preserve=FALSE,	verbose=2, file.type="Codelink", check=TRUE, fix=FALSE, old=FALSE) {
	.Deprecated(msg="The Codelink interface is deprecated. Read Codelink data with 'readCodelinkSet' instead. More details in the vignette and documentation.")
	.readCodelinkRaw(files=files, sample.name=sample.name, flag=flag, flag.weights=flag.weights, type.weights=type.weights, dec=dec, type=type, preserve=preserve,	verbose=verbose, file.type=file.type, check=check, fix=fix, old=old)
}
.readCodelinkRaw <- function(files=list.files(pattern = "TXT"), sample.name=NULL, flag, flag.weights, type.weights, dec=NULL, type="Spot", preserve=FALSE,	verbose=2, file.type="Codelink", check=TRUE, fix=FALSE, old=FALSE)
{	
	if(length(files) == 0) stop("no Codelink files found.")
	if(!old)
		warning("'readCodelink' and 'readCodelinkSet' do not convert intensities to NA based on flags anymore, except for spots flagged as 'M' (MSR spot). Instead, createWeights() is used to assign weights. These weights can be used during normalization and linear modeling. To obtain the old behavior use parameter 'old=TRUE' (weights will be created anyway).")
	if(old)
		warning("calling 'readCodelink'/'readCodelinkSet' with 'old=TRUE'")
	
	nslides <- length(files)

	type <- match.arg(type,c("Spot", "Raw", "Norm"))
	types <- c("Spot" = "Spot_mean",
			   "Raw" = "Raw_intensity",
			   "Norm" = "Normalized_intensity")
	file.type <- match.arg(file.type, c("Codelink", "XLS"))

	if(file.type=="XLS") readHeader <- readHeaderXLS
	
	if(!is.null(sample.name) && (length(sample.name) != nslides))
		stop("sample.name must have equal length as files.")
	
	flags <- c("G", "L", "S", "C", "I", "M", "X")
	flag.cc.new <- list(M = NA) # only MSR spots are assigned NA.
	flag.cc <- list(M = NA, C = NA, I = NA)
	if(!missing(flag)) {
		for(k in names(flag)) {

			if(any(k %in% flags))
				flag.cc[[k]] <- flag[[k]]
			else
				warning("unknown flag ", k, " skipping.\n")
		}
	}
	
	flag.ww = c(
		"G"=1,
		"L"=1,
		"S"=1,
		"C"=0,
		"I"=0,
		"M"=0,
		"X"=0
		)
	if(!missing(flag.weights)) {
		for(k in names(flag.weights)) {
			if(any(names(flag.ww) == k))
				flag.ww[[k]]=flag.weights[[k]]
			else
				warning("unsupported weight flag", k, " (ignored...)")
		}
	}
	
	type.ww = c(
		"DISCOVERY"=1,
		"FIDUCIAL"=0,
		"POSITIVE"=0,
		"NEGATIVE"=0,
		"OTHER"=0
		)
	
	if(!missing(type.weights)) {
		for(k in names(type.weights)) {
			if(any(names(type.ww) == k))
				type.ww[[k]]=type.weights[[k]]
			else
				warning("unsupported weight type", k, " (ignored...)")
		}
	}
	
	# read Header.
	#head <- readHeader(files[1])

	# read arrays.
	for(n in 1:nslides) {
		if(verbose > 0 && n > 1) cat(paste("** reading file", n, "of",
			nslides, ":", files[n], "\n"))
		if(is.null(dec)) head <- readHeader(files[n], dec = TRUE)
		else head <- readHeader(files[n])
		
		if (!.checkType(head, type, types))
			stop(paste("File", files[n], "does not contain column", types[type], "(choose other type instead)"))

		if(n==1) {
			product <- head$product
			ngenes <- head$size
			if(verbose > 0) {
				cat("** product:", product, "\n")
				cat("** chip size:", ngenes, "\n")
				if(fix) cat("** requested probe rrder FIX\n")
					cat(paste("** reading file", n, "of", nslides, ":",
						files[n], "\n"))
			}

			# define Codelink object.
			Y <- matrix(NA, nrow = ngenes, ncol = nslides,
				dimnames = list(1:ngenes, 1:nslides))
			Z <- rep(NA, ngenes)
			X <- c(1:nslides)
			J <- matrix(NA, nrow = ngenes, ncol = 2,
				dimnames = list(1:ngenes, c("row","col")))
			
			method.list <- list(background = "NONE", normalization = "NONE",
				merge = "NONE", log = FALSE)
			head.list <- list(product = "NONE", sample = X,  file = X,
				name = Z, type = Z, id = Z, flag = Y, method = method.list,
				Bstdev = Y,	snr = Y, logical = J)

			switch(type,
				Spot = data.list <- list(Smean = Y, Bmedian = Y),
				Raw = data.list <- list(Ri = Y),
				Norm = data.list <- list(Ni = Y)
			)
			codelink <- c(head.list,  data.list)
		}

		if(verbose>2) print(head)
		if(verbose>1) cat(paste("  + detected", head$dec, 
			"as decimal symbol.\n"))

		if(head$product != product) stop("Different array type (",
			head$product, ")!")
		if(head$product == "Unknown") warning("Product type for ", files[n],
			" is unknown (missing PRODUCT field in header).")
		if(head$size != ngenes)	stop("Different number of probes (",
			head$size, ")\n")

		if(is.null(sample.name)) codelink$sample[n] <- head$sample
		if(verbose > 1) cat(paste("  + sample Name:", codelink$sample[n], "\n"))

		# read bulk data.
		#data <- read.table(files[n], skip=head$nlines, sep="\t", header=TRUE, row.names=1, quote="", dec=head$dec, comment.char="", nrows=head$size, blank.lines.skip=TRUE)
		data <- read.table(files[n], skip = head$nlines, sep = "\t",
			header = TRUE, quote = "", dec = head$dec, comment.char = "",
			nrows = head$size, blank.lines.skip = TRUE)

		#######################################################################
		# check data consistency.
		if(check && !fix) {
			if(n == 1) {
				if(file.type == "Codelink")
					check.first <- as.character(data[, "Probe_name"])
				else
					check.first <- as.character(data[, "Probe_Name"])
			} else {
				if(file.type == "Codelink")
					check.now <- as.character(data[, "Probe_name"])
				else
					check.now <- as.character(data[, "Probe_Name"])

				if(!checkColumns(check.first, check.now))
					warning("Different column order in files!\nCheck that files where generated with the same version of the Codelink Software.\nAlternatively you can turn on the fix argument and I will try to fix the order, using the Feature_id column if exists (optimal) or the Probe_name column otherwise (sub-optimal). Be aware that if I use the Probe_name, the control, fiducial and some few duplicated probes will probably be messed up. Depending on what you want to do, this would be unacceptable.")
			}
		}

		# try to fix data consistency.
		if(fix) {
			if(any(grep("Feature_id", head$column))) {
				cat("  + using Feature_id to fix order (optimal).\n")
				fix.col <- as.character(data[, "Feature_id"])
			} else {
				cat("  + using Probe_name to fix order (sub-optimal).\n")
				if(file.type == "Codelink")
					fix.col <- as.character(data[, "Probe_name"])
				 else
					fix.col <- as.character(data[, "Probe_Name"])
			}
			data <- data[order(fix.col), ]
		}
		#######################################################################

		# assign flag values.
		if(file.type == "Codelink") 
			codelink$flag[,n] <- as.character(data[, "Quality_flag"])
		else
			codelink$flag[,n] <- as.character(data[, "Quality.Flag"])
		# flag information.
		# allow combination of different flags.
		#flag.m <- grep("M", codelink$flag[,n])	# MSR masked spots.
		#flag.i <- grep("I", codelink$flag[,n])	# Irregular spots.
		#flag.c <- grep("C", codelink$flag[,n])	# Background contaminated
		#flag.s <- grep("S", codelink$flag[,n])	# Saturated spots.
		#flag.g <- grep("G", codelink$flag[,n])	# Good spots.
		#flag.l <- grep("L", codelink$flag[,n])	# Limit spots.
		#flag.x <- grep("X", codelink$flag[,n])	# User excluded spots.

		#if(verbose>1) {
			#cat("  + Quality flags:\n")
			#cat(paste("      G:",length(flag.g),"\t"))
			#cat(paste("      L:",length(flag.l),"\t"))
			#cat(paste("      M:",length(flag.m),"\t"))
			#cat(paste("      I:",length(flag.i),"\n"))
			#cat(paste("      C:",length(flag.c),"\t"))
			#cat(paste("      S:",length(flag.s),"\t"))
			#cat(paste("      X:",length(flag.x),"\n"))
		#}

		# assign intensity values.
		switch(type,
			Spot = {
				codelink$Smean[,n] <- data[, "Spot_mean"]
				codelink$Bmedian[,n] <- data[, "Bkgd_median"]

				# if found bkgd stdev get it to compute SNR.
				if(any(grep("Bkgd_stdev", head$columns)))
					codelink$Bstdev[,n] <- data[, "Bkgd_stdev"]
				else codelink$Bstdev[,n] <- NA

				# set values based on flags.
				#if(!is.null(flag$M)) {
					#codelink$Smean[flag.m, n] <- flag$M
					#codelink$Bmedian[flag.m, n] <- flag$M
				#}
				#if(!is.null(flag$I)) {
					#codelink$Smean[flag.i, n] <- flag$I
					#codelink$Bmedian[flag.i, n] <- flag$I
				#}
				#if(!is.null(flag$C)) {
					#codelink$Smean[flag.c, n] <- flag$C
					#codelink$Bmedian[flag.c, n] <- flag$C
				#}
				#if(!is.null(flag$S)) {
					#codelink$Smean[flag.s, n] <- flag$S
					#codelink$Bmedian[flag.s, n] <- flag$S
				#}
				#if(!is.null(flag$G)) {
					#codelink$Smean[flag.g, n] <- flag$G
					#codelink$Bmedian[flag.g, n] <- flag$G
				#}
				#if(!is.null(flag$L)) {
					#codelink$Smean[flag.l, n] <- flag$L
					#codelink$Bmedian[flag.l, n] <- flag$L
				#}
				#if(!is.null(flag$X)) {
					#codelink$Smean[flag.x, n] <- flag$X
					#codelink$Bmedian[flag.x, n] <- flag$X
				#}
			},
			Raw = {
				if(file.type == "Codelink")
					codelink$Ri[, n] <- data[, "Raw_intensity"]
				else
					codelink$Ri[, n] <- data[, "Raw_Intensity"]
				codelink$method$background <- "Codelink Subtract"
				# Set values based on Flags.
				#if(!is.null(flag$M)) {
					#codelink$Ri[flag.m, n] <- flag$M
				#}
				#if(!is.null(flag$I)) {
					#codelink$Ri[flag.i, n] <- flag$I
				#}
				#if(!is.null(flag$C)) {
					#codelink$Ri[flag.c, n] <- flag$C
				#}
				#if(!is.null(flag$S)) {
					#codelink$Ri[flag.s, n] <- flag$S
				#}
				#if(!is.null(flag$G)) {
					#codelink$Ri[flag.g, n] <- flag$G
				#}
				#if(!is.null(flag$L)) {
					#codelink$Ri[flag.l, n] <- flag$L
				#}
				#if(!is.null(flag$X)) {
					#codelink$Ri[flag.x, n] <- flag$X
				#}
			},
			Norm = {
				codelink$Ni[,n] <- data[, "Normalized_intensity"]
				codelink$method$background <- "Codelink Subtract"
				codelink$method$normalization <- "Codelink Median"
				# Set values based on Flags.
				#if(!is.null(flag$M)) {
					#codelink$Ni[flag.m, n] <- flag$M
				#}
				#if(!is.null(flag$I)) {
					#codelink$Ni[flag.i, n] <- flag$I
				#}
				#if(!is.null(flag$C)) {
					#codelink$Ni[flag.c, n] <- flag$C
				#}
				#if(!is.null(flag$S)) {
					#codelink$Ni[flag.s, n] <- flag$S
				#}
				#if(!is.null(flag$G)) {
					#codelink$Ni[flag.g, n] <- flag$G
				#}
				#if(!is.null(flag$L)) {
					#codelink$Ni[flag.l, n] <- flag$L
				#}
				#if(!is.null(flag$X)) {
					#codelink$Ni[flag.x, n] <- flag$X
				#}
			}
		)
		if(n == 1) {
			if(file.type == "Codelink") {
				codelink$name <- as.character(data[, "Probe_name"])
				codelink$type <- as.character(data[, "Probe_type"])
				if(!fix && !is.null(data$Feature_id))
					codelink$id <- as.character(data[, "Feature_id"])
				if(any(grep("Logical_row", head$columns)) &&
					any(grep("Logical_col", head$column))) {
					codelink$logical[,"row"] <- data[, "Logical_row"]
					codelink$logical[,"col"] <- data[, "Logical_col"]
				}
			} else {
				codelink$name <- as.character(data[, "Probe_Name"])
				codelink$type <- as.character(data[, "Type"])
			}
		}
	}
	
	codelink=new("Codelink", codelink)

	# fix flags.
	if(old) {
		cat("** applying flags ...")
		for(k in names(flag.cc)) {
			sel <- grep(k, codelink$flag)
			switch(type,
				   "Spot" = {
				   	codelink$Smean[sel] <- flag.cc[[k]]
				   	codelink$Bmedian[sel] <- flag.cc[[k]]
				   },
				   "Raw" = {
				   	codelink$Ri[sel] <- flag.cc[[k]]
				   },
				   "Norm" = {
				   	codelink$Ni[sel] <- flag.cc[[k]]
				   }
				   )
		}
		cat("OK\n")
	} else {
		cat("** applying flags to MSR spots ...")
		for(k in names(flag.cc.new)) {
			sel <- grep(k, codelink$flag)
			switch(type,
				   "Spot" = {
				   	codelink$Smean[sel] <- flag.cc.new[[k]]
				   	codelink$Bmedian[sel] <- flag.cc.new[[k]]
				   },
				   "Raw" = {
				   	codelink$Ri[sel] <- flag.cc.new[[k]]
				   },
				   "Norm" = {
				   	codelink$Ni[sel] <- flag.cc.new[[k]]
				   }
				   )
		}
		cat("OK\n")
	}
		
	cat("** computing weights ...")
	codelink$weight=createWeights(codelink,type.weights=type.ww,flag.weights=flag.ww)
	cat("OK\n")
	
	# compute SNR.
	if(type == "Spot") {
		if(verbose>0) cat("** computing SNR ...")
		codelink$snr <- SNR(codelink$Smean, codelink$Bmedian, codelink$Bstdev)
		if(verbose>0) cat("OK\n")
		if(!preserve) codelink$Bstdev <- NULL
	}
	
	if(!is.null(sample.name)) codelink$sample <- sample.name
	codelink$file <- files
	codelink$product <- product

	codelink
}
# writeCodelink()
# write Codelink object to file.
writeCodelink <- function(object, file, dec = ".", sep = "\t", flag = FALSE, chip) {
	if(!is(object, "Codelink")) stop("A Codelink object is needed.")

	write(paste("# BkgdCorrection method", object$method$background, sep = sep), file = file)
	write(paste("# Normalization method", object$method$normalization, sep = "\t"), file = file, append = TRUE)
	write(paste("# Log transformed", object$method$log, sep = "\t"), file=file, append = TRUE)

	if(missing(chip)) chip <- annotation(object)
	if(chip == "") stop("chip name is needed.")	
	probes <- object$name
	probes.acc <- lookUp(probes, chip, "ACCNUM", load = TRUE)
	probes.eg <- lookUp(probes, chip, "ENTREZID")

	val <- NULL
	if(!is.null(object$Smean)) val <- object$Smean
	if(!is.null(object$Ri)) val <- object$Ri
	if(!is.null(object$Ni)) val <- object$Ni

	tmp <- cbind(object$name, unlist(probes.acc), unlist(probes.eg), val, object$snr)
	head <- c("PROBE_NAME", "ACCESSION", "ENTREZID", paste("INTENSITY_", object$sample, sep = ""),
            paste("SNR_", object$sample, sep = ""))

	if(flag) {
		tmp <- cbind(tmp, object$flag)
		head <- c(head, paste("FLAG_", object$sample, sep =""))
	} 

	rownames(tmp) <- 1:dim(object)[1]
	tmp <- rbind(Index=head, tmp)
	write.table(tmp, file = file, quote = FALSE, sep = sep, dec = dec, col.names = FALSE)
}

# assignWeights=function(x,flag.w) {
# 	w = matrix(1, nrow = nrow(x), ncol = ncol(x))
# 	for(k in names(flag.w)) {
# 		sel=grep(k,x)
# 		# keep the lowest weight.
# 		w[sel][w[sel]>flag.w[k]]=flag.w[k]
# 	}
# 	w
# }

# "assignWeights<-"=function(object, weight) {
# 	assayDataElement(x, "weight")=weight
# }
# setGeneric("assignWeights")

setGeneric("createWeights", function(object,type.weights=NULL,flag.weights=NULL) standardGeneric("createWeights"))
setMethod("createWeights", "CodelinkSet",
function(object,type.weights=NULL,flag.weights=NULL) {
	w=createTypeWeights(object,type.weights)
	createFlagWeights(object,flag.weights,weights=w)
})
setMethod("createWeights", "Codelink",
function(object,type.weights=NULL,flag.weights=NULL) {
  w=createTypeWeights(object,type.weights)
  createFlagWeights(object,flag.weights,weights=w)
})


setGeneric("createFlagWeights", function(object,flag.weights=NULL,weights) standardGeneric("createFlagWeights"))
setMethod("createFlagWeights", "CodelinkSet",
function(object,flag.weights=NULL,weights) {
	if(missing(weights)) {
		w = array(1,dim(object))
		colnames(w)=sampleNames(object)
		rownames(w)=featureNames(object)	
	} else w = weights
	if(is.null(flag.weights))
		flag.weights = c("G"=1,"L"=1,"S"=1,"C"=0,"I"=0,"M"=0,"X"=0)
	for(k in names(flag.weights)) {
		sel=grep(k,getFlag(object))
		# keep the lowest weight.
		w[sel][w[sel]>flag.weights[k]]=flag.weights[k]
	}
	w
})

setMethod("createFlagWeights", "Codelink",
function(object,flag.weights=NULL,weights) {
  if(missing(weights)) {
  	w = array(1,dim(object))
  	colnames(w)=colnames(object$Bmedian)
  	rownames(w)=rownames(object$Bmedian)
  } else w = weights
  if(is.null(flag.weights))
  	flag.weights = c("G"=1,"L"=1,"S"=1,"C"=0,"I"=0,"M"=0,"X"=0)
  for(k in names(flag.weights)) {
  	sel=grep(k,object$flag)
  	# keep the lowest weight.
  	w[sel][w[sel]>flag.weights[k]]=flag.weights[k]
  }
  w
})

setGeneric("createTypeWeights", function(object,type.weights=NULL,weights) standardGeneric("createTypeWeights"))
setMethod("createTypeWeights","CodelinkSet",
function(object,type.weights=NULL,weights) {
	if(missing(weights)) {
		w = array(1,dim(object))
		colnames(w)=sampleNames(object)
		rownames(w)=featureNames(object)	
	} else w = weights
	if(is.null(type.weights))
		type.weights = c("DISCOVERY"=1,"FIDUCIAL"=0,"POSITIVE"=0,"NEGATIVE"=0, "OTHER"=0)
	for(k in names(type.weights)) {
		sel=grep(k,probeTypes(object))
		# keep the lowest weight.
		w[sel,][w[sel,]>type.weights[k]]=type.weights[k]
	}
	w
})

setMethod("createTypeWeights","Codelink",
function(object,type.weights=NULL,weights) {
  if(missing(weights)) {
  	w = array(1,dim(object))
  	colnames(w)=colnames(object$Bmedian)
  	rownames(w)=rownames(object$Bmedian)
  } else w = weights
  if(is.null(type.weights))
  	type.weights = c("DISCOVERY"=1,"FIDUCIAL"=0,"POSITIVE"=0,"NEGATIVE"=0, "OTHER"=0)
  for(k in names(type.weights)) {
  	sel=grep(k,object$type)
  	# keep the lowest weight.
  	w[sel,][w[sel,]>type.weights[k]]=type.weights[k]
  }
  w
})



# reportCodelink()
# report output to HTML.
reportCodelink <- function(object, chip, filename=NULL, title="Main title", probe.type=FALSE, other=NULL, other.ord=NULL) {
	if(!is(object,"Codelink") && !is(object,"character")) stop("Codelink object or character vector needed.")
	if(probe.type && !is(object,"Codelink")) stop("Codelink object needed putting type")
	if(is.null(filename)) stop("Filename needed.")

	if(is(object,"Codelink")) genes <- object$name else genes <- object
	if(!is.null(other)) {
		if(!is.null(other.ord)) {
			ord <- order(other[[other.ord]])

			genes <- genes[ord]
			for(n in names(other)) {
				other[[n]] <- other[[n]][ord]
			}
		}
	}
	if(probe.type) genes.type <- object$type
	genes.acc <- lookUp(genes, chip, "ACCNUM")
	genes.eg <- lookUp(genes, chip, "ENTREZID")
	genes.ug <- lookUp(genes, chip, "UNIGENE")
	genes.sym <- lookUp(genes, chip, "SYMBOL")
	genes.name <- lookUp(genes, chip, "GENENAME")

	# cleaup names.
	genes.sym[is.na(genes.sym)] <- ""
	genes.name[is.na(genes.name)] <- ""
	
	genes.list <- list(genes, genes.acc, as.character(genes.eg), as.character(genes.ug))
	head <- c("Id", "Genbank", "Entrez ID", "Unigene", "Symbol", "Name")
	other.list <- list(genes.sym, genes.name)

	if(probe.type) {
		head <- c(head, "TYPE")
		other.list <- c(other.list,list(genes.type))
	}
	if(!is.null(other)) {
		head <- c(head, names(other))
		other.list <- c(other.list, other)
	}
	htmlpage(genelist=genes.list, filename=filename, table.head=head, othernames = other.list, title=title, repository = list("gb","gb","ll","ug"))
	#css <- "<style> body {font-family: Arial, Helvetiva, sans-serif;} table {font-size: 8pt; border: solid 1px black;} th{color: white; background: black;} td{border: 0; max-width: 300px;vertical-align: top;}</style>"
	#cat(css, file=filename, append=TRUE)
}

# this is not yet used because of portability issues in the C code.
# readCodelinkFiles <- function(files = list.files(pattern = "TXT"),
# 	what = "Spot_mean", flag)
# {
# 	what <- match.arg(what, c("Spot_mean", "Raw_intensity", "Norm_intensity"))
# 	tmp <- .Call("R_read_codelink", files, what, PACKAGE="codelink")
# 
# 	flags <- c("G", "L", "S", "C", "I", "M", "X")
# 	flag.cc <- list(M=NA, C=NA, I=NA)
# 	if(!missing(flag)) {
# 		for(k in names(flag)) {
# 
# 			if(any(k %in% flags))
# 				flag.cc[[k]] <- flag[[k]]
# 			else
# 				warning("unknown flag ", k, " skipping.\n")
# 		}
# 	}
# 
# 	nfiles <- ncol(tmp$intensity)
# 	nprobes <- nrow(tmp$intensity)
# 	dims <- list(1:nprobes, 1:nfiles)
# 
# 	cod <- new("Codelink")
# 	cod$product <- tmp$product
# 	cod$file <- tmp$file
# 	cod$sample <- tmp$sample
# 	switch(tmp$what,
# 		Spot_mean = {
# 			cod$method$background = "NONE"
# 			cod$method$normalization = "NONE"
# 			cod$method$merge = "NONE"
# 			cod$method$log = FALSE
# 		},
# 		Raw_intensity = {
# 			cod$method$background = "Codelink subtract"
# 			cod$method$normalization = "NONE"
# 			cod$method$merge = "NONE"
# 			cod$method$log = FALSE
# 		},
# 		Norm_intensity = {
# 			cod$method$background = "Codelink subtract"
# 			cod$method$normalization = "Codelink median"
# 			cod$method$merge = "NONE"
# 			cod$method$log = FALSE
# 		}
# 	)
# 	cod$name <- tmp$name
# 	cod$type <- tmp$type
# 	cod$id <- tmp$id
# 	cod$logical <- cbind(row = tmp$row, col = tmp$col)
# 	cod$flag <- tmp$flag
# 	cod$Smean <- tmp$intensity
# 	cod$Bmedian <- tmp$background
# 	cod$Bstdev <- tmp$bstdev
# 	
# 	# fix flags.
# 	cat("** applying flags ...")
# 	for(k in names(flag.cc)) {
# 		sel <- grep(k, cod$flag)
# 		cod$Smean[sel] <- flag.cc[[k]]
# 		cod$Bmedian[sel] <- flag.cc[[k]]
# 	}
# 	cat("OK\n")
# 	
# 	# compute snr.
# 	cat("** computing SNR ...")
# 	cod$snr <- SNR(tmp$intensity, tmp$background, tmp$bstdev)
# 	cat("OK\n")
# 
# 	# fix dimnames.
# 	dimnames(cod$flag) <- dims
# 	dimnames(cod$snr) <- dims
# 	dimnames(cod$Smean) <- dims
# 	dimnames(cod$Bmedian) <- dims
# 	dimnames(cod$Bstdev) <- dims
# 
# 	cod
#}
