#!/bin/bash
set -euo pipefail

REPO_DIR="/workspace/Sesame-AG"
UPSTREAM_REMOTE="origin"
TARGET_REMOTE="zhaolongwudi"
BRANCH="dev"
INTERVAL="${1:-1800}"
LOG_FILE="/tmp/sesame_ag_daemon.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log "守护进程启动，检查间隔: ${INTERVAL}s"
log "仓库: $REPO_DIR"

while true; do
    cd "$REPO_DIR"

    log "--- 开始检查 ---"

    if ! git fetch "$UPSTREAM_REMOTE" "$BRANCH" --quiet 2>&1; then
        log "获取上游失败，等待 ${INTERVAL}s 后重试"
        sleep "$INTERVAL"
        continue
    fi

    UPSTREAM_HEAD=$(git rev-parse "$UPSTREAM_REMOTE/$BRANCH" 2>/dev/null || echo "")
    LOCAL_HEAD=$(git rev-parse "$BRANCH" 2>/dev/null || echo "")

    if [ -z "$UPSTREAM_HEAD" ] || [ -z "$LOCAL_HEAD" ]; then
        log "无法获取 commit 信息，跳过"
        sleep "$INTERVAL"
        continue
    fi

    if git merge-base --is-ancestor "$UPSTREAM_HEAD" "$LOCAL_HEAD" 2>/dev/null; then
        log "上游无新提交 (upstream: ${UPSTREAM_HEAD:0:8})"
        sleep "$INTERVAL"
        continue
    fi

    NEW_COUNT=$(git rev-list --count "$LOCAL_HEAD..$UPSTREAM_HEAD" 2>/dev/null || echo "?")
    log "检测到 $NEW_COUNT 个新提交! ${LOCAL_HEAD:0:8} -> ${UPSTREAM_HEAD:0:8}"

    git checkout "$BRANCH" 2>/dev/null

    if git merge "$UPSTREAM_REMOTE/$BRANCH" --ff-only -m "sync: auto merge upstream dev [skip ci]" 2>&1; then
        log "合并成功"
    else
        log "合并失败，尝试强制同步..."
        git reset --hard "$UPSTREAM_REMOTE/$BRANCH"
        log "已强制同步到上游 HEAD"
    fi

    log "推送至目标仓库..."
    if git -c credential.helper= push "$TARGET_REMOTE" "$BRANCH" 2>&1; then
        log "推送成功"
    else
        log "推送失败"
    fi

    log "--- 本轮检查完成 ---"
    sleep "$INTERVAL"
done
