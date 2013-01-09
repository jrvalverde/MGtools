#!/bin/bash
#
#	Process an "Otupipe" readmap.uc output file to extract
# relevant information on per-group richness (how many individuals
# a group/OTU has) and community abundance (how many species with
# N individuals each are in there in the community).
#
#	Usage: invoke from within the same directory that contains
# the file "readmap.uc" or invoke with path name of readmap.uc file
#
#	Output files:
#	richnes:	Nindivs	OTU
#	abund:		NOTUs	indivs-per-OTU
#
#	(C) José R. Valverde, EMBnet/CNB, CSIC. 2012
#
#	Licensed under EU-GPL
#

# get file directory
#	if $1 undefined this will return "."
d=`dirname "$1"`

# get readmap.uc file name
file=${1:-"readmap.uc"}
f="${file##*/}"
ext="${file##*.}"
n="${f%.*}"
# at this point we should have
#   f=readmap.uc n=readmap ext=uc
#echo $d $f $n $ext ; exit

readmap_uc=$f

cd $d

if [ ! -e $readmap_uc ] ; then
   echo "$readmap_uc does not exist"
   exit
fi

if [ -e richness ] ; then echo "already done" ; exit ; fi

#notus=`grep -c "^>" otus.fa
notus=`grep ">OTU_" otus.fa | tail -n 1 | cut -d_ -f2`
check=`grep -c "^>" otus.fa`
if [ $notus -ne $check ] ; then echo "error: bad numbers" ; exit ; fi
#echo $notus

# compute abundances
grep -v '^#' $readmap_uc | grep OTU | cut -d'	' -f10 | cut -d_ -f2 | \
	sort -n | uniq -c | sort -g >> richness
cat richness | cut -c1-7 | tr -d ' ' | sort -r -n | uniq -c > abund
#cat abund | sed -e 's/^ *//g' | sed -e 's/ /	/g' > abund.tab

# richness contains pairs (Nindivs	OTU)
# abund contains pairs (NOTUS	indivs-per-OTU)

# With this information we can compute estimators and draw plots:

#
# compute Chao1 and its variance
#

u=`grep -c " 1 " richness`
d=`grep -c " 2 " richness`
s=`cat richness|wc -l`
i=`grep -c -v '#' $readmap_uc`
ci=$(($s + ($u * (($u - 1)) / ( 2 * ($d + 1))) ))
cf=`echo "scale=2;$s + ($u * (($u - 1)) / ( 2 * ($d + 1)))" | bc -l`
#
# S_chao1 variance
#
vs=`echo "scale=2; $d * ( ((($u/$d)^4)/4) + (($u/$d)^3) + ((($u/$d)^2)/2) )" | bc -l`
#echo "S_Chao1=$ci S_Chao1(float)=$cf var(S_Chao1)=$vs Nindiv=$i S_obs=$s singletons=$u doubletons=$d"
echo -n "Nindiv=$i S_obs=$s singletons=$u doubletons=$d "
echo -n "S_Chao1=$cf var(S_Chao1)=$vs "
#
# compute ACE (see Hughes et al. (2001) Appl. Env. Microbiol. v67(10) 4399-4406
#
threshold=10

# Compute all needed variables
i=0; Srare=0 ; Sabund=0; Nrare=0; Sum=0
while read line ; do
    notus=${line% *}		# remove everything after last space
    nindiv=${line#* }		# remove everything up to last space
    #echo "$line = $notus $nindiv"
    if [ $nindiv -le $threshold ] ; then
	Srare=$(($Srare + $notus))
	Nrare=$(($Nrare + $notus * $nindiv))
        Sum=$(($Sum + (($nindiv * ($nindiv - 1)) * $notus) ))
	#echo "indiv=$nindiv otus with indiv=$notus Srare=$Srare Nrare=$Nrare" 
    else
        Sabund=$(($Sabund + $notus))
	#echo "indiv=$nindiv otus with indiv=$notus Sabund=$Sabund" 
    fi
done <abund
F1=`grep " 1$" abund`
F1=${F1% *}
if [ "$F1" == "" ] ; then F1=0 ; fi

C_ACE=`echo "scale=2;1 - ($F1 / $Nrare)" | bc -l`

gammasq=`echo "scale=2;(($Srare * $Sum) / ($C_ACE * $Nrare * ($Nrare - 1))) - 1" | bc -l`
if [ `echo "$gammasq < 0" | bc` == "1" ] ; then gammasq=0 ; fi

Sace=`echo "scale=2;$Sabund + ($Srare / $C_ACE) + ($F1 / $C_ACE) * $gammasq" | bc -l`

#echo "ACE=$Sace Srare=$Srare Sabund=$Sabund F1=$F1 C_ACE=$C_ACE Sum=$Sum gammasq=$gammasq"
echo "S_ACE=$Sace"


#
# make plots
#

gnuplot <<END
    set terminal png enhanced
    set output "abund.png"
    set title "Relative species abundance"
    set xlabel "Number of individuals collected"
    set ylabel "Number of species collected"
    set style line 1 lw 3
    plot "abund" using 2:1 title "no. of species with x indivs" with boxes linestyle 1
END
gnuplot <<END
    set terminal png enhanced
    set output "labund.png"
    set title "Relative species abundance"
    set xlabel "Number of individuals collected"
    set ylabel "Number of species collected (Log_e)"
    set style line 1 lw 3
    plot "abund" using 2:(log(\$1)) title "Log_e no. of species with x indivs" linestyle 1
END
gnuplot <<END
    set terminal png enhanced
    set output "llabund.png"
    set title "Relative species abundance"
    set xlabel "Number of individuals collected (Log_e)"
    set ylabel "Number of species collected (Log_e)"
    set style line 1 lw 3
    plot "abund" using (log(\$2)):(log(\$1)) title "Log_e no. of species with x indivs" linestyle 1
END
gnuplot <<END
    set terminal png enhanced
    set output "preston.png"
    set title "Preston Plot"
    set xlabel "Individuals collected (Log_e bins)"
    set ylabel "Species collected"
    set style line 1 lw 3
    plot "abund" using (log(\$2)):1 title "no. of species with e^x indivs" with boxes linestyle 1
END
exit

