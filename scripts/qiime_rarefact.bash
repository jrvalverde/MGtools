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

function usage {
    echo ""
    echo "Usage:"
    echo "    $0 -q -s -h -i file -d database -n num_steps -r num_reps"
    echo ""
    echo "    $0 --quality-filter --safe-mode --help --input file "
    echo "            --gold-database database --num-steps n --num-replicas n "
    echo ""
    echo "    FILE=file FILTER='y/n' $0"
    echo ""
    echo "    All arguments are optional. If unused, defaults will be used"
    echo "    instead. Note that the input file may also be provided from"
    echo "    an environment variable, which is useful for batch submission"
    echo ""
    echo "       e. g.     qsub -v FILE=path/to/file,FILTER=y $0"
    echo ""
    exit
}

function is_int() {
    return $(test "$@" -eq "$@" > /dev/null 2>&1)
    # an alternate test might be
#    if [[ $var == [0-9]* ]] ; then is_integer ; fi
#    if [[ $var =~ ^-?[0-9]+$ ]] ; then is_integer ; fi
}

# default values
# --------------

# Set this to "n" to disable quality filtering at the OTU picking
# step. Normally you do not want to disable it, unless you are sure
# the dataset is free from noise, chimeras, etc...
# Using QF="y" will enable use of the gold.fa database, which needs
# also be specified
# QF="y"
# GOLD=$HOME/data/gold/gold.fa
QF=${FILTER:-"n"}	    	# use quality filtering with the gold database
GOLD="$HOME/data/gold/gold.fa"

# this is to be used only to recover from programming mistakes or
# in order to avoid recomputing steps that are known to be correctly
# done. Valid values are "y" or "n"
#
#	$SAFE == "y" means recompute everything to be safe in case
#	some computation did not complete successfully
#	$SAFE == "n" means do not recompute if directory exists, and
#	assume that section of the computation did complete correctly
SAFE="n"    	# do not recompute already existing directory steps

# These might be optional command line parameters
num_steps=100
#num_reps=100
# speed it up
num_reps=20

export PATH=./bin:$PATH

# Parse the command line
# ----------------------
# Note that we use `"$@"' to let each command-line parameter expand to a 
# separate word. The quotes around `$@' are essential!
# We need TEMP as the `eval set --' would nuke the return value of getopt.
TEMP=`getopt -o qshi:d:n:r: \
     --long quality-filter,safe-mode,help,input:,gold-database:,num-steps:,num-replicas: \
     -n "$0" -- "$@"`

# an invalid option was given
if [ $? != 0 ] ; then usage >&2 ; exit 1 ; fi

# Note the quotes around `$TEMP': they are essential!
eval set -- "$TEMP"

while true ; do
	case "$1" in
		-h|--help) 
		    usage ; shift ;;
		-q|--quality-filter) 
		    #echo "QUALITY FILTERING" 
		    QF="y" ; shift ;;
		-s|--safe-mode) 
		    #echo "SAFE MODE (will recompute everything)"
		    SAFE="y" ; shift ;;
		-i|--input) 
		    #echo "INPUT FILE \`$2'" 
		    FILE=$2 ; shift 2 ;;
		-d|--gold-database) 
		    #echo "GOLD DATABASE \`$2'" 
		    GOLD=$2 ; shift 2 ;;
		-n|--num-steps)
		    # echo "NUM STEPS $2"
		    # if $2 is a positive number, use it, ignore otherwise
		    if [[ $2 =~ ^[0-9]+$ ]] ; then num_steps=$2 ; fi
		    shift 2 ;;
		-r|--num-replicas)
		    # echo "NUM REPLICAS $2"
		    # if $2 is a positive number, use it, ignore otherwise
		    if [[ $2 =~ ^[0-9]+$ ]] ; then num_reps=$2 ; fi
		    shift 2 ;;
		--) shift ; break ;;
		*) echo "Internal error!" >&2 ; usage ; exit 1 ;;
	esac
done

# sanity checks
# -------------

# check if the filename was specified as an unnamed argument
file=${1:-""} ; shift

# get file name from environment variable as a last resort
#   	We allow the input file not to be specified in the
#   	command line, so it may be taken from an environment
#   	variable when run in batch mode.
#   	This is OK as we only want this for batch submission
#   	when we cannot give any command line arguments: if 
#   	we got it from a command line arg. then we are not in batch
#   	mode.
#   	Provide a safe default.
if [ "$file" == "" ] ; then
    file=${FILE:-"sequences.fas"}
fi

# get file directory
#	if $FILE undefined this will return "."
d=`dirname "$file"`
cd $d

# remove directory path
f="${file##*/}"
# extract file extension
ext="${file##*.}"
# remove file extension
base="${f%.*}"

if [ ! -e $f ] ; then echo "Error: input file '$file' must exist!" >&2; exit 1 ; fi

# compute step size for rarefaction
step=$(( `grep -c "^>" ./$f` / $num_steps ))

# ensure we have a reference database for quality filtering
if [ "$GOLD" == "" ] ; then QF="n" ; fi


# Guard against wasting resources. Use '-s' if full recalculation is needed
#	or, easier, remove the $base/rarefaction_plots.html file
if [ $SAFE = "n" ] ; then
    if [ -e ${base}/rarefaction_plots.html ] ; then 
    	echo "Done!"; exit 
    fi
fi

cat <<END
*** 
$0 \\
	-q ($QF) -s ($SAFE) -i $file \\
	-d $GOLD -n $num_steps -r $num_reps
***
END
#exit

# Prepare sequences for QIIME
# ---------------------------
#   This should not be uncommented unless absolutely needed, it is
#   better done by hand. It is left here only as a reminder for myself.
#	bin/qiime_renameseqs.sh $file SEQ > qiime/$file
#	cd qiime


# Detect OTUs using usearch/otupipe
# ---------------------------------
#	We need to use the same SeqID in the mapping file as in the OTU
# table. The OTU table will take it from sequence identifiers, and so
# should we.
SID=`grep -m 1 "^>" $f | sed -e 's/>//g;s/_.*//g' `

# Make map always to set the description appropriately
echo "#SampleID	BarcodeSequence	LinkerPrimerSequence	Description" > map
echo "$SID	AAAAAAAAAAAAAA	GGGGGGGGGGGGGGGG	$base	Clean" >> map

if [ "$SAFE" == "y" -o ! -e ${base}_otus.txt ] ; then
	echo "Picking OTUs with Otupipe"
	rm -rf ${base}_usearch
	if [ "$QF" == "y" ] ; then
		pick_otus.py -m usearch -o ${base}_usearch -i $file --db_filepath $GOLD --minsize 1
	else
		pick_otus.py -o ${base}_usearch -i $file
	fi
	
	# this is a placeholder/reminder that sometimes we need/want
	# to do it manually.
	#	bin/uclust_seqs.cmd $file
	
# Make OTUs visible
# -----------------
	if [ ! -e ${base}_usearch/${base}_otus.txt ] ; then
		echo "OTU picking failed!"
		exit 1
	fi
	cp ${base}_usearch/${base}_otus.txt .

        # IF the otus were generated manually, we should use this instead
	# python bin/readmap2qiime uclust-minsize=1/`basename $file .fas`-97/readmap.uc > `basename $file .fas`_otus.txt
fi

# Make OTU table
# --------------
if [ "$SAFE" == "y" -o ! -e ${base}_table.txt ] ; then
	echo "Making OTU table"
	make_otu_table.py -i ${base}_otus.txt -o ${base}_table.txt
	if [ ! -e ${base}_table.txt ] ; then
		echo "OTU table creation failed!"
		exit 1
	fi
fi
# Rarefy
# ------
if [ "$SAFE" == "y" -o ! -d ${base}_rare ] ; then
	echo "Making rarefactions"
	rm -rf ${base}_rare
	multiple_rarefactions.py -i ${base}_table.txt -o ${base}_rare -n $num_reps -m $step -x `grep -c ">" $file` -s $step
fi

# Calculate alpha values
# ----------------------
if [ "$SAFE" == "y" -o ! -d ${base}_alpha ] ; then
	echo "Computing alpha diversity"
	rm -rf alpha
	alpha_diversity.py -i ${base}_rare -o ${base}_alpha -m chao1,shannon,ace,observed_species
fi

# Collate data
# ------------
if [ "$SAFE" == "y" -o ! -d ${base}_coll ] ; then
	collate_alpha.py -i ${base}_alpha -o ${base}_coll
fi

# Plot
# ----
if [ "$SAFE" == "y" -o ! -e ${base}/rarefaction_plots.html ] ; then
	rm -rf ${base}
	echo "Plotting charts"
	make_rarefaction_plots.py -i ${base}_coll -m map -o ${base}
fi

# Clean up
# --------
# Clean up to free space (we may generate tens or hundreds of thousands 
#   of files): if all went well, we do not need them any longer
#
#   NOTE that we leave everything around if SAFE mode was selected
#   so that results can be inspected and verified manually.
#
if [ "$SAFE" == "n" -a -e ${base}/rarefaction_plots.html ] ; then
    rm -rf ${base}_rare ${base}_alpha ${base}_coll ${base}_usearch ${base}_otus.txt ${base}_table.txt
fi
