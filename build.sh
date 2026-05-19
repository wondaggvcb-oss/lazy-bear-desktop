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
