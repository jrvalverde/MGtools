#!/bin/bash
#
#   run blastall saving output to infile.blast

# real blastall
blastall="/home/scientific/contrib/metAMOS-master/Utilities/cpp/Linux-x86_64/blastall"

#echo $0 $*
args="$*"
# loop over args, find -i infile and save to infile.blast
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
$blastall "$args" > $infile.blast
sleep 3
