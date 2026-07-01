#!/bin/bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_TYPE="${1:-release}"

cd "$REPO_DIR"

echo "[$(date)] 开始构建 Sesame-AG APK (${BUILD_TYPE})..."

if [ ! -f "./gradlew" ]; then
    echo "错误: gradlew 不存在"
    exit 1
fi

chmod +x ./gradlew

if [ "$BUILD_TYPE" = "release" ]; then
    echo "[$(date)] 执行 Release 构建..."
    export CI="true"
    ./gradlew --no-daemon --stacktrace :app:assembleRelease
    APK_DIR="app/build/outputs/apk/release"
    APK_PATTERN="*.apk"
else
    echo "[$(date)] 执行 Debug 构建..."
    ./gradlew --no-daemon --stacktrace :app:assembleDebug
    APK_DIR="app/build/outputs/apk/debug"
    APK_PATTERN="*.apk"
fi

if [ -d "$APK_DIR" ]; then
    APK_COUNT=$(find "$APK_DIR" -name "$APK_PATTERN" -type f | wc -l)
    echo "[$(date)] 构建完成，生成 $APK_COUNT 个 APK"
    find "$APK_DIR" -name "$APK_PATTERN" -type f -exec ls -lh {} \;
else
    echo "[$(date)] APK 输出目录不存在: $APK_DIR"
    exit 1
fi

echo "[$(date)] 构建成功完成"
