#!/bin/bash
#
#   Rename sequences using numbers.
#
#   (C) Jose R Valverde, EMBnet/CNB, 2009-2012
#   	jrvalverde@cnb.csic.es
#
#	This is inefficient, see awk file renameseqs.awk for other way
# to do it faster
#

i=0

# if we do get an argument, process the named file
if [ "$#" -ne 0 ]; then 
  while (( "$#" )) ; do
    if [ ! -f "$1" ] ; then continue ; fi
    cat $1 | while read l ; do
      if [ `expr "$l" : '>'` -ne 0 ] ; then
#	echo `expr "$l" : '>'`
        i=$(($i+1))
#	echo $l.$i
        echo ">$i" `echo $l | tr '>' ' '` >> $1.n
      else
    	echo $l >> $1.n
      fi
    done
  done
  shift
else
# otherwise process standard input
  while read l ; do
    if [ `expr "$l" : '>'` -ne 0 ] ; then
#	echo `expr "$l" : '>'`
        i=$(($i+1))
#	echo $l.$i
        echo ">"`printf "%07d" $i` `echo $l | tr '>' ' '`
    else
    	echo $l 
    fi
  done
fi
