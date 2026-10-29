# -*- coding: utf-8 -*-
"""Đổi ảnh bìa bốn lô Tú Lệ từ gói 30 g sang hộp quà 600 g.

Ảnh bìa là thứ người quét mã nhìn thấy đầu tiên và cũng là ảnh đại diện của
cả dòng sản phẩm trên trang chủ. Ảnh gói lẻ chụp trên nền một đống gói khác
không nhận ra sản phẩm, nên đổi sang ảnh hộp.

Ảnh bìa nằm trong phần dữ liệu đem đi băm, nên sau khi đổi phải công bố lại:
không công bố lại thì trang truy xuất báo lô sai lệch so với bản đã neo.
Ảnh gói 30 g không mất, nó lùi xuống thành ảnh phụ trong thư viện.

Chạy: python tools/doi_anh_bia_tule.py [--dry] [--local]
"""
import json
import mimetypes
import os
import sys
import urllib.request
import uuid

sys.stdout.reconfigure(encoding='utf-8')

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOKEN_FILE = os.path.join(ROOT, 'worker', '.admin-token.txt')

LOCAL = 'http://127.0.0.1:8799'
# Tên miền chính đi qua Pages và Pages chặn một số công cụ dòng lệnh (lỗi
# 1010), nên gọi admin thẳng vào worker.
PRODUCTION = 'https://tule-trace.sontm.workers.dev'

LOTS = ['TL-2026-001', 'TL-2026-002', 'TL-2026-003', 'TL-2026-004']

COVER = os.path.join(ROOT, 'assets', 'tule-box.jpg')
COVER_CAPTION = 'Hộp Tú Lệ Smart Breakfast 600 g'
SACHET = os.path.join(ROOT, 'assets', 'smartbreakfast', 'goi-le.jpg')
SACHET_CAPTION = 'Gói khẩu phần 30 g'

DRY = '--dry' in sys.argv
BASE = LOCAL if '--local' in sys.argv else PRODUCTION
TOKEN = open(TOKEN_FILE, encoding='utf-8').read().strip()


def call(method, path, body=None):
    data = json.dumps(body, ensure_ascii=False).encode() if body is not None else None
    request = urllib.request.Request(BASE + path, data=data, method=method, headers={
        'Authorization': 'Bearer ' + TOKEN,
        'Content-Type': 'application/json',
        'User-Agent': 'tule-trace-tools/1.0',
    })
    with urllib.request.urlopen(request) as response:
        return json.load(response)


def upload(owner_id, path, role, caption):
    """Gửi một file lên /api/admin/media bằng multipart dựng tay."""
    boundary = '----tule' + uuid.uuid4().hex
    mime = mimetypes.guess_type(path)[0] or 'application/octet-stream'
    parts = []
    for name, value in (('ownerType', 'product_batch'),
                        ('ownerId', str(owner_id)),
                        ('role', role),
                        ('caption', caption)):
        parts.append(
            ('--%s\r\nContent-Disposition: form-data; name="%s"\r\n\r\n%s\r\n'
             % (boundary, name, value)).encode())
    with open(path, 'rb') as handle:
        content = handle.read()
    parts.append(
        ('--%s\r\nContent-Disposition: form-data; name="file"; filename="%s"\r\n'
         'Content-Type: %s\r\n\r\n' % (boundary, os.path.basename(path), mime)).encode())
    parts.append(content)
    parts.append(('\r\n--%s--\r\n' % boundary).encode())
    body = b''.join(parts)

    request = urllib.request.Request(BASE + '/api/admin/media', data=body, method='POST',
                                     headers={
                                         'Authorization': 'Bearer ' + TOKEN,
                                         'Content-Type':
                                             'multipart/form-data; boundary=' + boundary,
                                         'User-Agent': 'tule-trace-tools/1.0',
                                     })
    with urllib.request.urlopen(request) as response:
        return json.load(response)


def main():
    for code in LOTS:
        batch = call('GET', '/api/admin/product-batches/%s/trace' % code)
        covers = [m for m in batch['media'] if m['role'] == 'cover']
        print('==', code, '- ảnh bìa đang có:',
              ', '.join(m.get('caption') or str(m['id']) for m in covers) or 'không')

        # Gỡ ảnh bìa cũ trước rồi mới đính ảnh mới: hai ảnh cùng vai trò bìa
        # thì trang hiển thị cái nào là tuỳ thứ tự, không đoán được.
        for media in covers:
            print('   gỡ ảnh bìa cũ', media['id'])
            if not DRY:
                call('DELETE', '/api/admin/media/%d' % media['id'])

        print('   đính ảnh bìa mới:', os.path.basename(COVER))
        if not DRY:
            upload(batch['id'], COVER, 'cover', COVER_CAPTION)

        # Gói 30 g vẫn là một quy cách thật của sản phẩm nên giữ lại trong
        # thư viện ảnh, chỉ thôi làm ảnh đại diện.
        has_sachet = any(SACHET_CAPTION in (m.get('caption') or '')
                         for m in batch['media'])
        if has_sachet:
            print('   ảnh gói 30 g đã có trong thư viện')
        else:
            print('   chuyển ảnh gói 30 g xuống thư viện')
            if not DRY:
                upload(batch['id'], SACHET, 'gallery', SACHET_CAPTION)

        if DRY:
            print('   (dry) sẽ công bố lại')
        else:
            result = call('POST', '/api/admin/product-batches/%s/publish' % code, {})
            print('   công bố lại: bản', result['version'], result['sha256'][:12])


if __name__ == '__main__':
    main()
