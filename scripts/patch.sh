#!/usr/bin/env bash
#
# patch.sh
# 確認本地 master 已推上 GitHub 後，打 patch tag（patch-N-vX.Y.Z）並 push 觸發 patch.yml：
#   對「最新 tag 對應的 release 版本」下 shorebird patch，
#   純 Dart 變更數分鐘內 OTA 出貨，不經 Play Store 審查。
#
# 直接 git push origin master 不會觸發 Shorebird，一定要跑這支 script 才會出貨。
#
# 用法（從專案根目錄執行）：
#   ./scripts/patch.sh        # N 自動接續該版本現有 patch tag 的最大編號
#   ./scripts/patch.sh 3      # 指定 N（例如要對齊 Shorebird 的 patch 編號時）
#
# 注意：
# - patch tag 的 N 是該版本的第幾次 patch 出貨（本 script 自動遞增），
#   不以 v 開頭，所以不會觸發 release.yml，也不影響以 v* tag 計算的版號。
# - 動到 native（gradle / AndroidManifest / 含 native code 的 plugin / Flutter 升版）
#   無法 patch，CI 會偵測並失敗——此時請改跑 ./scripts/release.sh 打新版上架。
# - 需要至少一個已 release 的 v* tag 當 baseline。
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

# --- 前置檢查 ---------------------------------------------------------------
BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [[ "$BRANCH" != "master" ]]; then
  echo "❌ 目前在分支 ${BRANCH}，patch 只能出自 master。" >&2
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

LATEST_TAG=$(git describe --tags --abbrev=0 --match 'v*' 2>/dev/null || echo "")
if [[ -z "$LATEST_TAG" ]]; then
  echo "❌ 尚無任何 v* tag，沒有可 patch 的 baseline。請先跑 ./scripts/release.sh。" >&2
  exit 1
fi

if git describe --tags --exact-match --match 'v*' HEAD >/dev/null 2>&1; then
  echo "❌ HEAD 就是 tag $LATEST_TAG 本身，沒有新變更可 patch。" >&2
  exit 1
fi

VERSION_NAME=${LATEST_TAG#v} # Android versionName 需為 X.Y.Z 數字格式
BUILD_NUMBER=$(git rev-list "$LATEST_TAG" --count)
AHEAD=$(git rev-list "$LATEST_TAG"..HEAD --count)

# patch tag:patch-N-vX.Y.Z。N 可由第一個參數指定,否則接續該版本現有
# patch tag 的最大編號(含改格式前的舊 tag patch-vX.Y.Z-N)。
PATCH_N="${1:-}"
if [[ -z "$PATCH_N" ]]; then
  LAST_N=$(
    {
      git tag --list "patch-*-${LATEST_TAG}" | sed -E 's/^patch-([^-]*)-.*$/\1/'
      git tag --list "patch-${LATEST_TAG}-*" | sed 's/^.*-//'
    } | grep -E '^[0-9]+$' | sort -n | tail -1 || true
  )
  PATCH_N=$(( ${LAST_N:-0} + 1 ))
elif [[ ! "$PATCH_N" =~ ^[1-9][0-9]*$ ]]; then
  echo "❌ patch 編號必須是正整數：${PATCH_N}" >&2
  exit 1
fi
PATCH_TAG="patch-${PATCH_N}-${LATEST_TAG}"
if git rev-parse -q --verify "refs/tags/${PATCH_TAG}" >/dev/null; then
  echo "❌ tag ${PATCH_TAG} 已存在。" >&2
  exit 1
fi

echo ""
echo "🩹 即將 OTA patch："
echo "   目標 release : ${LATEST_TAG}（shorebird 識別：${VERSION_NAME}+${BUILD_NUMBER}，領先 ${AHEAD} commits）"
echo "   commit       : $(git log -1 --oneline)"
echo "   patch tag    : ${PATCH_TAG}"
echo ""
read -r -p "確認出貨？[y/N] " REPLY
if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
  echo "已取消。"
  exit 0
fi

# --- 打 patch tag 觸發 workflow ----------------------------------------------
# patch.yml 由 patch-N-vX.Y.Z tag 的 push 觸發,push master 本身不會觸發。
# 先確保 origin/master 與本地一致(有未推的 commit 就先推),再打 tag 並推上去。
# 只靠 git push,不需要 gh CLI。
if [[ "$(git rev-parse HEAD)" != "$(git rev-parse origin/master)" ]]; then
  git push origin master
  echo "✅ 已推送 master。"
fi

git tag -a "$PATCH_TAG" -m "OTA patch $PATCH_TAG"
git push origin "refs/tags/$PATCH_TAG"
echo "✅ 已推送 tag ${PATCH_TAG},觸發 patch workflow。"

REPO_URL=$(git remote get-url origin | sed -E 's#^git@github.com:#https://github.com/#; s#\.git$##')
echo "   $REPO_URL/actions/workflows/patch.yml"
