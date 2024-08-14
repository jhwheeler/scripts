#!/bin/bash

# Usage: ./recreate_branch.sh --source <source-branch> --target <branch-to-recreate>
# or: ./recreate_branch.sh -s <source-branch> -t <branch-to-recreate>

# This script will recreate a branch based on another branch.
# It will also stash any changes, fetch the latest changes, and push the new branch.
#
# This is useful in many cases, for example when staging/production has diverged from your development branch,
# and you want to recreate the staging/production branch based on the latest development branch.

# Exit immediately if a command exits with a non-zero status.
set -e

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -s|--source) SOURCE_BRANCH="$2"; shift ;;
        -t|--target) BRANCH_TO_RECREATE="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Check if both arguments are provided
if [ -z "$SOURCE_BRANCH" ] || [ -z "$BRANCH_TO_RECREATE" ]; then
    echo "Usage: $0 --source <source-branch> --target <branch-to-recreate>"
    echo "   or: $0 -s <source-branch> -t <branch-to-recreate>"
    exit 1
fi

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

echo "Checking out $SOURCE_BRANCH..."
git checkout $SOURCE_BRANCH || { echo "Failed to checkout source branch"; exit 1; }

echo "Pulling latest changes for $SOURCE_BRANCH..."
git pull origin $SOURCE_BRANCH || { echo "Failed to pull latest changes"; exit 1; }

echo "Deleting branch $BRANCH_TO_RECREATE locally..."
git branch -D $BRANCH_TO_RECREATE || { echo "Failed to delete local branch"; exit 1; }

echo "Deleting branch $BRANCH_TO_RECREATE remotely..."
git push origin --delete $BRANCH_TO_RECREATE || { echo "Failed to delete remote branch"; exit 1; }

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