#!/bin/bash
cd "$(dirname "$0")/.."
#set -x

cat .gitmodules |grep -F path|awk '{print $3}'|while read DIR; do  
  (
    cd $DIR && git fetch --prune && git remote prune origin && git worktree prune && git gc
  ); 
done
