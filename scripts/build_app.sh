#!/usr/bin/env zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

RAW_VERSION="${1:-1.0.0}"
VERSION="${RAW_VERSION#v}"

IFS='.' read -r V_MAJOR V_MINOR V_PATCH <<< "$VERSION"
V_MAJOR="${V_MAJOR:-1}"
V_MINOR="${V_MINOR:-0}"
V_PATCH="${V_PATCH:-0}"
BUILD_NUMBER=$(( V_MAJOR * 10000 + V_MINOR * 100 + V_PATCH ))

echo "==> [1/6] 生成星岛高分矢量图标 AppIcon.icns..."
if [[ ! -f "$ROOT_DIR/App/AppIcon.icns" ]]; then
  swift "$ROOT_DIR/scripts/generate_icon.swift" "$ROOT_DIR/App/AppIcon.icns"
fi

echo "==> [2/6] 编译 StarIsland 与特权守护进程 (Release arm64)..."
swift build -c release --arch arm64 --package-path "$ROOT_DIR/Packages/StarIslandKit"

BIN_DIR="$(swift build -c release --arch arm64 --package-path "$ROOT_DIR/Packages/StarIslandKit" --show-bin-path)"
MAIN_BIN="$BIN_DIR/StarIsland"
HELPER_BIN="$BIN_DIR/com.adgry.starisland.helper"

if [[ ! -x "$MAIN_BIN" ]]; then
  echo "错误：未找到主程序可执行文件 $MAIN_BIN" >&2
  exit 1
fi
if [[ ! -x "$HELPER_BIN" ]]; then
  echo "错误：未找到守护进程可执行文件 $HELPER_BIN" >&2
  exit 1
fi

STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/starisland-stage.XXXXXX")"
APP_BUNDLE="$STAGING_DIR/StarIsland.app"
RELEASE_DIR="$ROOT_DIR/dist/release-$VERSION"
ZIP_PATH="$RELEASE_DIR/StarIsland-arm64.zip"

cleanup() {
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "$APP_BUNDLE" >/dev/null 2>&1 || true
  rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

echo "==> [3/6] 组装 StarIsland.app 应用包结构 (v$VERSION / build $BUILD_NUMBER)..."
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources/zh-Hans.lproj"
mkdir -p "$APP_BUNDLE/Contents/Library/LaunchDaemons"
mkdir -p "$RELEASE_DIR"

cp "$MAIN_BIN" "$APP_BUNDLE/Contents/MacOS/StarIsland"
cp "$HELPER_BIN" "$APP_BUNDLE/Contents/MacOS/com.adgry.starisland.helper"
chmod 755 "$APP_BUNDLE/Contents/MacOS/StarIsland" "$APP_BUNDLE/Contents/MacOS/com.adgry.starisland.helper"

cp "$ROOT_DIR/App/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
cp "$ROOT_DIR/Helper/com.adgry.starisland.helper.plist" "$APP_BUNDLE/Contents/Library/LaunchDaemons/com.adgry.starisland.helper.plist"

sed -e "s/__APP_VERSION__/$VERSION/g" \
    -e "s/__BUILD_NUMBER__/$BUILD_NUMBER/g" \
    "$ROOT_DIR/App/Info.plist" > "$APP_BUNDLE/Contents/Info.plist"

cat > "$APP_BUNDLE/Contents/Resources/zh-Hans.lproj/InfoPlist.strings" <<'EOF'
"CFBundleName" = "星岛";
"CFBundleDisplayName" = "星岛";
EOF

printf "APPL????" > "$APP_BUNDLE/Contents/PkgInfo"

/usr/bin/xattr -cr "$APP_BUNDLE"

echo "==> [4/6] 执行双层 Ad-hoc 权限代码签名（先签内层 Helper，再签外层 App）..."
/usr/bin/codesign --force --sign - \
  --identifier "com.adgry.starisland.helper" \
  --entitlements "$ROOT_DIR/Helper/StarIslandHelper.entitlements" \
  "$APP_BUNDLE/Contents/MacOS/com.adgry.starisland.helper"

/usr/bin/codesign --force --sign - \
  --identifier "com.adgry.starisland" \
  --entitlements "$ROOT_DIR/App/StarIsland.entitlements" \
  "$APP_BUNDLE"

echo "==> [5/6] 严格校验应用包与嵌套组件签名..."
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
/usr/bin/plutil -lint "$APP_BUNDLE/Contents/Info.plist" "$APP_BUNDLE/Contents/Library/LaunchDaemons/com.adgry.starisland.helper.plist"

echo "==> [6/6] 打包发行压缩包 $ZIP_PATH..."
rm -f "$ZIP_PATH"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ZIP_PATH"

(cd "$RELEASE_DIR" && shasum -a 256 "StarIsland-arm64.zip" > "StarIsland-arm64.zip.sha256")
echo "✅ 构建完成：$ZIP_PATH"
