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

# Merge dene
git merge upstream/main \
  --allow-unrelated-histories \
  --no-commit \
  --no-ff || true

# .github conflict'ini her zaman "sil" lehine çöz
# Müşteri reposunda .github/ olmamalı
git rm -rf .github/ 2>/dev/null || true
git checkout HEAD -- .github/ 2>/dev/null || true

# Kalan conflict'leri core lehine çöz
if git diff --name-only --diff-filter=U | grep -q .; then
  git diff --name-only --diff-filter=U | while read file; do
    git checkout --theirs "$file" 2>/dev/null || git rm "$file"
  done
fi

# Commit et
git add -A

if git diff --cached --quiet; then
  echo "Nothing to commit, already up to date"
  exit 0
fi

git commit -m "chore: sync from core"
git push origin "$CLIENT_BRANCH"
echo "Success: $CLIENT_REPO updated"