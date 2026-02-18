#!/bin/bash
set -e
set -x
./.bus/dev/open-tasks.sh|while read DIR; do
  (cd $DIR && bus dev iterate triage stage commit)
done
