#!/bin/bash
#
#	uclust_seqs file.fas {minimum-cluster-size}
#
#	Cluster a sequence dataset in Fasta format using Otupipe
#   at 97%, 95% and 90% similarity, using a minimum cluster size
#   of 1 or user-specified.
#
#	This script is intended to be used with 16S data and
#   relies on Gold.fa to locate additional chimeras by default.
#   It also assumes usearch is in ~/bin/usearch.
#
#	If you want to use a different Reference Database or if
#   usearch is located elsewhere, you can either modify the script
#   or define the environment variables u and UCHIME_REFDB before
#   calling this script.
#
#	(C) Jose R Valverde, EMBnet/CNB, CSIC, 2012
#
#	Licensed under EU-GPL
#
#   $Id$
#   $Log$
#

##
##	YOU MAY LIKELY WANT TO CUSTOMIZE THIS
##
export u=${u:-"$HOME/bin/usearch"}
export UCHIME_REFDB=${UCHIME_REFDB:-"$HOME/data/gold/gold.fa"}
##
##	END OF CUSTOMIZATION SECTION
##

function usage {
    cat <<END

    Usage: $0 input.fas
    Usage: $0 input.fas min-cluster-size
    Usage: $0 -i input.fas -m min-cluster-size
    Usage: $0 --input input.fas --min-cluster-size min-clus-siz
    
    	input.fas   is the file containing the sequences to cluster
	min-cluster-size is an optional argument specifying the minimum 
	    	    number of sequences in a given cluster for it to be 
		    considered; if unspecified, it will default to '1'

    	You may use environment variables \$u and \$UCHIME_REFDB to
	select the location of usearch and the Gold reference database.
	
	Output will be saved under a subdirectory udner "uclust-minsize=m"

    Example: $0 input.fas 1

END
}

export PATH=./bin:$PATH

# minimal sanity checks (not really needed as getopt will do its own)
if [ $# -lt 1 ] ; then usage; exit ; fi

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

MINSIZE=0
FILE=""
while true ; do
	case "$1" in
		-h|--help) 
		    usage ; shift ;;
		-i|--input) 
		    #echo "INPUT FILE \`$2'" 
		    FILE=$2 ; shift 2 ;;
		-m|--min-cluster-size)
		    # echo "MIN CUSTER SIZE $2"
		    # if $2 is a positive number, use it, ignore otherwise
		    if [[ $2 =~ ^[0-9]+$ ]] ; then MINSIZE=$2 ; fi
		    shift 2 ;;
		--) shift ; break ;;
		*) echo "Internal error!" >&2 ; usage ; exit 1 ;;
	esac
done

f=$FILE

if [ "$f" == "" ] ; then
    #echo $1
    # see if we can get it from the remaining argument list
    f=$1
    shift
fi
# get fasta file directory
# get fasta file name without extension
d=`dirname $f`
file="${f##*/}"
ext="${file##*.}"
n="${file%.*}"

if [ $MINSIZE -eq 0 ] ; then
    # see if we can retrieve it from the remaining argument list
    #export MINSIZE=1
    #export MINSIZE=3
    # set minsize to $2 ($1 after the shift) or, if undefined, to 1
    export MINSIZE=${1:-1}
fi

echo "$0 -i $f ($d $file) -m $MINSIZE"
#exit

if [ ! -e $f ] ; then
    usage
    echo "Error: $f does not exist!"
    exit
fi

cd $d

# directory to save results to
dest="uclust-minsize=$MINSIZE"

if [ ! -d $dest ] ; then mkdir $dest ; fi
cd $dest
#
# according to Schloss and Handelsman, 3, 5, 20% divergence
# represent species, genus and phylum
#
#for i in 97 95 90 80 ; do
for i in 97 95 90 ; do
    if [ -s $n-$i/otus.fa ] ; then continue ; fi
    export PCTID_ERR=$i
    export PCTID_OTU=$i
    export PCTID_BIN=$i
    export OTUTMPDIR=$n-$i-out
    
    mkdir -p $n-$i
    echo "	Doing $n-$i ($MINSIZE)"
    #pwd
    date > ../log/$n-$i.uclust.log 
    otupipe.bash ../$n.fas $n-$i &>> ../log/$n-$i.uclust.log
    date >> ../log/$n-$i.uclust.log
done
cd ..
