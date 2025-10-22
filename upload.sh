#!/bin/bash
# Upload ONLY files in the repo root to GitHub (origin/main) via SSH,
# without pulling other remote files; then delete those local files.
# Works with sparse-checkout: it dynamically adds just-these-files to the cone.

set -euo pipefail

# 0) Show current remote to confirm SSH-443 / SSH in use
git remote -v

# 1) Candidate files in repo ROOT (skip dirs). Edit EXCLUDES if needed.
shopt -s nullglob dotglob
EXCLUDES=( ".git" ".gitignore" ".gitattributes" "upload.sh" "upload_root.sh" )
ROOT_FILES=()

for f in * .*; do
  # skip non-regular files and directories
  [[ -f "$f" ]] || continue

  skip=false
  for ex in "${EXCLUDES[@]}"; do
    [[ "$f" == "$ex" ]] && { skip=true; break; }
  done
  $skip && continue

  ROOT_FILES+=( "$f" )
done

if [ ${#ROOT_FILES[@]} -eq 0 ]; then
  echo "📂 Root has no uploadable files. Nothing to do."
  exit 0
fi

echo "📝 Files to upload from root:"
printf '  - %s\n' "${ROOT_FILES[@]}"

# 2) Make sure LFS tracks PDFs (first run effective, then harmless)
git lfs install >/dev/null 2>&1 || true
git lfs track "*.pdf"  >/dev/null 2>&1 || true
git add .gitattributes 2>/dev/null || true

# 3) Avoid conflicts: fetch + (best-effort) rebase pull
git fetch origin
git pull origin main --rebase || true

# 4) Ensure sparse-checkout includes these root files (won't pull the rest)
# Works when sparse-checkout is enabled (cone mode). If not enabled, this is harmless.
for f in "${ROOT_FILES[@]}"; do
  git sparse-checkout add "$f" 2>/dev/null || true
done

# 5) Commit & push only these files
git add -- "${ROOT_FILES[@]}"
git commit -m "auto: upload root files on $(date '+%Y-%m-%d %H:%M:%S')"
git push origin main

# 6) Clean local copies of just-uploaded files
echo "✅ Uploaded. Cleaning local copies..."
for f in "${ROOT_FILES[@]}"; do
  rm -f -- "$f"
done

echo "🎉 Done."
