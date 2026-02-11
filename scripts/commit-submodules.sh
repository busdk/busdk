#!/bin/bash
cd "$(dirname "$0")/.."
#set -e
#set -x

echo bus bus-*|tr ' ' '\n'|while read DIR; do 
  echo "----- $DIR -----"
  (cd $DIR && git add .)
  bus dev commit < /dev/null
  echo "----- $DIR -----"
  echo
done
