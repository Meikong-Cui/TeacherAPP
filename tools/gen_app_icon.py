#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""从一张品牌原图生成 App 图标全套资源（Android + iOS）。

用法：
    python tools/gen_app_icon.py [源图路径]

默认源图为设计稿原图（桌面）。输出：
  · android/app/src/main/res/mipmap-{m,h,xh,xxh,xxxh}dpi/ic_launcher.png      传统图标
  · android/app/src/main/res/mipmap-*/ic_launcher_foreground.png              自适应前景
  · android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml               自适应图标描述
  · ios/Runner/Assets.xcassets/AppIcon.appiconset/                           iOS 全套 + Contents.json
  · assets/images/app_icon_1024.png                                          母版归档（未打进包）

依赖：Pillow、numpy

注意（实测踩过的坑，改脚本前先读）：
  1. 龙的脸/肚皮是**暖白** (252,243,238)，不是纯白。任何"接近白就变纯白"的全图处理，
     都会因为它们单通道卡在阈值边缘而产生斑驳块 ⇒ 只允许局部白化。
  2. 原图底部两处作者签名与龙身轮廓线是**同一个深色连通块**（cv2.connectedComponents
     只分出 1 个 7416px 的块），像素级无法分离；逐行分段、形态学开运算、inpaint
     都会顺带吃掉轮廓线，比保留签名更难看。故本脚本**不处理签名**——
     图标以 48–192px 显示时签名仅 1–3px，肉眼不可辨。要彻底去除请先在原图上编辑。
  3. iOS 图标不能带 alpha 通道，脚本统一输出 RGB。
  4. CROP_BOX 按源图 1289x1191 标定（主体 x[176,990] y[107,1190]）；换图需重算。
"""
import json
import os
import sys

from PIL import Image

DEFAULT_SRC = os.path.expanduser("~/Desktop/627591717b08a5e701871b6d0c680ea5.jpg")
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ANDROID_RES = os.path.join(ROOT, "android/app/src/main/res")
IOS_ASSETS = os.path.join(ROOT, "ios/Runner/Assets.xcassets")
ASSET_OUT = os.path.join(ROOT, "assets/images")

CROP_BOX = (18, 60, 1148, 1191)
BG = (255, 255, 255)

# 普通图标内容占画布比例；自适应前景按 108dp 画布计，落在 72dp 安全区内
CONTENT_RATIO = 0.86
ADAPTIVE_CONTENT_RATIO = 0.68

IOS_ICONS = {
    "Icon-App-20x20@1x.png": 20,
    "Icon-App-20x20@2x.png": 40,
    "Icon-App-20x20@3x.png": 60,
    "Icon-App-29x29@1x.png": 29,
    "Icon-App-29x29@2x.png": 58,
    "Icon-App-29x29@3x.png": 87,
    "Icon-App-40x40@1x.png": 40,
    "Icon-App-40x40@2x.png": 80,
    "Icon-App-40x40@3x.png": 120,
    "Icon-App-60x60@2x.png": 120,
    "Icon-App-60x60@3x.png": 180,
    "Icon-App-76x76@1x.png": 76,
    "Icon-App-76x76@2x.png": 152,
    "Icon-App-83.5x83.5@2x.png": 167,
    "Icon-App-1024x1024@1x.png": 1024,
}

ANDROID_DENSITIES = {"mdpi": 1.0, "hdpi": 1.5, "xhdpi": 2.0, "xxhdpi": 3.0, "xxxhdpi": 4.0}

IOS_CONTENTS = {
    "images": [
        {"filename": "Icon-App-20x20@1x.png", "idiom": "ipad", "scale": "1x", "size": "20x20"},
        {"filename": "Icon-App-20x20@2x.png", "idiom": "ipad", "scale": "2x", "size": "20x20"},
        {"filename": "Icon-App-20x20@2x.png", "idiom": "iphone", "scale": "2x", "size": "20x20"},
        {"filename": "Icon-App-20x20@3x.png", "idiom": "iphone", "scale": "3x", "size": "20x20"},
        {"filename": "Icon-App-29x29@1x.png", "idiom": "ipad", "scale": "1x", "size": "29x29"},
        {"filename": "Icon-App-29x29@2x.png", "idiom": "ipad", "scale": "2x", "size": "29x29"},
        {"filename": "Icon-App-29x29@2x.png", "idiom": "iphone", "scale": "2x", "size": "29x29"},
        {"filename": "Icon-App-29x29@3x.png", "idiom": "iphone", "scale": "3x", "size": "29x29"},
        {"filename": "Icon-App-40x40@1x.png", "idiom": "ipad", "scale": "1x", "size": "40x40"},
        {"filename": "Icon-App-40x40@2x.png", "idiom": "ipad", "scale": "2x", "size": "40x40"},
        {"filename": "Icon-App-40x40@2x.png", "idiom": "iphone", "scale": "2x", "size": "40x40"},
        {"filename": "Icon-App-40x40@3x.png", "idiom": "iphone", "scale": "3x", "size": "40x40"},
        {"filename": "Icon-App-60x60@2x.png", "idiom": "iphone", "scale": "2x", "size": "60x60"},
        {"filename": "Icon-App-60x60@3x.png", "idiom": "iphone", "scale": "3x", "size": "60x60"},
        {"filename": "Icon-App-76x76@1x.png", "idiom": "ipad", "scale": "1x", "size": "76x76"},
        {"filename": "Icon-App-76x76@2x.png", "idiom": "ipad", "scale": "2x", "size": "76x76"},
        {"filename": "Icon-App-83.5x83.5@2x.png", "idiom": "ipad", "scale": "2x", "size": "83.5x83.5"},
        {"filename": "Icon-App-1024x1024@1x.png", "idiom": "ios-marketing", "scale": "1x", "size": "1024x1024"},
    ],
    "info": {"author": "xcode", "version": 1},
}

ADAPTIVE_XML = """<?xml version="1.0" encoding="utf-8"?>
<!-- 自适应图标（Android 8.0 / API 26+）：前景为哈哈龙形象，背景纯白。
     前景图按 108dp 画布 68% 内容比例输出，落在 72dp 安全区内，圆形/圆角遮罩都不会裁到。 -->
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@android:color/white" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
"""


def square_icon(img, size, content_ratio):
    """等比缩放后居中贴到纯白正方形画布（四周留白，避免被系统圆角/圆形遮罩裁到）。"""
    target = max(1, int(round(size * content_ratio)))
    w, h = img.size
    scale = target / max(w, h)
    new_size = (max(1, int(round(w * scale))), max(1, int(round(h * scale))))
    resized = img.resize(new_size, Image.LANCZOS)
    canvas = Image.new("RGB", (size, size), BG)
    canvas.paste(resized, ((size - new_size[0]) // 2, (size - new_size[1]) // 2))
    return canvas


def main():
    src_path = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_SRC
    if not os.path.exists(src_path):
        raise SystemExit(f"源图不存在: {src_path}")

    base = Image.open(src_path).convert("RGB").crop(CROP_BOX)
    print("裁剪后尺寸:", base.size)

    os.makedirs(ASSET_OUT, exist_ok=True)
    square_icon(base, 1024, CONTENT_RATIO).save(
        os.path.join(ASSET_OUT, "app_icon_1024.png"), "PNG", optimize=True
    )
    print("母版 ->", os.path.join(ASSET_OUT, "app_icon_1024.png"))

    for density, factor in ANDROID_DENSITIES.items():
        d = os.path.join(ANDROID_RES, f"mipmap-{density}")
        os.makedirs(d, exist_ok=True)
        px = int(round(48 * factor))
        square_icon(base, px, CONTENT_RATIO).save(
            os.path.join(d, "ic_launcher.png"), "PNG", optimize=True
        )
        fg_px = int(round(108 * factor))
        square_icon(base, fg_px, ADAPTIVE_CONTENT_RATIO).save(
            os.path.join(d, "ic_launcher_foreground.png"), "PNG", optimize=True
        )
        print(f"  Android {density}: ic_launcher {px}px, foreground {fg_px}px")

    anydpi = os.path.join(ANDROID_RES, "mipmap-anydpi-v26")
    os.makedirs(anydpi, exist_ok=True)
    with open(os.path.join(anydpi, "ic_launcher.xml"), "w", encoding="utf-8", newline="\n") as f:
        f.write(ADAPTIVE_XML)

    icon_dir = os.path.join(IOS_ASSETS, "AppIcon.appiconset")
    os.makedirs(icon_dir, exist_ok=True)
    with open(os.path.join(IOS_ASSETS, "Contents.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump({"info": {"author": "xcode", "version": 1}}, f, ensure_ascii=False, indent=2)
    with open(os.path.join(icon_dir, "Contents.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(IOS_CONTENTS, f, ensure_ascii=False, indent=2)
    for name, px in IOS_ICONS.items():
        square_icon(base, px, CONTENT_RATIO).save(
            os.path.join(icon_dir, name), "PNG", optimize=True
        )
    print(f"  iOS: {len(IOS_ICONS)} 张 + Contents.json")
    print("完成。")


if __name__ == "__main__":
    main()
