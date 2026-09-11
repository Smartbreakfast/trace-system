# -*- coding: utf-8 -*-
"""Hai hình minh hoạ cho slide: vân tay dữ liệu và tốc độ trước/sau."""
import hashlib
import io
import os

from PIL import Image, ImageDraw, ImageFont

FONTS = 'C:/Users/sontm/coded/com-tule/assets/fonts/'
INK = (23, 53, 41)
MUTED = (90, 101, 96)
ORANGE = (226, 112, 58)
ORANGE_INK = (168, 75, 27)
GREEN = (44, 107, 63)
CREAM = (247, 245, 237)
LINE = (222, 226, 216)
WHITE = (255, 255, 255)


def font(name, size):
    return ImageFont.truetype(FONTS + name, size)


REG = lambda s: font('BeVietnamPro-Regular.ttf', s)
BOLD = lambda s: font('BeVietnamPro-Bold.ttf', s)
SEMI = lambda s: font('BeVietnamPro-SemiBold.ttf', s)
MONO = lambda s: font('BeVietnamPro-SemiBold.ttf', s)


def rounded(draw, box, radius, fill, outline=None, width=2):
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


# ------------------------------------------------------------------ hình 1
def van_tay():
    W, H = 2000, 1100
    img = Image.new('RGB', (W, H), WHITE)
    d = ImageDraw.Draw(img)

    a = '{"code":"TL-2026-002","ngay":"07.09.2026","lac":"Lục Yên"}'
    b = '{"code":"TL-2026-002","ngay":"08.09.2026","lac":"Lục Yên"}'
    ha = hashlib.sha256(a.encode()).hexdigest()
    hb = hashlib.sha256(b.encode()).hexdigest()

    def block(top, title, json_text, hash_text, colour, diff_at):
        rounded(d, (60, top, W - 60, top + 420), 26, CREAM, LINE, 3)
        d.text((100, top + 34), title, font=BOLD(38), fill=colour)
        d.text((100, top + 108), 'Hồ sơ (rút gọn)', font=SEMI(26), fill=MUTED)
        # json, tô đỏ phần khác nhau
        x = 100
        y = top + 152
        f = MONO(30)
        for i, ch in enumerate(json_text):
            col = ORANGE if diff_at and diff_at[0] <= i < diff_at[1] else INK
            d.text((x, y), ch, font=f, fill=col)
            x += d.textlength(ch, font=f)
        d.text((100, top + 236), 'Vân tay SHA-256', font=SEMI(26), fill=MUTED)
        f2 = MONO(30)
        d.text((100, top + 280), hash_text[:64], font=f2, fill=colour)
        d.text((100, top + 330), hash_text[64:], font=f2, fill=colour)

    i1 = a.index('07.09')
    i2 = b.index('08.09')
    block(60, 'Hồ sơ gốc', a, ha, GREEN, (i1, i1 + 5))
    block(560, 'Sửa đúng MỘT chữ số: 07 thành 08', b, hb, ORANGE_INK, (i2, i2 + 5))

    d.text((60, 1010), 'Đổi một ký tự thì vân tay khác hoàn toàn — đó là cách máy biết hồ sơ có bị sửa hay không.',
           font=SEMI(32), fill=INK)
    img.save('ppt/fig-van-tay.png')
    print('fig-van-tay.png')


# ------------------------------------------------------------------ hình 2
def toc_do():
    W, H = 2000, 1000
    img = Image.new('RGB', (W, H), WHITE)
    d = ImageDraw.Draw(img)
    d.text((60, 50), 'Thời gian người quét QR nhìn thấy nội dung', font=BOLD(46), fill=INK)
    d.text((60, 120), 'Đo trên điện thoại phổ thông, mạng 4G yếu', font=REG(30), fill=MUTED)

    base_y = 300
    scale = 1700 / 18.3

    rows = [
        ('Bản cũ: giao diện Flutter', 18.3, '18,3 giây', (176, 96, 69)),
        ('Bản mới: HTML dựng sẵn', 1.0, '1,0 giây', GREEN),
    ]
    for i, (label, value, text, colour) in enumerate(rows):
        y = base_y + i * 220
        d.text((60, y - 54), label, font=SEMI(34), fill=INK)
        width = max(int(value * scale), 120)
        rounded(d, (60, y, 60 + width, y + 96), 20, colour)
        d.text((60 + width + 30, y + 24), text, font=BOLD(44), fill=colour)

    y = base_y + 470
    d.text((60, y), 'Dung lượng phải tải về trước khi thấy chữ đầu tiên',
           font=SEMI(34), fill=INK)
    rounded(d, (60, y + 60, 1000, y + 170), 22, CREAM, LINE, 3)
    d.text((100, y + 92), '3,2 MB', font=BOLD(52), fill=(176, 96, 69))
    d.text((330, y + 104), 'bản cũ', font=REG(32), fill=MUTED)
    rounded(d, (1040, y + 60, 1980, y + 170), 22, CREAM, LINE, 3)
    d.text((1080, y + 92), '202 KB', font=BOLD(52), fill=GREEN)
    d.text((1330, y + 104), 'bản mới — nhẹ hơn 16 lần', font=REG(32), fill=MUTED)
    img.save('ppt/fig-toc-do.png')
    print('fig-toc-do.png')


van_tay()
toc_do()
