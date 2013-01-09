#!/bin/bash
#
#	Remove trailing N
#
#	Also remove the cases NXN+ and NXXN+
#	
#	To cope with NNXNNN cases we remove trailing N's once more at the end
#
#	Finally remove sequences with N in the middle
#
#	Then we can remove short sequences (<200 nt)
#
# NOTE: we do not want to remove any sequence with an N anywhere as then
# in some cases we'll remove too many. Better we first remove trailing N 
# and then filter out sequences with ambiguity
#
#   (C) Jose R Valverde, EMBnet/CNB, 2009-2012
#   	jrvalverde@cnb.csic.es
#

perl bin/fasta1.pl $1 | sed -e 's/N*$//g' | sed -e 's/N.$//g' | sed -e 's/N..$//g' \
	| sed -e 's/N*$//g' | fold -w 60 \
	> $1.noN

perl bin/fastanoNnoShort.pl $1.noN | fold -w 60 > $1.longclean

