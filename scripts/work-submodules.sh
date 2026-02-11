#!/bin/bash
cd "$(dirname "$0")/.."
#set -e
#set -x

echo bus-*|tr ' ' '\n'|while read DIR; do 
  if test -e "$DIR/scripts/work.sh"; then
    echo "----- $DIR -----"
    (
      cd $DIR
      bus dev work < /dev/null
    )
    echo "----- $DIR -----"
    echo
  fi
done
