#!/bin/bash

notus=`grep ">OTU_" otus.fa | tail -n 1 | cut -d_ -f2`
#echo $notus
# we use the "obsoleted" seq command because {1..$var} does not
#	work.
for i in $(seq 1 1 $notus) ; do 
	# this is very inefficient: we run twice over
	# the file for each OTU
 	n=`grep -c "OTU_$i$" readmap.uc` 
	if [ $n -eq 1 ] ; then 
		#echo "$i; $n" 
		grep "OTU_$i$" readmap.uc | cut -d '	' -f 9
	fi
done
