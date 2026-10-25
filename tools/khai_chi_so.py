# -*- coding: utf-8 -*-
"""Khai các chỉ số cho báo cáo vào trang Chỉ số của hệ thống.

    python tools/khai_chi_so.py                 # khai vào máy chủ local
    python tools/khai_chi_so.py --production    # khai vào bản đang chạy thật
    python tools/khai_chi_so.py --xem           # chỉ đọc, không ghi

Trang Chỉ số có hai nửa. Nửa "hệ thống tự đếm" là bộ đếm lượt mở hồ sơ, không
ai khai được, kể cả script này. Nửa "cơ sở sản xuất cung cấp" là những con số
hệ thống không đo được, và đó là phần script này ghi.

MỖI CHỈ SỐ BẮT BUỘC CÓ NGUỒN. Máy chủ từ chối bản ghi để trống ô nguồn, và
giao diện luôn hiện nguồn ngay dưới con số. Lý do: người chấm hồ sơ sẽ hỏi con
số này ở đâu ra, và một con số không trả lời được câu đó thì bỏ ra khỏi báo cáo
còn hơn.

Token quản trị đọc từ (theo thứ tự): --token, biến môi trường ADMIN_TOKEN,
worker/.admin-token.txt cho production, worker/.dev.vars cho máy local. Script
không in token ra màn hình.
"""
import argparse
import json
import os
import sys
import urllib.error
import urllib.request

sys.stdout.reconfigure(encoding='utf-8')

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

LOCAL = 'http://127.0.0.1:8799'
# Gọi admin đi thẳng vào worker: tên miền chính đi qua Cloudflare Pages và
# Pages chặn một số công cụ dòng lệnh bằng lỗi 1010.
PRODUCTION_ADMIN = 'https://tule-trace.sontm.workers.dev'

# Chỉ số do cơ sở sản xuất và bộ phận phân tích nghiệp vụ cung cấp.
#
# Sửa giá trị ở đây khi có số mới, nhưng KHÔNG được sửa một giá trị mà để
# nguyên dòng nguồn cũ. Số đổi thì nguồn phải đổi theo, nếu không thì dòng
# nguồn trở thành lời nói dối có chữ ký.
METRICS = [
    {
        'key': 'nguoi-su-dung',
        'label': 'Số người sử dụng sản phẩm',
        'value': '1.315 người',
        'source': 'Danh sách khách hàng và phiếu khảo sát của cơ sở sản xuất, '
                  'do bộ phận phân tích nghiệp vụ tổng hợp (10/2026)',
        'note': 'Người mua quét mã QR không cần tài khoản, nên đây là số do cơ '
                'sở sản xuất cung cấp chứ không phải số tài khoản trên hệ '
                'thống. Hệ thống đang có tài khoản cho người nhập liệu theo '
                'ba vai trò, xem mục Tài khoản.',
    },
    {
        'key': 'luot-truy-cap-ha-tang',
        'label': 'Lượt truy cập trước khi bật bộ đếm',
        'value': '1.806 lượt',
        'source': 'Thống kê truy cập Cloudflare Pages của tên miền '
                  'trace.smartbreakfast.store, đọc ngày 21/10/2026',
        'note': 'Giai đoạn 21/09–21/10/2026, 0 lỗi. Đây là số của lớp hạ tầng, '
                'chụp lại được trên dash.cloudflare.com. Bộ đếm trong hệ thống '
                'bắt đầu từ ngày bật nên không bao giai đoạn này.',
    },
]


def token(base):
    if os.environ.get('ADMIN_TOKEN'):
        return os.environ['ADMIN_TOKEN']
    name = '.admin-token.txt' if 'workers.dev' in base else '.dev.vars'
    path = os.path.join(ROOT, 'worker', name)
    if not os.path.exists(path):
        sys.exit('Không thấy %s để lấy token quản trị.' % path)
    with open(path, encoding='utf-8') as handle:
        text = handle.read()
    if name == '.dev.vars':
        for line in text.splitlines():
            if line.strip().startswith('ADMIN_TOKEN'):
                return line.split('=', 1)[1].strip().strip('"\'')
        sys.exit('Không thấy ADMIN_TOKEN trong worker/.dev.vars')
    return text.strip()


def call(base, key, method, body=None):
    request = urllib.request.Request(
        '%s/api/admin/metrics%s' % (base, '/' + key if key else ''),
        method=method,
        data=json.dumps(body).encode('utf-8') if body else None,
        headers={
            'authorization': 'Bearer %s' % TOKEN,
            # Cloudflare chặn user-agent mặc định của urllib bằng lỗi 1010.
            'User-Agent': 'tule-trace-tools/1.0',
            **({'content-type': 'application/json'} if body else {}),
        },
    )
    try:
        with urllib.request.urlopen(request) as response:
            return json.loads(response.read().decode('utf-8'))
    except urllib.error.HTTPError as error:
        detail = error.read().decode('utf-8', 'replace')[:300]
        sys.exit('%s %s -> %s %s' % (method, key or '', error.code, detail))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--production', action='store_true')
    parser.add_argument('--base')
    parser.add_argument('--token')
    parser.add_argument('--xem', action='store_true', help='chỉ đọc, không ghi')
    args = parser.parse_args()

    base = args.base or (PRODUCTION_ADMIN if args.production else LOCAL)
    global TOKEN
    TOKEN = args.token or token(base)

    if not args.xem:
        for metric in METRICS:
            call(base, metric['key'], 'PUT', metric)
            print('đã khai %s' % metric['key'])

    data = call(base, '', 'GET')
    views = data.get('views', {})
    print('\n--- hệ thống tự đếm ---')
    print('%s lượt mở hồ sơ, trên %s lô'
          % (views.get('total', 0), views.get('batches', 0)))
    for row in views.get('byBatch', []):
        print('  %-18s %s lượt' % (row['code'], row['views']))
    print('\n--- cơ sở sản xuất cung cấp ---')
    for row in data.get('reported', []):
        print('  %s: %s' % (row['label'], row['value']))
        print('      nguồn: %s' % row['source'])


if __name__ == '__main__':
    main()
