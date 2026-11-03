#!/bin/bash
# Push zakicit.lua ke GitHub dan update loader dengan commit hash baru
set -e
cd /Users/macbookpro/orca/projects/rea

# Commit semua perubahan zakicit dulu
git add zakicit.lua zakicit_loader.lua push_zakicit.sh .gitignore 2>/dev/null || true
git commit -m "update zakicit $(date '+%Y-%m-%d %H:%M')" --no-verify 2>/dev/null || echo "Nothing to commit"
git push origin master:main --no-verify --force

# Ambil SHA setelah push zakicit
SHA=$(git rev-parse HEAD)
RAW_URL="https://raw.githubusercontent.com/AkhmadZaki14/zakicit/$SHA/zakicit.lua"
echo "SHA: $SHA"

# Update URL di loader
sed -i '' "s|https://raw.githubusercontent.com/AkhmadZaki14/zakicit/[^\"/']*/zakicit.lua|$RAW_URL|g" zakicit_loader.lua

# Commit loader dengan SHA yang sudah benar
git add zakicit_loader.lua
git commit -m "loader: pin $SHA" --no-verify 2>/dev/null || true
git push origin master:main --no-verify --force

echo "Done! URL: $RAW_URL"
# Verifikasi
curl -s "$RAW_URL" | grep "BUILD"
