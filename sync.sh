#!/bin/bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
UPSTREAM_REMOTE="origin"
TARGET_REMOTE="zhaolongwudi"
BRANCH="dev"
LOCK_FILE="/tmp/sesame_ag_sync.lock"
STATE_FILE="/tmp/sesame_ag_last_sync_commit.txt"

cleanup() {
    rm -f "$LOCK_FILE"
}

if [ -f "$LOCK_FILE" ]; then
    echo "[$(date)] 同步任务已在运行，跳过"
    exit 0
fi
touch "$LOCK_FILE"
trap cleanup EXIT

cd "$REPO_DIR"

echo "[$(date)] 开始同步检查..."

git fetch "$UPSTREAM_REMOTE" "$BRANCH" --quiet

UPSTREAM_HEAD=$(git rev-parse "$UPSTREAM_REMOTE/$BRANCH")
LOCAL_HEAD=$(git rev-parse "$BRANCH")

if [ "$UPSTREAM_HEAD" = "$LOCAL_HEAD" ]; then
    echo "[$(date)] 无新提交，当前: ${UPSTREAM_HEAD:0:8}"
    exit 0
fi

echo "[$(date)] 检测到新提交! 上游: ${UPSTREAM_HEAD:0:8}, 本地: ${LOCAL_HEAD:0:10}"

git checkout "$BRANCH"
git merge "$UPSTREAM_REMOTE/$BRANCH" --ff-only -m "sync: merge upstream dev branch"

echo "[$(date)] 推送至目标仓库..."
git push "$TARGET_REMOTE" "$BRANCH" 2>&1

echo "$UPSTREAM_HEAD" > "$STATE_FILE"
echo "[$(date)] 同步完成: ${UPSTREAM_HEAD:0:8}"

echo "[$(date)] 触发构建..."
if [ -f "./build.sh" ]; then
    bash ./build.sh || echo "[$(date)] 构建失败，请检查日志"
else
    echo "[$(date)] build.sh 不存在，跳过构建"
fi

echo "[$(date)] 全部完成"
