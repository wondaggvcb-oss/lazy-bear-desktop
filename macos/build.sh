#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="熊"
BUNDLE_ID="${BUNDLE_ID:-com.example.lazy-bear-desktop}"
APP_DIR="$ROOT/dist/$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
ASSET_OUT="$RESOURCES/assets"

mkdir -p "$ROOT/assets" "$ROOT/Resources"

gif_sources=()
while IFS= read -r file; do
  gif_sources+=("$file")
done < <(find "$ROOT/assets" -maxdepth 1 -type f -iname "*.gif" -print | sort -f)

rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$ASSET_OUT" "$ROOT/.build/module-cache"

make_icon_from_gif() {
  local gif_path="$1"
  local iconset="$ROOT/.build/BearIcon.iconset"
  local source_png="$ROOT/.build/BearIcon-source.png"

  if ! command -v sips >/dev/null 2>&1 || ! command -v iconutil >/dev/null 2>&1; then
    echo "没有找到 macOS 图标工具，跳过自动图标生成。"
    return 1
  fi

  rm -rf "$iconset"
  mkdir -p "$iconset"

  if ! sips -s format png "$gif_path" --out "$source_png" >/dev/null 2>&1; then
    echo "无法从 GIF 生成图标，跳过自动图标生成。"
    return 1
  fi

  sips -z 16 16 "$source_png" --out "$iconset/icon_16x16.png" >/dev/null
  sips -z 32 32 "$source_png" --out "$iconset/icon_16x16@2x.png" >/dev/null
  sips -z 32 32 "$source_png" --out "$iconset/icon_32x32.png" >/dev/null
  sips -z 64 64 "$source_png" --out "$iconset/icon_32x32@2x.png" >/dev/null
  sips -z 128 128 "$source_png" --out "$iconset/icon_128x128.png" >/dev/null
  sips -z 256 256 "$source_png" --out "$iconset/icon_128x128@2x.png" >/dev/null
  sips -z 256 256 "$source_png" --out "$iconset/icon_256x256.png" >/dev/null
  sips -z 512 512 "$source_png" --out "$iconset/icon_256x256@2x.png" >/dev/null
  sips -z 512 512 "$source_png" --out "$iconset/icon_512x512.png" >/dev/null
  sips -z 1024 1024 "$source_png" --out "$iconset/icon_512x512@2x.png" >/dev/null

  iconutil -c icns "$iconset" -o "$RESOURCES/BearIcon.icns" >/dev/null
}

if [ "${#gif_sources[@]}" -gt 0 ]; then
  for src in "${gif_sources[@]}"; do
    cp "$src" "$ASSET_OUT/$(basename "$src")"
  done
  echo "已复制 ${#gif_sources[@]} 个 GIF 到 app 包。"
else
  echo "没有找到 GIF，app 将以占位模式启动。请把自己的 .gif 放进 assets/ 文件夹后重新构建。"
fi

icon_block=""
icon_source="${gif_sources[0]:-}"

if [ -f "$ROOT/Resources/BearIcon.icns" ]; then
  cp "$ROOT/Resources/BearIcon.icns" "$RESOURCES/BearIcon.icns"
  echo "已使用 Resources/BearIcon.icns 作为 app 图标。"
  icon_block='
  <key>CFBundleIconFile</key>
  <string>BearIcon</string>'
elif [ -n "$icon_source" ] && make_icon_from_gif "$icon_source"; then
  echo "已用 GIF 自动生成 app 图标。"
  icon_block='
  <key>CFBundleIconFile</key>
  <string>BearIcon</string>'
fi

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleExecutable</key>
  <string>LazyBear</string>$icon_block
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <false/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSScreenCaptureUsageDescription</key>
  <string>熊需要看屏幕才能主动和你互动，对屏幕内容做一针见血的可爱评论。</string>
</dict>
</plist>
PLIST

swiftc \
  -module-cache-path "$ROOT/.build/module-cache" \
  -framework Cocoa \
  -framework Vision \
  -framework ImageIO \
  -framework ScreenCaptureKit \
  "$ROOT/BearApp.swift" \
  -o "$MACOS/LazyBear"
ENTITLEMENTS="$ROOT/entitlements.plist"
if [ -f "$ENTITLEMENTS" ]; then
  codesign --force --deep --sign - --entitlements "$ENTITLEMENTS" "$APP_DIR" >/dev/null
  echo "已签名（含 entitlements）：$APP_DIR"
else
  codesign --force --deep --sign - "$APP_DIR" >/dev/null
  echo "已签名（无 entitlements）：$APP_DIR"
fi
