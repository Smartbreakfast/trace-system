# -*- coding: utf-8 -*-
"""Sinh toàn bộ icon của app và của web từ một ảnh logo gốc.

    python tools/make_app_icons.py [đường/dẫn/logo.png]

Mặc định đọc tai-lieu/anh/logo-nguon.png. Chạy lại được bất cứ lúc nào: có ảnh
gốc nét hơn thì thay file đó rồi chạy, khỏi phải nhớ từng khổ.

Ba nhóm khổ, ba tỉ lệ khác nhau, vì mỗi nơi cắt ảnh một kiểu:

  - Icon thường (iOS, Android cũ, PWA, favicon): logo chiếm 82% cạnh. Nền trắng
    đặc, không kênh alpha cho iOS vì App Store từ chối icon có alpha.
  - Icon maskable của PWA và lớp foreground của icon thích ứng Android: hệ điều
    hành bo tròn hoặc cắt theo hình của máy, vùng an toàn chỉ còn khoảng hai
    phần ba, nên logo phải nhỏ lại còn 64%.
  - logo-mark.png dùng trong thanh điều hướng: giữ nền trong suốt, không viền.
"""
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, 'tai-lieu', 'anh', 'logo-nguon.png')

WHITE = (255, 255, 255)

# Khổ icon iOS: tên file theo Contents.json của AppIcon.appiconset.
IOS = [
    ('Icon-App-20x20@1x.png', 20), ('Icon-App-20x20@2x.png', 40),
    ('Icon-App-20x20@3x.png', 60), ('Icon-App-29x29@1x.png', 29),
    ('Icon-App-29x29@2x.png', 58), ('Icon-App-29x29@3x.png', 87),
    ('Icon-App-40x40@1x.png', 40), ('Icon-App-40x40@2x.png', 80),
    ('Icon-App-40x40@3x.png', 120), ('Icon-App-60x60@2x.png', 120),
    ('Icon-App-60x60@3x.png', 180), ('Icon-App-76x76@1x.png', 76),
    ('Icon-App-76x76@2x.png', 152), ('Icon-App-83.5x83.5@2x.png', 167),
    ('Icon-App-1024x1024@1x.png', 1024),
]

# Android: ic_launcher là icon vuông cho máy cũ, ic_launcher_foreground là lớp
# hình của icon thích ứng (khung 108dp, vùng an toàn 72dp).
ANDROID = [
    ('mdpi', 48, 108), ('hdpi', 72, 162), ('xhdpi', 96, 216),
    ('xxhdpi', 144, 324), ('xxxhdpi', 192, 432),
]


def logo(path):
    """Ảnh gốc đã cắt sát mép và bỏ nền trắng quanh viền."""
    image = Image.open(path).convert('RGBA')
    # Nền của file gốc là trắng đặc chứ không trong suốt, nên getbbox() trả về
    # nguyên khung. Tự dò mép bằng cách coi mọi điểm gần trắng là nền.
    mask = Image.new('L', image.size, 0)
    pixels = image.load()
    draw = mask.load()
    for y in range(image.size[1]):
        for x in range(image.size[0]):
            r, g, b, a = pixels[x, y]
            if a > 8 and not (r > 246 and g > 246 and b > 246):
                draw[x, y] = 255
    box = mask.getbbox() or (0, 0, *image.size)
    cut = image.crop(box)
    # Ô vuông: cạnh dài nhất quyết định, phần thiếu để trong suốt.
    side = max(cut.size)
    square = Image.new('RGBA', (side, side), (255, 255, 255, 0))
    square.paste(cut, ((side - cut.size[0]) // 2, (side - cut.size[1]) // 2))
    return square


def render(mark, size, fill, background):
    """Một icon vuông: logo đặt giữa, chiếm `fill` phần cạnh."""
    inner = max(1, int(round(size * fill)))
    scaled = mark.resize((inner, inner), Image.LANCZOS)
    if background is None:
        canvas = Image.new('RGBA', (size, size), (255, 255, 255, 0))
    else:
        canvas = Image.new('RGBA', (size, size), background + (255,))
    offset = (size - inner) // 2
    canvas.alpha_composite(scaled, (offset, offset))
    return canvas


def save(image, path, keep_alpha=True):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    out = image if keep_alpha else image.convert('RGB')
    out.save(path)
    print('   ', os.path.relpath(path, ROOT).replace('\\', '/'), out.size)


def main():
    source = sys.argv[1] if len(sys.argv) > 1 else SOURCE
    mark = logo(source)
    print('ảnh gốc', os.path.basename(source), '→ logo', mark.size)

    print('\nthương hiệu')
    save(render(mark, 512, 1.0, None),
         os.path.join(ROOT, 'assets', 'brand', 'logo-mark.png'))
    save(render(mark, 1024, 0.82, WHITE),
         os.path.join(ROOT, 'assets', 'brand', 'app-icon-1024.png'),
         keep_alpha=False)

    print('\nweb')
    web = os.path.join(ROOT, 'web')
    for size in (192, 512):
        save(render(mark, size, 0.82, WHITE),
             os.path.join(web, 'icons', 'Icon-%d.png' % size))
        save(render(mark, size, 0.64, WHITE),
             os.path.join(web, 'icons', 'Icon-maskable-%d.png' % size))
    save(render(mark, 64, 0.9, WHITE), os.path.join(web, 'favicon.png'))

    print('\nandroid')
    res = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res')
    for bucket, square, adaptive in ANDROID:
        save(render(mark, square, 0.82, WHITE),
             os.path.join(res, 'mipmap-%s' % bucket, 'ic_launcher.png'),
             keep_alpha=False)
        save(render(mark, adaptive, 0.64, None),
             os.path.join(res, 'mipmap-%s' % bucket,
                          'ic_launcher_foreground.png'))

    print('\nios')
    appicon = os.path.join(ROOT, 'ios', 'Runner', 'Assets.xcassets',
                           'AppIcon.appiconset')
    for name, size in IOS:
        # Không kênh alpha: App Store từ chối icon trong suốt.
        save(render(mark, size, 0.82, WHITE),
             os.path.join(appicon, name), keep_alpha=False)


if __name__ == '__main__':
    main()
