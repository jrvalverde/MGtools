#!/bin/bash
#
#	blast_get_diversity.sh
#
#	Identify representative sequences at a given percentage level using BLAST
#
#	The sequences must all be stored in separate files under a subdirectory
#	named 'seqs' and named like "seq-%6d.fas" (i. e. seq-[six decimals].fas)
#
#	    # NOTE: this can be accomplished with 
#	    psplit -L ">" -l 1 -a 4 file.fas seqs-
#
#	    # if renaming sequences is needed, you can use
#	    i=0; for j in seq-* ; do i=$(($i+1)) ; cat $j | sed -e "s/^>.*/>seq-$i/g" > seq-`printf "%06d" $i`.fas ; done
#
#	Sequences are compared against all others and, if they don't match any
#	with similarity higher than the thReshold, they are assumed to be a new
#	species.
#
#	There are several ways about this, the one we use is:
#
#		- compare against previous "independent" sequences only, and
#	if distance is larger, add to the set. This will allow us to pick new
#	sequences with that minimal distance among themselves.
#
#		- a more sensible approach would be to calculate the distance
#	to the closest sequences in the whole group for each sequence, and then
#	carry out the clustering on the data using a better algorithm
#

function usage {
    echo ""
    echo "Usage: $0 {threshold}"
    echo "Usage: $0 -t {threshold}"
    echo "Usage: $0 --threshold {threshold}"
    echo ""
    echo "Example: $0 97"
    echo ""
    echo "	threshold is a number indicating the % similarity threshold"
    echo "	it is optional, if not given, it will default to 97"
    echo ""
    echo "	All sequences to be checked must be in a subdirectory named"
    echo "	'seqs' as separate '*.fas' files."
    echo ""
    echo "	This will generate data in directories blast unique assigned"
    echo "  	and cluster-{threshold} and a file 'seeds.txt'"
    echo ""
}

threshold=0

export PATH=./bin:$PATH

# Parse the command line
# ----------------------
# Note that we use `"$@"' to let each command-line parameter expand to a 
# separate word. The quotes around `$@' are essential!
# We need TEMP as the `eval set --' would nuke the return value of getopt.
TEMP=`getopt -o ht: \
     --long help,threshold \
     -n "$0" -- "$@"`

# an invalid option was given
if [ $? != 0 ] ; then usage >&2 ; exit 1 ; fi

# Note the quotes around `$TEMP': they are essential!
eval set -- "$TEMP"

while true ; do
	case "$1" in
		-h|--help) 
		    usage ; shift ;;
		-t|--threshold)
		    # echo "THRESHOLD $2"
		    # if $2 is a positive number, use it, ignore otherwise
		    if [[ $2 =~ ^[0-9]+$ ]] ; then threshold=$2 ; fi
		    shift 2 ;;
		--) shift ; break ;;
		*) echo "Internal error!" >&2 ; usage ; exit 1 ;;
	esac
done


#   After processing the command line without a threshold, check if it is
#   in the remaining arguments
#	Take threshold from first argument, and if it does not
#	exist, use 97 as default.
if [ $threshold -eq 0 ] ; then
    threshold=${1:-97}
fi
# now, it's possible that the first argument given is not a number. In that
# case, we'll print some help
if [[ ! $threshold =~ ^[0-9]+$ ]] ; then 
    usage
    exit
fi
if [ $threshold -gt 100 -o $threshold -lt 0 ] ; then
    usage
    exit
fi

echo "$0 -t $threshold"
#exit

if [ ! -d seqs ] ; then usage ; echo "error: no 'seqs' directory"; exit ; fi

if [ ! -d log ] ; then mkdir log ; fi
if [ ! -d blast ] ; then mkdir blast ; fi
if [ ! -d unique ] ; then mkdir unique ; fi
if [ ! -d assigned ] ; then mkdir assigned ; fi
if [ ! -d clusters-$threshold ] ; then mkdir clusters-${threshold} ; fi

echo "Cleaning up"
rm -f unique/* assigned/*

# for book-keeping
date -u

# populate initial blast database ensuring first sequence does not match
#	this one will be discarded on the first update.
cd blast
  cat > seqs.f <<END
>centinel
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
END
  formatdb -i seqs.f -p F -o F
cd ..

nclusters=0
# process all sequence files
for i in seqs/*.fas ; do
    echo -n $i
    # blast against already identified representative sequences
    # We are interested only on the closest match (if it is closer than
    # the threshold, then the sequence is not a new group, if not, then it 
    # cannot be closer to any other and is a new group).
    blastall -p blastn -d blast/seqs.f -i $i -o $i.blastn -g -a 4 -b 1 -m 8
    # we could use blat instead
    # blat -t=dna -q=dna -out=blast8 blast/seqs.f $i $i.blastn
    
    # extract identity and match
    ident=`cat $i.blastn | head -n 1 | cut -d'	' -f 3`
    match=`cat $i.blastn | head -n 1 | cut -d'	' -f 2`
    if [ "$ident" == "" ] ; then ident=0 ; match="seq0" ; fi
    
    # check identity against threshold
    gt=`echo "$ident >= $threshold" | bc`
    # gt == 1 (greater-equal), gt == 0 (smaller)
    if [ "$gt" == "0" ] ; then
    	echo " is new ($ident / $match)"
    	# new group found
	cd unique
	ln -s ../seqs/`basename $i` .
	cd ..
	nclusters=$(($nclusters+1))
	grep ">" $i > clusters-$threshold/clus-$nclusters.txt
	cd blast
	#cat ../unique/*.fas ../assigned/*.fas > seqs.f
	cat ../unique/*.fas > seqs.f
	# next is unneeded if we use blat instead of blast
	formatdb -i seqs.f -p F -o F
	cd ..
    else
    	echo " matches ($ident / $match)"
    	# this sequence matches an existing group
        cd assigned
    	ln -s ../seqs/`basename $i` `basename $i .fas`-$match.fas
	cd ..
	# find its cluster
	for k in clusters-$threshold/* ; do
	    grep ">$match" $k
	    if [ $? == 1 ] ; then
	    	grep ">" $i >> $k 
		break
	    fi
	done
	# this should never happen
#	if [ $found == 0 ] ; then
#	    $((nclusters=$nclusters+1))
#	    grep ">" $i > clusters-$threshold/clus-$nclusters.txt
#	fi
    fi

done

ls -1 unique/* > seeds.txt

# for book-keeping
date -u

