#!/bin/bash
# swift build, with only the diagnostics.
swift build "$@" 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -v "^\[\|swift-frontend\|^Fetch\|^Creating\|^Working\|^Computing\|^Updating" 
