# 2012 Frank Grimm (http://frankgrimm.net)
# plot raw, band and combined plots

# Note: make sure to delete empty csv files / csv files that don't contain data rows

# read raw data
loadRaw <- function(basedir, timestamp, rawfile) {
	RawData <- read.delim(paste(basedir, rawfile, sep=""), sep="\t", strip.white=TRUE)
	RawData$idx <- 1:length(RawData$time)
	return(RawData)
}

# read data for individual bands
loadBands <- function(basedir, timestamp, bandfile) {
	BandData <- read.delim(paste(basedir, bandfile, sep=""), sep="\t", strip.white=TRUE)
	BandData$idx <- 1:length(BandData$time)
	return(BandData)
}

outputGraphs <- function(basedir, timestamp, RawData, BandData) {

	#prepare output
	png(paste(basedir, timestamp, "-co.png", sep=""), width=4096, height=768, bg="white")
	par(mfrow=c(2,1))

	#raw value plot
	plot(RawData$idx, RawData$raw, type="l", xlab="Index", ylab="Value", main=paste("Raw (", timestamp, ")", sep= ""))

	legend("topright", col="black", legend=c("raw"), cex=0.6, lwd=1, bg="white")

	#combined band-plot
	bp_ylim <- c(min(BandData$delta, BandData$theta, BandData$alpha_low, BandData$alpha_high, BandData$beta_low, BandData$beta_high, BandData$gamma_low, BandData$gamma_mid), max(BandData$delta, BandData$theta, BandData$alpha_low, BandData$alpha_high, BandData$beta_low, BandData$beta_high, BandData$gamma_low, BandData$gamma_mid))
	bp_colors <- rainbow(8)
	plot(BandData$idx, BandData$alpha_low, type="n", xlab="Index", ylab="Value", main="Bands", col=bp_colors[1])
	bp_columns = colnames(BandData)[2:9]
	for (bandIdx in 1:length(bp_columns)) {
	  lines(BandData$idx, BandData[[bp_columns[bandIdx]]], ylim=bp_ylim, col=bp_colors[bandIdx])
	}
	#add legend
	legend("topright", col=bp_colors[1:8], legend=bp_columns, cex=0.6, lwd=1, bg="white")
	dev.off()
}

outputRawAnalysis <- function(basedir, timestamp, RawData) {
	png(paste(basedir, timestamp, "-raw.png", sep=""), width=8192, height=768, bg="white")	
	par(mfrow=c(1,1))

	bp_ylim <- c(min(BandData$delta, BandData$theta, BandData$alpha_low, BandData$alpha_high, BandData$beta_low, BandData$beta_high, BandData$gamma_low, BandData$gamma_mid), max(BandData$delta, BandData$theta, BandData$alpha_low, BandData$alpha_high, BandData$beta_low, BandData$beta_high, BandData$gamma_low, BandData$gamma_mid))
	bp_colors <- rainbow(8)
	plot(BandData$idx, BandData$alpha_low, type="n", xlab="Index", ylab="Value", main="Bands", col=bp_colors[1])
	bp_columns = colnames(BandData)[2:9]
	for (bandIdx in 1:length(bp_columns)) {
	  lines(BandData$idx, BandData[[bp_columns[bandIdx]]], ylim=bp_ylim, col=bp_colors[bandIdx])
	}
	#add legend
	legend("topright", col=bp_colors[1:8], legend=bp_columns, cex=0.6, lwd=1, bg="white")
	dev.off()

}

outputBandGraph <- function(basedir, timestamp, BandData) {
	png(paste(basedir, timestamp, "-bands.png", sep=""), width=8192, height=768, bg="white")	
	par(mfrow=c(1,1))

	plot(RawData$idx, RawData$raw, type="n", xlab="Index", ylab="Value", main=paste("Combined (", timestamp, ")", sep= ""))
	lines(RawData$idx, RawData$raw, type="l")

	legend("topright", col="black", legend=c("raw"), cex=0.6, lwd=1, bg="white")
	
	dev.off()
}

# enum raw data files
basedir <- "./"
rawfiles = list.files(path=basedir, pattern="*-raw.csv")

for (rawfile in rawfiles) {
	# create filenames
	timestamp = substr(rawfile, 0, nchar(rawfile)-8)
	bandfile = paste(timestamp, "-bands.csv", sep="")
	
	# print some info
	print(paste("File (raw): ", basedir, timestamp, rawfile, sep=""))
	print(paste("File (bands): ", basedir, timestamp, bandfile, sep=""))

	# load data
	RawData <- loadRaw(basedir, timestamp, rawfile)
	BandData <- loadRaw(basedir, timestamp, bandfile)
	
	# create plots
	outputGraphs(basedir, timestamp, RawData, BandData)
	outputRawAnalysis(basedir, timestamp, RawData)
	outputBandGraph(basedir, timestamp, BandData)
	
}
