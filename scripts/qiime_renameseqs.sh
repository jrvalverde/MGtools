#!/bin/bash
#
#   Usage:
#
#	qiime_renameseqs.sh file.fas NAME > out.fas
#
#	rename sequences for use with QIIME
#
#	(C) Jose R Valverde, EMBnet/CNB, CSIC, 2012
#
#	Licensed under EU-GPL
#
#   $Id$
#   $Log$
#

function usage {
    cat >&2 <<END

    Usage: $0 fasta-file PREFIX > output.fas
    Usage: $0 -i fasta-file -p PREFIX -o output.fas
    Usage: $0 --input fasta-file --prefix PREFIX --output output.fas

    All sequences in the input fasta file will be renamed as >PREFIX_number
    If no -o output-file is specified, output will go to standard output
    (useful for pipelines).

END
}

# Parse the command line
# ----------------------
# Note that we use `"$@"' to let each command-line parameter expand to a 
# separate word. The quotes around `$@' are essential!
# We need TEMP as the `eval set --' would nuke the return value of getopt.
TEMP=`getopt -o hi:p:o: \
     --long help,input:,prefix:,output: \
     -n "$0" -- "$@"`

# an invalid option was given
if [ $? != 0 ] ; then usage >&2 ; exit 1 ; fi

# Note the quotes around `$TEMP': they are essential!
eval set -- "$TEMP"

f=""
n=""
o=""
while true ; do
	case "$1" in
		-h|--help) 
		    usage ; shift ;;
		-i|--input) 
		    #echo "INPUT FILE \`$2'" 
		    f=$2 ; shift 2 ;;
		-o|--output) 
		    #echo "INPUT FILE \`$2'" 
		    o=$2 ; shift 2 ;;
		-p|--prefix) 
		    #echo "PREFIX \`$2'" 
		    n=$2 ; shift 2 ;;
		--) shift ; break ;;
		*) echo "Internal error!" >&2 ; usage ; exit 1 ;;
	esac
done

if [ "$f" == "" ] ; then
    f=${1:-"sequences.fas"} ; shift
fi

if [ "$n" == "" ] ; then
    n=${1:-"SEQ"} ; shift
fi

if [ "$o" == "" ] ; then
    o=${1:-""} ; shift
fi

echo "$0 -i '$f' -p '$n' -o '$o'"
#exit

if [ ! -e "$f" ] ; then usage; echo "Error: $f must exist!" >&2 ; exit; fi

dir=`dirname "$f"`
file=`basename $f`

cd $dir

if [ "$o" == "" ] ; then
cat $file | awk "/>/ {s+=1; printf \">${n}_%08d\n\",s }
!/>/ { print }"
else
    if [ -e "$o" ] ; then 
	usage
	echo "Error: $o exists, cowardly refusing to overwrite it" >&2
	exit
    fi
cat $file | awk "/>/ {s+=1; printf \">${n}_%08d\n\",s }
!/>/ { print }" > $o

exit
fi

#
# old, very slow, but easier to understand, version
#
i=0

cat $file | while read l ; do
    if [ `expr "$l" : '>'` -ne 0 ] ; then
#	echo `expr "$l" : '>'`
        i=$(($i+1))
#	echo $l.$i
        echo ">${n}_"`printf %08d $i`
    else
    	echo $l 
    fi
done
