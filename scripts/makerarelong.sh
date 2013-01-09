####
#	The final step is to be done using QIIME through the virtual
#	machine: make rarefaction curves.
#
#	The order has been chosen to proceed from the smaller to the
#	larger sequences.
#
export PATH=/home/qiime/bin:$PATH

for i in refv3v5 refv4v6 refssu ; do
  cd $i
  echo "*** $i ***"
    cd qiime
#    ln -s ../*.fas .
    if [ ! -e bin ] ; then ln -s ../bin . ; fi
    for j in *.fas ; do
      echo $j
      bash ./bin/qiime_rarefact.sh $j
    done >& qiime.log
    cd ..
  cd ..
done
#
####
