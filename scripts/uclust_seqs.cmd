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
##	YOU MAY WANT TO CUSTOMIZE THIS
##
export u=${u:-"$HOME/bin/usearch"}
export UCHIME_REFDB=${UCHIME_REFDB:-"$HOME/data/gold/gold.fa"}
##
##	END OF CUSTOMIZATION SECTION
##

# minimal sanity checks
if [ $# -lt 1 ] ; then echo "usage: $0 file.fas {optional-min-cluster-size}"; exit ; fi

if [ ! -e $1 ] ; then echo "error: first argument must be an existing fasta file"; exit ; fi

# get fasta file directory
d=`dirname $1`
# get fasta file name without extension
#file=`basename $1`
# note: this can also be done avoiding and external call with
file="${1##*/}"
ext="${file##*.}"
n="${file%.*}"

#echo $d $file $n $ext ; exit

#export MINSIZE=1
#export MINSIZE=3
# set minsize to $2 or, if undefined, to 1
export MINSIZE=${2:-1}

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
