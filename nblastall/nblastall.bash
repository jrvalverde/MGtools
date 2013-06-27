#!/bin/bash
#
#   run blastall splitting the input file and processing it in parallel
#
#   Right now it will use up to a maximum of half the available CPUs
#   (see $n)
#
#   We need to itercept the -i argument and use it to create the output
# file name.
#
#   This will work for blastall, but is not recommended for blast2
#

METAMOS_HOME="/home/scientific/contrib/metAMOS-master"

# real blastall
blastall="$METAMOS_HOME/Utilities/cpp/Linux-x86_64/blastall.orig"
psplit="$HOME/bin/psplit"
chunks="blast_chunks"

args="$*"
#echo $0 $args

# the new command line is
cmd="$blastall $*"
#@echo "Cmd: $cmd"

# Compute number of processors to use.
#   We can make this as complex as needed, e.g. using LoadAvg or whatever
#   Use half the processors available
# n=`nproc --all`
n=`grep -c processor /proc/cpuinfo`
if [ $n -ne 1 ] ; then let n=$n/2 ; fi
#echo "$n CPUs will be used"


# loop over args, find -i infile and save file name
#   the shifts here modify $* but not $args
while (( $# )) ; do
#    echo $1
    if [ "$1" == "-i" ] ; then
#    	echo -n "-i " 
	shift
	in=$1
	break
    fi
    shift
done

# This is not correct: when no -i is used, blastall reads from stdin
#
#if [ "$in" == "" ] ; then 
#    echo "###ERR: NO INPUT FILE"
#    exit
#else
#    infile="$in"
#fi
# 
# a better approach would be to use the following
#   first check special case (print help and nothing else)
if [ "$args" == "-" ] ; then $blastall - ; exit ; fi
#   otherwise, we're expected to read from stdin
if [ "$in" == "" ] ; then
    infile=$(tempfile)
    cat > $infile
else
    infile="$in"
fi

nseqs=`grep -c '^>' $infile`
if [ $nseqs -eq 0 ] ; then exit ; fi

chunksize=`expr $nseqs / $n`
# this avoids creating one too many jobs
# if nseqs is not a round multiple of n
chunksize=`expr $chunksize + 1`
#echo "CHUNKSIZE: $chunksize"

if [ ! -d $chunks ] ; then mkdir $chunks ; fi
rm -rf $chunks/* ; 

$psplit -L '^>' -l $chunksize -a 8 $infile $chunks/chunk

# Build the template command line
#   basically, we just remove the -i filename combination as we'll substitute
#   it by our own.
#
#   \b matches at a word boundary. A word boundary is a position between a 
#   character that can be matched by \w and a character that cannot be 
#   matched by \w. \b also matches at the start and/or end of the string if 
#   the first and/or last characters in the string are word characters. \B 
#   matches at every position where \b cannot match.
#
#chunk='kkk.fas'
#echo `echo "$cmd" | sed -e "s/-i[[:space:]][^[:space:]]*[[:space:]]/-i $chunk /g"`
#
#echo `echo "$cmd" | sed -e "s/-i [^ ]* /-i $chunk /g"`
#
#minicmd=`echo "$cmd" | sed -e "s/-i[[:space:]][^[:space:]]*[[:space:]]//g"`
#minicmd=`echo "$cmd" | sed -e "s/-i[[:space:]][^[:space:]]*$//g"`
minicmd=`echo "$cmd" | sed -e "s/[[:space:]]-i[[:space:]]*[^[:space:]]*\b//g"`
#echo MINICMD: $minicmd

#
# LET'S DO THE ACTUAL TRICK OF RUNNING BLASTALL IN PARALLEL
#
cd $chunks
for i in * ; do
    $minicmd -i $i >& $i.blast &
done
wait
cat *.blast
cd ..

# should be uncommented in production
#   CLEAN UP
#rm -rf $chunks
# if we were supposed to read from stdin but made a copy instead...
if [ "$in" == "" ] ; then rm -rf $infile ; fi
 
