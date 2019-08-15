#!/bin/bash

#number of concurrent jobs

if [ -z $QJOBS ]
then
arch=`uname`
if [ "$arch" == "Linux" ]
then
QJOBS=`grep -ic ^processor /proc/cpuinfo`
elif ["$arch" == "Darwin" ]
QJOBS=`sysctl -n hw.ncpu`
else
QJOBS=2
echo "Warning: could not determine number of CPU cores"
fi
fi

JOBSFNAME=$1

if [ -z $JOBSFNAME ]
then
echo "No job queue file specified (coder error)"
else

#Ugly workaround for apparent bug in gnu parallel
#When reading a live file, procs dont start until after the initial 
# $QJOBS jobs submitted
#Submit $QJOBS empty jobs to start things off...

echo > $JOBSFNAME
for (( i=0;i<=$QJOBS;i++ ))
do
echo ":" >> $JOBSFNAME
done

#touch $JOBSFNAME

tail -f $JOBSFNAME | parallel -j$QJOBS

fi
