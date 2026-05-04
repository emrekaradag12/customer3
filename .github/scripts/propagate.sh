#!/bin/bash
set -e

CLIENT_REPO=$1
CLIENT_BRANCH=$2
CORE_REPO=$3
TOKEN=$4

git config --global user.name "Core Bot"
git config --global user.email "bot@company.com"

echo "Starting propagation to $CLIENT_REPO"

git clone "https://x-access-token:${TOKEN}@github.com/${CLIENT_REPO}.git" client-repo
cd client-repo

git remote add upstream "https://x-access-token:${TOKEN}@github.com/${CORE_REPO}.git"
git fetch upstream

git checkout "$CLIENT_BRANCH"

if git merge upstream/main \
     --allow-unrelated-histories \
     --no-edit \
     -m "chore: sync from core"; then
  git push origin "$CLIENT_BRANCH"
  echo "Success: $CLIENT_REPO updated"
  exit 0
fi

git merge --abort

if git merge upstream/main \
     --allow-unrelated-histories \
     --strategy-option=theirs \
     --no-edit \
     -m "chore: sync from core auto-resolved"; then
  git push origin "$CLIENT_BRANCH"
  echo "Success: $CLIENT_REPO updated with auto-resolve"
  exit 0
fi

echo "Failed: manual intervention needed"
exit 1