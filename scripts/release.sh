#!/usr/bin/env zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

RAW_VERSION="${1:-1.0.0}"
VERSION="${RAW_VERSION#v}"
TAG="v$VERSION"

"$ROOT_DIR/scripts/build_app.sh" "$VERSION"

ZIP_PATH="$ROOT_DIR/dist/release-$VERSION/StarIsland-arm64.zip"
SHA_PATH="$ZIP_PATH.sha256"

if ! git rev-parse "$TAG" >/dev/null 2>&1; then
  git tag -a "$TAG" -m "星岛 StarIsland $TAG"
fi

git push origin HEAD
git push origin "$TAG"

NOTES=$(cat <<EOF
## 星岛 StarIsland $TAG

- **100% 原生简体中文**、**零付费墙**的全功能 macOS 灵动岛生产力工作台。
- 内置媒体同步歌词与 8D 空间音效、双因子智能验证码去重识别、剪贴板历史与追踪链接净化、文件暂存架与本地媒体压缩、Apple Vision 离线 OCR 与圈选识图、窗口磁吸分屏与 Dock 悬停实时窗口预览、键鼠效率增强与 Touch ID 应用锁、SMC 智能电池充电上限与风扇管家、免 Key 天气/NBA 体育比分/股票加密货币看板、多模型 AI 助手（Gemini / OpenAI 兼容 / 本地 Ollama）与手机免装 App 扫码双向快传。
- 支持软件内直连 \`adgry/StarIsland\` 自动检测更新并一键安装升级。

### 安装说明
1. 下载下方 \`StarIsland-arm64.zip\` 并解压；
2. 将 \`StarIsland.app\` 拖入 \`/Applications\`（应用程序）目录并打开；
3. 若首次打开提示安全确认，可在终端执行：\`xattr -cr /Applications/StarIsland.app\`。
EOF
)

if gh release view "$TAG" --repo adgry/StarIsland >/dev/null 2>&1; then
  gh release upload "$TAG" "$ZIP_PATH" "$SHA_PATH" --clobber --repo adgry/StarIsland
else
  gh release create "$TAG" "$ZIP_PATH" "$SHA_PATH" \
    --repo adgry/StarIsland \
    --title "星岛 StarIsland $TAG" \
    --notes "$NOTES"
fi

echo "🚀 已成功发布至 https://github.com/adgry/StarIsland/releases/tag/$TAG"
