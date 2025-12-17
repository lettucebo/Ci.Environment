#!/bin/bash

# Script to delete all copilot branches
# This script will delete all local and remote branches that start with "copilot/"

echo "Fetching all branches..."
git fetch --all

echo ""
echo "Found the following copilot branches:"
git branch -r | grep "origin/copilot/" | sed 's|origin/||'

echo ""
read -p "Do you want to delete all copilot branches? (yes/no): " confirmation

if [ "$confirmation" != "yes" ]; then
    echo "Operation cancelled."
    exit 0
fi

# Switch to default branch first (master or main)
echo ""
DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "master")
echo "Switching to $DEFAULT_BRANCH branch..."
git checkout $DEFAULT_BRANCH

# Delete all local copilot branches
echo ""
echo "Deleting local copilot branches..."
git branch | grep "copilot/" | xargs -r git branch -D

# Delete all remote copilot branches
echo ""
echo "Deleting remote copilot branches..."
git branch -r | grep "origin/copilot/" | sed 's|origin/||' | xargs -r -I {} git push origin --delete {}

echo ""
echo "All copilot branches have been deleted."
