#!/bin/bash
cd "$(dirname "$0")/.."
#set -e
#set -x

echo bus-*|tr ' ' '\n'|while read DIR; do 
  if test -e "$DIR/scripts/work.sh"; then
    echo "----- $DIR -----"
    (
      set -e
      cd $DIR
      bus dev spec plan work e2e stage commit < /dev/null
    )
    echo "----- $DIR -----"
    echo
  fi
done
