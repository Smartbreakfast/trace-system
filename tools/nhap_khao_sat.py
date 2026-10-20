# -*- coding: utf-8 -*-
"""Nhập đánh giá thật từ phiếu khảo sát (CSV) vào hệ thống, nhãn nguồn SURVEY.

    python tools/nhap_khao_sat.py phieu.csv                  # vào máy local
    python tools/nhap_khao_sat.py phieu.csv --production      # vào bản chạy thật

Tệp CSV có dòng đầu là tên cột, cần đúng ba cột đầu, hai cột sau tuỳ chọn:

    ma_lo,so_sao,nhan_xet,ten,ngay
    TL-2026-004,5,Quét mã ra đúng lô,Nguyễn T. H.,12/10/2026
    TB-2026-001,4,,Trần V. A.,

  - `ma_lo`    mã lô in trên bao bì, ví dụ TL-2026-004
  - `so_sao`   1 đến 5
  - `nhan_xet` để trống được, khi đó phiếu chỉ tính vào điểm trung bình
  - `ten`      để trống thì hiện là "Khách ẩn danh"
  - `ngay`     dd/mm/yyyy hoặc yyyy-mm-dd; để trống thì lấy thời điểm nhập

Mỗi dòng mang một mã phiếu riêng suy từ tên tệp và số dòng, nên nhập lại cùng
một tệp là SỬA các phiếu cũ, không nhân đôi số liệu.

Nhập xong nhớ bỏ dữ liệu dựng sẵn nếu còn:

    python tools/seed_ratings.py --clear   (thêm --production nếu làm trên bản thật)
"""
import argparse
import csv
import os
import sys
from datetime import datetime, timezone

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from seed_ratings import LOCAL, PRODUCTION_ADMIN, admin_token, call  # noqa: E402


def parse_date(raw):
    text = (raw or '').strip()
    if not text:
        return None
    for shape in ('%d/%m/%Y', '%Y-%m-%d', '%d.%m.%Y', '%d-%m-%Y'):
        try:
            parsed = datetime.strptime(text, shape)
        except ValueError:
            continue
        return parsed.replace(tzinfo=timezone.utc).isoformat().replace('+00:00', 'Z')
    sys.exit('Ngày không đọc được: %r. Dùng dd/mm/yyyy hoặc yyyy-mm-dd.' % text)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('csv_file')
    parser.add_argument('--base', default=LOCAL)
    parser.add_argument('--production', action='store_true')
    parser.add_argument('--token', default='')
    args = parser.parse_args()

    base = PRODUCTION_ADMIN if args.production else args.base
    token = admin_token(base, args.token)
    tag = os.path.splitext(os.path.basename(args.csv_file))[0][:40]

    # utf-8-sig: Excel của Windows lưu CSV kèm BOM, không bỏ thì cột đầu tiên
    # mang tên "﻿ma_lo" và dòng nào cũng thiếu mã lô.
    with open(args.csv_file, encoding='utf-8-sig', newline='') as handle:
        rows = list(csv.DictReader(handle))

    if not rows:
        sys.exit('Tệp không có dòng dữ liệu nào.')
    missing = {'ma_lo', 'so_sao'} - set(rows[0].keys())
    if missing:
        sys.exit('Thiếu cột: %s' % ', '.join(sorted(missing)))

    print('nhập %d phiếu vào %s' % (len(rows), base))
    for index, row in enumerate(rows, start=1):
        code = (row.get('ma_lo') or '').strip().upper()
        if not code:
            print('  dòng %d: thiếu mã lô, bỏ qua' % index)
            continue
        try:
            stars = int(str(row.get('so_sao')).strip())
        except (TypeError, ValueError):
            print('  dòng %d: số sao không đọc được, bỏ qua' % index)
            continue
        if not 1 <= stars <= 5:
            print('  dòng %d: số sao %s ngoài khoảng 1-5, bỏ qua' % (index, stars))
            continue

        created = parse_date(row.get('ngay'))
        call(base, token, 'POST', '/api/admin/ratings', {
            'code': code,
            'stars': stars,
            'comment': (row.get('nhan_xet') or '').strip()[:400],
            'displayName': (row.get('ten') or '').strip()[:60],
            'deviceId': 'phieu-%s-%04d' % (tag, index),
            'source': 'SURVEY',
            **({'createdAt': created} if created else {}),
        })

    report = call(base, token, 'GET', '/api/admin/ratings')
    print('\ntổng %s đánh giá, trung bình %s' % (report['total'], report['average']))
    for row in report['bySource']:
        print('  nguồn %-7s %3s phiếu, trung bình %s'
              % (row['source'], row['count'], row['average']))


if __name__ == '__main__':
    main()
