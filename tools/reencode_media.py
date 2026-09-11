# -*- coding: utf-8 -*-
"""Nén lại ảnh của một lô sang WebP.

Vì sao phải tải lên file mới chứ không ghi đè file cũ trong R2: khoá R2 là mã
băm của chính nội dung file, và khoá đó nằm trong bản công bố đã đem đi băm và
neo lên chuỗi. Ghi đè nội dung mà giữ nguyên khoá là để một cái tên nói dối về
thứ nó chứa. Nên quy trình là: tải lên bản WebP (khoá mới), xoá bản cũ, rồi
công bố một phiên bản mới - đúng cái việc mà hệ thống sinh ra để làm.

    python tools/reencode_media.py TL-2026-002 --dry-run
    python tools/reencode_media.py TL-2026-002
    python tools/reencode_media.py TL-2026-002 --publish

Cần Pillow (pip install pillow) và token quản trị ở worker/.admin-token.txt.
"""
import argparse
import io
import json
import os
import sys
import urllib.request
import uuid

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = os.environ.get('TRACE_BASE', 'https://trace.smartbreakfast.store')
UA = {'user-agent': 'tule-reencode/1.0'}

# Cùng công thức với lib/ui/media_manager.dart. Hai chỗ phải khớp nhau, vì ảnh
# tải lên từ giao diện và ảnh nén lại bằng script phải ra cùng một chất lượng.
RECIPES = {
    'cover': (1400, 82),
    'area_map': (1600, 88),
    'lab_report': (2000, 86),
    'certificate': (2000, 86),
}
DEFAULT_RECIPE = (1280, 80)


def token():
    path = os.path.join(ROOT, 'worker', '.admin-token.txt')
    value = os.environ.get('ADMIN_TOKEN') or (
        io.open(path, encoding='utf-8').read().strip() if os.path.exists(path) else ''
    )
    if not value:
        sys.exit('Thiếu token quản trị (worker/.admin-token.txt hoặc ADMIN_TOKEN).')
    return value


def call(method, path, body=None, headers=None, raw=False):
    req = urllib.request.Request(BASE + path, method=method, data=body)
    for key, value in {**UA, 'authorization': f'Bearer {token()}', **(headers or {})}.items():
        req.add_header(key, value)
    with urllib.request.urlopen(req) as response:
        data = response.read()
    return data if raw else json.loads(data or b'{}')


def fetch(url):
    req = urllib.request.Request(BASE + url, headers=UA)
    with urllib.request.urlopen(req) as response:
        return response.read()


def collect(trace):
    """Mọi ảnh của lô, kèm chủ sở hữu, theo đúng thứ tự id."""
    items = []

    def add(asset, owner_type, owner_id, where):
        if asset.get('kind') != 'image':
            return
        items.append({
            'asset': asset,
            'ownerType': owner_type,
            'ownerId': owner_id,
            'where': where,
        })

    for asset in trace.get('media', []):
        add(asset, 'product_batch', trace['id'], 'lô')
    for ingredient in trace.get('ingredients', []):
        for asset in ingredient.get('media', []):
            add(asset, 'ingredient_batch', ingredient['id'], ingredient['name'])
        for event in ingredient.get('processEvents', []):
            for asset in event.get('media', []):
                add(asset, 'process_event', event['id'], event['title'])
    for event in trace.get('batchEvents', []):
        for asset in event.get('media', []):
            add(asset, 'process_event', event['id'], event['title'])
    items.sort(key=lambda item: item['asset']['id'])
    return items


def reencode(raw, role):
    max_edge, quality = RECIPES.get(role, DEFAULT_RECIPE)
    image = Image.open(io.BytesIO(raw))
    image.load()
    width, height = image.size
    # Nền trắng như bản chạy trên trình duyệt: vùng trong suốt của PNG không
    # được thành ô đen giữa trang.
    if image.mode in ('RGBA', 'LA', 'P'):
        flat = Image.new('RGB', image.size, (255, 255, 255))
        rgba = image.convert('RGBA')
        flat.paste(rgba, mask=rgba.split()[-1])
        image = flat
    else:
        image = image.convert('RGB')
    longest = max(width, height)
    if longest > max_edge:
        scale = max_edge / longest
        image = image.resize(
            (max(1, round(width * scale)), max(1, round(height * scale))),
            Image.LANCZOS,
        )
    out = io.BytesIO()
    image.save(out, 'WEBP', quality=quality, method=6)
    return out.getvalue(), image.size


def multipart(fields, file_name, file_bytes, content_type='image/webp'):
    boundary = f'----tule{uuid.uuid4().hex}'
    body = io.BytesIO()

    def write(text):
        body.write(text.encode('utf-8'))

    for key, value in fields.items():
        if value is None:
            continue
        write(f'--{boundary}\r\nContent-Disposition: form-data; name="{key}"\r\n\r\n{value}\r\n')
    write(f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="{file_name}"\r\n')
    write(f'Content-Type: {content_type}\r\n\r\n')
    body.write(file_bytes)
    write(f'\r\n--{boundary}--\r\n')
    return body.getvalue(), f'multipart/form-data; boundary={boundary}'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('code')
    parser.add_argument('--dry-run', action='store_true', help='chỉ đo, không đụng dữ liệu')
    parser.add_argument('--publish', action='store_true', help='công bố bản mới sau khi xong')
    parser.add_argument(
        '--min-gain',
        type=int,
        default=12,
        help='bỏ qua ảnh nếu bản WebP không nhẹ hơn được ngần này phần trăm',
    )
    args = parser.parse_args()

    trace = call('GET', f'/api/admin/product-batches/{args.code}/trace')
    items = collect(trace)
    print(f'{len(items)} ảnh trong lô {args.code}')

    before = after = 0
    for item in items:
        asset = item['asset']
        if asset.get('contentType') == 'image/webp':
            item['plan'] = 'keep'
            before += asset.get('size', 0)
            after += asset.get('size', 0)
            continue

        raw = fetch(asset['url'])
        webp, size = reencode(raw, asset['role'])
        before += len(raw)
        gain = 100 - round(100 * len(webp) / len(raw))
        item['raw'] = raw

        # Ảnh JPEG vốn đã nén tốt ở đúng kích thước hiển thị thì mã hoá lại chỉ
        # đổi một lần mất mát nữa lấy vài phần trăm dung lượng. Không đáng.
        if gain < args.min_gain:
            item['plan'] = 'keep'
            after += len(raw)
            print(
                f"  #{asset['id']:>3} {asset['role']:<11} {item['where'][:26]:<26} "
                f"{len(raw)//1024:>5}KB    giữ nguyên (chỉ nhẹ được {gain}%)"
            )
            continue

        item['plan'] = 'webp'
        item['webp'] = webp
        after += len(webp)
        print(
            f"  #{asset['id']:>3} {asset['role']:<11} {item['where'][:26]:<26} "
            f"{len(raw)//1024:>5}KB -> {len(webp)//1024:>4}KB  {size[0]}x{size[1]}  -{gain}%"
        )

    print()
    print(f'tổng: {before/1048576:.2f} MB -> {after/1048576:.2f} MB '
          f'({100 - round(100*after/before) if before else 0}% nhẹ hơn)')

    if args.dry_run:
        return

    # Tải lên cả nhóm chứ không chỉ ảnh có đổi: id mới luôn lớn hơn id cũ, nên
    # nếu chỉ thay một tấm giữa nhóm thì tấm đó nhảy xuống cuối dải ảnh. Ảnh
    # không đổi được tải lại bằng đúng byte gốc, không mã hoá lại lần nữa.
    groups = {}
    for item in items:
        key = (item['ownerType'], item['ownerId'], item['asset']['role'])
        groups.setdefault(key, []).append(item)

    for key, group in groups.items():
        if not any(item.get('plan') == 'webp' for item in group):
            continue
        print(f'  tải lại nhóm {key[0]} #{key[1]} / {key[2]}: {len(group)} ảnh')
        for item in group:
            asset = item['asset']
            if item.get('plan') == 'webp':
                payload = item['webp']
                ctype = 'image/webp'
                name = asset['fileName'].rsplit('.', 1)[0][:60] + '.webp'
            else:
                payload = item.get('raw') or fetch(asset['url'])
                ctype = asset.get('contentType', 'image/jpeg')
                name = asset['fileName']
            fields = {
                'ownerType': item['ownerType'],
                'ownerId': str(item['ownerId']),
                'role': asset['role'],
                'caption': asset.get('caption', ''),
                'certType': asset.get('certType'),
                'certNumber': asset.get('certNumber'),
                'validUntil': asset.get('validUntil'),
            }
            body, content_type = multipart(fields, name, payload, ctype)
            call('POST', '/api/admin/media', body, {'content-type': content_type})
        for item in group:
            call('DELETE', f"/api/admin/media/{item['asset']['id']}")

    if args.publish:
        result = call(
            'POST',
            f'/api/admin/product-batches/{args.code}/publish',
            json.dumps({'publishedBy': 'admin'}).encode('utf-8'),
            {'content-type': 'application/json'},
        )
        print('đã công bố bản v%s, hash %s' % (result.get('version'), str(result.get('sha256'))[:16]))


if __name__ == '__main__':
    main()
