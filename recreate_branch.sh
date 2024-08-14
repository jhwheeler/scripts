#!/bin/bash

# Usage: ./recreate_branch.sh <branch-to-recreate> <source-branch>

# This script will recreate a branch based on another branch.
# It will also stash any changes, fetch the latest changes, and push the new branch.
#
# This is useful in many cases, for example when staging/production has diverged from your development branch,
# and you want to recreate the staging/production branch based on the latest development branch.

# Exit immediately if a command exits with a non-zero status.
set -e

# Check if two arguments are provided
if [ $# -ne 2 ]; then
    echo "Usage: $0 <branch-to-recreate> <source-branch>"
    exit 1
fi

BRANCH_TO_RECREATE=$1
SOURCE_BRANCH=$2

# Stash any uncommitted changes, including untracked files
echo "Attempting to stash changes..."
STASH_RESULT=$(git stash push --include-untracked)
if [[ $STASH_RESULT == "No local changes to save" ]]; then
    CHANGES_STASHED=false
else
    CHANGES_STASHED=true
fi

echo "Fetching latest changes from origin..."
git fetch origin || { echo "Failed to fetch from origin"; exit 1; }

echo "Deleting branch $BRANCH_TO_RECREATE locally..."
git branch -D $BRANCH_TO_RECREATE || { echo "Failed to delete local branch"; exit 1; }

echo "Deleting branch $BRANCH_TO_RECREATE remotely..."
git push origin --delete $BRANCH_TO_RECREATE || { echo "Failed to delete remote branch"; exit 1; }

echo "Checking out $SOURCE_BRANCH..."
git checkout $SOURCE_BRANCH || { echo "Failed to checkout source branch"; exit 1; }

echo "Pulling latest changes for $SOURCE_BRANCH..."
git pull origin $SOURCE_BRANCH || { echo "Failed to pull latest changes"; exit 1; }

echo "Creating new branch $BRANCH_TO_RECREATE..."
git checkout -b $BRANCH_TO_RECREATE || { echo "Failed to create new branch"; exit 1; }

echo "Pushing $BRANCH_TO_RECREATE to origin..."
git push -u origin $BRANCH_TO_RECREATE || { echo "Failed to push new branch"; exit 1; }

echo "Checking out previous branch..."
git checkout - || { echo "Failed to checkout previous branch"; exit 1; }

# Apply the changes that were stashed at the beginning of the script, if any
if $CHANGES_STASHED; then
    echo "Applying stashed changes..."
    if git stash pop; then
        echo "Stashed changes applied successfully"
    else
        echo "Warning: There were conflicts when applying stashed changes"
        echo "Please resolve conflicts manually and then run 'git stash drop' to clear the stash"
    fi
fi

echo "Branch $BRANCH_TO_RECREATE has been recreated based on $SOURCE_BRANCH"