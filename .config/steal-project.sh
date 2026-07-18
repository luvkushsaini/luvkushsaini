#!/bin/bash
# I don't recommend this, this is written just for automation
# Just enter the required details and execute the script

REPO_URL=""
GITHUB_ID=""

REPO_NAME=$(basename "${REPO_URL%.git}")

git clone $REPO_URL tmp && cd tmp

git filter-branch --env-filter '
CORRECT_NAME="Your Name"
CORRECT_EMAIL="your.email@example.com"

export GIT_COMMITTER_NAME="$CORRECT_NAME"
export GIT_COMMITTER_EMAIL="$CORRECT_EMAIL"
export GIT_AUTHOR_NAME="$CORRECT_NAME"
export GIT_AUTHOR_EMAIL="$CORRECT_EMAIL"
' --tag-name-filter cat -- --branches --tags



git remote set-url origin "https://github.com/$GITHUB_ID/.git"

git push origin main

cd .. && rm -rf tmp