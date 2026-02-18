#!/bin/bash
set -x
set -e
.bus/dev/changed-docs-1.sh|grep -vF bus-books|while read DIR; do
  (cd "$DIR" && bus dev spec plan triage stage commit)
done
