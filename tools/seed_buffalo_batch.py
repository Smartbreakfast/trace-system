# -*- coding: utf-8 -*-
"""Điền hồ sơ demo cho một lô thịt trâu gác bếp.

    python tools/seed_buffalo_batch.py TB-2026-001 [--to https://...] [--dry]

Dòng thịt trâu chưa có hồ sơ sản xuất thật nên đây là dữ liệu demo. Các con số
lấy theo mức mà nghề vẫn làm và báo chí ghi nhận: khoảng 3 kg thịt tươi cho 1 kg
thành phẩm (Tiền Phong và CafeF ghi 3-4 kg tuỳ độ khô), thái dọc thớ thành
miếng cỡ 5 x 20 cm, ướp 3-4 giờ, treo cách bếp than 60-70 cm và hong 9-12 giờ.
Khi cơ sở gửi sổ sản xuất thật thì sửa bảng YIELD và PARAMS bên dưới rồi chạy
lại, đừng sửa tay trong admin.

Ảnh cũng là ảnh demo và chú thích nói thẳng điều đó: ảnh sản phẩm và ảnh công
đoạn đều là ảnh tham khảo của nghề gác bếp lấy trên mạng, ảnh vùng nguyên liệu
là ảnh chụp màn hình Google Maps. Không tấm nào được ghi như thể là ảnh chụp tại
chính lô này, và không tấm nào là ảnh bao bì của một thương hiệu đang bán hàng.
"""
import io
import json
import os
import sys
import unicodedata
import urllib.request
from datetime import datetime, timedelta

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PHOTOS = os.path.join(ROOT, 'docs', 'image', 'trau')
FONT_BOLD = os.path.join(ROOT, 'assets', 'fonts', 'BeVietnamPro-Bold.ttf')
FONT_REG = os.path.join(ROOT, 'assets', 'fonts', 'BeVietnamPro-Regular.ttf')
TOKEN_FILE = os.path.join(ROOT, 'worker', '.admin-token.txt')

INK = (23, 53, 42)
TINT = (120, 62, 48)

DESCRIPTION = (
    'Thịt trâu bắp và thăn nuôi thả tại Lai Châu, thái dọc thớ, ướp mắc khén '
    'và hạt dổi rồi hong trên bếp củi cho tới khi se mặt. Mỗi mẻ đóng thành '
    'túi hút chân không 100 g, dán mã QR của chính lô đó.'
)

# Ảnh sản phẩm: ảnh chụp món thịt trâu gác bếp nói chung, không phải bao bì của
# thương hiệu nào. Dữ liệu này là demo nên không mượn ảnh sản phẩm thật của ai.
GALLERY = [
    ('sp-mam-co.jpg', 'cover',
     'Ảnh tham khảo: thịt trâu gác bếp xé dọc thớ'),
    ('sp-tho-thit.jpg', 'gallery',
     'Ảnh tham khảo: thớ thịt bên trong miếng gác bếp'),
    ('sp-dia-thanh-pham.jpg', 'gallery',
     'Ảnh tham khảo: thành phẩm thái miếng và xé sợi'),
    ('sp-hut-chan-khong.jpg', 'gallery',
     'Ảnh tham khảo: quy cách túi hút chân không'),
]

# Bộ ảnh sản phẩm cũ là ảnh dựng bao bì của một thương hiệu riêng, không được
# dùng cho bản demo công khai. Gặp chú thích nào trong danh sách này thì xoá.
RETIRED_CAPTIONS = {
    'Hộp quà Thịt trâu gác bếp (ảnh minh hoạ)',
    'Hộp mở nắp, hai túi 100 g (ảnh minh hoạ)',
    'Phần thăn trâu sau khi hong khói (ảnh minh hoạ)',
    'Phần bắp trâu sau khi hong khói (ảnh minh hoạ)',
}

# Ảnh chụp thật của nghề gác bếp, dùng làm ảnh tham khảo cho từng công đoạn.
# Chú thích ghi rõ "ảnh tham khảo" vì đây không phải ảnh chụp tại lô này.
STEP_PHOTOS = {
    'so che va thai dai': (
        'thai-dai.jpg', 'Ảnh tham khảo: thịt thái dọc thớ, treo lên giàn'),
    'tam uop': (
        'tam-uop.jpg', 'Ảnh tham khảo: thịt và bộ gia vị mắc khén, hạt dổi'),
    'hong khoi va lam kho': (
        'hong-khoi.jpg', 'Ảnh tham khảo: hong trên bếp củi'),
    'dong goi va dan qr': (
        'thanh-pham.jpg', 'Ảnh tham khảo: thành phẩm trước khi đóng gói'),
    'tiep nhan va kiem tra thit': (
        'tiep-nhan-thit.jpg', 'Ảnh tham khảo: thịt trâu tươi lúc tiếp nhận'),
}

# Vùng nguyên liệu: ảnh chụp màn hình Google Maps, đúng cách mà bên ngũ cốc
# đang làm cho bốn vùng trồng.
AREA_PHOTO = ('vung-nguyen-lieu.png', 'Vùng nuôi trâu: tỉnh Lai Châu, Tây Bắc')

# Khối lượng vào và ra của từng công đoạn, tính bằng gam, theo quy mô mẻ.
# Khoá là tên công đoạn đã bỏ dấu.
YIELD = {
    # Lô nguyên liệu: tiếp nhận bao nhiêu nhận đủ bấy nhiêu, chỉ kiểm tra.
    'tiep nhan va kiem tra thit': (1.00, 1.00),
    'so che va thai dai': (1.00, 0.90),
    'tam uop': (0.90, 0.96),
    'hong khoi va lam kho': (0.96, 0.35),
    'dong goi va dan qr': (0.35, 0.33),
}

PARAMS = {
    'tiep nhan va kiem tra thit': {
        'Nhiệt độ bảo quản': '0-4°C',
        'Phần thịt': 'bắp và thăn',
    },
    'so che va thai dai': {
        'Phần thịt': 'bắp và thăn',
        'Miếng thái': 'dọc thớ, khoảng 5 x 20 cm',
    },
    'tam uop': {
        'Gia vị': 'muối hột, mắc khén, hạt dổi, gừng, tỏi, sả, ớt',
        'Thời gian ướp': '4 giờ',
    },
    'hong khoi va lam kho': {
        'Nguồn nhiệt': 'bếp củi',
        'Khoảng cách treo': '60-70 cm',
        'Thời gian': '12 giờ',
    },
    'dong goi va dan qr': {
        'Quy cách': 'túi hút chân không 100 g',
    },
}

# Quy mô từng mẻ: khối lượng thịt tươi đưa vào, gam.
SCALE = {
    'TB-2026-001': 12000,
    'TB-2026-002': 15000,
    'TB-2026-003': 18000,
}

# Số ngày trước ngày sản xuất của từng công đoạn.
OFFSET = {
    'so che va thai dai': -4,
    'tam uop': -3,
    'hong khoi va lam kho': -2,
    'dong goi va dan qr': 0,
}


def fold(text):
    text = (text or '').replace('Đ', 'd').replace('đ', 'd')
    stripped = unicodedata.normalize('NFD', text.lower())
    plain = ''.join(c for c in stripped if unicodedata.category(c) != 'Mn')
    return ' '.join(plain.split())


def request(base, path, token, method='GET', body=None, form=None):
    headers = {'authorization': 'Bearer ' + token, 'user-agent': 'tule-tools/1.0'}
    data = None
    if form is not None:
        boundary = '----tule' + os.urandom(8).hex()
        parts = []
        for key, value in form['fields'].items():
            parts.append(
                ('--%s\r\nContent-Disposition: form-data; name="%s"\r\n\r\n%s\r\n'
                 % (boundary, key, value)).encode('utf-8')
            )
        parts.append(
            ('--%s\r\nContent-Disposition: form-data; name="file"; '
             'filename="%s"\r\nContent-Type: image/jpeg\r\n\r\n'
             % (boundary, form['name'])).encode('utf-8')
        )
        parts.append(form['bytes'])
        parts.append(('\r\n--%s--\r\n' % boundary).encode('utf-8'))
        data = b''.join(parts)
        headers['content-type'] = 'multipart/form-data; boundary=' + boundary
    elif body is not None:
        data = json.dumps(body, ensure_ascii=False).encode('utf-8')
        headers['content-type'] = 'application/json; charset=utf-8'
    req = urllib.request.Request(base + path, data=data, headers=headers,
                                 method=method)
    with urllib.request.urlopen(req, timeout=180) as res:
        raw = res.read().decode('utf-8')
        return json.loads(raw) if raw else {}


def shrink(name, role):
    edge, quality = {
        'cover': (1400, 82),
        'area_map': (1600, 90),
    }.get(role, (1280, 75))
    img = Image.open(os.path.join(PHOTOS, name)).convert('RGB')
    width, height = img.size
    if max(width, height) > edge:
        scale = edge / max(width, height)
        img = img.resize((round(width * scale), round(height * scale)),
                         Image.LANCZOS)
    buffer = io.BytesIO()
    img.save(buffer, 'JPEG', quality=quality, optimize=True)
    return buffer.getvalue()


def illustration(title):
    """Thẻ minh hoạ trung tính: nhìn là biết ngay không phải ảnh chụp."""
    width, height = 1280, 720
    img = Image.new('RGB', (width, height), (250, 250, 246))
    draw = ImageDraw.Draw(img)
    for i in range(height):
        ratio = i / height
        colour = tuple(
            int(250 - (250 - c) * 0.10 - (250 - c) * 0.16 * ratio) for c in TINT
        )
        draw.line([(0, i), (width, i)], fill=colour)
    draw.ellipse((width - 420, -160, width + 200, 460),
                 fill=tuple(int(c * 0.18 + 250 * 0.82) for c in TINT))
    draw.ellipse((-220, height - 320, 340, height + 220),
                 fill=tuple(int(c * 0.22 + 250 * 0.78) for c in TINT))

    title_font = ImageFont.truetype(FONT_BOLD, 74)
    sub_font = ImageFont.truetype(FONT_REG, 34)
    tag_font = ImageFont.truetype(FONT_BOLD, 24)
    draw.rounded_rectangle((72, 70, 356, 138), radius=15, fill=INK)
    draw.text((96, 86), 'ẢNH MINH HOẠ', font=tag_font, fill=(255, 255, 255))

    words, lines, current = title.split(), [], ''
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
    draw.text((84, y + 16), 'Thịt trâu gác bếp', font=sub_font,
              fill=(92, 107, 97))
    buffer = io.BytesIO()
    img.save(buffer, 'JPEG', quality=82, optimize=True)
    return buffer.getvalue()


def shift(date_text, days):
    day = datetime.strptime(date_text, '%d.%m.%Y') + timedelta(days=days)
    return day.strftime('%d.%m.%Y')


def seed(code, base, dry):
    token = io.open(TOKEN_FILE, encoding='utf-8').read().strip()
    trace = request(base, '/api/admin/product-batches/%s/trace' % code, token)
    fresh = SCALE.get(code, 12000)

    # Lô nguyên liệu (NL-...) là thịt tươi trước khi chế biến: không mang mô tả
    # và không mang ảnh sản phẩm của lô thành phẩm.
    raw_lot = code.upper().startswith('NL-')

    if not raw_lot:
        print('Mô tả lô')
        if not dry:
            request(base, '/api/admin/product-batches/%s' % code, token,
                    'PATCH', {'description': DESCRIPTION})

    print('\nẢnh sản phẩm')
    for item in trace['media']:
        if item.get('caption') not in RETIRED_CAPTIONS:
            continue
        print('     - bỏ ảnh bao bì cũ:', item.get('caption'))
        if not dry:
            request(base, '/api/admin/media/%s' % item['id'], token, 'DELETE')
    have = {
        m.get('caption') for m in trace['media']
        if m.get('caption') not in RETIRED_CAPTIONS
    }
    for name, role, caption in (() if raw_lot else GALLERY):
        if caption in have:
            print('     đã có', caption)
            continue
        payload = shrink(name, role)
        print('     + %-8s %5.0f KB  %s' % (role, len(payload) / 1024, caption))
        if dry:
            continue
        request(base, '/api/admin/media', token, 'POST', form={
            'bytes': payload,
            'name': os.path.splitext(name)[0] + '.jpg',
            'fields': {
                'ownerType': 'product_batch',
                'ownerId': str(trace['id']),
                'role': role,
                'caption': caption,
            },
        })

    print('\nVùng nguyên liệu')
    for ingredient in trace['ingredients']:
        if any(item['role'] == 'area_map' for item in ingredient['media']):
            print('     đã có ảnh vùng cho', ingredient['name'])
            continue
        name, caption = AREA_PHOTO
        payload = shrink(name, 'area_map')
        print('     + area_map %5.0f KB  %s' % (len(payload) / 1024, caption))
        if dry:
            continue
        request(base, '/api/admin/media', token, 'POST', form={
            'bytes': payload,
            'name': 'vung-nguyen-lieu.jpg',
            'fields': {
                'ownerType': 'ingredient_batch',
                'ownerId': str(ingredient['id']),
                'role': 'area_map',
                'caption': caption,
            },
        })

    print('\nCông đoạn')
    for event in trace.get('batchEvents', []):
        key = fold(event['title'])
        body = {'eventDate': shift(trace['production_date'],
                                   OFFSET.get(key, 0))}
        if key in YIELD:
            start, end = YIELD[key]
            body['inputQuantity'] = round(fresh * start)
            body['outputQuantity'] = round(fresh * end)
            body['quantityUnit'] = 'g'
        if key in PARAMS:
            params = dict(PARAMS[key])
            if key == 'dong goi va dan qr':
                params['Số gói'] = str(round(fresh * YIELD[key][1] / 100))
            body['params'] = params
        print('  %-24s %-12s %s' % (
            event['title'][:24], body['eventDate'],
            '%s → %s g' % (body.get('inputQuantity', '-'),
                           body.get('outputQuantity', '-'))))
        if not dry:
            request(base, '/api/admin/process-events/%s' % event['id'], token,
                    'PATCH', body)
        shot = STEP_PHOTOS.get(key)
        has_photo = shot and os.path.exists(os.path.join(PHOTOS, shot[0]))
        # Ảnh dựng đặt tạm lúc chưa có ảnh tham khảo thì thay bằng ảnh thật.
        # Ảnh do người vận hành tự tải lên thì không đụng tới.
        placeholder = [
            item for item in event['media']
            if (item.get('caption') or '').startswith('Ảnh minh hoạ công đoạn')
        ]
        if event['media'] and not (has_photo and
                                   len(placeholder) == len(event['media'])):
            continue
        for item in placeholder:
            print('     - bỏ ảnh dựng cũ')
            if not dry:
                request(base, '/api/admin/media/%s' % item['id'], token,
                        'DELETE')
        if has_photo:
            picture = shrink(shot[0], 'gallery')
            caption = shot[1]
            print('     + ảnh tham khảo %5.0f KB  %s'
                  % (len(picture) / 1024, caption))
        else:
            picture = illustration(event['title'])
            caption = 'Ảnh minh hoạ công đoạn %s' % event['title']
            print('     + ảnh minh hoạ %5.0f KB' % (len(picture) / 1024))
        if dry:
            continue
        request(base, '/api/admin/media', token, 'POST', form={
            'bytes': picture,
            'name': fold(event['title']).replace(' ', '-') + '.jpg',
            'fields': {
                'ownerType': 'process_event',
                'ownerId': str(event['id']),
                'role': 'gallery',
                'caption': caption,
            },
        })

    if dry:
        print('\nchạy thử, chưa đụng vào dữ liệu.')
        return
    published = request(base, '/api/admin/product-batches/%s/publish' % code,
                        token, 'POST')
    print('\nđã công bố phiên bản', published.get('version'))


if __name__ == '__main__':
    args = sys.argv[1:]
    batch = next((a for a in args if not a.startswith('--')), 'TB-2026-001')
    target = 'https://tule-trace.sontm.workers.dev'
    if '--to' in args:
        target = args[args.index('--to') + 1]
    seed(batch, target.rstrip('/'), '--dry' in args)
