"""Nạp ảnh minh hoạ cho lô demo TL-2026-001.

    python scripts/demo_media.py            # dùng http://127.0.0.1:8787
    python scripts/demo_media.py https://... TOKEN

Ảnh được vẽ bằng PIL ngay tại chỗ, cố ý trông ra hình đồ hoạ chứ không giống
ảnh chụp. Một trang truy xuất mà dán ảnh nông trại tải trên mạng vào thì chính
là kiểu bằng chứng giả mà sản phẩm này sinh ra để chống.

Chạy lại sau mỗi lần `npm run db:seed:local`, vì seed xoá sạch bảng media.
Cần: pip install pillow
"""

import json
import math
import os
import random
import sys
import urllib.request
import uuid

from PIL import Image, ImageDraw, ImageFilter, ImageFont

# Console Windows mặc định là cp1252, in tiếng Việt vào đó sẽ nổ.
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

BASE = sys.argv[1] if len(sys.argv) > 1 else 'http://127.0.0.1:8787'
TOKEN = sys.argv[2] if len(sys.argv) > 2 else 'dev-token-tule'
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '.demo-media')
os.makedirs(OUT, exist_ok=True)

INK = (25, 54, 43)
CREAM = (247, 245, 237)

ACCENTS = [
    (107, 165, 109),
    (182, 92, 69),
    (226, 165, 69),
    (135, 107, 158),
]

FONT_PATH = 'C:/Windows/Fonts/segoeui.ttf'
FONT_BOLD = 'C:/Windows/Fonts/segoeuib.ttf'


def font(path, size):
    try:
        return ImageFont.truetype(path, size)
    except OSError:
        return ImageFont.load_default()


def mix(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def make_image(path, accent, index, title, subtitle, seed):
    width, height = 900, 620
    image = Image.new('RGB', (width, height), mix(accent, CREAM, 0.78))
    draw = ImageDraw.Draw(image, 'RGBA')
    rng = random.Random(seed)

    # Vài dải cong nhạt, gợi ruộng bậc thang mà không giả làm ảnh chụp.
    for band in range(7):
        offset = height * (0.25 + band * 0.11)
        amplitude = 26 + rng.random() * 34
        phase = rng.random() * math.tau
        points = []
        for x in range(0, width + 20, 20):
            y = offset + math.sin(x / 190 + phase) * amplitude
            points.append((x, y))
        points += [(width, height), (0, height)]
        draw.polygon(points, fill=mix(accent, CREAM, 0.62 - band * 0.055) + (200,))

    # Vòng tròn lớn làm điểm nhìn.
    glow = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse(
        (width - 330, -110, width + 90, 310), fill=accent + (70,)
    )
    image = Image.alpha_composite(
        image.convert('RGBA'), glow.filter(ImageFilter.GaussianBlur(28))
    ).convert('RGB')
    draw = ImageDraw.Draw(image, 'RGBA')

    # Số thứ tự công đoạn. Ảnh bìa không có số nên bỏ qua.
    if index > 0:
        draw.ellipse((56, 52, 132, 128), fill=INK)
        number = font(FONT_BOLD, 34)
        box = draw.textbbox((0, 0), str(index), font=number)
        draw.text(
            (94 - (box[2] - box[0]) / 2, 90 - (box[3] - box[1]) / 2 - box[1]),
            str(index),
            font=number,
            fill=CREAM,
        )

    # Dải chữ dưới cùng.
    draw.rectangle((0, height - 168, width, height), fill=CREAM + (232,))
    draw.text((58, height - 138), title, font=font(FONT_BOLD, 40), fill=INK)
    draw.text((58, height - 78), subtitle, font=font(FONT_PATH, 26), fill=(90, 101, 96))

    # Nhãn demo, để không ai nhầm đây là ảnh tư liệu thật.
    tag = 'ẢNH MINH HOẠ'
    tag_font = font(FONT_BOLD, 20)
    box = draw.textbbox((0, 0), tag, font=tag_font)
    tw, th = box[2] - box[0], box[3] - box[1]
    draw.rounded_rectangle(
        (width - tw - 92, 56, width - 44, 56 + th + 26), 10, fill=INK + (210,)
    )
    draw.text((width - tw - 68, 66), tag, font=tag_font, fill=CREAM)

    image.save(path, 'PNG', optimize=True)


def get(path):
    with urllib.request.urlopen(BASE + path) as response:
        return json.loads(response.read().decode('utf-8'))


trace = get('/api/public/traces/TL-2026-001')

jobs = []

# Ảnh bìa lô.
cover = os.path.join(OUT, 'cover.png')
make_image(
    cover,
    (107, 165, 109),
    0,
    'Tú Lệ Smart Breakfast',
    'Bột ngũ cốc từ bốn nông sản bản địa',
    seed=1,
)
jobs.append(
    {
        'file': cover,
        'ownerType': 'product_batch',
        'ownerId': trace['id'],
        'role': 'cover',
        'caption': 'Ảnh minh hoạ gói thành phẩm (dữ liệu demo)',
    }
)

for i, ingredient in enumerate(trace['ingredients']):
    accent = ACCENTS[i % len(ACCENTS)]

    # Một ảnh cho chính vùng nguyên liệu.
    path = os.path.join(OUT, 'ingredient-%d.png' % ingredient['id'])
    make_image(path, accent, i + 1, ingredient['name'], ingredient['origin'], seed=10 + i)
    jobs.append(
        {
            'file': path,
            'ownerType': 'ingredient_batch',
            'ownerId': ingredient['id'],
            'role': 'gallery',
            'caption': 'Vùng nguyên liệu %s (ảnh minh hoạ)' % ingredient['origin'],
        }
    )

    for j, event in enumerate(ingredient['processEvents']):
        path = os.path.join(OUT, 'event-%d.png' % event['id'])
        make_image(
            path,
            accent,
            j + 1,
            event['title'],
            '%s · %s' % (ingredient['name'], event['event_date']),
            seed=100 + event['id'],
        )
        jobs.append(
            {
                'file': path,
                'ownerType': 'process_event',
                'ownerId': event['id'],
                'role': 'gallery',
                'caption': 'Ảnh minh hoạ công đoạn (dữ liệu demo)',
            }
        )

print('Đã sinh', len(jobs), 'ảnh ->', OUT)


def upload(job):
    boundary = uuid.uuid4().hex
    lines = []

    def field(name, value):
        lines.append(('--%s\r\n' % boundary).encode())
        lines.append(
            ('Content-Disposition: form-data; name="%s"\r\n\r\n' % name).encode()
        )
        lines.append(str(value).encode('utf-8'))
        lines.append(b'\r\n')

    field('ownerType', job['ownerType'])
    field('ownerId', job['ownerId'])
    field('role', job['role'])
    field('caption', job['caption'])

    name = os.path.basename(job['file'])
    lines.append(('--%s\r\n' % boundary).encode())
    lines.append(
        (
            'Content-Disposition: form-data; name="file"; filename="%s"\r\n' % name
        ).encode()
    )
    lines.append(b'Content-Type: image/png\r\n\r\n')
    lines.append(open(job['file'], 'rb').read())
    lines.append(b'\r\n')
    lines.append(('--%s--\r\n' % boundary).encode())

    body = b''.join(lines)
    request = urllib.request.Request(
        BASE + '/api/admin/media',
        data=body,
        method='POST',
        headers={
            'Authorization': 'Bearer ' + TOKEN,
            'Content-Type': 'multipart/form-data; boundary=' + boundary,
        },
    )
    with urllib.request.urlopen(request) as response:
        return json.loads(response.read().decode('utf-8'))


ok = 0
for job in jobs:
    try:
        result = upload(job)
        ok += 1
        print('%-16s %-4s %s' % (job['ownerType'], job['ownerId'], result['url']))
    except Exception as error:  # noqa: BLE001
        print('FAILED', job['file'], error)

print('uploaded', ok, 'of', len(jobs))

# Công bố lại để hash khớp với hồ sơ vừa có thêm ảnh.
publish = urllib.request.Request(
    BASE + '/api/admin/product-batches/TL-2026-001/publish',
    data=json.dumps({'enteredBy': 'demo-seed'}).encode(),
    method='POST',
    headers={
        'Authorization': 'Bearer ' + TOKEN,
        'Content-Type': 'application/json',
    },
)
with urllib.request.urlopen(publish) as response:
    print('republished', json.loads(response.read().decode('utf-8')))
