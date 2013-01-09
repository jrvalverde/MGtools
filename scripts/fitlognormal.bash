#!/bin/bash
#
#	(C) José R. Valverde, EMBnet/CNB, CSIC. 2012
#
#	Licensed under EU-GPL
#
function usage {
    cat <<END

    Usage: $0
    Usage: $0 richness
    Usage: $0 -i richness
    Usage: $0 --input richness
    Usage: $0 -h/--help     	    	(print this help)
    
    	richness: a file containing pairs of numbers, a pair per line,
	    representing each the number of individuals and the number
	    of the OTU (i. e. for each OTU we have the number of individuals
	    it contains). You can generate it with uclust_abundances.sh

    Example: $0 richness

END
}

file=""

# Parse the command line
# ----------------------
# Note that we use `"$@"' to let each command-line parameter expand to a 
# separate word. The quotes around `$@' are essential!
# We need TEMP as the `eval set --' would nuke the return value of getopt.
TEMP=`getopt -o hi:m: \
     --long help,input:,min-cluster-size: \
     -n "$0" -- "$@"`

# an invalid option was given
if [ $? != 0 ] ; then usage >&2 ; exit 1 ; fi

# Note the quotes around `$TEMP': they are essential!
eval set -- "$TEMP"

while true ; do
	case "$1" in
		-h|--help) 
		    usage ; shift ;;
		-i|--input) 
		    #echo "INPUT FILE \`$2'" 
		    file=$2 ; shift 2 ;;
		--) shift ; break ;;
		*) echo "Internal error!" >&2 ; usage ; exit 1 ;;
	esac
done

if [ "$file" == "" ] ; then
    # get richness file name
    file=${1:-"richness"}
fi

# get file directory
#	if $1 undefined this will return "."
d=`dirname "$file"`

f="${file##*/}"
ext="${file##*.}"
n="${f%.*}"
# at this point we should have
#   f=readmap.uc n=readmap ext=uc
echo "$0 $d/$f"
#exit

cd $d

if [ ! -e $f ] ; then
   echo "$f does not exist"
   exit
fi


out=$n.prm
if [ -e $out ] ; then echo "$out exists!" ; exit ; fi

R --vanilla > /dev/null 2>&1 <<END
library("MASS")
Dataset <- 
  read.table("$f",
   header=FALSE, sep="", na.strings="NA", dec=".", strip.white=TRUE)
sink("$out", append=FALSE, split=TRUE)
fitdistr(Dataset\$V1, "lognormal")
sink()
#f <- fitdistr(Dataset\$V1, "lognormal")
#write.table(f\$estimate, "$out", col.names=FALSE, row.names=FALSE, quote=FALSE, na="NA")
END
cat $out

