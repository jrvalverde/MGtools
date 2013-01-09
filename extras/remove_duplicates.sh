#!/bin/bash
#
#	Remove duplicated sequences
#

perl -e '$count=0; $len=0; while(<>) {s/\r?\n//; s/\t/ /g; if (s/^>//) { if ($. != 1) {print "\n"} s/ |$/\t/; $count++; $_ .= "\t";} else {s/ //g; $len += length($_)} print $_;} print "\n"; warn "\nConverted $count FASTA records in $. lines to tabular format\nTotal sequence length: $len\n\n";' $1 > dup.tab
perl -e '$column = 2; $unique=0; while(<>) {s/\r?\n//; @F=split /\t/, $_; if (! ($save{$F[$column]}++)) {print "$_\n"; $unique++}} warn "\nChose $unique unique lines out of $. total lines.\nRemoved duplicates in column $column.\n\n"' dup.tab > unique.tab
perl -e '$len=0; while(<>) {s/\r?\n//; @F=split /\t/, $_; print ">$F[0]"; if (length($F[1])) {print " $F[1]"} print "\n"; $s=$F[2]; $len+= length($s); $s=~s/.{60}(?=.)/$&\n/g; print "$s\n";} warn "\nConverted $. tab-delimited lines to FASTA format\nTotal sequence length: $len\n\n";' unique.tab > $1.unique.fasta
rm *.tab

# XXX JR XXX note:
#	a simpler alternative may be to remove sequence names leaving the >
#	then remove newlines
#	then change '>' by '\n>'
#	then use UNIX uniq(1)
#	then change '>' by '>NAME\n'
#	then rename all sequences
#	then use fold to make sequence lines 60 characters wide
#
#	I need to test which is more efficient
