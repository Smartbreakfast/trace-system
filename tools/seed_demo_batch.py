# -*- coding: utf-8 -*-
"""Điền nốt phần hồ sơ lô mà bộ công đoạn không chạm tới.

    python tools/seed_demo_batch.py TL-2026-002 [--to https://...] [--dry]

Bổ sung mô tả lô, ngày thu hoạch và nhập kho của từng nguyên liệu, hai mốc
khối lượng đầu và cuối mỗi nhánh, dải ảnh sản phẩm, và chuyển bốn tấm ảnh
vùng trồng sang đúng vai trò area_map.

Ảnh lấy từ docs/image, là ảnh thật của sản phẩm và của vùng nguyên liệu. Nén
bằng PIL theo đúng mức mà màn quản trị dùng, xem lib/ui/media_manager.dart.
"""
import io
import json
import os
import sys
import unicodedata
import urllib.request

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PHOTOS = os.path.join(ROOT, 'docs', 'image')
TOKEN_FILE = os.path.join(ROOT, 'worker', '.admin-token.txt')

DESCRIPTION = (
    'Bột ngũ cốc từ bốn nông sản bản địa Tây Bắc: cốm Tú Lệ, lạc đỏ Lục Yên, '
    'chuối tiêu xanh và khoai môn Lục Yên. Mỗi mẻ 1.000 g, đóng thành 20 gói '
    '30 g. Bốn nhánh nguyên liệu được sơ chế riêng thành bột rồi mới phối trộn '
    'và đóng gói tại xưởng.'
)

# Ngày thu hoạch và nhập kho, khớp với mốc thời gian của công đoạn đầu nhánh.
DATES = {
    'com tu le': ('18.08.2026', '19.08.2026'),
    'lac do luc yen': ('16.08.2026', '19.08.2026'),
    'chuoi tieu xanh': ('22.08.2026', '23.08.2026'),
    'khoai mon luc yen': ('25.08.2026', '26.08.2026'),
}

# Khối lượng bột thu được của mỗi nhánh, đặt ở đúng công đoạn mang tên loại
# bột đó. Con số theo bảng định mức cho một mẻ 1.000g.
#
# Không gán khối lượng cho các bước còn lại. Tài liệu chỉ có tổng đầu vào và
# tổng bột thu được của cả nhánh; một chuỗi số trung gian tự nghĩ ra thì cộng
# lại không khớp với chính nó, mà đây là hệ thống bán niềm tin vào con số.
ANCHORS = {
    'com tu le': {'bot com': (None, 135)},
    'lac do luc yen': {'bot lac': (None, 205)},
    'chuoi tieu xanh': {'bot chuoi': (None, 210)},
    'khoai mon luc yen': {'bot khoai mon': (None, 320)},
}

# Ảnh vùng trồng: đang nằm ở vai trò gallery, đúng ra phải là area_map để trang
# khách hiện nó ngay đầu hồ sơ nguyên liệu.
AREA_PHOTOS = {
    'com tu le': ('Mẫu/1.1 VÙng nguyên liệu cốm tú lệ.png',
                  'Ruộng bậc thang Tú Lệ, Yên Bái'),
    'lac do luc yen': ('Mẫu/2.1 lạc đỏ lục yên vùng nguyên liệu.png',
                       'Vùng trồng lạc đỏ Lục Yên, Yên Bái'),
    'chuoi tieu xanh': ('Mẫu/3.1 vùng nguyên liệu chuối tiêu xanh.png',
                        'Vùng trồng chuối tiêu Bảo Thắng, Lào Cai'),
    'khoai mon luc yen': ('Mẫu/4. vùng nguyên liệu khoai môn.png',
                          'Vùng trồng khoai môn Lâm Thượng, Lục Yên'),
}

# Dải ảnh sản phẩm cho mục Thông tin chung.
GALLERY = [
    ('_MG_4793.JPG', 'Hộp Tú Lệ Smart Breakfast 600 g'),
    ('_MG_4753.JPG', 'Sản phẩm đóng hộp tại buổi giới thiệu'),
    ('_MG_4783.JPG', 'Hộp và gói 30 g bày cùng nguyên liệu'),
]

# Mức nén theo vai trò, giữ đúng bảng trong lib/ui/media_manager.dart.
RECIPE = {'area_map': (1600, 90), 'gallery': (1280, 75)}


def fold(text):
    text = (text or '').replace('Đ', 'd').replace('đ', 'd')
    plain = ''.join(
        c for c in unicodedata.normalize('NFD', text.lower())
        if unicodedata.category(c) != 'Mn'
    )
    return ' '.join(plain.split())


def request(base, path, token, method='GET', body=None, form=None):
    headers = {
        'authorization': 'Bearer ' + token,
        'user-agent': 'tule-trace-seed/1.0',
    }
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
        data = json.dumps(body).encode('utf-8')
        headers['content-type'] = 'application/json'

    req = urllib.request.Request(base + path, data=data, headers=headers,
                                 method=method)
    with urllib.request.urlopen(req, timeout=120) as res:
        raw = res.read().decode('utf-8')
        return json.loads(raw) if raw else {}


def shrink(path, role):
    edge, quality = RECIPE[role]
    img = Image.open(path).convert('RGB')
    width, height = img.size
    if max(width, height) > edge:
        scale = edge / max(width, height)
        img = img.resize((round(width * scale), round(height * scale)),
                         Image.LANCZOS)
    buffer = io.BytesIO()
    img.save(buffer, 'JPEG', quality=quality, optimize=True)
    return buffer.getvalue()


def upload(base, token, dry, path, role, owner_type, owner_id, caption):
    full = os.path.join(PHOTOS, path)
    if not os.path.exists(full):
        print('     thiếu ảnh', path)
        return
    payload = shrink(full, role)
    print('     + %-10s %5.0f KB  %s' % (role, len(payload) / 1024, caption))
    if dry:
        return
    request(base, '/api/admin/media', token, 'POST', form={
        'bytes': payload,
        'name': fold(os.path.splitext(os.path.basename(path))[0]).replace(' ', '-') + '.jpg',
        'fields': {
            'ownerType': owner_type,
            'ownerId': str(owner_id),
            'role': role,
            'caption': caption,
        },
    })


def seed(code, base, dry):
    token = io.open(TOKEN_FILE, encoding='utf-8').read().strip()
    trace = request(base, '/api/admin/product-batches/%s/trace' % code, token)

    print('Mô tả lô')
    if not dry:
        request(base, '/api/admin/product-batches/%s' % code, token, 'PATCH',
                {'description': DESCRIPTION})

    print('\nDải ảnh sản phẩm')
    have = {m.get('caption') for m in trace['media']}
    for name, caption in GALLERY:
        if caption in have:
            print('     đã có', caption)
            continue
        upload(base, token, dry, name, 'gallery', 'product_batch', trace['id'],
               caption)

    for ing in trace['ingredients']:
        key = fold(ing['name'])
        print('\n==', ing['name'])

        if key in DATES:
            harvest, received = DATES[key]
            print('   thu hoạch %s · nhập kho %s' % (harvest, received))
            if not dry:
                request(base, '/api/admin/ingredient-batches/%s' % ing['id'],
                        token, 'PATCH',
                        {'harvestDate': harvest, 'receivedDate': received})

        # Ảnh vùng trồng: xoá bản đang ở vai trò gallery rồi tải lại đúng vai trò.
        if key in AREA_PHOTOS and not any(m['role'] == 'area_map'
                                          for m in ing['media']):
            path, caption = AREA_PHOTOS[key]
            upload(base, token, dry, path, 'area_map', 'ingredient_batch',
                   ing['id'], caption)
            for old in ing['media']:
                if old['role'] == 'gallery':
                    print('     - gỡ bản cũ ở vai trò gallery')
                    if not dry:
                        request(base, '/api/admin/media/%s' % old['id'], token,
                                'DELETE')

        anchors = ANCHORS.get(key, {})
        for event in ing['processEvents']:
            pair = anchors.get(fold(event['title']))
            if not pair:
                continue
            body = {'quantityUnit': 'g'}
            if pair[0] is not None:
                body['inputQuantity'] = pair[0]
            if pair[1] is not None:
                body['outputQuantity'] = pair[1]
            print('   %-26s ra %s g' % (event['title'][:26], pair[1]))
            if not dry:
                request(base, '/api/admin/process-events/%s' % event['id'],
                        token, 'PATCH', body)

    if dry:
        print('\nchạy thử, chưa đụng vào dữ liệu.')
        return
    published = request(base, '/api/admin/product-batches/%s/publish' % code,
                        token, 'POST')
    print('\nđã công bố phiên bản', published.get('version'))


if __name__ == '__main__':
    args = sys.argv[1:]
    batch = next((a for a in args if not a.startswith('--')), 'TL-2026-002')
    target = 'https://tule-trace.sontm.workers.dev'
    if '--to' in args:
        target = args[args.index('--to') + 1]
    seed(batch, target.rstrip('/'), '--dry' in args)
