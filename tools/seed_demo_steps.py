# -*- coding: utf-8 -*-
"""Điền dữ liệu demo cho các công đoạn của một lô.

Đặt người thực hiện, ngày thực hiện, khối lượng và tham số kỹ thuật theo đúng
tài liệu quy trình; công đoạn nào chưa có ảnh thì sinh một tấm minh hoạ.

    python tools/seed_demo_steps.py TL-2026-002 [--to https://...] [--dry]

Ảnh sinh ra là hình minh hoạ, không phải ảnh chụp thật, nên chú thích ghi rõ
điều đó. Một hệ thống truy xuất mà để ảnh dựng lẫn vào ảnh hiện trường thì tự
phá đúng thứ nó bán.
"""
import io
import json
import os
import sys
import unicodedata
import urllib.request

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONT_BOLD = os.path.join(ROOT, 'assets', 'fonts', 'BeVietnamPro-Bold.ttf')
FONT_REG = os.path.join(ROOT, 'assets', 'fonts', 'BeVietnamPro-Regular.ttf')
TOKEN_FILE = os.path.join(ROOT, 'worker', '.admin-token.txt')

INK = (23, 53, 42)

# Người thực hiện theo nhánh. Nhóm năm học sinh làm đề tài, mỗi bạn theo một
# vùng nguyên liệu, bạn còn lại phụ trách công đoạn tại xưởng.
CREW = {
    'com tu le': 'Trịnh Gia Nhi',
    'lac do luc yen': 'Phạm Hà Giang',
    'chuoi tieu xanh': 'Phạm Vũ Dũng',
    'khoai mon luc yen': 'Vũ Sơn Hải',
}
FACILITY_CREW = 'Nguyễn Tuấn Vũ'

# Màu nền ảnh minh hoạ theo nhánh.
TINT = {
    'com tu le': (127, 166, 83),
    'lac do luc yen': (180, 68, 58),
    'chuoi tieu xanh': (201, 162, 39),
    'khoai mon luc yen': (122, 91, 140),
}

# Mốc thời gian cho từng nhánh: ngày bắt đầu và bước nhảy giữa các công đoạn.
TIMELINE = {
    'com tu le': ['18.08.2026', '20.08.2026', '21.08.2026', '21.08.2026'],
    'lac do luc yen': [
        '19.08.2026', '20.08.2026', '20.08.2026', '21.08.2026',
        '21.08.2026', '22.08.2026', '22.08.2026', '23.08.2026',
    ],
    'chuoi tieu xanh': [
        '24.08.2026', '24.08.2026', '25.08.2026', '26.08.2026', '26.08.2026',
    ],
    'khoai mon luc yen': [
        '27.08.2026', '27.08.2026', '28.08.2026', '29.08.2026',
        '29.08.2026', '30.08.2026', '30.08.2026',
    ],
}
FACILITY_DATES = ['06.09.2026', '07.09.2026']

# Tham số kỹ thuật lấy từ thuyết minh quy trình, khoá là tên công đoạn đã bỏ
# dấu, giá trị áp cho nhánh nào ghi trong tuple đầu ('*' là mọi nhánh).
PARAMS = [
    ('rang', '*', {'Nhiệt độ': '100°C'}),
    ('ngam', '*', {'Thời gian': '2-3 giờ'}),
    ('thai', '*', {'Độ dày lát': '0,5-1 cm'}),
    ('thuy phan', '*', {
        'Nhiệt độ': '80-90°C',
        'Thời gian': '60 phút',
        'Enzyme': 'amylase',
    }),
    ('say phun', '*', {'Nhiệt độ đầu vào': '180°C'}),
]

# Khối lượng vào và ra, đặt ở công đoạn tạo ra bột của mỗi nhánh. Con số theo
# bảng định mức cho một mẻ 1.000g thành phẩm.
YIELD = {
    ('com tu le', 'xay'): (500, 135),
    ('lac do luc yen', 'say phun'): (1000, 205),
    ('chuoi tieu xanh', 'say phun'): (1000, 210),
    ('khoai mon luc yen', 'say phun'): (500, 320),
}

FACILITY_DETAIL = {
    'phoi tron': {
        'quantity': (1000, 1000),
        'params': {
            'Bột cốm': '135 g',
            'Bột lạc': '205 g',
            'Bột khoai môn': '320 g',
            'Bột chuối': '210 g',
            'Bột kem sữa': '130 g',
        },
    },
    'dong goi': {
        'quantity': (1000, 1000),
        'params': {'Quy cách': '30 g/gói', 'Đóng hộp': '20 gói/hộp'},
    },
}


def fold(text):
    text = (text or '').replace('Đ', 'd').replace('đ', 'd')
    stripped = unicodedata.normalize('NFD', text.lower())
    plain = ''.join(c for c in stripped if unicodedata.category(c) != 'Mn')
    return ' '.join(plain.split())


def request(base, path, token, method='GET', body=None, form=None):
    url = base + path
    # Cloudflare chặn User-Agent mặc định của urllib, phải khai một cái tên.
    headers = {
        'authorization': 'Bearer ' + token,
        'user-agent': 'tule-trace-seed/1.0',
    }
    data = None
    if form is not None:
        boundary = '----tule' + os.urandom(8).hex()
        chunks = []
        for key, value in form['fields'].items():
            chunks.append(
                ('--%s\r\nContent-Disposition: form-data; name="%s"\r\n\r\n%s\r\n'
                 % (boundary, key, value)).encode('utf-8')
            )
        chunks.append(
            ('--%s\r\nContent-Disposition: form-data; name="file"; '
             'filename="%s"\r\nContent-Type: image/jpeg\r\n\r\n'
             % (boundary, form['name'])).encode('utf-8')
        )
        chunks.append(form['bytes'])
        chunks.append(('\r\n--%s--\r\n' % boundary).encode('utf-8'))
        data = b''.join(chunks)
        headers['content-type'] = 'multipart/form-data; boundary=' + boundary
    elif body is not None:
        data = json.dumps(body).encode('utf-8')
        headers['content-type'] = 'application/json'

    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=60) as res:
        raw = res.read().decode('utf-8')
        return json.loads(raw) if raw else {}


def illustration(title, branch_key, subtitle):
    """Ảnh minh hoạ một công đoạn: nền màu nhánh, tên công đoạn, nhãn rõ ràng."""
    width, height = 1280, 854
    tint = TINT.get(branch_key, (60, 92, 76))
    img = Image.new('RGB', (width, height), (250, 250, 246))
    draw = ImageDraw.Draw(img)

    # Dải màu chéo rất nhạt cho ảnh có chiều sâu mà không giả làm ảnh chụp.
    for i in range(height):
        ratio = i / height
        colour = tuple(
            int(250 - (250 - c) * 0.10 - (250 - c) * 0.16 * ratio)
            for c in tint
        )
        draw.line([(0, i), (width, i)], fill=colour)
    draw.ellipse(
        (width - 420, -160, width + 200, 460),
        fill=tuple(int(c * 0.18 + 250 * 0.82) for c in tint),
    )
    draw.ellipse(
        (-220, height - 320, 340, height + 220),
        fill=tuple(int(c * 0.22 + 250 * 0.78) for c in tint),
    )

    title_font = ImageFont.truetype(FONT_BOLD, 74)
    sub_font = ImageFont.truetype(FONT_REG, 34)
    tag_font = ImageFont.truetype(FONT_BOLD, 24)

    # Nhãn nói thẳng đây là hình minh hoạ.
    draw.rounded_rectangle((72, 70, 356, 138), radius=15, fill=INK)
    draw.text((96, 86), 'ẢNH MINH HOẠ', font=tag_font, fill=(255, 255, 255))

    # Tên công đoạn, xuống dòng thủ công cho vừa bề ngang.
    words = title.split()
    lines, current = [], ''
    for word in words:
        probe = (current + ' ' + word).strip()
        if draw.textlength(probe, font=title_font) > width - 200 and current:
            lines.append(current)
            current = word
        else:
            current = probe
    if current:
        lines.append(current)

    y = height // 2 - len(lines) * 46
    for line in lines:
        draw.text((80, y), line, font=title_font, fill=INK)
        y += 92
    draw.text((84, y + 16), subtitle, font=sub_font, fill=(92, 107, 97))

    buffer = io.BytesIO()
    img.save(buffer, 'JPEG', quality=82, optimize=True)
    return buffer.getvalue()


def params_for(title_key, branch_key):
    for name, branch, values in PARAMS:
        if name == title_key and branch in ('*', branch_key):
            return values
    return None


def seed(code, base, dry):
    token = io.open(TOKEN_FILE, encoding='utf-8').read().strip()
    trace = request(base, '/api/admin/product-batches/%s/trace' % code, token)
    made = 0
    touched = 0

    groups = []
    for ing in trace['ingredients']:
        key = fold(ing['name'])
        groups.append((
            key,
            ing['name'],
            CREW.get(key, FACILITY_CREW),
            TIMELINE.get(key, []),
            ing['processEvents'],
        ))
    groups.append((
        'xuong', 'Tại xưởng', FACILITY_CREW, FACILITY_DATES,
        trace.get('batchEvents', []),
    ))

    for key, label, person, dates, events in groups:
        for index, event in enumerate(events):
            title_key = fold(event['title'])
            body = {
                'operator': person,
                'eventDate': dates[index] if index < len(dates)
                else (dates[-1] if dates else event.get('event_date')),
            }
            values = params_for(title_key, key)
            if key == 'xuong' and title_key in FACILITY_DETAIL:
                detail = FACILITY_DETAIL[title_key]
                body['inputQuantity'] = detail['quantity'][0]
                body['outputQuantity'] = detail['quantity'][1]
                body['quantityUnit'] = 'g'
                values = detail['params']
            elif (key, title_key) in YIELD:
                amount = YIELD[(key, title_key)]
                body['inputQuantity'] = amount[0]
                body['outputQuantity'] = amount[1]
                body['quantityUnit'] = 'g'
            if values:
                body['params'] = values

            print('  %-30s %-14s %s' % (event['title'][:30], body['eventDate'],
                                        person))
            touched += 1
            if not dry:
                request(base, '/api/admin/process-events/%s' % event['id'],
                        token, 'PATCH', body)

            if event['media']:
                continue
            picture = illustration(event['title'], key, label)
            print('     + ảnh minh hoạ %5.0f KB' % (len(picture) / 1024))
            made += 1
            if dry:
                continue
            request(base, '/api/admin/media', token, 'POST', form={
                'bytes': picture,
                'name': fold(event['title']).replace(' ', '-') + '.jpg',
                'fields': {
                    'ownerType': 'process_event',
                    'ownerId': str(event['id']),
                    'role': 'gallery',
                    'caption': 'Ảnh minh hoạ công đoạn %s' % event['title'],
                },
            })

    print('\n%d công đoạn được cập nhật, %d ảnh minh hoạ' % (touched, made))
    if dry:
        print('chạy thử, chưa đụng vào dữ liệu.')
        return
    published = request(base, '/api/admin/product-batches/%s/publish' % code,
                        token, 'POST')
    print('đã công bố phiên bản', published.get('version'))


if __name__ == '__main__':
    args = sys.argv[1:]
    batch = next((a for a in args if not a.startswith('--')), 'TL-2026-002')
    target = 'https://tule-trace.sontm.workers.dev'
    if '--to' in args:
        target = args[args.index('--to') + 1]
    seed(batch, target.rstrip('/'), '--dry' in args)
