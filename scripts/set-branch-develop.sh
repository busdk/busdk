#!/bin/bash
cd "$(dirname "$0")/.."
set -x
#git checkout develop
cat .gitmodules |grep -F path|awk '{print $3}'|while read DIR; do 
  (cd $DIR && git fetch && git checkout develop); 
done
