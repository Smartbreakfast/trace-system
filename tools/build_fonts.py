# -*- coding: utf-8 -*-
"""Dựng bộ font của trang truy xuất: cắt gọn còn Latin + tiếng Việt.

Font gốc của Google Fonts phủ cả bảng chữ cái mà trang này không bao giờ dùng
tới. Cắt xuống chỉ còn ký tự cần thiết thì mỗi file còn khoảng 30-45KB, đủ nhẹ
cho người quét QR bằng 3G ở vùng cao.

    pip install fonttools brotli
    python tools/build_fonts.py <thư mục chứa ttf gốc>
"""
import os
import sys

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

DST = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'assets', 'fonts')

# Latin cơ bản + dấu tiếng Việt + vài ký hiệu dùng trong giao diện.
UNICODES = (
    'U+0020-007E,U+00A0-00FF,U+0102-0103,U+0110-0111,U+0128-0129,'
    'U+0168-0169,U+01A0-01B0,U+1EA0-1EF9,U+20AB,U+2013-2014,U+2018-201D,'
    'U+2026,U+00B7,U+2022,U+00D7,U+2192,U+00B0'
)

# (file gốc, tên file ra, trọng lượng cần lấy nếu là font biến thiên)
JOBS = [
    ('BeVietnamPro-Regular.ttf', 'BeVietnamPro-Regular.ttf', None),
    ('BeVietnamPro-SemiBold.ttf', 'BeVietnamPro-SemiBold.ttf', None),
    ('BeVietnamPro-Bold.ttf', 'BeVietnamPro-Bold.ttf', None),
    ('Lora-var.ttf', 'Lora-SemiBold.ttf', 600),
]


def build(src_dir):
    os.makedirs(DST, exist_ok=True)
    for source, target, weight in JOBS:
        path = os.path.join(src_dir, source)
        if not os.path.exists(path):
            print('thiếu', source)
            continue

        font = TTFont(path)
        if weight is not None:
            font = instancer.instantiateVariableFont(font, {'wght': weight})

        options = subset.Options()
        options.layout_features = ['*']
        options.name_IDs = ['*']
        options.notdef_outline = True
        # CanvasKit tự lo hinting, giữ bảng hint trong file chỉ tốn dung lượng.
        options.hinting = False
        options.recalc_bounds = True
        subsetter = subset.Subsetter(options=options)
        subsetter.populate(unicodes=subset.parse_unicodes(UNICODES))
        subsetter.subset(font)

        out = os.path.join(DST, target)
        font.save(out)
        print('%-28s %6.1f KB -> %-28s %6.1f KB' % (
            source, os.path.getsize(path) / 1024,
            target, os.path.getsize(out) / 1024,
        ))


if __name__ == '__main__':
    build(sys.argv[1] if len(sys.argv) > 1 else '.')
