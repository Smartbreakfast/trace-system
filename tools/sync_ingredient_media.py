# -*- coding: utf-8 -*-
"""Đồng bộ ảnh của từng nguyên liệu từ một lô nguồn sang các lô khác.

Dùng khi người vận hành sửa ảnh vùng nguyên liệu ở một lô rồi muốn các lô còn
lại giống hệt. Ghép theo **tên nguyên liệu**, nên lô đích phải có cùng bộ tên.

    python tools/sync_ingredient_media.py TL-2026-002 TL-2026-001 TL-2026-003
    python tools/sync_ingredient_media.py TL-2026-002 TL-2026-003 --dry-run

Ảnh cũ của nguyên liệu ở lô đích bị xoá hết rồi chép lại theo nguồn, để hai bên
giống nhau cả về thứ tự. Ảnh của lô và của công đoạn không đụng tới.
"""
import argparse
import io
import json
import os
import sys
import urllib.error
import urllib.request
import uuid

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = os.environ.get('TRACE_BASE', 'https://trace.smartbreakfast.store')
AGENT = 'tule-sync/1.0'


def token():
    path = os.path.join(ROOT, 'worker', '.admin-token.txt')
    value = os.environ.get('ADMIN_TOKEN') or (
        io.open(path, encoding='utf-8').read().strip() if os.path.exists(path) else ''
    )
    if not value:
        sys.exit('Thiếu token quản trị (worker/.admin-token.txt hoặc ADMIN_TOKEN).')
    return value


def call(method, path, body=None):
    data = json.dumps(body, ensure_ascii=False).encode('utf-8') if body is not None else None
    req = urllib.request.Request(BASE + path, method=method, data=data)
    req.add_header('user-agent', AGENT)
    req.add_header('authorization', 'Bearer ' + token())
    if data:
        req.add_header('content-type', 'application/json; charset=utf-8')
    try:
        with urllib.request.urlopen(req) as response:
            raw = response.read()
    except urllib.error.HTTPError as error:
        sys.exit('%s %s -> %s %s' % (method, path, error.code, error.read()[:300]))
    return json.loads(raw) if raw else None


def fetch(url):
    req = urllib.request.Request(BASE + url, headers={'user-agent': AGENT})
    with urllib.request.urlopen(req) as response:
        return response.read()


def upload(asset, owner_id):
    raw = fetch(asset['url'])
    boundary = '----tule' + uuid.uuid4().hex
    body = io.BytesIO()

    def write(text):
        body.write(text.encode('utf-8'))

    fields = [
        ('ownerType', 'ingredient_batch'),
        ('ownerId', str(owner_id)),
        ('role', asset.get('role') or 'gallery'),
        ('caption', asset.get('caption') or ''),
    ]
    for key, value in fields:
        write('--%s\r\nContent-Disposition: form-data; name="%s"\r\n\r\n%s\r\n' % (boundary, key, value))
    write('--%s\r\nContent-Disposition: form-data; name="file"; filename="%s"\r\n'
          % (boundary, asset.get('fileName') or 'anh'))
    write('Content-Type: %s\r\n\r\n' % (asset.get('contentType') or 'application/octet-stream'))
    body.write(raw)
    write('\r\n--%s--\r\n' % boundary)

    req = urllib.request.Request(BASE + '/api/admin/media', method='POST', data=body.getvalue())
    req.add_header('user-agent', AGENT)
    req.add_header('authorization', 'Bearer ' + token())
    req.add_header('content-type', 'multipart/form-data; boundary=' + boundary)
    try:
        with urllib.request.urlopen(req) as response:
            response.read()
    except urllib.error.HTTPError as error:
        sys.exit('tải ảnh hỏng: %s %s' % (error.code, error.read()[:300]))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('source')
    parser.add_argument('targets', nargs='+')
    parser.add_argument('--dry-run', action='store_true')
    parser.add_argument('--no-publish', action='store_true')
    args = parser.parse_args()

    src = call('GET', '/api/admin/product-batches/%s/trace' % args.source)
    wanted = {item['name']: item.get('media', []) for item in src.get('ingredients', [])}
    print('nguồn %s:' % args.source)
    for name, assets in wanted.items():
        print('  %-20s %s' % (name[:20], ', '.join('%s/%s' % (a['role'], a.get('fileName') or '') for a in assets) or '(không ảnh)'))

    for code in args.targets:
        target = call('GET', '/api/admin/product-batches/%s/trace' % code)
        print('\n%s:' % code)
        for item in target.get('ingredients', []):
            assets = wanted.get(item['name'])
            if assets is None:
                print('  %-20s KHÔNG có ở lô nguồn, bỏ qua' % item['name'][:20])
                continue
            old = item.get('media', [])
            same = [a.get('sha256') for a in old] == [a.get('sha256') for a in assets]
            if same:
                print('  %-20s đã giống nguồn' % item['name'][:20])
                continue
            print('  %-20s xoá %d ảnh, chép %d ảnh' % (item['name'][:20], len(old), len(assets)))
            if args.dry_run:
                continue
            for asset in old:
                call('DELETE', '/api/admin/media/%s' % asset['id'])
            for asset in assets:
                upload(asset, item['id'])

        if args.dry_run or args.no_publish:
            continue
        published = call('POST', '/api/admin/product-batches/%s/publish' % code, {'publishedBy': 'admin'})
        print('  đã công bố v%s, mã băm %s…' % (published.get('version'), str(published.get('sha256'))[:16]))


if __name__ == '__main__':
    main()
