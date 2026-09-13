#!/usr/bin/env bash
#
# release.sh
# 打新版本 tag 並推上 GitHub，觸發 release.yml：
#   shorebird release 建置已簽章 AAB + APK（註冊 OTA baseline）→ 上架 Play Store internal 軌道。
#   AAB / APK 下載連結會顯示在該 run 的 summary 頁面。
#
# 用法（從專案根目錄執行）：
#   ./scripts/release.sh           # patch bump（1.2.0 → 1.2.1）
#   ./scripts/release.sh minor     # minor bump（1.2.0 → 1.3.0）
#   ./scripts/release.sh major     # major bump（1.2.0 → 2.0.0）
#   ./scripts/release.sh v1.4.0    # 直接指定版本（必須以 v 開頭，1.4.0 會被拒絕）
#
# 純 Dart 的小改動不必上架，改用 ./scripts/patch.sh 走 OTA。
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

BUMP="${1:-patch}"

# --- 前置檢查 ---------------------------------------------------------------
BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [[ "$BRANCH" != "master" ]]; then
  echo "❌ 目前在分支 ${BRANCH}，release 只能出自 master。" >&2
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "❌ working tree 不乾淨，請先 commit 或 stash。" >&2
  exit 1
fi

echo "🔄 同步遠端狀態..."
git fetch origin --tags

if ! git merge-base --is-ancestor origin/master HEAD; then
  echo "❌ 本地 master 落後 origin/master，請先 git pull。" >&2
  exit 1
fi

# --- 計算新版本 --------------------------------------------------------------
# 版本號 = tag 名稱 = vX.Y.Z。
LATEST_TAG=$(git describe --tags --abbrev=0 --match 'v*' 2>/dev/null || echo "")

if [[ "$BUMP" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  NEW_VERSION="$BUMP"                 # 已是 vX.Y.Z，原樣使用，不再加 v
elif [[ "$BUMP" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "❌ 版本號必須以 v 開頭：${BUMP} → v${BUMP}" >&2
  exit 1
elif [[ -z "$LATEST_TAG" ]]; then
  NEW_VERSION="v1.0.0"
  echo "ℹ️  尚無任何 v* tag，首個版本預設 ${NEW_VERSION}（也可直接指定：./scripts/release.sh v0.1.0）"
else
  IFS='.' read -r MAJOR MINOR PATCH <<< "${LATEST_TAG#v}"
  case "$BUMP" in
    major) NEW_VERSION="v$((MAJOR + 1)).0.0" ;;
    minor) NEW_VERSION="v$MAJOR.$((MINOR + 1)).0" ;;
    patch) NEW_VERSION="v$MAJOR.$MINOR.$((PATCH + 1))" ;;
    *)
      echo "❌ 無效參數：${BUMP}（可用 major / minor / patch 或 vX.Y.Z）" >&2
      exit 1
      ;;
  esac
fi

NEW_TAG="$NEW_VERSION"
if git rev-parse "$NEW_TAG" >/dev/null 2>&1; then
  echo "❌ tag $NEW_TAG 已存在。" >&2
  exit 1
fi

# Android versionName 需為 X.Y.Z 數字格式（Flutter --build-name / Play Console），故去掉 v。
VERSION_NAME="${NEW_VERSION#v}"

# --- 版本資訊（Play Console「這個版本有什麼新功能」）------------------------
# release.yml 會把 docs/release-notes/<tag>.md 隨 AAB 送上 Play Console，
# 缺檔或格式不符 CI 會失敗，所以打 tag 前先在本機擋下來。
NOTES="docs/release-notes/${NEW_TAG}.md"
if [[ ! -f "$NOTES" ]]; then
  echo "❌ 找不到 ${NOTES}。" >&2
  echo "   請先在 Claude Code 執行  /release-notes ${NEW_TAG}  產生版本資訊並 commit 後再 release。" >&2
  exit 1
fi
echo "📝 檢查版本資訊 ${NOTES}..."
python3 scripts/release_notes.py "$NOTES" "$(mktemp -d)" >/dev/null || {
  echo "❌ ${NOTES} 格式不符，請執行 python3 scripts/release_notes.py ${NOTES} /tmp/whatsnew 查看錯誤。" >&2
  exit 1
}

# versionCode 規則與 CI 相同：到 tag 為止的總 commit 數（tag 會打在 HEAD）。
BUILD_NUMBER=$(git rev-list HEAD --count)

echo ""
echo "📦 即將 release："
echo "   版本號 / tag : ${NEW_TAG}（目前最新：${LATEST_TAG:-無}）"
echo "   versionName  : ${VERSION_NAME}（Android 顯示用，去掉 v）"
echo "   versionCode  : $BUILD_NUMBER"
echo "   commit       : $(git log -1 --oneline)"
echo "   版本資訊     : $NOTES"
echo ""
read -r -p "確認打 tag 並觸發上架？[y/N] " REPLY
if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
  echo "已取消。"
  exit 0
fi

# --- 打 tag 並 atomic push ---------------------------------------------------
# master 與 tag 一次 atomic push：兩者同時成功或同時失敗，
# 避免 tag 推上去了 master 卻沒更新（release.yml 會檢查 tag 必須在 origin/master 上）。
git tag -a "$NEW_TAG" -m "Release $NEW_TAG"
git push --atomic origin master "refs/tags/$NEW_TAG"

REPO_URL=$(git remote get-url origin | sed -E 's#^git@github.com:#https://github.com/#; s#\.git$##')
echo ""
echo "✅ 已推送 ${NEW_TAG}，release workflow 啟動中："
echo "   $REPO_URL/actions/workflows/release.yml"

# 有 gh 的話抓出這次 run 的連結，並提示可即時追蹤。
if command -v gh >/dev/null 2>&1; then
  sleep 8
  RUN_URL=$(gh run list --workflow=release.yml --limit 1 --json url --jq '.[0].url' 2>/dev/null || true)
  [[ -n "$RUN_URL" ]] && echo "   本次 run：$RUN_URL"
  echo "   即時追蹤：gh run watch"
fi
