# 2012 Frank Grimm (http://frankgrimm.net)
# calculate simple moving averages on the raw data

# Note: make sure to delete empty csv files / csv files that don't contain data rows

library(zoo)

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

processRawGraph <- function(basedir, timestamp, RawData) {
	png(paste(basedir, timestamp, "-pr.png", sep=""), width=8192, height=768, bg="white")	
	par(mfrow=c(1,1))

	plot(RawData$idx, RawData$raw, type="n", xlab="Index", ylab="Value", main=paste("(", timestamp, ")", sep= ""))
	lines(RawData$idx, RawData$raw, type="l")

	# calculate moving averages
	RawData$rawabs <- abs(RawData$raw)
	RawData$rawmean <- rollmean(zoo(RawData[,2]), 400, fill=0)
	RawData$rawmeanabs <- rollmean(zoo(RawData[,4]), 400, fill=0)
	RawData$tgt <- RawData$rawmeanabs * 3
	
	lines(RawData$idx, RawData$rawmean, type="l", col="red")
	lines(RawData$idx, RawData$rawmeanabs, type="l", col="green")
	lines(RawData$idx, RawData$tgt, type="l", col="blue")

	legend("topright", col="black", legend=c("raw"), cex=0.6, lwd=1, bg="white")
	#print(RawData[2500:2520,])
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
	BandData <- loadBands(basedir, timestamp, bandfile)
	
	processRawGraph(basedir, timestamp, RawData)
	
}

