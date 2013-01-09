#!/bin/bash
#
#	Remove trailing N
#
#	Also remove the cases NXN+ and NXXN+
#	
#	To cope with NNXNNN cases we remove trailing N's once more at the end
#
#
#   (C) Jose R Valverde, EMBnet/CNB, 2009-2012
#   	jrvalverde@cnb.csic.es
#
perl bin/fasta1.pl $1 | sed -e 's/N*$//g' | sed -e 's/N.$//g' | sed -e 's/N..$//g' \
	| sed -e 's/N*$//g' | fold -w 60 \
	> $1.noN

