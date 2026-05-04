# core-repo/.github/scripts/propagate.sh

#!/bin/bash
set -e

CLIENT_REPO=$1
CLIENT_BRANCH=$2
CORE_REPO=$3
TOKEN=$4
BOT_NAME=$5
BOT_EMAIL=$6

echo "🔄 Starting propagation to $CLIENT_REPO..."

# Git config
git config --global user.name "$BOT_NAME"
git config --global user.email "$BOT_EMAIL"

# Clone client repo
git clone "https://x-access-token:${TOKEN}@github.com/${CLIENT_REPO}.git" client-repo
cd client-repo

# Core'u upstream olarak ekle
git remote add upstream "https://github.com/${CORE_REPO}.git"
git fetch upstream

# Merge dene
git checkout "$CLIENT_BRANCH"

if git merge upstream/main --no-edit -m "chore: sync from core $(date +'%Y-%m-%d %H:%M')"; then
  # Başarılı → push et
  git push origin "$CLIENT_BRANCH"
  echo "✅ $CLIENT_REPO successfully updated"
else
  # Conflict → abort, branch aç, PR oluştur
  git merge --abort

  CONFLICT_BRANCH="core-sync-conflict-$(date +'%Y%m%d-%H%M')"
  git checkout -b "$CONFLICT_BRANCH"

  # Conflict olan dosyaları kaydet
  CONFLICT_FILES=$(git diff --name-only --diff-filter=U 2>/dev/null || echo "Could not determine conflict files")

  # Conflict'li haliyle push et
  git add -A
  git commit -m "chore: core sync conflict - needs manual resolution" || true
  git push origin "$CONFLICT_BRANCH"

  # PR aç
  gh pr create \
    --repo "$CLIENT_REPO" \
    --title "⚠️ Core sync conflict - $(date +'%Y-%m-%d')" \
    --body "## Core Sync Conflict

Otomatik merge başarısız oldu. Manuel müdahale gerekiyor.

### Conflict Çıkan Dosyalar
\`\`\`
$CONFLICT_FILES
\`\`\`

### Ne Yapmalısın?
1. Bu branch'i local'e çek
2. Conflict'leri çöz
3. PR'ı merge et

> ⚠️ \`tenant.config.ts\` ve \`public/\` klasörüne dokunma — onlar güvendedir." \
    --base "$CLIENT_BRANCH" \
    --head "$CONFLICT_BRANCH"

  echo "⚠️ Conflict detected in $CLIENT_REPO — PR opened"
  exit 1
fi