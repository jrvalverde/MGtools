#!/bin/bash
#
#	blat_get_diversity.sh
#
#	Identify representative sequences at a given percentage level using BLAT
#
#	The sequences must all be stored in separate files under a subdirectory
#	named 'seqs' and named like "seq-%Nd.fas" (i. e. seq-[N decimals].fas)
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

#	Take threshold from first argument, and if it does not
#	exist, use 97 as default.
threshold=${1:-97}

if [ ! -d seqs ] ; then echo "error: no 'seqs' directory"; exit ; fi

if [ ! -d log ] ; then mkdir log ; fi
if [ ! -d blat ] ; then mkdir blat ; fi
if [ ! -d unique ] ; then mkdir unique ; fi
if [ ! -d assigned ] ; then mkdir assigned ; fi
if [ ! -d clusters-$threshold ] ; then mkdir clusters-${threshold} ; fi

echo "Cleaning up"
rm -f unique/* assigned/* clusters-$threshold/*

# for book-keeping
date -u

# populate initial blat database ensuring first sequence does not match
cat > blat/seqs.f <<END
>centinel
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
END


nclusters=0
# process all sequence files
for i in seqs/*.fas ; do
    echo -n $i
    # blat against already identified representative sequences
    # We are interested only on the closest match (if it is closer than
    # the threshold, then the sequence is not a new group, if not, then it 
    # cannot be closer to any other and is a new group).
    #
    # we will use blat to search
     blat -t=dna -q=dna -out=blast8 blat/seqs.f $i $i.blastn &>> log/blat
    
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
	grep "^>" $i > clusters-$threshold/clus-$nclusters.txt
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
	    	grep "^>" $i >> $k 
		break
	    fi
	done
	# this should never happen
#	if [ $found == 0 ] ; then
#	    $((nclusters=$nclusters+1))
#	    grep ">" $i > clusters-$threshold/clus-$nclusters.txt
#	fi
    fi
    cat $i >> blat/seqs.f
    
done

# for book-keeping
date -u

