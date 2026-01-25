#!/bin/bash
cd "$(dirname "$0")/.."
#set -e
#set -x

echo bus bus-*|tr ' ' '\n'|while read DIR; do 
  echo "----- $DIR -----"
  ./$DIR/scripts/work.sh < /dev/null
  echo "----- $DIR -----"
  echo
done
