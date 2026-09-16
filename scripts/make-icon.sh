#!/bin/bash
# 将 icon.svg 转换为 macOS .icns 图标文件
# 用法: scripts/make-icon.sh [输出路径]  （默认 build/AppIcon.icns）
set -euo pipefail
cd "$(dirname "$0")/.."

OUT="${1:-build/AppIcon.icns}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# qlmanage 把 SVG 渲染为 1024px 位图（白底），再把圆角外恢复为透明
qlmanage -t -s 1024 -o "$TMP" icon.svg >/dev/null 2>&1
SRC="$TMP/icon.svg.png"
if [ ! -f "$SRC" ]; then
  echo "错误：qlmanage 无法渲染 icon.svg" >&2
  exit 1
fi
python3 scripts/apply-alpha.py "$SRC"

ICONSET="$TMP/AppIcon.iconset"
mkdir -p "$ICONSET" "$(dirname "$OUT")"

for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$SRC" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "$double" "$double" "$SRC" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done

iconutil -c icns "$ICONSET" -o "$OUT"
echo "图标已生成：$OUT"
