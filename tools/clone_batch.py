# -*- coding: utf-8 -*-
"""Nhân một lô đã có dữ liệu đầy đủ thành lô khác, để demo.

Dùng đúng API quản trị chứ không đụng thẳng vào database: mọi kiểm tra đầu vào
vẫn chạy, và lô mới có mã băm cùng giao dịch trên chuỗi của riêng nó.

    python tools/clone_batch.py TL-2026-002 TL-2026-003 --shift 2
    python tools/clone_batch.py TL-2026-002 TL-2026-001 --shift -26 --force

  --shift   số ngày dời mọi mốc thời gian so với lô nguồn, để hai lô không
            trùng ngày tháng.
  --force   lô đích đã có dữ liệu thì xoá sạch nguyên liệu, công đoạn và ảnh
            của nó rồi dựng lại. Không có cờ này thì dừng.

Ảnh được tải về rồi đẩy lên lại. Khoá R2 là mã băm nội dung nên file giống
nhau vẫn dùng chung một object, chỉ thêm bản ghi trong cơ sở dữ liệu.
"""
import argparse
import io
import json
import os
import re
import sys
import urllib.request
import uuid
from datetime import datetime, timedelta

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = os.environ.get('TRACE_BASE', 'https://trace.smartbreakfast.store')
UA = {'user-agent': 'tule-clone/1.0'}


def token():
    path = os.path.join(ROOT, 'worker', '.admin-token.txt')
    value = os.environ.get('ADMIN_TOKEN') or (
        io.open(path, encoding='utf-8').read().strip() if os.path.exists(path) else ''
    )
    if not value:
        sys.exit('Thiếu token quản trị (worker/.admin-token.txt hoặc ADMIN_TOKEN).')
    return value


def call(method, path, body=None, headers=None, soft=False):
    data = None
    head = dict(UA)
    head['authorization'] = 'Bearer ' + token()
    if body is not None:
        data = json.dumps(body, ensure_ascii=False).encode('utf-8')
        head['content-type'] = 'application/json; charset=utf-8'
    head.update(headers or {})
    req = urllib.request.Request(BASE + path, method=method, data=data)
    for key, value in head.items():
        req.add_header(key, value)
    try:
        with urllib.request.urlopen(req) as response:
            raw = response.read()
    except urllib.error.HTTPError as error:
        # `soft` dùng cho phép thử "lô này có chưa": 404 là câu trả lời, không
        # phải sự cố.
        if soft and error.code == 404:
            return None
        sys.exit('%s %s -> %s %s' % (method, path, error.code, error.read()[:300]))
    return json.loads(raw) if raw else None


def fetch(url):
    req = urllib.request.Request(BASE + url, headers=UA)
    with urllib.request.urlopen(req) as response:
        return response.read()


def shift_date(value, days):
    """Dời một ngày dạng dd.MM.yyyy. Chuỗi lạ thì trả về nguyên si."""
    if not value or not days:
        return value
    match = re.match(r'^(\d{2})\.(\d{2})\.(\d{4})$', str(value).strip())
    if not match:
        return value
    day, month, year = (int(part) for part in match.groups())
    moved = datetime(year, month, day) + timedelta(days=days)
    return moved.strftime('%d.%m.%Y')


def upload_asset(asset, owner_type, owner_id):
    """Tải ảnh từ lô nguồn rồi đẩy lên cho chủ sở hữu mới."""
    raw = fetch(asset['url'])
    boundary = '----tule' + uuid.uuid4().hex
    body = io.BytesIO()

    def write(text):
        body.write(text.encode('utf-8'))

    fields = [
        ('ownerType', owner_type),
        ('ownerId', str(owner_id)),
        ('role', asset.get('role') or 'gallery'),
        ('caption', asset.get('caption') or ''),
        ('certType', asset.get('certType')),
        ('certNumber', asset.get('certNumber')),
        ('validUntil', asset.get('validUntil')),
    ]
    for key, value in fields:
        if value is None:
            continue
        write('--%s\r\nContent-Disposition: form-data; name="%s"\r\n\r\n%s\r\n' % (boundary, key, value))
    write('--%s\r\nContent-Disposition: form-data; name="file"; filename="%s"\r\n'
          % (boundary, asset.get('fileName') or 'file'))
    write('Content-Type: %s\r\n\r\n' % (asset.get('contentType') or 'application/octet-stream'))
    body.write(raw)
    write('\r\n--%s--\r\n' % boundary)

    req = urllib.request.Request(BASE + '/api/admin/media', method='POST', data=body.getvalue())
    req.add_header('authorization', 'Bearer ' + token())
    req.add_header('content-type', 'multipart/form-data; boundary=' + boundary)
    req.add_header('user-agent', UA['user-agent'])
    try:
        with urllib.request.urlopen(req) as response:
            response.read()
    except urllib.error.HTTPError as error:
        sys.exit('tải ảnh hỏng: %s %s' % (error.code, error.read()[:300]))


def wipe(trace):
    """Xoá nguyên liệu, công đoạn ở xưởng và ảnh của lô đích."""
    for asset in trace.get('media', []):
        call('DELETE', '/api/admin/media/%s' % asset['id'])
    for event in trace.get('batchEvents', []):
        call('DELETE', '/api/admin/process-events/%s' % event['id'])
    # Xoá nguyên liệu kéo theo công đoạn và ảnh của nó.
    for item in trace.get('ingredients', []):
        call('DELETE', '/api/admin/ingredient-batches/%s' % item['id'])


def event_body(event, owner_key, owner_id, days):
    body = {
        owner_key: owner_id,
        'title': event.get('title') or '',
        'description': event.get('description') or '',
        'eventDate': shift_date(event.get('event_date') or event.get('eventDate'), days),
        'enteredBy': event.get('entered_by') or event.get('enteredBy') or '',
    }
    for key, source in (
        ('position', 'position'),
        ('operator', 'operator'),
        ('inputQuantity', 'input_quantity'),
        ('outputQuantity', 'output_quantity'),
        ('quantityUnit', 'quantity_unit'),
    ):
        value = event.get(source)
        if value is not None and value != '':
            body[key] = value
    params = event.get('params')
    if params:
        body['params'] = json.loads(params) if isinstance(params, str) else params
    return body


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('source')
    parser.add_argument('target')
    parser.add_argument('--shift', type=int, default=0, help='dời ngày tháng bao nhiêu ngày')
    parser.add_argument('--name', default='', help='đổi tên lô đích')
    parser.add_argument('--force', action='store_true', help='xoá dữ liệu cũ của lô đích')
    args = parser.parse_args()
    days = args.shift

    src = call('GET', '/api/admin/product-batches/%s/trace' % args.source)
    print('nguồn %s: %d nguyên liệu, %d công đoạn xưởng' %
          (args.source, len(src.get('ingredients', [])), len(src.get('batchEvents', []))))

    fields = {
        'name': args.name or src.get('name'),
        'productionDate': shift_date(src.get('production_date'), days),
        'expiryDate': shift_date(src.get('expiry_date'), days),
        'description': src.get('description') or '',
        'facilityName': src.get('facility_name') or '',
        'latitude': src.get('latitude'),
        'longitude': src.get('longitude'),
    }

    target = call('GET', '/api/admin/product-batches/%s/trace' % args.target, soft=True)

    if target:
        if not args.force:
            sys.exit('Lô %s đã có. Thêm --force nếu muốn dựng lại từ đầu.' % args.target)
        print('lô %s đã có, xoá dữ liệu cũ' % args.target)
        wipe(target)
        call('PATCH', '/api/admin/product-batches/%s' % args.target, fields)
        batch_id = target['id']
    else:
        created = call('POST', '/api/admin/product-batches', dict(fields, code=args.target))
        batch_id = created['id']
        print('đã tạo lô %s, id %s' % (args.target, batch_id))

    for asset in src.get('media', []):
        upload_asset(asset, 'product_batch', batch_id)
    print('  %d ảnh của lô' % len(src.get('media', [])))

    for item in src.get('ingredients', []):
        made = call('POST', '/api/admin/ingredient-batches', {
            'productBatchId': batch_id,
            'name': item.get('name'),
            'origin': item.get('origin'),
            'supplier': item.get('supplier') or '',
            'harvestDate': shift_date(item.get('harvest_date'), days),
            'receivedDate': shift_date(item.get('received_date'), days),
            'summary': item.get('summary') or '',
            'latitude': item.get('latitude'),
            'longitude': item.get('longitude'),
            'areaGeoJson': item.get('area_geojson'),
        })
        for asset in item.get('media', []):
            upload_asset(asset, 'ingredient_batch', made['id'])
        for event in item.get('processEvents', []):
            event_made = call('POST', '/api/admin/process-events',
                              event_body(event, 'ingredientBatchId', made['id'], days))
            for asset in event.get('media', []):
                upload_asset(asset, 'process_event', event_made['id'])
        print('  %s: %d công đoạn' % (item.get('name'), len(item.get('processEvents', []))))

    for event in src.get('batchEvents', []):
        event_made = call('POST', '/api/admin/process-events',
                          event_body(event, 'productBatchId', batch_id, days))
        for asset in event.get('media', []):
            upload_asset(asset, 'process_event', event_made['id'])
    print('  %d công đoạn ở xưởng' % len(src.get('batchEvents', [])))

    published = call('POST', '/api/admin/product-batches/%s/publish' % args.target,
                     {'publishedBy': 'admin'})
    print('đã công bố v%s, mã băm %s…' % (published.get('version'), str(published.get('sha256'))[:16]))
    print('%s/t/%s' % (BASE, args.target))


if __name__ == '__main__':
    main()
