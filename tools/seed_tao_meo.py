# -*- coding: utf-8 -*-
"""Dựng dòng sản phẩm ô mai táo mèo của HTX Đoàn Lương.

    python tools/seed_tao_meo.py --dry          # xem sẽ làm gì, không ghi
    python tools/seed_tao_meo.py                # dựng vào bản đang chạy thật
    python tools/seed_tao_meo.py --to http://127.0.0.1:8799

Chạy được nhiều lần: cái gì đã có thì bỏ qua, không tạo trùng và không ghi đè
thứ người vận hành đã sửa tay.

PHẢI CHẠY MIGRATION 0016 TRƯỚC, vì cơ sở và hai mã sản phẩm nằm trong đó:

    npm run db:migrate:taomeo:remote     (trong thư mục worker)

ĐÂU LÀ THẬT, ĐÂU LÀ DỰNG — đọc kỹ trước khi đưa cho ai xem:

- Cơ sở, tên sản phẩm, quy cách hũ 200 g và toàn bộ ảnh là của hợp tác xã thật.
  Ảnh do chính hợp tác xã đăng, chú thích ghi rõ là ảnh tư liệu chứ không phải
  ảnh chụp tại lô này.
- Mã lô, ngày sản xuất, khối lượng từng công đoạn là DỰNG, đúng như dòng thịt
  trâu gác bếp. Khi hợp tác xã gửi sổ sản xuất thật thì sửa bảng LOTS và YIELD
  rồi chạy lại, đừng sửa tay trong màn quản trị.
- Ba giấy OCOP của hợp tác xã KHÔNG đưa lên: giấy ghi "có giá trị 36 tháng kể
  từ ngày ký Quyết định 4357/QĐ-UBND ngày 21/8/2023", tức đã hết hiệu lực từ
  21/8/2026. Đăng một tờ giấy hết hạn như minh chứng còn hiệu lực là đúng loại
  lỗi mà hội đồng sẽ bắt. Chờ hợp tác xã gửi giấy gia hạn.
- Toạ độ là tâm tỉnh Yên Bái lấy từ bảng Natural Earth của chính dự án, không
  phải toạ độ xưởng. Giao diện đã nói rõ đó là vị trí tương đối.
"""
import argparse
import io
import json
import os
import sys
import urllib.error
import urllib.request

from PIL import Image

sys.stdout.reconfigure(encoding='utf-8')

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PHOTOS = os.path.join(ROOT, 'docs', 'image', 'taomeo')
TOKEN_FILE = os.path.join(ROOT, 'worker', '.admin-token.txt')

LOCAL = 'http://127.0.0.1:8799'
# Gọi admin đi thẳng vào worker: tên miền chính đi qua Pages và Pages chặn một
# số công cụ dòng lệnh bằng lỗi 1010.
PRODUCTION = 'https://tule-trace.sontm.workers.dev'

FACILITY_CODE = 'TAOMEO'
FINISHED_SKU = 'tao-meo-o-mai'
INGREDIENT_SKU = 'ingredient-tao-meo-tuoi'

# Địa chỉ chép đúng giấy chứng nhận OCOP 2023 của hợp tác xã.
PLACE = 'Hợp tác xã Đoàn Lương, xã Văn Phú, thành phố Yên Bái'
# Tâm tỉnh Yên Bái theo lib/data/vn_provinces.dart (Natural Earth, public
# domain). Đây là vị trí tương đối theo tỉnh, không phải toạ độ xưởng.
LAT, LNG = 21.7484, 104.512

DESCRIPTION = (
    'Quả táo mèo (sơn tra) Tây Bắc thái lát, ngâm khử chát, sên với đường rồi '
    'sấy khô và đóng hũ 200 g. Mỗi lô dán mã QR của chính lô đó.'
)

RAW_LOT = {
    'code': 'NL-TAOMEO-2026-001',
    'name': 'Quả táo mèo tươi - lô nguyên liệu',
    'production': '05.09.2026',
    'expiry': '05.12.2026',
    'description': 'Lô quả táo mèo tươi trước khi sơ chế và sên đường.',
}

# Ba mẻ, rải theo mùa táo mèo (quả chín từ khoảng tháng 8 đến tháng 10).
# Mọi mốc thời gian phải nằm trong quá khứ so với ngày chạy seeder: hồ sơ
# truy xuất là bản ghi việc đã làm, không phải lịch sản xuất.
# `fresh` là khối lượng quả tươi đưa vào, tính bằng gam.
LOTS = [
    {'code': 'TM-2026-001', 'name': 'Ô mai táo mèo - mẻ tháng 09',
     'production': '10.09.2026', 'expiry': '10.09.2027',
     'harvest': '05.09.2026', 'received': '06.09.2026', 'fresh': 30000},
    {'code': 'TM-2026-002', 'name': 'Ô mai táo mèo - mẻ tháng 10',
     'production': '08.10.2026', 'expiry': '08.10.2027',
     'harvest': '03.10.2026', 'received': '04.10.2026', 'fresh': 45000},
    {'code': 'TM-2026-003', 'name': 'Ô mai táo mèo - mẻ cuối tháng 10',
     'production': '22.10.2026', 'expiry': '22.10.2027',
     'harvest': '17.10.2026', 'received': '18.10.2026', 'fresh': 36000},
]

INGREDIENT = {
    'name': 'Quả táo mèo tươi',
    'origin': 'Yên Bái',
    'supplier': 'Hộ trồng sơn tra tại địa phương',
    'summary': 'Quả sơn tra chín, chắc quả, được chọn lọc trước khi sơ chế.',
}

# Công đoạn của nhánh nguyên liệu, theo đúng thứ tự nghề làm ô mai táo mèo.
# `offset` là số ngày so với ngày sản xuất của lô.
# `yield` là (hệ số khối lượng vào, hệ số khối lượng ra) so với khối lượng quả
# tươi ban đầu.
STEPS = [
    {
        'title': 'Tiếp nhận và chọn quả',
        'description': 'Cân nhận quả táo mèo, loại quả sâu, quả dập và quả '
                       'chưa đủ độ chín.',
        'offset': -5, 'yield': (1.00, 0.95),
        'params': {'Giống quả': 'táo mèo (sơn tra)'},
    },
    {
        'title': 'Rửa, bỏ hạt và thái lát',
        'description': 'Rửa nhiều lần cho sạch nhựa và bụi, bỏ hạt rồi thái '
                       'lát để quả ngấm đều ở các bước sau.',
        'offset': -4, 'yield': (0.95, 0.72),
        'params': {'Độ dày lát': '5-7 mm'},
        'photo': None,
    },
    {
        'title': 'Ngâm khử chát',
        'description': 'Ngâm nước muối loãng rồi xả lại bằng nước sạch để '
                       'giảm vị chát và chua gắt của quả tươi.',
        'offset': -3, 'yield': (0.72, 0.72),
        'params': {'Dung dịch ngâm': 'nước muối loãng'},
    },
    {
        'title': 'Sên đường',
        'description': 'Sên lát táo mèo với đường trên lửa vừa, đảo đều cho '
                       'tới khi lát quả trong và ngấm hết nước đường.',
        'offset': -2, 'yield': (0.72, 0.60),
        'params': {'Gia vị': 'đường, muối, gừng'},
        'photo': ('sen-duong.jpg',
                  'Ảnh tư liệu của HTX Đoàn Lương: sên táo mèo với đường'),
    },
    {
        'title': 'Sấy khô',
        'description': 'Rải đều lên khay rồi sấy trong tủ sấy cho tới khi lát '
                       'quả se mặt, dẻo chứ không giòn.',
        'offset': -1, 'yield': (0.60, 0.32),
        'params': {'Thiết bị': 'tủ sấy nhiều khay'},
        'photo': ('say-khay.jpg',
                  'Ảnh tư liệu của HTX Đoàn Lương: khay táo mèo trong tủ sấy'),
    },
    {
        'title': 'Đóng hũ và dán mã QR',
        'description': 'Đóng hũ 200 g, dán nhãn và mã QR của chính lô này.',
        'offset': 0, 'yield': (0.32, 0.30),
        'params': {'Quy cách': 'hũ 200 g'},
        'photo': ('sp-hu-nen-co.jpg',
                  'Ảnh tư liệu của HTX Đoàn Lương: hũ ô mai táo mèo 200 g'),
    },
]

# Ảnh sản phẩm của lô. Đều là ảnh do hợp tác xã đăng, không phải ảnh dựng.
GALLERY = [
    ('sp-o-mai-roi.jpg', 'cover',
     'Ảnh tư liệu của HTX Đoàn Lương: ô mai táo mèo thành phẩm'),
    ('sp-hai-hu.jpg', 'gallery',
     'Ảnh tư liệu của HTX Đoàn Lương: hũ ô mai táo mèo 200 g'),
    ('sp-nhan-hu.jpg', 'gallery',
     'Ảnh tư liệu của HTX Đoàn Lương: nhãn hũ ô mai táo mèo'),
    ('gian-hang.jpg', 'gallery',
     'Ảnh tư liệu của HTX Đoàn Lương: gian hàng sản phẩm từ táo mèo'),
]


def token():
    if os.environ.get('ADMIN_TOKEN'):
        return os.environ['ADMIN_TOKEN']
    if not os.path.exists(TOKEN_FILE):
        sys.exit('Không thấy %s để lấy token quản trị.' % TOKEN_FILE)
    return io.open(TOKEN_FILE, encoding='utf-8').read().strip()


def call(base, path, method='GET', body=None, form=None, soft=False):
    headers = {
        'authorization': 'Bearer %s' % TOKEN,
        # Cloudflare chặn user-agent mặc định của urllib bằng lỗi 1010.
        'User-Agent': 'tule-trace-tools/1.0',
    }
    data = None
    if form is not None:
        boundary = '----tule' + os.urandom(8).hex()
        parts = []
        for key, value in form['fields'].items():
            parts.append(
                ('--%s\r\nContent-Disposition: form-data; name="%s"\r\n\r\n%s\r\n'
                 % (boundary, key, value)).encode('utf-8'))
        parts.append(
            ('--%s\r\nContent-Disposition: form-data; name="file"; '
             'filename="%s"\r\nContent-Type: image/jpeg\r\n\r\n'
             % (boundary, form['name'])).encode('utf-8'))
        parts.append(form['bytes'])
        parts.append(('\r\n--%s--\r\n' % boundary).encode('utf-8'))
        data = b''.join(parts)
        headers['content-type'] = 'multipart/form-data; boundary=' + boundary
    elif body is not None:
        data = json.dumps(body, ensure_ascii=False).encode('utf-8')
        headers['content-type'] = 'application/json; charset=utf-8'
    request = urllib.request.Request(base + path, data=data, headers=headers,
                                     method=method)
    try:
        with urllib.request.urlopen(request, timeout=180) as response:
            raw = response.read().decode('utf-8')
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as error:
        # `soft` dùng cho phép thử "cái này có chưa": 404 là câu trả lời.
        if soft and error.code == 404:
            return None
        detail = error.read().decode('utf-8', 'replace')[:300]
        sys.exit('%s %s -> %s %s' % (method, path, error.code, detail))


def shrink(name, role):
    edge, quality = {'cover': (1400, 82)}.get(role, (1280, 78))
    img = Image.open(os.path.join(PHOTOS, name)).convert('RGB')
    width, height = img.size
    if max(width, height) > edge:
        scale = edge / max(width, height)
        img = img.resize((round(width * scale), round(height * scale)),
                         Image.LANCZOS)
    buffer = io.BytesIO()
    img.save(buffer, 'JPEG', quality=quality, optimize=True)
    return buffer.getvalue()


def put_media(base, owner_type, owner_id, name, role, caption, dry):
    payload = shrink(name, role)
    print('     + %-8s %5.0f KB  %s' % (role, len(payload) / 1024, caption))
    if dry:
        return
    call(base, '/api/admin/media', 'POST', form={
        'bytes': payload,
        'name': name,
        'fields': {
            'ownerType': owner_type,
            'ownerId': str(owner_id),
            'role': role,
            'caption': caption,
        },
    })


def ensure_batch(base, products, lot, sku, dry):
    """Tạo lô nếu chưa có. Trả về hồ sơ quản trị của lô, hoặc None khi chạy thử."""
    existing = call(base, '/api/admin/product-batches/%s/trace' % lot['code'],
                    soft=True)
    if existing:
        print('  lô %s đã có' % lot['code'])
        return existing
    print('  tạo lô %s' % lot['code'])
    if dry:
        # Lô chưa tồn tại nên không đọc được hồ sơ thật. Trả một hồ sơ rỗng để
        # phần còn lại vẫn in ra kế hoạch, nếu không thì chạy thử chỉ nói được
        # mỗi câu "sẽ tạo lô" và chẳng kiểm được gì.
        return {'id': 0, 'status': 'DRAFT', 'media': [], 'ingredients': []}
    call(base, '/api/admin/product-batches', 'POST', {
        'productId': products[sku],
        'name': lot['name'],
        'code': lot['code'],
        'productionDate': lot['production'],
        'expiryDate': lot['expiry'],
        'description': lot.get('description', DESCRIPTION),
        'facilityName': PLACE,
        'latitude': LAT,
        'longitude': LNG,
    })
    return call(base, '/api/admin/product-batches/%s/trace' % lot['code'])


def shift(date_text, days):
    from datetime import datetime, timedelta
    day = datetime.strptime(date_text, '%d.%m.%Y') + timedelta(days=days)
    return day.strftime('%d.%m.%Y')


def seed(base, dry):
    facilities = {row['code']: row['id']
                  for row in call(base, '/api/admin/facilities')}
    if FACILITY_CODE not in facilities:
        sys.exit('Chưa có cơ sở %s. Chạy migration 0016 trước:\n'
                 '    cd worker && npm run db:migrate:taomeo:remote'
                 % FACILITY_CODE)
    products = {row['sku']: row['id']
                for row in call(base, '/api/admin/products')}
    for sku in (FINISHED_SKU, INGREDIENT_SKU):
        if sku not in products:
            sys.exit('Chưa có mã sản phẩm %s. Chạy migration 0016 trước.' % sku)
    print('cơ sở %s, sản phẩm %s' % (FACILITY_CODE, FINISHED_SKU))

    print('\nLô nguyên liệu')
    raw = ensure_batch(base, products, RAW_LOT, INGREDIENT_SKU, dry)
    raw_id = raw['id'] if raw else None

    for lot in LOTS:
        print('\n=== %s ===' % lot['code'])
        trace = ensure_batch(base, products, lot, FINISHED_SKU, dry)
        if trace is None:
            continue

        if trace['status'] == 'PUBLISHED':
            print('  đã công bố, không đụng vào nữa')
            continue

        print('  Ảnh sản phẩm')
        have = {item.get('caption') for item in trace['media']}
        for name, role, caption in GALLERY:
            if caption in have:
                print('     đã có', caption)
                continue
            put_media(base, 'product_batch', trace['id'], name, role, caption,
                      dry)

        print('  Nguyên liệu')
        if trace['ingredients']:
            ingredient = trace['ingredients'][0]
            print('     đã có', ingredient['name'])
        elif dry:
            ingredient = None
            print('     tạo', INGREDIENT['name'])
        else:
            ingredient = call(base, '/api/admin/ingredient-batches', 'POST', {
                'productBatchId': trace['id'],
                'name': INGREDIENT['name'],
                'origin': INGREDIENT['origin'],
                'supplier': INGREDIENT['supplier'],
                'harvestDate': lot['harvest'],
                'receivedDate': lot['received'],
                'summary': INGREDIENT['summary'],
                'sourceProductBatchId': raw_id,
                'latitude': LAT,
                'longitude': LNG,
            })
            print('     tạo', INGREDIENT['name'])

        print('  Công đoạn')
        titles = set()
        if ingredient:
            titles = {event['title']
                      for event in ingredient.get('processEvents', [])}
        for index, step in enumerate(STEPS):
            if step['title'] in titles:
                print('     đã có', step['title'])
                continue
            start, end = step['yield']
            body = {
                'ingredientBatchId': ingredient['id'] if ingredient else 0,
                'title': step['title'],
                'description': step['description'],
                'eventDate': shift(lot['production'], step['offset']),
                'position': index,
                'inputQuantity': round(lot['fresh'] * start),
                'outputQuantity': round(lot['fresh'] * end),
                'quantityUnit': 'g',
                'params': dict(step['params']),
            }
            if step['title'].startswith('Đóng hũ'):
                body['params']['Số hũ'] = str(
                    round(lot['fresh'] * end / 200))
            print('     %-26s %-12s %s → %s g'
                  % (step['title'], body['eventDate'],
                     body['inputQuantity'], body['outputQuantity']))
            created = None if dry else call(
                base, '/api/admin/process-events', 'POST', body)
            shot = step.get('photo')
            if shot:
                put_media(base, 'process_event',
                          created['id'] if created else 0,
                          shot[0], 'gallery', shot[1], dry)

        if dry:
            continue
        published = call(base, '/api/admin/product-batches/%s/publish'
                         % lot['code'], 'POST')
        print('  đã công bố phiên bản', published.get('version'))

    if dry:
        print('\nchạy thử, chưa đụng vào dữ liệu.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--to')
    parser.add_argument('--local', action='store_true')
    parser.add_argument('--dry', action='store_true')
    args = parser.parse_args()
    TOKEN = token()
    seed((args.to or (LOCAL if args.local else PRODUCTION)).rstrip('/'),
         args.dry)
