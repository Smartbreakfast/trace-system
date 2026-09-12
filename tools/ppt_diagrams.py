# -*- coding: utf-8 -*-
"""Ba sơ đồ kỹ thuật cho bộ slide: thành phần hệ thống, mô hình dữ liệu, luồng công bố."""
from PIL import Image, ImageDraw, ImageFont
import os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, 'docs', 'ppt-ky-thuat')
os.makedirs(OUT, exist_ok=True)

FONTS = 'C:/Users/sontm/coded/com-tule/assets/fonts/'
INK = (23, 53, 41)
INK_SOFT = (44, 76, 62)
MUTED = (92, 107, 97)
ORANGE = (226, 112, 58)
ORANGE_INK = (168, 75, 27)
TEAL = (0, 126, 136)
WHITE = (255, 255, 255)
CREAM = (246, 246, 241)
LINE = (213, 218, 204)
GREEN_SOFT = (239, 247, 236)
GREEN_EDGE = (203, 227, 192)

R = lambda s: ImageFont.truetype(FONTS + 'BeVietnamPro-Regular.ttf', s)
B = lambda s: ImageFont.truetype(FONTS + 'BeVietnamPro-Bold.ttf', s)
S = lambda s: ImageFont.truetype(FONTS + 'BeVietnamPro-SemiBold.ttf', s)


def rr(d, box, r, fill, outline=LINE, w=2):
    d.rounded_rectangle(box, radius=r, fill=fill, outline=outline, width=w)


def arrow(d, x1, y1, x2, y2, colour=MUTED, w=3, head=14):
    d.line([(x1, y1), (x2, y2)], fill=colour, width=w)
    import math
    ang = math.atan2(y2 - y1, x2 - x1)
    for sign in (-1, 1):
        d.line([(x2, y2),
                (x2 - head * math.cos(ang + sign * 0.45),
                 y2 - head * math.sin(ang + sign * 0.45))], fill=colour, width=w)


def label(d, x, y, text, f, colour=INK, anchor=None):
    d.text((x, y), text, font=f, fill=colour, anchor=anchor)


# --------------------------------------------------------- 1. thành phần
def so_do_thanh_phan():
    W, H = 2200, 1100
    img = Image.new('RGB', (W, H), WHITE)
    d = ImageDraw.Draw(img)

    # hai nhóm người dùng
    rr(d, (50, 250, 380, 420), 18, CREAM)
    label(d, 80, 282, 'Người mua', B(36))
    label(d, 80, 336, 'quét QR trên bao bì', R(24), MUTED)

    rr(d, (50, 700, 380, 870), 18, CREAM)
    label(d, 80, 732, 'Người vận hành', B(36))
    label(d, 80, 786, 'nhập liệu, công bố lô', R(24), MUTED)

    # biên Cloudflare
    d.rounded_rectangle((450, 90, 1600, 1010), radius=26, outline=(205, 212, 200), width=3)
    label(d, 478, 118, 'CLOUDFLARE', S(24), MUTED)

    # Pages
    rr(d, (490, 180, 1100, 350), 18, WHITE, TEAL, 3)
    label(d, 520, 206, 'Pages  ·  trace.smartbreakfast.store', B(29), TEAL)
    label(d, 520, 256, '/ và /t/*  ->  Worker', R(24), INK_SOFT)
    label(d, 520, 296, '/admin     ->  bản build Flutter', R(24), INK_SOFT)

    # Worker
    rr(d, (490, 400, 1100, 690), 18, WHITE, INK, 3)
    label(d, 520, 428, 'Worker (Hono)', B(32), INK)
    for i, t in enumerate([
        'Dựng HTML trang tra cứu (src/page)',
        'API công khai + API quản trị',
        'Chuẩn hoá JSON, băm SHA-256',
        'Hàng chờ neo chuỗi, cron 10 phút',
    ]):
        label(d, 520, 486 + i * 46, '•  ' + t, R(24), INK_SOFT)

    # D1 + R2
    rr(d, (490, 740, 780, 950), 16, GREEN_SOFT, GREEN_EDGE, 3)
    label(d, 520, 766, 'D1', B(32), INK)
    for i, t in enumerate(['6 bảng: lô, nguyên liệu,', 'công đoạn, ảnh,', 'bản công bố, hàng chờ']):
        label(d, 520, 818 + i * 36, t, R(22), MUTED)

    rr(d, (810, 740, 1100, 950), 16, GREEN_SOFT, GREEN_EDGE, 3)
    label(d, 840, 766, 'R2', B(32), INK)
    for i, t in enumerate(['ảnh, video, hồ sơ', 'khoá lưu trữ là mã băm', 'của chính nội dung']):
        label(d, 840, 818 + i * 36, t, R(22), MUTED)

    # Flutter admin
    rr(d, (1150, 400, 1560, 690), 18, WHITE, ORANGE, 3)
    label(d, 1180, 428, 'Màn quản trị', B(30), ORANGE_INK)
    label(d, 1180, 478, 'Flutter Web', S(25), MUTED)
    for i, t in enumerate(['Tạo lô, nhập nguyên liệu', 'Khai công đoạn, tải ảnh',
                           'Công bố, tải mã QR']):
        label(d, 1180, 528 + i * 44, '•  ' + t, R(23), INK_SOFT)

    # Besu
    rr(d, (1700, 400, 2150, 690), 18, WHITE, INK, 3)
    label(d, 1730, 428, 'VBSN Besu', B(32), INK)
    label(d, 1730, 478, 'chainId 84001', S(25), MUTED)
    label(d, 1730, 528, 'Hợp đồng TuleTrace', R(24), INK_SOFT)
    label(d, 1730, 568, '0xcd6811f9…d3ca', R(23), MUTED)
    label(d, 1730, 618, 'Nhận mã băm + mốc thời gian', R(23), MUTED)

    # landing
    rr(d, (1700, 180, 2150, 350), 18, CREAM, LINE, 2)
    label(d, 1730, 208, 'Landing page', B(30), INK)
    label(d, 1730, 258, 'smartbreakfast.store', R(24), MUTED)
    label(d, 1730, 298, 'Worker + static assets', R(23), MUTED)

    # mũi tên
    arrow(d, 385, 300, 485, 262)                      # người mua -> Pages
    arrow(d, 385, 780, 1145, 620, ORANGE)             # người vận hành -> admin
    arrow(d, 795, 355, 795, 395, TEAL)                # Pages -> Worker
    arrow(d, 620, 695, 620, 735)                      # Worker -> D1
    arrow(d, 900, 695, 900, 735)                      # Worker -> R2
    arrow(d, 1145, 470, 1105, 470, ORANGE)            # admin -> Worker (API)
    label(d, 1108, 425, 'API', R(21), MUTED)
    arrow(d, 1565, 545, 1695, 545, INK)               # Worker/admin -> Besu
    label(d, 1580, 500, 'mã băm', R(21), MUTED)
    arrow(d, 1105, 265, 1695, 265, MUTED)             # trace <-> landing
    arrow(d, 1695, 300, 1105, 300, MUTED)
    label(d, 1290, 210, 'liên kết hai chiều', R(21), MUTED)

    img.save(os.path.join(OUT, 'dg-thanh-phan.png'))
    print('dg-thanh-phan.png')


# ------------------------------------------------------------ 2. dữ liệu
def so_do_du_lieu():
    W, H = 2200, 1150
    img = Image.new('RGB', (W, H), WHITE)
    d = ImageDraw.Draw(img)

    def table(x, y, w, title, rows, tint=WHITE, edge=LINE):
        h = 78 + len(rows) * 40
        rr(d, (x, y, x + w, y + h), 14, tint, edge, 3)
        d.rounded_rectangle((x, y, x + w, y + 60), radius=14, fill=INK)
        d.rectangle((x, y + 40, x + w, y + 60), fill=INK)
        label(d, x + 22, y + 14, title, B(28), WHITE)
        for i, r in enumerate(rows):
            label(d, x + 22, y + 74 + i * 40, r, R(23), INK_SOFT)
        return (x, y, x + w, y + h)

    t1 = table(60, 90, 520, 'product_batches',
               ['code (duy nhất)', 'name, production_date', 'expiry_date, facility_name',
                'status: DRAFT / PUBLISHED'])
    t2 = table(60, 480, 520, 'ingredient_batches',
               ['product_batch_id →', 'name, origin, supplier', 'harvest_date, received_date',
                'latitude, longitude'])
    t3 = table(60, 870, 520, 'process_events',
               ['ingredient_batch_id →', 'title, event_date, operator',
                'input_quantity, output_quantity', 'params (JSON)'])
    t4 = table(700, 90, 520, 'media_assets',
               ['owner_type, owner_id →', 'role: cover / gallery /', '   area_map / certificate',
                'r2_key = sha256 nội dung'])
    t5 = table(700, 520, 520, 'published_snapshots',
               ['product_batch_id →', 'version (tăng dần)', 'payload (JSON đầy đủ)',
                'sha256, published_at'], GREEN_SOFT, GREEN_EDGE)
    t6 = table(700, 900, 520, 'blockchain_outbox',
               ['snapshot_id →', 'status, attempts', 'tx_hash, block_number'],
               GREEN_SOFT, GREEN_EDGE)

    for a, b in [(t1, t2), (t2, t3)]:
        arrow(d, 320, a[3], 320, b[1], MUTED, 3)
    arrow(d, 585, 200, 695, 200, MUTED)
    arrow(d, 585, 560, 695, 600, MUTED)
    arrow(d, 960, t5[3], 960, t6[1], MUTED)

    x = 1300
    rr(d, (x, 90, 2140, 1060), 18, CREAM, LINE, 2)
    label(d, x + 40, 130, 'Ba quy tắc của mô hình này', B(34), INK)
    notes = [
        ('Bản công bố là bất biến',
         'published_snapshots giữ cả payload đầy đủ, không chỉ mã băm. Công bố lại sinh '
         'version mới, không ghi đè bản cũ.'),
        ('Tệp định danh theo nội dung',
         'Khoá R2 là sha256 của chính tệp. Tải lại đúng tệp thì dùng chung một object; '
         'tráo ảnh sau khi công bố là mã băm lệch ngay.'),
        ('Trường rỗng không vào payload',
         'Thêm một khoá rỗng là đổi mã băm của mọi lô đã công bố. Nên chỉ ghi khoá khi '
         'thật sự có dữ liệu.'),
    ]
    y = 200
    for title, body in notes:
        label(d, x + 40, y, title, S(28), ORANGE_INK)
        y += 48
        words = body.split()
        line = ''
        for word in words:
            test = (line + ' ' + word).strip()
            if d.textlength(test, font=R(24)) > 760:
                label(d, x + 40, y, line, R(24), INK_SOFT)
                y += 36
                line = word
            else:
                line = test
        label(d, x + 40, y, line, R(24), INK_SOFT)
        y += 70

    img.save(os.path.join(OUT, 'dg-du-lieu.png'))
    print('dg-du-lieu.png')


# ------------------------------------------------------------- 3. luồng
def so_do_luong():
    W, H = 2200, 820
    img = Image.new('RGB', (W, H), WHITE)
    d = ImageDraw.Draw(img)

    steps = [
        ('1', 'Người vận hành', 'bấm "Hoàn thành lô"', WHITE, LINE),
        ('2', 'Gom hồ sơ', 'đọc D1 + R2, dựng JSON chuẩn hoá', WHITE, LINE),
        ('3', 'Băm SHA-256', 'ra 64 ký tự hex', WHITE, LINE),
        ('4', 'Lưu phiên bản', 'published_snapshots, version + 1', GREEN_SOFT, GREEN_EDGE),
        ('5', 'Hàng chờ', 'blockchain_outbox: PENDING', GREEN_SOFT, GREEN_EDGE),
        ('6', 'Gửi giao dịch', 'viem ký bằng ví thương hiệu', WHITE, LINE),
        ('7', 'Xác nhận', 'lưu tx_hash, block_number', WHITE, LINE),
    ]
    w, gap = 268, 24
    x = 60
    for num, title, body, tint, edge in steps:
        rr(d, (x, 220, x + w, 470), 16, tint, edge, 3)
        label(d, x + 24, 248, num, B(26), ORANGE)
        label(d, x + 24, 292, title, B(28), INK)
        # xuống dòng thủ công
        words = body.split()
        line, y = '', 344
        for word in words:
            test = (line + ' ' + word).strip()
            if d.textlength(test, font=R(22)) > w - 48:
                label(d, x + 24, y, line, R(22), MUTED)
                y += 32
                line = word
            else:
                line = test
        label(d, x + 24, y, line, R(22), MUTED)
        if x + w + gap < 60 + (w + gap) * 7:
            arrow(d, x + w + 4, 345, x + w + gap - 4, 345, MUTED, 3, 11)
        x += w + gap

    label(d, 60, 110, 'Luồng công bố một lô', B(44), INK)
    label(d, 60, 172, 'Người vận hành chỉ thấy bước 1. Sáu bước còn lại chạy trong Worker, '
                      'bước 6-7 chạy nền nên không ai phải đứng chờ.', R(26), MUTED)

    rr(d, (60, 540, 2140, 720), 16, CREAM, LINE, 2)
    label(d, 100, 570, 'Khi người mua quét QR', S(28), ORANGE_INK)
    label(d, 100, 620, 'Worker dựng lại JSON từ bản đã công bố → băm lại → so với mã băm đã neo trên chuỗi.',
          R(25), INK_SOFT)
    label(d, 100, 662, 'Khớp: ĐÃ XÁC MINH. Lệch: DỮ LIỆU SAI LỆCH — không có đường nào giấu đi.',
          R(25), INK_SOFT)

    img.save(os.path.join(OUT, 'dg-luong.png'))
    print('dg-luong.png')


so_do_thanh_phan()
so_do_du_lieu()
so_do_luong()
