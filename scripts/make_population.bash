#!/bin/bash
#
#	We need two input files:
#		one contains a list of integers (one per line) with the
# size of each OTU
#		the other contains a list of sequences to use as cluster
# / OTU seeds (e. g. ls seeds/* > seedlist.txt)
#
#	(C) José R Valverde, EMBnet/CNB. CSIC. 2012
#
#	Licensed under EU-GPL
#
#	$Log$
#

function usage {
    cat <<END

    Usage: $0 otusizes otusseds
    Usage: $0 -r otusizes -s otusseeds -h
    Usage: $0 --reference-sizes otusizes --seed-sequences otuseeds -h
    
    otusizes	-- a file containing the size of each OTU as an integer in a
    	    	    separate line, generated normally using a 
		    make_*_template.bash script, e.g. 
    	    	    	1
		    	3
		    	...
    otuseeds	-- a file listing the sequences to use as seeds for each
    	    	    OTU, one sequence file per line, e.g. 
		    	refseqs/seq01.fas
    	    	    	refseqa/seq02.fas
		    	...
    
	Default values are "population.txt" and "seeds.txt"

END

}

otusizes=""
otuseeds=""

# Parse the command line
# ----------------------
# Note that we use `"$@"' to let each command-line parameter expand to a 
# separate word. The quotes around `$@' are essential!
# We need TEMP as the `eval set --' would nuke the return value of getopt.
TEMP=`getopt -o hr:s: \
     --long help,reference-sizes:,seed-sequences: \
     -n "$0" -- "$@"`

# an invalid option was given
if [ $? != 0 ] ; then usage >&2 ; exit 1 ; fi

# Note the quotes around `$TEMP': they are essential!
eval set -- "$TEMP"

while true ; do
	case "$1" in
		-h|--help) 
		    usage ; shift ;;
		-r|--reference-sizes) 
		    #echo "REF SIZES \`$2'" 
		    otusizes=$2 ; shift 2 ;;
		-s|--seed-sequences) 
		    #echo "REF SEQS \`$2'" 
		    otuseeds=$2 ; shift 2 ;;
		--) shift ; break ;;
		*) echo "Internal error!" >&2 ; usage ; exit 1 ;;
	esac
done

# Population structure (OTU sizes), defaults to "population.txt"
if [ "$otusizes" == "" ] ; then
    otusizes=${1:-"population.txt"}
    shift
fi
# listing of pool of fasta files to use as seeds, defauls to seeds.txt
if [ "$otuseeds" == "" ] ; then
    otuseeds=${1:-"seeds.txt"}
    shift
fi

echo "$0 -r $otusizes -s $otuseeds"
#exit

if [ ! -e $otusizes ] ; then echo "error: $otusizes does not exist" ; exit ; fi
if [ ! -e $otuseeds ] ; then echo "error: $otuseeds does not exist" ; exit ; fi

# output files will be named after population-structure template (the
# file with otu sizes) after removing the extension and substituting it
# by .fas and .uc

# remove everything up to the last /
pop="${otusizes##*/}"
# remove everything after the last .
pop="${pop%.*}"
# add .fas extension
population="$pop.fas"
# add .uc extension
readmap="$pop.uc"

### echo "$population $readmap" ; exit

# allowed percent ID variability for individsuals within an OTU 
#	(should be < 1/2 · 3%)
pctid="1.25"

# since we need to work on two files simultaneously, we will use two bash
# arrays instead of reading the files line by line directly

sizes=( `cat $otusizes`)
seeds=( `cat $otuseeds`)

#number of otus is given by the number of sizes
notus=$(( ${#sizes[@]} ))
# number of avilable seeds
nseeds=$(( ${#seeds[@]} ))

### echo $notus $nseeds

if [ $notus -gt $nseeds ] ; then
	echo "error: not enough seeds to build the requested population"
	exit
fi

if [ -e $population ] ; then
	echo "error: $population already exists"
	exit
fi

if [ -e $readmap ] ; then
	echo "error: $readmap already exists"
	exit
fi


i=0
for siz in "${sizes[@]}" ; do
	# new seed
	#	new seed is ${seeds[$i]}
	### echo $siz ${seeds[$i]}
	seq=${seeds[$i]}
	i=$(($i+1))
	# add seed to the population
	cat $seq >> $population

	# annotate: seed_$i belongs to otu_$i
	# readmap.uc style annotation:
	#
	# Tab-separated fields:	
	# 1=Type, 2=ClusterNr, 3=SeqLength or ClusterSize, 4=PctId, 5=Strand, 6=QueryStart, 7=SeedStart, 8=Alignment, 9=QueryLabel, 10=TargetLabel
	# Record types (field 1): L=LibSeed, S=NewSeed, H=Hit, R=Reject, D=LibCluster, C=NewCluster, N=NoHit
	#
	# extract tag line, remove > and keep only first word
	seqname=`grep ">" $seq | sed -e 's/>//g' -e 's/ .*//g' | tr -d '\n'` 
	# extract sequence, remove whitespace and count characters
	seqlen=`grep -v ">" $seq | tr -d '[:space:]' | wc -c`
	echo "H	$i	$seqlen	100.0	+	0	0	*	$seqname	$seqname" >> $readmap

	# sequence added: decrease otu size count
	siz=$(($siz - 1))

	nmut=`echo "$seqlen * $pctid / 100" | bc`
	### echo "len: $seqlen mut:$nmut"
	# generate mutant individuals for this OTU
	while [ $siz -gt 0 ] ; do
		### echo $siz
		# mutate
		#	choose a temporary file name (note: this choice might be dangerous!)
		mutant="/tmp/mutant.$$"
		msbar -sequence $seq -count $nmut -point 1 -block 0 -codon 0 -outseq $mutant &>/dev/null
		# rename mutant sequence so we can trace it back later
		cat $mutant | sed -e "/>/ s/\$/_$siz/g" > $mutant.fas
		
		# add mutant to population
		cat $mutant.fas >> $population
		# annotate
		echo "H	$i	$seqlen	$pctid	+	0	0	*	${seqname}_$siz	$seqname" >> $readmap
		rm $mutant $mutant.fas

		# one mutant added, decrease otu size by one
		siz=$((siz - 1))
	done

        if [ `expr $i % 100` -eq 0 ] ; then echo -n "." ; fi
	### if [ $i -eq 10 ] ; then exit ; fi	# for debugging
done
