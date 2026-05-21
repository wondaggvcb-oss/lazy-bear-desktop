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

shopt -s nullglob
gif_sources=("$ROOT"/assets/*.gif "$ROOT"/assets/*.GIF)

if [ "${#gif_sources[@]}" -eq 0 ]; then
  echo "没有找到 GIF。请把自己的 .gif 放进 assets/ 文件夹后再运行。"
  exit 1
fi

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

states=(idle eat love car kiss lie wave)
for i in "${!states[@]}"; do
  state="${states[$i]}"
  named_lower="$ROOT/assets/jokebear_${state}.gif"
  named_upper="$ROOT/assets/jokebear_${state}.GIF"
  if [ -f "$named_lower" ]; then
    src="$named_lower"
  elif [ -f "$named_upper" ]; then
    src="$named_upper"
  elif [ "$i" -lt "${#gif_sources[@]}" ]; then
    src="${gif_sources[$i]}"
  else
    src="${gif_sources[0]}"
  fi
  cp "$src" "$ASSET_OUT/jokebear_${state}.gif"
done

icon_block=""
if [ -f "$ROOT/Resources/BearIcon.icns" ]; then
  cp "$ROOT/Resources/BearIcon.icns" "$RESOURCES/BearIcon.icns"
  echo "已使用 Resources/BearIcon.icns 作为 app 图标。"
  icon_block='
  <key>CFBundleIconFile</key>
  <string>BearIcon</string>'
elif make_icon_from_gif "$ASSET_OUT/jokebear_idle.gif"; then
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
</dict>
</plist>
PLIST

swiftc \
  -module-cache-path "$ROOT/.build/module-cache" \
  -framework Cocoa \
  -framework Vision \
  -framework ImageIO \
  "$ROOT/BearApp.swift" \
  -o "$MACOS/LazyBear"
codesign --force --deep --sign - "$APP_DIR" >/dev/null

echo "已生成：$APP_DIR"
