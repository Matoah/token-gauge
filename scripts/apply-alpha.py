#!/usr/bin/env python3
"""为 qlmanage 渲染出的图标 PNG 恢复透明背景。

qlmanage 渲染 SVG 时会垫不透明白底，圆角矩形四角外变成白色。
按 icon.svg 的几何（rect x=100 y=100 w=824 h=824 rx=185）生成
圆角矩形 Alpha 蒙版，把矩形以外的像素抠为透明。

用法: apply-alpha.py <1024px源图>
"""
import sys

from PIL import Image, ImageDraw

SRC = sys.argv[1]
# 圆角矩形几何（对应 icon.svg），内缩 2px 避免阴影边缘留下灰色絮边
INSET = 2
X0, Y0, X1, Y1 = 100 + INSET, 100 + INSET, 924 - INSET, 924 - INSET
RADIUS = 185

img = Image.open(SRC).convert("RGBA")
scale = img.width / 1024  # 兼容非 1024 渲染尺寸
box = [v * scale for v in (X0, Y0, X1, Y1)]

mask = Image.new("L", img.size, 0)
ImageDraw.Draw(mask).rounded_rectangle(box, radius=RADIUS * scale, fill=255)
img.putalpha(mask)
img.save(SRC)
print(f"透明背景已应用: {SRC}")
