#!/bin/bash

grep -lF '[ ]' bus-*/PLAN.md|sed -re 's@/PLAN.md@@'|sort|uniq
