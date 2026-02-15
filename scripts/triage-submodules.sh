#!/bin/bash
cd "$(dirname "$0")/.."
#set -e
#set -x

echo bus-*|tr ' ' '\n'|while read DIR; do 
  echo "----- $DIR -----"
  (
    set -e
    cd $DIR
    bus dev spec e2e stage commit plan triage stage commit < /dev/null
  )
  echo "----- $DIR -----"
  echo
done
