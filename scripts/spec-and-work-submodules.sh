#!/bin/bash
cd "$(dirname "$0")/.."
#set -e
#set -x

echo bus-accounts bus-assets bus-attachments bus-bank bus-entities \
   bus-invoices bus-journal bus-loans bus-pdf bus-period bus-reconcile \
   bus-reports bus-validate bus-vat |tr ' ' '\n'|while read DIR; do 
  if test -e "$DIR/scripts/work.sh"; then
    echo "----- $DIR -----"
    (
      set -e
      cd $DIR
      ./scripts/refine-spec.sh < /dev/null
      ./scripts/work.sh < /dev/null
    )
    echo "----- $DIR -----"
    echo
  fi
done
