#!/bin/bash
#
#	Make rarefaction plots using QIIME toolset
#
#	This script implements the full pipeline. It needs to be 
# hand tuned in some specific instances:
#
#	For short sequences, the default Otupipe protocol fails,
# so you cannot use this approach unless you use a specially tuned
# version of Otupipe. This should not bother you if you work with
# 454 seqs, only if you process Illumina data, and even so, only
# with old unpaired reads. See the comments below for some hints,
# but we'll not discuss it as we are still studying the best
# approach.
#
#	By default, most steps store data in a subdirectory as
# a large number of files; we cannot test for them all, but if
# we test for the directory, and a previous run failed mid-way,
# our analysis would fail as well. So, by default, again, we do
# a full calculation each time.
#
#	If you are sure any previous calculation did complete the
# steps corresponding to existing subdirectories (e. g. you remove
# the directory of the last incomplete step) you can save computation
# time by setting $SAFE == "n": this will take all existing subdirs
# as valid and avoid recomputing their contents.
#
#	(C) Jose R Valverde, EMBnet/CNB, CSIC, 2011-2012
#
#	Released under EU-GPL
#

# get file directory
#	if $1 undefined this will return "."
d=`dirname "$1"`

cd $d

# get file name
file=${1:-"sequences.fas"}
# remove directory path
f="${file##*/}"
# extract file extension
ext="${file##*.}"
# remove file extension
base="${f%.*}"

# These might be optional command line parameters
num_steps=100
num_reps=100

export PATH=./bin:$PATH

# compute step size for rarefaction
step=$(( `grep -c ">" $file` / $num_steps ))

# XXX JR XXX
# this is to be used only to recover from programming mistakes and
# in order to avoid recomputing steps that are known to be correctly
# done. Valid values are "y" or "n"
#
#	$SAFE == "y" means recompute everything to be safe in case
#	some computation did not complete successfully
#	$SAFE == "n" means do not recompute if directory exists, and
#	assume that section of the computation did complete correctly
SAFE="n"


# Guard against wasting resources. Comment this if recalculation is needed
#	or, easier, remove the rarefaction_plots.html file
if [ -e ${base}/rarefaction_plots.html ] ; then echo "Done!"; exit ; fi


#1) Prepare sequences for QIIME
#	bin/qiime_renameseqs.sh $file SEQ > qiime/$file
#	cd qiime

#2) Detect OTUs using usearch/otupipe
#	We need to use the same SeqID in the mapping file as in the OTU
# table. The OTU table will take it from sequence identifiers, and so
# should us.
SID=`grep -m 1 "^>" $1 | sed -e 's/>//g;s/_.*//g' `

#if [ ! -e map ] ; then
# Make it always to set the description appropriately
        echo "#SampleID	BarcodeSequence	LinkerPrimerSequence	Description" > map
	echo "$SID	AAAAAAAAAAAAAA	GGGGGGGGGGGGGGGG	$base	Clean" >> map
#fi

if [ ! -e ${base}_otus.txt ] ; then
	echo "Picking OTUs with Otupipe"
	rm -rf ${base}_usearch
	pick_otus.py -m usearch -o ${base}_usearch -i $file --db_filepath $HOME/data/gold/gold.fa --minsize 1
#	bin/uclust_seqs.cmd $file
#3) Move to QIIME
	if [ ! -e ${base}_usearch/${base}_otus.txt ] ; then
		echo "OTU picking failed!"
		exit 1
	fi
	cp ${base}_usearch/${base}_otus.txt .
#	python bin/readmap2qiime uclust/`basename $file .fas`-97/readmap.uc > `basename $file .fas`_otus.txt
fi

#4) Make OTU table
if [ ! -e ${base}_table.txt ] ; then
	echo "Making OTU table"
	make_otu_table.py -i ${base}_otus.txt -o ${base}_table.txt
	if [ ! -e ${base}_table.txt ] ; then
		echo "OTU table creation failed!"
		exit 1
	fi
fi
#5) Rarefy
if [ $SAFE == "y" -o ! -d ${base}_rare ] ; then
	echo "Making rarefactions"
	rm -rf ${base}_rare
	multiple_rarefactions.py -i ${base}_table.txt -o ${base}_rare -n $num_reps -m $step -x `grep -c ">" $file` -s $step
fi

#6) Calculate alpha values
if [ $SAFE == "y" -o ! -d ${base}_alpha ] ; then
	echo "Computing alpha diversity"
	rm -rf alpha
	alpha_diversity.py -i ${base}_rare -o ${base}_alpha -m chao1,shannon,ace,observed_species
fi

#7) Collate data
if [ $SAFE == "y" -o ! -d ${base}_coll ] ; then
	collate_alpha.py -i ${base}_alpha -o ${base}_coll
fi

#8) Plot
if [ $SAFE == "y" -o ! -e ${base}/rarefaction_plots.html ] ; then
	rm -rf ${base}
	echo "Plotting charts"
	make_rarefaction_plots.py -i ${base}_coll -m map -o ${base}
fi
