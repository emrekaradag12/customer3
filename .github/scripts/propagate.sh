#!/bin/bash
set -e

CLIENT_REPO=$1
CLIENT_BRANCH=$2
CORE_REPO=$3
TOKEN=$4
BOT_NAME=$5
BOT_EMAIL=$6

echo "🔄 Starting propagation to $CLIENT_REPO..."

git config --global user.name "$BOT_NAME"
git config --global user.email "$BOT_EMAIL"

# Token'lı clone
git clone "https://x-access-token:${TOKEN}@github.com/${CLIENT_REPO}.git" client-repo
cd client-repo

# Token'lı upstream
git remote add upstream "https://x-access-token:${TOKEN}@github.com/${CORE_REPO}.git"
git fetch upstream

git checkout "$CLIENT_BRANCH"

if git merge upstream/main --no-edit -m "chore: sync from core $(date +'%Y-%m-%d %H:%M')"; then
  git push origin "$CLIENT_BRANCH"
  echo "✅ $CLIENT_REPO successfully updated"
else
  git merge --abort

  CONFLICT_BRANCH="core-sync-conflict-$(date +'%Y%m%d-%H%M')"
  git checkout -b "$CONFLICT_BRANCH"
  git add -A
  git commit -m "chore: core sync conflict - needs manual resolution" || true
  git push origin "$CONFLICT_BRANCH"

  gh pr create \
    --repo "$CLIENT_REPO" \
    --title "⚠️ Core sync conflict - $(date +'%Y-%m-%d')" \
    --body "Otomatik merge başarısız. Manuel müdahale gerekiyor." \
    --base "$CLIENT_BRANCH" \
    --head "$CONFLICT_BRANCH"

  echo "⚠️ Conflict detected in $CLIENT_REPO — PR opened"
  exit 1
fi