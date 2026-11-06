#!/usr/bin/env bash
set -euo pipefail

# 星岛 StarIsland 本地构建、签名与 GitHub 发布脚本
# 用法：
#   ./scripts/release.sh <新版本号> [更新说明] [--build-only]

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

REPO="adgry/StarIsland"
NEW_VERSION="${1:-}"
RELEASE_NOTES="${2:-}"
BUILD_ONLY="${3:-}"

if [[ -z "$NEW_VERSION" ]]; then
  echo "用法: ./scripts/release.sh <版本号> [更新说明] [--build-only]"
  exit 1
fi

CLEAN_VERSION="${NEW_VERSION#v}"
CLEAN_VERSION="${CLEAN_VERSION#V}"
TAG_NAME="v${CLEAN_VERSION}"

if [[ "$RELEASE_NOTES" == "--build-only" ]]; then
  BUILD_ONLY="--build-only"
  RELEASE_NOTES=""
fi

if [[ -z "$RELEASE_NOTES" ]]; then
  RELEASE_NOTES="星岛 StarIsland ${TAG_NAME} 全功能解锁版更新发布。"
fi

echo "==> [1/5] 更新版本号至 ${CLEAN_VERSION} (${TAG_NAME})..."
printf "%s\n" "$CLEAN_VERSION" > "$ROOT_DIR/VERSION"

python3 - "$ROOT_DIR/Sapphire.xcodeproj/project.pbxproj" "$CLEAN_VERSION" <<'PY'
import re, sys

pbxproj_path, new_version = sys.argv[1], sys.argv[2]
nums = [int(x) for x in re.findall(r"\d+", new_version)]
while len(nums) < 3:
    nums.append(0)
build_number = max(2, nums[0] * 10000 + nums[1] * 100 + nums[2])

with open(pbxproj_path, "r", encoding="utf-8") as f:
    content = f.read()

pattern = re.compile(
    r"(MARKETING_VERSION = )([^;]+)(;[\s\S]{0,400}?PRODUCT_BUNDLE_IDENTIFIER = com\.adgry\.starisland;)"
)
updated, count = pattern.subn(rf"\g<1>{new_version}\g<3>", content)
if count == 0:
    raise SystemExit("未能在 project.pbxproj 中定位主应用 MARKETING_VERSION")

build_pattern = re.compile(
    r"(CODE_SIGN_ENTITLEMENTS = Sapphire/Sapphire(?:Debug)?\.entitlements;[\s\S]{0,300}?CURRENT_PROJECT_VERSION = )([^;]+)(;)"
)
updated, build_count = build_pattern.subn(rf"\g<1>{build_number}\g<3>", updated)
if build_count == 0:
    raise SystemExit("未能在 project.pbxproj 中定位主应用 CURRENT_PROJECT_VERSION")

with open(pbxproj_path, "w", encoding="utf-8") as f:
    f.write(updated)
print(
    f"    已更新 project.pbxproj 中 {count} 处 MARKETING_VERSION -> {new_version}, "
    f"{build_count} 处 CURRENT_PROJECT_VERSION -> {build_number}"
)
PY

echo "==> [2/5] 编译 Release 版 StarIsland.app..."
DERIVED_DATA="$ROOT_DIR/dist/DerivedData"
DIST_DIR="$ROOT_DIR/dist/release-${CLEAN_VERSION}"
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

xcodebuild \
  -project Sapphire.xcodeproj \
  -scheme Sapphire \
  -configuration Release \
  -destination "platform=macOS,arch=arm64" \
  -derivedDataPath "$DERIVED_DATA" \
  ENABLE_DEBUG_DYLIB=NO \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGN_REQUIRED=NO \
  build >/dev/null

BUILT_APP="$DERIVED_DATA/Build/Products/Release/StarIsland.app"
if [[ ! -d "$BUILT_APP" ]]; then
  echo "错误：未找到构建产物 $BUILT_APP"
  exit 1
fi

SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | awk '/"Apple Development:.*"|"Developer ID Application:.*"/ {print $2; exit}')"
if [[ -z "$SIGN_IDENTITY" ]]; then
  SIGN_IDENTITY="-"
  echo "==> [3/5] 未检测到钥匙串证书，使用 Ad-Hoc 签名 StarIsland.app..."
else
  echo "==> [3/5] 使用钥匙串有效证书 ($SIGN_IDENTITY) 双层签名 StarIsland.app..."
fi

STAGED_APP="$DIST_DIR/StarIsland.app"
ditto "$BUILT_APP" "$STAGED_APP"
xattr -cr "$STAGED_APP" || true
codesign --force --deep --sign "$SIGN_IDENTITY" "$STAGED_APP"
codesign --force --sign "$SIGN_IDENTITY" \
  --identifier com.adgry.starisland.helper \
  --entitlements "$ROOT_DIR/com.shariq.sapphireHelper/sapphireHelper.entitlements" \
  "$STAGED_APP/Contents/MacOS/com.shariq.sapphireHelper"
codesign --force --sign "$SIGN_IDENTITY" --entitlements "$ROOT_DIR/scripts/SapphireAdHoc.entitlements" "$STAGED_APP"
codesign --verify --deep --strict --verbose=2 "$STAGED_APP"

ZIP_NAME="StarIsland-arm64.zip"
ZIP_PATH="$DIST_DIR/$ZIP_NAME"
(
  cd "$DIST_DIR"
  COPYFILE_DISABLE=1 /usr/bin/zip -qryy "$ZIP_NAME" "StarIsland.app"
  shasum -a 256 "$ZIP_NAME" > "${ZIP_NAME}.sha256"
)

echo "    安装包已生成: $ZIP_PATH ($(du -h "$ZIP_PATH" | awk '{print $1}'))"

if [[ "$BUILD_ONLY" == "--build-only" ]]; then
  echo "✅ 仅构建模式完成：$STAGED_APP"
  exit 0
fi

rm -rf "$STAGED_APP"

echo "==> [4/5] 提交版本变更并推送到 GitHub ($REPO)..."
if [[ -n "$(git status --porcelain)" ]]; then
  git add -A
  git commit -m "chore(release): 发布 ${TAG_NAME}"
fi
git push origin HEAD:main

echo "==> [5/5] 上传安装包至 GitHub Releases (${TAG_NAME})..."
if gh release view "$TAG_NAME" --repo "$REPO" >/dev/null 2>&1; then
  gh release upload "$TAG_NAME" "$ZIP_PATH" "${ZIP_PATH}.sha256" --clobber --repo "$REPO"
  gh release edit "$TAG_NAME" --title "星岛 StarIsland ${TAG_NAME}" --notes "$RELEASE_NOTES" --repo "$REPO"
else
  gh release create "$TAG_NAME" "$ZIP_PATH" "${ZIP_PATH}.sha256" \
    --repo "$REPO" \
    --target main \
    --title "星岛 StarIsland ${TAG_NAME}" \
    --notes "$RELEASE_NOTES"
fi
git fetch --tags origin --force >/dev/null 2>&1 || true

echo "✅ 发布完成：https://github.com/${REPO}/releases/tag/${TAG_NAME}"
