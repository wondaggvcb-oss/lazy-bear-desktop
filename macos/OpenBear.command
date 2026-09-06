#!/bin/bash

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_PATH="$SCRIPT_DIR/LazyBear.app"

if [ ! -d "$APP_PATH" ]; then
  echo "找不到同文件夹里的 LazyBear.app。"
  echo "请把 OpenBear.command 和 LazyBear.app 放在一起。"
  read -r -p "按回车关闭..."
  exit 1
fi

xattr -cr "$APP_PATH" 2>/dev/null || true
open "$APP_PATH"
