# -*- coding: utf-8 -*-
"""Đưa ảnh trong icon/ về đúng cỡ hiển thị: vuông, 128px, nền trong suốt.

Ảnh gốc 300-900KB cho một hình vẽ ở 40px là quá nặng: trang truy xuất chủ yếu
mở bằng 3G ở vùng cao, tải 2,3MB icon là mất luôn mấy giây đầu.
"""
import io
import os
import glob
from PIL import Image

SRC = 'C:/Users/sontm/coded/com-tule/icon'
DST = 'C:/Users/sontm/coded/com-tule/assets/ingredients'
SIZE = 128

# Ảnh nào ứng với nguyên liệu nào. Khoá là tên file đã bỏ dấu cho dễ khớp.
NAMES = {
    'com tu le': 'com-tu-le',
    'lac do luc yen': 'lac-do-luc-yen',
    'chuoi tieu xanh': 'chuoi-tieu-xanh',
    'khoai mon luc yen': 'khoai-mon-luc-yen',
}

MARKS = {
    'à': 'a', 'á': 'a', 'ả': 'a', 'ã': 'a', 'ạ': 'a', 'ă': 'a', 'ằ': 'a',
    'ắ': 'a', 'ẳ': 'a', 'ẵ': 'a', 'ặ': 'a', 'â': 'a', 'ầ': 'a', 'ấ': 'a',
    'ẩ': 'a', 'ẫ': 'a', 'ậ': 'a', 'đ': 'd', 'è': 'e', 'é': 'e', 'ẻ': 'e',
    'ẽ': 'e', 'ẹ': 'e', 'ê': 'e', 'ề': 'e', 'ế': 'e', 'ể': 'e', 'ễ': 'e',
    'ệ': 'e', 'ì': 'i', 'í': 'i', 'ỉ': 'i', 'ĩ': 'i', 'ị': 'i', 'ò': 'o',
    'ó': 'o', 'ỏ': 'o', 'õ': 'o', 'ọ': 'o', 'ô': 'o', 'ồ': 'o', 'ố': 'o',
    'ổ': 'o', 'ỗ': 'o', 'ộ': 'o', 'ơ': 'o', 'ờ': 'o', 'ớ': 'o', 'ở': 'o',
    'ỡ': 'o', 'ợ': 'o', 'ù': 'u', 'ú': 'u', 'ủ': 'u', 'ũ': 'u', 'ụ': 'u',
    'ư': 'u', 'ừ': 'u', 'ứ': 'u', 'ử': 'u', 'ữ': 'u', 'ự': 'u', 'ỳ': 'y',
    'ý': 'y', 'ỷ': 'y', 'ỹ': 'y', 'ỵ': 'y',
}


def fold(text):
    return ''.join(MARKS.get(ch, ch) for ch in text.lower())


os.makedirs(DST, exist_ok=True)

for path in sorted(glob.glob(os.path.join(SRC, '*.png'))):
    stem = fold(os.path.splitext(os.path.basename(path))[0]).strip()
    slug = NAMES.get(stem)
    if not slug:
        print('bỏ qua (chưa biết ứng với nguyên liệu nào):', stem)
        continue

    im = Image.open(path).convert('RGBA')

    # Cắt sát nội dung rồi đặt vào khung vuông: ảnh gốc mỗi cái một tỷ lệ, để
    # nguyên thì hình trong avatar tròn cái to cái nhỏ.
    bbox = im.getbbox()
    if bbox:
        im = im.crop(bbox)
    side = max(im.width, im.height)
    canvas = Image.new('RGBA', (side, side), (0, 0, 0, 0))
    canvas.paste(im, ((side - im.width) // 2, (side - im.height) // 2))
    canvas = canvas.resize((SIZE, SIZE), Image.LANCZOS)

    out = os.path.join(DST, slug + '.png')
    canvas.save(out, 'PNG', optimize=True)

    # Còn nặng thì giảm bảng màu, vẫn giữ kênh trong suốt.
    if os.path.getsize(out) > 24 * 1024:
        canvas.quantize(colors=128, method=Image.FASTOCTREE).save(
            out, 'PNG', optimize=True
        )

    print('%-22s %5.1f KB -> %-22s %5.1f KB' % (
        os.path.basename(path).encode('ascii', 'replace').decode(),
        os.path.getsize(path) / 1024,
        slug + '.png',
        os.path.getsize(out) / 1024,
    ))
