#!/bin/bash
set -euo pipefail

echo "========================================"
echo "  Sesame-AG 自动同步构建系统 - 配置向导"
echo "========================================"
echo ""

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

configure_local() {
    echo "--- 本地 Cron 配置 ---"

    local CRON_INTERVAL="${1:-30}"
    local SYNC_SCRIPT="$REPO_DIR/sync.sh"

    local CRON_JOB="*/$CRON_INTERVAL * * * * $SYNC_SCRIPT >> /tmp/sesame_ag_sync_cron.log 2>&1"

    if crontab -l 2>/dev/null | grep -qF "$SYNC_SCRIPT"; then
        echo "Cron 任务已存在，更新中..."
        (crontab -l 2>/dev/null | grep -vF "$SYNC_SCRIPT"; echo "$CRON_JOB") | crontab -
    else
        (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
    fi

    echo "Cron 任务已配置 (每 ${CRON_INTERVAL} 分钟执行一次)"
    echo "日志文件: /tmp/sesame_ag_sync_cron.log"
}

setup_email_env() {
    echo ""
    echo "--- SMTP 邮件配置 ---"
    echo "请提供以下 SMTP 配置（留空跳过）："

    if [ -n "${SMTP_SERVER:-}" ]; then
        echo "SMTP_SERVER 已设置: $SMTP_SERVER"
    else
        read -r -p "SMTP 服务器地址: " SMTP_SERVER
        export SMTP_SERVER
    fi

    if [ -n "${SMTP_PORT:-}" ]; then
        echo "SMTP_PORT 已设置: $SMTP_PORT"
    else
        read -r -p "SMTP 端口 [587]: " SMTP_PORT
        SMTP_PORT="${SMTP_PORT:-587}"
        export SMTP_PORT
    fi

    if [ -n "${SMTP_USER:-}" ]; then
        echo "SMTP_USER 已设置"
    else
        read -r -p "SMTP 用户名: " SMTP_USER
        export SMTP_USER
    fi

    if [ -n "${SMTP_PASS:-}" ]; then
        echo "SMTP_PASS 已设置"
    else
        read -r -s -p "SMTP 密码: " SMTP_PASS
        echo ""
        export SMTP_PASS
    fi

    if [ -n "${FROM_EMAIL:-}" ]; then
        echo "FROM_EMAIL 已设置: $FROM_EMAIL"
    else
        read -r -p "发件邮箱: " FROM_EMAIL
        export FROM_EMAIL
    fi

    if [ -n "${TO_EMAIL:-}" ]; then
        echo "TO_EMAIL 已设置: $TO_EMAIL"
    else
        read -r -p "收件邮箱: " TO_EMAIL
        export TO_EMAIL
    fi
}

show_github_actions_guide() {
    echo ""
    echo "========================================"
    echo "  GitHub Actions Secrets 配置指南"
    echo "========================================"
    echo ""
    echo "在 https://github.com/zhaolongwudi/Sesame-AG/settings/secrets/actions"
    echo "中添加以下 Secrets:"
    echo ""
    echo "  GH_PAT        GitHub Personal Access Token"
    echo "                  需要 repo 和 workflow 权限"
    echo ""
    echo "  SMTP_SERVER   邮件服务器地址"
    echo "  SMTP_PORT     邮件服务器端口 (如 587)"
    echo "  SMTP_USER     SMTP 用户名"
    echo "  SMTP_PASS     SMTP 密码"
    echo "  FROM_EMAIL    发件邮箱"
    echo "  TO_EMAIL      收件邮箱"
    echo ""
    echo "========================================"
    echo "  GitHub PAT 生成步骤"
    echo "========================================"
    echo ""
    echo "1. 打开 https://github.com/settings/tokens"
    echo "2. 点击 'Generate new token (classic)'"
    echo "3. 勾选 repo (全部) 和 workflow"
    echo "4. 生成后复制 token"
    echo "5. 粘贴到 GitHub Secrets 的 GH_PAT"
    echo ""
}

do_initial_push() {
    echo ""
    echo "--- 初始推送到目标仓库 ---"
    cd "$REPO_DIR"
    git push zhaolongwudi dev 2>&1 || {
        echo "推送失败。请确保:"
        echo "  1. 已创建 https://github.com/zhaolongwudi/Sesame-AG"
        echo "  2. 已配置 Git 凭据"
        echo "     git remote set-url zhaolongwudi https://<TOKEN>@github.com/zhaolongwudi/Sesame-AG.git"
    }
}

case "${1:-}" in
    cron)
        configure_local "${2:-30}"
        ;;
    email)
        setup_email_env
        ;;
    guide)
        show_github_actions_guide
        ;;
    push)
        do_initial_push
        ;;
    all|"")
        configure_local "30"
        show_github_actions_guide
        echo ""
        echo "本地 cron 已配置。现在需要:"
        echo "  1. 提供 GitHub PAT 完成初始推送"
        echo "  2. 在目标仓库配置 GitHub Actions Secrets"
        echo ""
        echo "运行 './setup.sh push' 尝试初始推送"
        echo "运行 './setup.sh guide' 查看 GitHub Actions 配置指南"
        ;;
esac
