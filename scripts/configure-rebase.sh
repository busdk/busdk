#!/bin/bash
cd "$(dirname "$0")/.."
set -x
git config pull.rebase true
(
  cat .gitmodules|grep -F path|awk '{print $3}'|while read DIR; do
    (cd $DIR && git config pull.rebase true)&
  done
)|cat
