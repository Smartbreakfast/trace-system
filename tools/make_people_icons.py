# -*- coding: utf-8 -*-
"""Đưa ảnh nhóm thực hiện trong icon/ về đúng cỡ hiển thị.

Ảnh gốc là ảnh chân dung đã cắt tròn trên nền trắng, mỗi tấm 120-160KB cho một
khung 44px là quá nặng. Cắt sát vòng tròn rồi thu về 96px, nền trong suốt.

    python tools/make_people_icons.py
"""
import glob
import os
import unicodedata

from PIL import Image, ImageDraw

SRC = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'icon'
)
DST = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    'assets',
    'people',
)
SIZE = 96


def fold(text):
    """Bỏ dấu tiếng Việt để đặt tên file."""
    text = text.replace('Đ', 'D').replace('đ', 'd')
    stripped = unicodedata.normalize('NFD', text)
    return ''.join(c for c in stripped if unicodedata.category(c) != 'Mn')


def slug(name):
    return '-'.join(fold(name).lower().split())


def trim_white(img):
    """Cắt sát phần không phải nền trắng."""
    grey = img.convert('L')
    mask = grey.point(lambda v: 255 if v < 245 else 0)
    box = mask.getbbox()
    return img.crop(box) if box else img


def build():
    os.makedirs(DST, exist_ok=True)
    rows = []
    for path in sorted(glob.glob(os.path.join(SRC, '*.jpg'))):
        base = os.path.splitext(os.path.basename(path))[0]
        if ',' not in base:
            continue
        name, klass = [part.strip() for part in base.split(',', 1)]

        img = trim_white(Image.open(path).convert('RGB'))
        side = min(img.size)
        left = (img.width - side) // 2
        top = (img.height - side) // 2
        img = img.crop((left, top, left + side, top + side)).resize(
            (SIZE, SIZE), Image.LANCZOS
        )

        # Cắt tròn để khung tròn trong giao diện không lộ góc nền trắng.
        mask = Image.new('L', (SIZE, SIZE), 0)
        ImageDraw.Draw(mask).ellipse((0, 0, SIZE - 1, SIZE - 1), fill=255)
        out = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
        out.paste(img, (0, 0), mask)
        # Giảm bảng màu: khung hiển thị chỉ 44px nên mắt không thấy khác,
        # mà mỗi tấm nhẹ đi hai phần ba. Năm tấm nằm trong gói ứng dụng, ai
        # quét mã QR cũng phải tải, nên từng KB đều tính.
        alpha = out.getchannel('A')
        out = out.convert('RGB').quantize(colors=96, method=Image.FASTOCTREE)
        out = out.convert('RGBA')
        out.putalpha(alpha)

        target = os.path.join(DST, slug(name) + '.png')
        out.save(target, optimize=True)
        rows.append((name, klass, os.path.basename(target),
                     os.path.getsize(target)))

    for name, klass, file_name, size in rows:
        print('%-22s %-20s %-26s %5.1f KB'
              % (name, klass, file_name, size / 1024))
    print('\nDan vao lib/data/people.dart:')
    for name, klass, file_name, _ in rows:
        print("  '%s': (asset: 'assets/people/%s', role: '%s'),"
              % (name, file_name, klass))


if __name__ == '__main__':
    build()
