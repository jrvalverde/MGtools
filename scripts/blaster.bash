#!/bin/bash
#
# run blast on a fasta file against Silva SSU with he suggested
# parameters for MEGAN taxonomic assignment.
#
#	May be run as
#
#	blast file
#
#	f=path/to/file blast
#
#	The last form is appropriate for submitting as a generic batch
# job.
#
# (C) Jose R Valverde, 2009-2012
#
#	Released under EU-GPL
#

# CUSTOMIZE THIS TO POINT TO SILVA DATABASE
DB=$HOME/data/silva/ssu

# CUSTOMIZE PATH to find blast1
# in trueno
#export PATH=/home/cnb/jrvalverde/src/ncbi/ncbi-2.2.14/ncbi/bin:$PATH
# in cnb
#export PATH=/home/scientific/contrib/ncbi/ncbi-2.2.14/ncbi/bin:$PATH
# in ngs
# unneeded, system installed

function usage {
    cat <<END

    Usage: $0
    Usage: $0 file.fasta
    Usage: $0 -i file.fasta
    Usage: $0 --input file.fasta
    Usage: $0 -h/--help     	    	(print this help)
    
    	The fasta file to blast against the default database defined
	in this script.
	
	If the fasta file contains more than 70000 sequences it will
	be split in chunks and each chunk blasted separately. Output
	in this case will go to a subdirectory instead of a file.
	
    Example: $0 readmap.uc

END
}

f=""

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
		    f=$2 ; shift 2 ;;
		--) shift ; break ;;
		*) echo "Internal error!" >&2 ; usage ; exit 1 ;;
	esac
done

# check if $f is set and if not, use $1
if [ $f == "" ] ; then f=${1:-"sequences.fas"} ; fi

if [ ! -e $f ] ; then usage ; echo "Error: $f must exist" ; exit ; fi

file=$f


# remove directory path (everything up to the last /)
f="${file##*/}"
# get extension (remove everything up to the last .)
ext="${file##*.}"
# get name (remove everything from last . till end)
n="${f%.*}"
# get directory (remove everything from last / till end)
d=${file%/*}

if [ ! -e $file ] ; then echo "Error: $file does not exist!" ; exit ; fi

echo "Blasting $d/$n.$ext ($file)"

cd $d


# check if the input file is too long: in our hands, blast starts producing
# garbage on output after ~75.000 sequences.
#   NOTE: we do not use blast2, because it's even worst: blast2 caches all
#   output till the last minute and when the input file is too long, it
#   crashes leaving no output behind, possibly after days or weeks of
#   computation.

nseqs=`grep -c ">" $f`
if [ $nseqs -le 70000 ] ; then

    if [ ! -s $n.blastn ] ; then
	blastall -p blastn -F "m D" -W 7 -f 8 -E 100 \
	    -d $DB \
	    -i $f \
	    > $n.blastn 2>&1
    fi
    echo "Results will be saved in $n.blastn"

else

    mkdir -p $n
    cd $n
    # split file in 70K seqs chunks
    psplit  -L "^>" -l 70000 -a 4 ../$f seq-
    # rename chunks
    i=0
    for j in seq-* ; do 
    	i=$(($i+1)) 
	echo mv $j seq-`printf "%06d" $i`.fas 
    done
    d=`pwd`
    # NOTE: you may want to parallelize this
    #	e. g. backgrounding jobs or using batch queues
    #	As batch processing is system dependent, we do not provide it
    for f in *.fas ; do
	if [ ! -s `basename $f .fas`.blastn ] ; then
    	    # e.g.
    	    #qsub -q slow -V -N $n-$f <<ENDSUB
	    #  cd $d
	    blastall -p blastn -F "m D" -W 7 -f 8 -E 100 \
	    	-d $DB \
	    	-i $f \
	    	> `basename $f .fas`.blastn 2>&1
#ENDSUB
	else
    	    echo "ignoring $f"
	fi
    done
    echo "Results will be saved in subdirectory $n"

fi
