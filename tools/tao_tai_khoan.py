# -*- coding: utf-8 -*-
"""Tạo các tài khoản đầu tiên cho bản đang chạy thật.

    python tools/tao_tai_khoan.py --production

Mật khẩu sinh ngẫu nhiên và KHÔNG in ra màn hình. Script ghi chúng vào
`worker/.tai-khoan.txt` (đã nằm trong .gitignore) để bạn mở ra đọc rồi đưa cho
từng người, và người đó tự đổi ở mục "Đổi mật khẩu" sau lần đăng nhập đầu.

Họ tên để dạng chức danh, không đặt tên người thật: đổi lại trong mục Tài khoản
của màn quản trị khi biết ai sẽ dùng tài khoản nào.

Script chỉ tạo tài khoản chưa có; chạy lại không ghi đè tài khoản đang dùng.
"""
import argparse
import json
import os
import secrets
import sys
import urllib.error
import urllib.request

sys.stdout.reconfigure(encoding='utf-8')

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOCAL = 'http://127.0.0.1:8799'
PRODUCTION_ADMIN = 'https://tule-trace.sontm.workers.dev'

# Chữ cái dễ đọc: bỏ 0/O và 1/l để đọc qua điện thoại không nhầm.
ALPHABET = 'abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789'

ACCOUNTS = [
    {
        'username': 'quantri',
        'fullName': 'Quản trị hệ thống',
        'role': 'ADMIN',
        'facilityCode': None,
    },
    {
        'username': 'tule.phutrach',
        'fullName': 'Phụ trách cơ sở Tú Lệ Smart Breakfast',
        'role': 'FACILITY',
        'facilityCode': 'TULE',
    },
    {
        'username': 'trau.phutrach',
        'fullName': 'Phụ trách cơ sở thịt trâu gác bếp',
        'role': 'FACILITY',
        'facilityCode': 'TRAU',
    },
    {
        'username': 'tule.nhanvien',
        'fullName': 'Nhân viên công đoạn Tú Lệ',
        'role': 'STAFF',
        'facilityCode': 'TULE',
    },
    {
        'username': 'trau.nhanvien',
        'fullName': 'Nhân viên công đoạn thịt trâu',
        'role': 'STAFF',
        'facilityCode': 'TRAU',
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


def call(base, path, method='GET', body=None):
    request = urllib.request.Request(
        base + path,
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
        sys.exit('%s %s -> %s %s' % (method, path, error.code, detail))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--production', action='store_true')
    parser.add_argument('--base')
    parser.add_argument('--token')
    args = parser.parse_args()

    base = args.base or (PRODUCTION_ADMIN if args.production else LOCAL)
    global TOKEN
    TOKEN = args.token or token(base)

    facilities = {row['code']: row['id'] for row in call(base, '/api/admin/facilities')}
    existing = {row['username'] for row in call(base, '/api/admin/users')}

    lines = []
    for account in ACCOUNTS:
        if account['username'] in existing:
            print('bỏ qua %s (đã có)' % account['username'])
            continue
        password = ''.join(secrets.choice(ALPHABET) for _ in range(14))
        call(base, '/api/admin/users', 'POST', {
            'username': account['username'],
            'password': password,
            'fullName': account['fullName'],
            'role': account['role'],
            'facilityId': facilities.get(account['facilityCode']),
        })
        print('đã tạo %s (%s)' % (account['username'], account['role']))
        lines.append('%-16s %-14s %s' % (
            account['username'], password, account['fullName']))

    if not lines:
        return
    target = os.path.join(ROOT, 'worker', '.tai-khoan.txt')
    with open(target, 'a', encoding='utf-8') as handle:
        handle.write('# %s\n' % base)
        handle.write('# Mật khẩu ban đầu. Người dùng tự đổi sau lần đăng nhập đầu.\n')
        for line in lines:
            handle.write(line + '\n')
        handle.write('\n')
    print('\nMật khẩu đã ghi vào worker/.tai-khoan.txt (không in ra đây).')


if __name__ == '__main__':
    main()
