#!/bin/bash
#
#	make synthetic samples from VAMPS derived reference databases.
#
#	José R Valverde, EMBnet/CNB, CSIC, 2012
#	
#	Licensed under EU-GPL
#
#	$Id$
#	$Log$
#

# we start from the reference datasets from VAMPS
#	First we cluster them and identify sequence representative
# of existing OTUs
#
#	The rationale is that although we know each ref seq in VAMPS
# does actually come from a different species, many have, mostly when
# dealing with fragments of 16S, very close similarity to other species
# and thus can be confused.
#
#	We want to generate synthetic datasets where we know the number
# of OTUs, so we need to ensure that at least the seeding sequences for
# each synthetic OTU are distant enough from all others to be detected
# (at least at 3% distance).
#
#	Clustering with UCLUST will yield a otus.fa file where the
# selected sequences are understood to represent distinct OTUs and
# therefore not to cluster together (at the specified distance/similarity).
#
for i in *.fas ; do
  bash bin/uclust_seqs.cmd $i
done


for i in refssu refv3 refv3v5 refv4v6 refv6a refv9 ; do
  if [ ! -d $i ] ; then mkdir $i ; fi
  cd $i
  echo $i
  # basic housekeeping
  if [ ! -e bin ] ; then  ln -s ../bin . ; fi

  if [ ! -e otus97.fas ] ; then
    ln -s ../uclust-minsize=1/$i-97/otus.fa otus97.fas
  fi

  #    clean-up otus found by usearch using blat:
  #	The rationale here is that usearch might split a large cluster
  # into separate sub-clusters (or group in separate clusters sequences
  # which might -on average- be separate enough but not individually
  #
  #	Running blat we try to identify these cases to remove them
  #
  if [ ! -e log/blat.log ] ; then
    mkdir seqs
    cd seqs
    psplit -L "^>" -l 1 -a 4 ../otus97.fas seq-
    i=0; for j in seq-* ; do i=$(($i+1)) ; echo mv $j seq-`printf "%06d" $i`.fas ; done
    cd ..
    mkdir log
    bash bin/blat_get_diversity.sh
  fi

  # we can now create a listing of sequences that may act as putative
  # seeds (sequences coming from distict species that are at least
  # 3% apart from all others
  if [ ! -e seeds.txt ] ; then ls unique/* > seeds.txt ; fi
  
  # make templates
  # Using R we can now generate a specific log-normal distribution
  # that will guide the process of building the synthetic population sample.
  bash bin/make_lognormal_template.sh 10000 0 1
  bash bin/make_lognormal_template.sh 10000 0 1.6
  bash bin/make_lognormal_template.sh 10000 0 2
  
  # make samples
  #	Note that in the process we may lose OTUs: if two sequences are
  #	exactly 3% apart, and we mutate them, it is possible some mutants
  #	will be closer than 3% to the other cluster, and in the process
  #	bring the two sets close enough that they might be clustered
  #	together.
  bash bin/make_population.sh LogNormal-0-1-10000.txt seeds.txt
  bash bin/make_population.sh LogNormal-0-1.6-10000.txt seeds.txt
  bash bin/make_population.sh LogNormal-0-2-10000.txt seeds.txt

  # now make duplicate populations
  cat LogNormal-0-1-10000.fas LogNormal-0-1-10000.fas | \
    ./bin/renameseqs.awk > LogNormal-0-1-10000x2.fas

  cat LogNormal-0-1.6-10000.fas LogNormal-0-1.6-10000.fas  | \
    ./bin/renameseqs.awk > LogNormal-0-1.6-10000x2.fas
  
  cat LogNormal-0-2-10000.fas LogNormal-0-2-10000.fas   | \
    ./bin/renameseqs.awk > LogNormal-0-2-10000x2.fas

  # finally make triplicate populations
  cat LogNormal-0-1-10000.fas LogNormal-0-1-10000.fas LogNormal-0-1-10000.fas | \
    ./bin/renameseqs.awk > LogNormal-0-1-10000x3.fas

  cat LogNormal-0-1.6-10000.fas LogNormal-0-1.6-10000.fas LogNormal-0-1.6-10000.fas | \
    ./bin/renameseqs.awk  > LogNormal-0-1.6-10000x3.fas

  cat LogNormal-0-2-10000.fas LogNormal-0-2-10000.fas LogNormal-0-2-10000.fas | \
    ./bin/renameseqs.awk  > LogNormal-0-2-10000x3.fas

  cd ..
done

# v6 is special: the number of OTUS identified by uclust_seqs is smaller
#	than 10.000, so the biggest number of different OTUs we can 
#	generate is smaller (7652 uclust OTUs, 7175 after blat cleaning)
cd refv6
  echo refv6

  if [ ! -e otus97.fas ] ; then
    ln -s ../uclust-minsize=1/$i-97/otus.fa otus97.fas
  fi

  # 	clean-up otus found by usearch using blat:
  if [ ! -e log/blat.log ] ; then
    mkdir seqs
    cd seqs
    psplit -L "^>" -l 1 -a 4 ../otus97.fas seq-
    i=0; for j in seq-* ; do i=$(($i+1)) ; echo mv $j seq-`printf "%06d" $i`.fas ; done
    cd ..
    mkdir log
    bash bin/blat_get_diversity.sh
  fi

  if [ ! -e seeds.txt ] ; then ls unique/* > seeds.txt ; fi
  
  # make templates
  bash bin/make_lognormal_template.sh 7000 0 1
  bash bin/make_lognormal_template.sh 7000 0 1.6
  bash bin/make_lognormal_template.sh 7000 0 2
  
  # make samples
  bash bin/make_population.sh LogNormal-0-1-7000.txt seeds.txt
  bash bin/make_population.sh LogNormal-0-1.6-7000.txt seeds.txt
  bash bin/make_population.sh LogNormal-0-2-7000.txt seeds.txt

  # now make duplicate populations
  cat LogNormal-0-1-7000.fas LogNormal-0-1-7000.fas | \
    ./bin/renameseqs.awk > LogNormal-0-1-7000x2.fas

  cat LogNormal-0-1.6-7000.fas LogNormal-0-1.6-7000.fas  | \
    ./bin/renameseqs.awk > LogNormal-0-1.6-7000x2.fas
  
  cat LogNormal-0-2-7000.fas LogNormal-0-2-7000.fas   | \
    ./bin/renameseqs.awk > LogNormal-0-2-7000x2.fas

  # finally make triplicate populations
  cat LogNormal-0-1-7000.fas LogNormal-0-1-7000.fas LogNormal-0-1-7000.fas | \
    ./bin/renameseqs.awk > LogNormal-0-1-7000x3.fas

  cat LogNormal-0-1.6-7000.fas LogNormal-0-1.6-7000.fas LogNormal-0-1.6-7000.fas | \
    ./bin/renameseqs.awk  > LogNormal-0-1.6-7000x3.fas

  cat LogNormal-0-2-7000.fas LogNormal-0-2-7000.fas LogNormal-0-2-7000.fas | \
    ./bin/renameseqs.awk  > LogNormal-0-2-7000x3.fas

cd ..

#
#	The initial analysis step (OTU counting)
#
for i in refssu refv3 refv3v5 refv4v6 refv6 refv6a refv9 ; do
  cd $i
  echo "*** $i ***"
  for j in *.fas ; do
    echo $j
    bash bin/uclust_seqs.cmd $j
    bash bin/uclust_seqs.cmd $j 3
  done
  cd ..
done

####
#	The final step is to be done using QIIME: make rarefaction curves.
#
#	The order has been chosen to proceed from the smaller to the
#	larger sequences.
#
for i in refv6 refv6a refv9 refv3 ; do
  cd $i
  echo "*** $i ***"
    cd qiime
    ln -s ../*.fas .
    for j in *.fas ; do
      echo $j
      bash bin/qiime_rarefact_short.sh $i
    done
    cd ..
  cd ..
done
for i in refv3v5 refv4v6 refssu ; do
  cd $i
  echo "*** $i ***"
    cd qiime
    ln -s ../*.fas .
    for j in *.fas ; do
      echo $j
      bash bin/qiime_rarefact.sh $i
    done
    cd ..
  cd ..
done

####
