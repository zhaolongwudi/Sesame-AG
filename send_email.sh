#!/bin/bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

SMTP_SERVER="${SMTP_SERVER:-}"
SMTP_PORT="${SMTP_PORT:-587}"
SMTP_USER="${SMTP_USER:-}"
SMTP_PASS="${SMTP_PASS:-}"
FROM_EMAIL="${FROM_EMAIL:-}"
TO_EMAIL="${TO_EMAIL:-}"
COMMIT_MSG="${1:-新版本}"
COMMIT_ID="${2:-unknown}"

if [ -z "$SMTP_SERVER" ] || [ -z "$SMTP_USER" ] || [ -z "$SMTP_PASS" ] || [ -z "$FROM_EMAIL" ] || [ -z "$TO_EMAIL" ]; then
    echo "错误: SMTP 配置不完整，请设置环境变量:"
    echo "  SMTP_SERVER, SMTP_PORT, SMTP_USER, SMTP_PASS, FROM_EMAIL, TO_EMAIL"
    exit 1
fi

APK_DIR=""
if [ -d "$REPO_DIR/app/build/outputs/apk/release" ]; then
    APK_DIR="$REPO_DIR/app/build/outputs/apk/release"
elif [ -d "$REPO_DIR/app/build/outputs/apk/debug" ]; then
    APK_DIR="$REPO_DIR/app/build/outputs/apk/debug"
fi

SUBJECT="[Sesame-AG] 新构建完成 - ${COMMIT_MSG:0:50}"

BODY="Sesame-AG 自动构建完成

提交: ${COMMIT_ID}
信息: ${COMMIT_MSG}

构建时间: $(date '+%Y-%m-%d %H:%M:%S')

仓库: https://github.com/zhaolongwudi/Sesame-AG/"

TEMP_EMAIL="/tmp/sesame_ag_email_$$.txt"

{
    echo "From: $FROM_EMAIL"
    echo "To: $TO_EMAIL"
    echo "Subject: $SUBJECT"
    echo "MIME-Version: 1.0"
    echo "Content-Type: multipart/mixed; boundary=\"BOUNDARY_$$\""
    echo ""
    echo "--BOUNDARY_$$"
    echo "Content-Type: text/plain; charset=utf-8"
    echo ""
    echo "$BODY"
    echo ""

    if [ -n "$APK_DIR" ] && [ -d "$APK_DIR" ]; then
        for apk in "$APK_DIR"/*.apk; do
            if [ -f "$apk" ]; then
                APK_NAME=$(basename "$apk")
                echo "--BOUNDARY_$$"
                echo "Content-Type: application/vnd.android.package-archive"
                echo "Content-Disposition: attachment; filename=\"$APK_NAME\""
                echo "Content-Transfer-Encoding: base64"
                echo ""
                base64 "$apk"
                echo ""
            fi
        done
    fi

    echo "--BOUNDARY_$$--"
} > "$TEMP_EMAIL"

echo "[$(date)] 发送邮件至 $TO_EMAIL..."

if command -v sendmail &>/dev/null; then
    sendmail -t < "$TEMP_EMAIL"
elif command -v msmtp &>/dev/null; then
    msmtp -t < "$TEMP_EMAIL"
elif command -v curl &>/dev/null; then
    curl --silent --show-error --url "smtps://$SMTP_SERVER:$SMTP_PORT" \
        --ssl-reqd \
        --mail-from "$FROM_EMAIL" \
        --mail-rcpt "$TO_EMAIL" \
        --user "$SMTP_USER:$SMTP_PASS" \
        --upload-file "$TEMP_EMAIL"
else
    echo "错误: 未找到可用的邮件发送工具 (sendmail/msmtp/curl)"
    rm -f "$TEMP_EMAIL"
    exit 1
fi

rm -f "$TEMP_EMAIL"
echo "[$(date)] 邮件发送完成"
