#!/bin/sh
for i in `find . -type d -depth 1 -not -name '.*'`; do
    echo "pushing $i"
    i=`basename $i`
    # Create the damn repo
    curl -u "omega/token:5e477eca2753e6ffb0065d44e7cd41f1" "https://github.com/api/v2/json/repos/create?name=startsiden/$i&public=0"
    cd $i
    git remote add origin git@github.com:startsiden/$i.git
    git push origin --all
    cd ..
done
