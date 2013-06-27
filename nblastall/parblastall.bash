#!/bin/bash
#
#   Run blastall in parallel
#
#   This script will process the command line and extract the target
# file name, then split this file in chunks in a subdirectory, run 
# blastall against each chunk in parallel using up to a maximum of 
# half the available number of processors, and return the concatenated 
# output of each blast sub-job
#
#   In order to return the output properly, and since we will run jobs
# in parallel, we need to avoid interspersed parallel job output, that
# means that each sub-job needs to save its output to a file so that
# once completed all files can be returned.
#
#   Since we use xargs(1) to do the parallelization, we cannot redirect
# each separate command output easily, so we use an auxiliary script
# blastall_sav that will run blastall and save its output to a file.
#
#
#   NOTE: an alternative may be to measure the size of the file in sequences
# then split the file in as many pieces as the maximum number of simultaneous
# jobs only, and run all processes at once instead of using xargs. This
# other approach may be simpler and cleaner, and should work for blastall
# as it lacks blast2 file size/memory size limitations.
#

METAMOS_HOME="/home/scientific/contrib/metAMOS-master"

# our blastall that saves output to a .blast file
blastallsav="$METAMOS_HOME/Utilities/bash/blastall_sav"
psplit="psplit"

# working subdir
chunks="blastall_chunks"
chunksize=50000

# the new command line is
cmd="$blastallsav $*"
#@echo "Cmd: $cmd"

# Use half the processors available
n=`grep -c processor /proc/cpuinfo`
if [ $n -ne 1 ] ; then let n=$n/2 ; fi

echo "$n CPUs will be used"

# find out -i argument in command line
# split -i argument file into $n pieces
# call blastall with the command line substituting -i argument by chunk
#
# blastall [-] [-A N] [-B N] [-C x] [-D N] [-E N]  [-F str]  [-G N]  [-I]
#       [-J]   [-K N]  [-L start,stop]  [-M str]  [-O filename]  [-P N]  [-Q N]
#       [-R filename] [-S] [-T] [-U] [-V] [-W N] [-X N]  [-Y X]  [-Z N]  [-a N]
#       [-b N] [-d str] [-e X] [-f X] [-g F] [-i filename] [-l str] [-m N] [-n]
#       [-o filename] -p str [-q N] [-r N] [-s]  [-t N]  [-v N]  [-w N]  [-y X]
#       [-z X]
#
# option string would be:
#A:B:C:D:E:F:G:IJK:L:M:O:P:Q:R:STUVW:X:Y:Z:a:b:d:e:f:g:i:l:m:no:p:q:r:stv:w:y:z:
#
# we only need to check for the i argument split the file and call repeatedly with
# the values.
#
#echo $#
while (( $# )) ; do
#    echo $1
    if [ "$1" == "-i" ] ; then
#    	echo -n "-i " 
	shift
	infile=$1
	break
    fi
    shift
done
if [ "$in" == "" ] ; then
    infile=$(tempfile)
    cat > $infile
else
    infile="$in"
fi
#echo "Parallel blastall processing of $infile"

# do we need this?
#inseqs=`grep -c '^>' $infile

if [ ! -d $chunks ] ; then mkdir $chunks ; fi
rm -rf $chunks/*

$psplit -L '^>' -l $chunksize -a 8 $infile $chunks/chunk

# Build the template command line
#
#chunk='kkk.fas'
#echo `echo "$cmd" | sed -e "s/-i[[:space:]][^[:space:]]*[[:space:]]/-i $chunk /g"`
#
#echo `echo "$cmd" | sed -e "s/-i [^ ]* /-i $chunk /g"`
#
#minicmd=`echo "$cmd" | sed -e "s/[[:space:]]-i[[:space:]][^[:space:]]*[[:space:]]//g"`
minicmd=`echo "$cmd" | sed -e "s/[[:space:]]-i[[:space:]]*[^[:space:]]*\b//g"`
# echo MINICMD: $minicmd

# use xargs to parallelize
cd $chunks
ls chunk* | xargs -l -P $n $minicmd "-i"
cat *.blast
cd ..
rm -rf $chunks


