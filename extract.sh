#!/bin/sh
DIR=$1
shift;
EXTRACT="$*"
if [ -z "$DIR" ]; then
    echo "No dir specified"
    exit 1;
fi
FILES=`ls $DIR`
if [ -n "$EXTRACT" ]; then
    FILES="$EXTRACT"
fi
echo "  Extracting: $FILES"
for i in `echo $FILES`; do
    li=`echo ${i} | tr '[A-Z]' '[a-z]'`
    echo " --->>> $i -- $li"
    cd $DIR
    git branch -D extract
    git branch extract
    git filter-branch -f --subdirectory-filter $i extract
    cd ..
    mkdir $li
    cd $li
    git init
    git pull ../$DIR extract
    cd ..
done
