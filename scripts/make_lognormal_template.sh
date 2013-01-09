#!/bin/bash
#
NOTUS=${1:-1000}
MEANLOG=${2:-0}
SDLOG=${3:-1}

if [ $1 == "-h" ] ; then
	echo "usage: $0 [notus] [meanlog] [sdlog]"
	exit
fi

# refuse to overwrite existing files
if [ -e LogNormal-$MEANLOG-$SDLOG-$NOTUS-template.txt ] ; then
	echo "error: LogNormal-$MEANLOG-$SDLOG-$NOTUS-template.txt exists"
	exit
fi
if [ -e LogNormal-$MEANLOG-$SDLOG-$NOTUS.txt ] ; then
	echo "error: LogNormal-$MEANLOG-$SDLOG-$NOTUS.txt exists"
	exit
fi


R --vanilla <<END
LogNormalSamples <- as.data.frame(matrix(rlnorm($NOTUS*1, meanlog=$MEANLOG, 
  sdlog=$SDLOG), ncol=1))
rownames(LogNormalSamples) <- paste("sample", 1:$NOTUS, sep="")
colnames(LogNormalSamples) <- "obs"
LogNormalSamples\$int <- with(LogNormalSamples, ceiling(obs))
write.table(LogNormalSamples, "LogNormal-$MEANLOG-$SDLOG-$NOTUS-template.txt", 
  sep="\t", col.names=FALSE, row.names=FALSE, quote=FALSE, na="NA")
END

cut -d'	' -f2 LogNormal-$MEANLOG-$SDLOG-$NOTUS-template.txt > LogNormal-$MEANLOG-$SDLOG-$NOTUS.txt

