#!/bin/bash
# Run ESPRIT on a fasta file
#	The full filename path must be provided in $f or as the first 
#   command line argument
#
#	e.g.: 
#   	    esprit $HOME/somedir/somefile.fas
#   	    f=$HOME/somedir/somefile.fas esprit
#
#   	This convoluted calling options are built-in so as to make it
#   easy to pass arguments when run as a batch queue job.
#
#   (C) Jose R Valverde, EMBnet/CNB, 2009-2012
#   	jrvalverde@cnb.csic.es
#
#   Licensed under EU-GPL
#

export PATH=$HOME/ESPRIT/bin:$PATH:$HOME/bin


f=${f:-""}
if [ "$f" == "" ] ; then
    f=${1:-""}
fi

if [ ! -e "$f" ] ; then
    echo "Error: '$f' does not exist!"
    echo "Usage: $0 file.fasta"
    echo "Usage: f=file.fasta $0"
    exit
fi

echo $f

dir=`dirname $f`
file=`basename $f`
file=`basename $f | sed -e 's/[()]/-/g'`
base=`basename $f .fas`
base=`basename $base .fna`

cd $dir
if [ ! -d esprit/$base ] ; then
    mkdir -p esprit/$base
    cd esprit/$base
    ln -s $f $file

    date > ../../log/$base.esprit.times

    esprit_pc -f -i $file

    date >> ../../log/$base.esprit.times

fi

#
exit
#
# Pseudocode for esprit_cc: use it to manually recover from failures
#
#   invoking each program alone gives help
#
preproc [-p primer.fas] sequence.fas sequence_clean.fas sequence.frq;
for ((i=1; i<=10; i++)) do
  for ((j=i; j<=10; j++)) do
    kmerdist_par sequence_clean.fas 10 $i $j
  done
done
cat *.dist >> kmer.dist
split -s 100 kmer.dist
for ((i=0; i<=99; i++)) do
  needledist clean.sequence.fas kmer.dist_$i needle.dist_$i
done
cat needle.dist_* >> sequence.ndist
hcluster sequence.ndist sequence.frq
do_stat sequence.Cluster_List
