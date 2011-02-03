#!/bin/sh

for i in `find .. -type d -depth 1 -name 'data-collector-*'`; do
    echo " merging in $i"
    base=`basename $i`
    git checkout -b merge
    git pull $i master
    if [ -f .gitignore ]; then
        echo $base >> ../IGNORE
        cat .gitignore >> ../IGNORE
        git rm .gitignore
    fi
    if [ -f .cvsignore ]; then
        git rm .cvsignore
    fi
    mkdir $base
    git mv `ls | grep -v 'data-collector'` $base
    git commit -m "Moved $base into a sub-folder again"
    git checkout master
    git merge merge
    git branch -d merge
done
