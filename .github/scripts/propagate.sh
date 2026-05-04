İki ayrı sorun var burada:
Sorun 1: README.md conflict — hem core'da hem customer1'de README var, çakıştı.
Sorun 2: No commits between main and core-sync-conflict branch — conflict branch'i oluşturuldu ama commit atılamadı, PR açılamadı.

Kök Sebep
Customer1 reposu bağımsız oluşturulmuş, kendi README'si var. Core'un README'si ile çakışıyor. Bu ilk merge'e özgü bir sorun.

Kalıcı Çözüm — Script'i Baştan Yaz
Conflict durumunda --strategy-option=theirs kullan. Yani conflict çıkarsa core'u kabul et, müşteri dosyalarına dokunma. README gibi core dosyaları her zaman core'dan gelmeli zaten.
bash#!/bin/bash
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

git clone "https://x-access-token:${TOKEN}@github.com/${CLIENT_REPO}.git" client-repo
cd client-repo

git remote add upstream "https://x-access-token:${TOKEN}@github.com/${CORE_REPO}.git"
git fetch upstream

git checkout "$CLIENT_BRANCH"

# Önce normal merge dene
if git merge upstream/main \
     --allow-unrelated-histories \
     --no-edit \
     -m "chore: sync from core $(date +'%Y-%m-%d %H:%M')"; then
  git push origin "$CLIENT_BRANCH"
  echo "✅ $CLIENT_REPO successfully updated"
  exit 0
fi

# Normal merge başarısız — conflict var
echo "⚠️ Conflict detected, trying strategy=theirs for core files..."
git merge --abort

# Core'u esas al (theirs = upstream/core)
if git merge upstream/main \
     --allow-unrelated-histories \
     --strategy-option=theirs \
     --no-edit \
     -m "chore: sync from core (auto-resolved) $(date +'%Y-%m-%d %H:%M')"; then
  git push origin "$CLIENT_BRANCH"
  echo "✅ $CLIENT_REPO updated with auto-conflict resolution"
  exit 0
fi

# Hâlâ başarısız — PR aç
echo "⚠️ Auto-resolution failed, opening PR..."
git merge --abort || true

CONFLICT_BRANCH="core-sync-conflict-$(date +'%Y%m%d-%H%M')"
git checkout -b "$CONFLICT_BRANCH"

# Conflict'li dosyaları theirs ile kabul et
git checkout --theirs . || true
git add -A

# Commit atılacak bir şey var mı kontrol et
if git diff --cached --quiet; then
  echo "Nothing to commit, skipping PR"
  exit 1
fi

git commit -m "chore: core sync conflict - needs manual resolution"
git push origin "$CONFLICT_BRANCH"

gh pr create \
  --repo "$CLIENT_REPO" \
  --title "⚠️ Core sync conflict - $(date +'%Y-%m-%d')" \
  --body "Otomatik merge başarısız. Manuel müdahale gerekiyor." \
  --base "$CLIENT_BRANCH" \
  --head "$CONFLICT_BRANCH"

echo "⚠️ PR opened for $CLIENT_REPO"
exit 1