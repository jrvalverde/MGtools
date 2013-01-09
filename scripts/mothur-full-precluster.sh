#!/bin/sh
#
#   Run mothur on an input data file using all three neighbor joining
#   methods and preclustering
#   	called with $f = filename.fas or $1 = filename.fas
#
#   Allowing use of the first argument or of an environment variable
#   enables us to run the command as a job in a cluster queue. In that
#   case, the full file path name should be given.
#
#   (C) Jose R Valverde, EMBnet/CNB, 2009-2012
#   	jrvalverde@cnb.csic.es
#
#
# on call we get $file the fasta formatted UNaligned sequences file name.
#
#echo "$PBS_JOBID: called with f=$f" >> log

MOTHUR=mothur

f=${f:-""}

if [ "$f" == "" ] ; then
    f=${1:-""}
fi

if [ ! -e "$f" ] ; then
    echo "Error: '$f' does not exist!"
    echo "Usage: $0 file.fas"
    echo "Usage: f=file.fas $0"
    exit
fi

dir=${dir-`dirname $f`}
fname=${ffile-`basename $f`}

dir=`dirname $f`
file=`basename $f`
base=`basename $f .fas`
#
# We assume a .fas termination!
#base=`basename $base .fna`

if [ ! -d $dir/mothur-full-pre ] ; then
	mkdir $dir/mothur-full-pre
fi
cd $dir/mothur-full-pre


# work on a subdirectory to keep things organized
if [ ! -d ${base}-mothur-pre ] ; then
  mkdir ${base}-mothur-pre
  cd ${base}-mothur-pre
  ln -s ../../ref/* .
  ln -s $f .

  # run mothur
  #	Perform a single sample analysis of the data file
  #
  #	1. Read aligned sequences (we could align them using MOTHUR as well)
  #	2. Do preclustering to reduce dataset size
  #	3. Compute distances and store in phylip format
  #	4. compute rarefaction curves and maps
  $MOTHUR <<END > mothur.out 2>&1
unique.seqs(fasta=$file)
align.seqs(candidate=$base.unique.fas,template=silva.bacteria.fasta)
filter.seqs(fasta=$base.unique.align)
unique.seqs(fasta=$base.unique.filter.fasta, name=$base.names)
pre.cluster(fasta=$base.unique.filter.unique.fasta, name=$base.unique.filter.names)
dist.seqs(fasta=$base.unique.filter.unique.fasta,output=lt)
read.dist(phylip=${base}.unique.filter.unique.phylip.dist, cutoff=0.10, precision=1000)
cluster(method=furthest)
rarefaction.single()
collect.single()
summary.single()
heatmap.bin(scale=log2, label=0.03)
heatmap.bin(scale=linear)
heatmap.bin()
read.dist(phylip=${base}.unique.filter.unique.phylip.dist, cutoff=0.10, precision=1000)
cluster(method=nearest)
rarefaction.single()
collect.single()
summary.single()
heatmap.bin(scale=log2, label=0.03)
heatmap.bin(scale=linear)
heatmap.bin()
read.dist(phylip=${base}.unique.filter.unique.phylip.dist, cutoff=0.10, precision=1000)
cluster(method=average)
rarefaction.single()
collect.single()
summary.single()
heatmap.bin(scale=log2, label=0.03)
heatmap.bin(scale=linear)
heatmap.bin()
END
  mkdir -p ../../mothur-pre
  cp $base.unique.filter.unique.precluster.fasta ../../mothur-pre/$base.aln
  cd ..
fi
cd ..
