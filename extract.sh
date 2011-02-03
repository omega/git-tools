#!/bin/sh

for i in `ls data-collectors`; do
    li=`echo ${i} | tr '[A-Z]' '[a-z]'`
    echo " --->>> $i -- $li"
    cd data-collectors
    git branch -D extract
    git branch extract
    git filter-branch -f --subdirectory-filter $i extract
    cd ..
    mkdir $li
    cd $li
     git init
     git pull ../data-collectors extract
     cd ..
done
