#
#   make lognormal template
#
#   Make a log-normal distribution to use as template for population
#   generation by make_population.sh
#
#   	This is a counterintuitive command. Please, read carefully.
#
#   	This command takes three arguments:
#
#   	    NOTUS   -- number of OTUs
#   	    MEANLOG -- log(mean) for the REFERENCE distribution
#   	    SDLOG   -- log(sd) for the REFERENCE distribution
#
#   The key word here is REFERENCE. Please, read on.
#
#   Using these values, this command will generate a REFERENCE distribution
#   using R. Now, this distribution will contain many values less than one,
#   and so, to calculate population OTU sizes, we will round off values up
#   thus skewing the distribution to the right. The net result will be that
#   the final distribution will have a log(mean) and log(sd) that are different
#   from those specified in the command line.
#
#   We will calculate those values and report them, and name the final
#   population OTU sizes file after those, but the point to remember is
#   that you will get two files
#
#   	    LogNormal-$NOTUS-$SDLOG-$MEANLOG-template.txt
#   	    	    This one will contain the reference distribution that
#   	    	    complies with the requested values AND the final up-rounded
#   	    	    integer distribution that does NOT.
#
#   	    LogNormal-M-S-N.txt
# 	    	    This one will contain the corresponding, integer, up-rounded
#   	    	    vlaues, and the name will indicate the actual corresponding
#   	    	    final parameters.
#
#   (C) José R. Valverde, EMBnet/CNB, CSIC. 2012
#   Licensed under EU-GPL
#
#
function usage {
    cat<<END
    
    Usage: $0 [notus] [meanlog] [sdlog] [-h]
    Usage: $0 [-n notus] [-m meanlog] [-s sdlog] [-h]
    Usage: $0 [--notus notus] [--log-mean meanlog] [--log-sd sdlog] [--help]
    
    Default values are: notus=1000 log(mean)=0 log(sd)=1
    
    This will generate a reference real log-normal distribution with the 
    specified parameters, and a derived integer log-normal distribution 
    using the ceiling-rounded values which will, therefore, have different 
    parameters instead. These are printed out at the end and saved in another
    file:
    
    	LogNormal-notus-meanlog-sdlog-template.txt
	    -- the real and integer distribution values
    	LogNormal-notus-meanlog-sdlog-template.prm
	    -- the parameters measured for the reference population by
	    a curve fit, which should be close to the command line arguments,
	    and the actual parameters of the integer derived distribution
	    which should be right-skewed (bigger) than the command line ones
	Lognormal-notus-meanlog-sdlog.txt
    	    -- the integer distribution to use with make_population.sh

END
}

NOTUS=-1
MEANLOG=-1
SDLOG=-1

# Parse the command line
# ----------------------
# Note that we use `"$@"' to let each command-line parameter expand to a 
# separate word. The quotes around `$@' are essential!
# We need TEMP as the `eval set --' would nuke the return value of getopt.
TEMP=`getopt -o hn:m:s: \
     --long help,notus:,log-mean:,log-sd: \
     -n "$0" -- "$@"`

# an invalid option was given
if [ $? != 0 ] ; then usage >&2 ; exit 1 ; fi

# Note the quotes around `$TEMP': they are essential!
eval set -- "$TEMP"

while true ; do
	case "$1" in
		-h|--help) 
		    usage ; shift ;;
		-n|--notus)
		    # echo "NUM OTUS $2"
		    # if $2 is a positive number, use it, ignore otherwise
		    if [[ $2 =~ ^[0-9]+$ ]] ; then NOTUS=$2 ; fi
		    shift 2 ;;
		-m|--log-mean)
		    # echo "log(mean) $2"
		    # if $2 is a positive number, use it, ignore otherwise
		    if [[ $2 =~ ^[0-9]+$ ]] ; then MEANLOG=$2 ; fi
		    shift 2 ;;
		-s|--log-sd)
		    # echo "log(sd) $2"
		    # if $2 is a positive number, use it, ignore otherwise
		    if [[ $2 =~ ^[0-9]+$ ]] ; then SDLOG=$2 ; fi
		    shift 2 ;;
		--) shift ; break ;;
		*) echo "Internal error!" >&2 ; usage ; exit 1 ;;
	esac
done


# if no values could be got from named arguments, then try to get
# them from the remaining args, but note that then they will be
# position dependent
if [ $NOTUS -eq -1 ] ; then NOTUS=${1:-1000} ; shift ; fi
if [ $MEANLOG -eq -1 ] ; then MEANLOG=${1:-0} ; shift ; fi
if [ $SDLOG -eq -1 ] ; then SDLOG=${1:-1} ; shift; fi

echo "$0 -n $NOTUS -m $MEANLOG -s $SDLOG"
#exit

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

# fit distributions and get actual parameters
R --vanilla <<END
library("MASS")
Dataset <- 
  read.table("LogNormal-$MEANLOG-$SDLOG-$NOTUS-template.txt",
   header=FALSE, sep="", na.strings="NA", dec=".", strip.white=TRUE)
sink("LogNormal-$MEANLOG-$SDLOG-$NOTUS-template.prm", append=FALSE, split=TRUE)
fitdistr(Dataset\$V1, "lognormal")
fitdistr(Dataset\$V2, "lognormal")
sink()
f2 <- fitdistr(Dataset\$V2, "lognormal")
write.table(f2\$estimate, "kkk", col.names=FALSE, row.names=FALSE, quote=FALSE, na="NA")
END
ML=`head -n 1 kkk`
SDL=`tail -n 1 kkk`
rm -f kkk
echo "Final log(mean)=$ML log(sd)=$SDL"

cut -d'	' -f2 LogNormal-$MEANLOG-$SDLOG-$NOTUS-template.txt > LogNormal-$MEANLOG-$SDLOG-$NOTUS.txt

