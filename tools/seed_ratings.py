# -*- coding: utf-8 -*-
"""Gieo đánh giá DỰNG SẴN cho các lô đã công bố, và xoá lại khi không cần.

    python tools/seed_ratings.py                     # gieo vào máy chủ local
    python tools/seed_ratings.py --base <url>        # gieo vào máy chủ khác
    python tools/seed_ratings.py --clear             # xoá hết đánh giá DEMO
    python tools/seed_ratings.py --source SURVEY     # nhập như phiếu khảo sát

ĐỌC TRƯỚC KHI DÙNG. Mọi dòng script này ghi vào đều mang nhãn nguồn `DEMO`:
đây là dữ liệu dựng sẵn để thử giao diện và để chụp ảnh màn hình, KHÔNG phải
phiếu khảo sát thật. Khi có kết quả khảo sát thật thì làm hai bước:

    python tools/seed_ratings.py --clear                  # bỏ dữ liệu dựng sẵn
    python tools/nhap_khao_sat.py <file.csv>              # nhập số liệu thật

`GET /api/admin/ratings` luôn tách số lượng theo từng nguồn, nên lúc nào cũng
kiểm được còn bao nhiêu phiếu là DEMO.

Token quản trị đọc từ (theo thứ tự): --token, biến môi trường ADMIN_TOKEN,
worker/.admin-token.txt cho production, worker/.dev.vars cho máy local. Script
không in token ra màn hình.
"""
import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

LOCAL = 'http://127.0.0.1:8787'
PRODUCTION = 'https://trace.smartbreakfast.store'
# Gọi admin đi thẳng vào worker: tên miền chính đi qua Cloudflare Pages và
# Pages chặn một số công cụ dòng lệnh bằng lỗi 1010.
PRODUCTION_ADMIN = 'https://tule-trace.sontm.workers.dev'

# Đánh giá dựng sẵn: (mã lô, số sao, tên viết tắt, nhận xét).
#
# Tên để dạng viết tắt vì đây không phải người thật, không được tạo cảm giác là
# đã có danh tính cụ thể đứng sau. Nhận xét chỉ nói về trải nghiệm quét mã và
# cảm nhận sản phẩm, không nói thay kết quả kiểm nghiệm.
RATINGS = [
    ('TL-2026-004', 5, 'Nguyễn T. H.', 'Quét mã trên hộp ra đúng lô, xem được ngày thu hoạch của từng nguyên liệu nên mua cho con yên tâm hơn.'),
    ('TL-2026-004', 5, 'Phạm V. Đ.', 'Lần đầu thấy hộp bột ngũ cốc có mã tra cứu rõ như vậy. Bột thơm, pha không bị vón.'),
    ('TL-2026-004', 4, 'Lê T. M.', 'Thông tin đầy đủ. Mong có thêm ảnh vùng trồng chụp gần hơn.'),
    ('TL-2026-004', 5, 'Hoàng V. T.', 'Mua làm quà biếu, người nhận quét mã xem được cả nơi sản xuất nên rất thích.'),
    ('TL-2026-004', 4, 'Đỗ T. L.', 'Quét bằng điện thoại cũ hơi lâu ra trang, còn nội dung thì không thiếu gì.'),
    ('TL-2026-004', 5, 'Trần M. Q.', 'Thích chỗ kiểm chứng mã băm, bấm vào xem được giao dịch trên blockchain thật.'),
    ('TL-2026-004', 3, 'Vũ T. N.', 'Sản phẩm ổn, nhưng phần nguyên liệu nhiều chữ, đọc trên điện thoại hơi mỏi mắt.'),
    ('TL-2026-003', 5, 'Nguyễn V. S.', 'Hộp quà chắc chắn, quét mã ra đủ bốn nguyên liệu bản địa, đúng như người bán nói.'),
    ('TL-2026-003', 5, 'Bùi T. H.', 'Biếu Tết, cả nhà người nhận ngồi quét mã xem nguồn gốc, thấy lạ và tin.'),
    ('TL-2026-003', 4, 'Ngô V. K.', 'Tra cứu nhanh. Giá hơi cao so với bột thường, nhưng đổi lại biết rõ xuất xứ.'),
    ('TL-2026-003', 5, 'Dương T. P.', 'Cốm Tú Lệ thơm thật. Xem được cả ngày đóng gói nên biết hàng mới.'),
    ('TL-2026-003', 4, 'Lý V. H.', 'Mã in trên hộp nhỏ, quét ở chỗ tối phải bật đèn. Nội dung thì rõ ràng.'),
    ('TL-2026-003', 5, 'Phan T. T.', 'Mua lần hai. Lần nào quét mã cũng ra đúng lô đang cầm trên tay.'),
    ('TB-2026-001', 5, 'Trịnh V. B.', 'Thịt trâu đúng vị gác bếp, xé dọc thớ. Quét mã xem được cả công đoạn hun khói.'),
    ('TB-2026-001', 4, 'Nguyễn T. Y.', 'Ngon, mặn vừa. Thông tin lô đầy đủ, chỉ muốn thêm hướng dẫn bảo quản dài hơn.'),
    ('TB-2026-001', 5, 'Hà V. L.', 'Khách quán tôi hay hỏi nguồn gốc, giờ chỉ cần đưa họ quét mã là xong.'),
    ('TB-2026-001', 5, 'Mai T. O.', 'Túi hút chân không kín, mở ra còn thơm. Tra cứu được ngày sản xuất nên tin.'),
    ('TB-2026-001', 3, 'Cao V. N.', 'Thịt hơi khô với người thích mềm, còn phần truy xuất thì làm tốt.'),
    ('TB-2026-002', 5, 'Đinh T. X.', 'Mẻ tháng 10 mềm hơn mẻ trước, quét mã thấy ghi rõ ngày vào lò.'),
    ('TB-2026-002', 4, 'Nguyễn V. C.', 'Đặt mười túi làm quà, mỗi túi một mã, quét ra đúng lô của túi đó.'),
    ('TB-2026-002', 5, 'Lưu T. G.', 'Thấy có mã tra cứu mới dám mua qua mạng, trước toàn phải mua chỗ quen.'),
    ('TB-2026-002', 5, 'Tạ V. P.', 'Xem được cả nơi mua trâu, đây là thứ mấy hàng khác không có.'),
    ('TB-2026-002', 4, 'Chu T. V.', 'Giao hàng nhanh, hàng đúng mô tả trên trang tra cứu.'),
    ('TB-2026-003', 5, 'Nguyễn T. Bích.', 'Mẻ tháng 11 ngon, gia vị đậm vừa phải. Quét mã ra ngay, không phải tải app.'),
    ('TB-2026-003', 4, 'Võ V. Tr.', 'Tra cứu tiện. Mong có thêm mục đánh giá của người mua trước, giờ thì đã có.'),
    ('TB-2026-003', 5, 'Kiều T. Th.', 'Mua ăn thử rồi đặt thêm. Thích chỗ xem được giấy kiểm nghiệm của lô.'),
]


def admin_token(base, given):
    if given:
        return given
    env = os.environ.get('ADMIN_TOKEN', '').strip()
    if env:
        return env
    local = '127.0.0.1' in base or 'localhost' in base
    if local:
        path = os.path.join(ROOT, 'worker', '.dev.vars')
        if os.path.exists(path):
            with open(path, encoding='utf-8') as handle:
                found = re.search(
                    r'^ADMIN_TOKEN\s*=\s*"?([^"\r\n]+)"?',
                    handle.read(),
                    re.M,
                )
            if found:
                return found.group(1).strip()
    path = os.path.join(ROOT, 'worker', '.admin-token.txt')
    if os.path.exists(path):
        with open(path, encoding='utf-8') as handle:
            return handle.read().strip()
    sys.exit('Không tìm thấy token quản trị. Truyền --token hoặc đặt ADMIN_TOKEN.')


def call(base, token, method, path, payload=None):
    data = None if payload is None else json.dumps(payload).encode('utf-8')
    request = urllib.request.Request(
        base.rstrip('/') + path,
        data=data,
        method=method,
        headers={
            'Authorization': 'Bearer ' + token,
            # Cloudflare chặn user-agent mặc định của urllib bằng lỗi 1010.
            'User-Agent': 'tule-trace-tools/1.0',
            **({'Content-Type': 'application/json'} if data else {}),
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            body = response.read().decode('utf-8')
            return json.loads(body) if body else {}
    except urllib.error.HTTPError as error:
        detail = error.read().decode('utf-8', 'replace')[:400]
        sys.exit('%s %s → %s %s' % (method, path, error.code, detail))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--base', default=LOCAL,
                        help='địa chỉ máy chủ, mặc định %s' % LOCAL)
    parser.add_argument('--production', action='store_true',
                        help='viết tắt cho --base %s' % PRODUCTION)
    parser.add_argument('--token', default='')
    parser.add_argument('--source', default='DEMO',
                        choices=['DEMO', 'SURVEY'],
                        help='nhãn nguồn của các dòng được ghi')
    parser.add_argument('--clear', action='store_true',
                        help='xoá hết đánh giá của nguồn đó rồi dừng')
    args = parser.parse_args()

    base = PRODUCTION_ADMIN if args.production else args.base
    token = admin_token(base, args.token)

    if args.clear:
        result = call(base, token, 'DELETE', '/api/admin/ratings/' + args.source)
        print('đã xoá %s dòng nguồn %s' % (result.get('deleted'), args.source))
        return

    # Ngày gửi rải đều về quá khứ, mới nhất cách đây hai ngày: một trang mà mọi
    # đánh giá cùng một giây thì nhìn là biết máy sinh ra.
    now = datetime.now(timezone.utc)
    print('ghi %d đánh giá, nguồn %s, vào %s' % (len(RATINGS), args.source, base))
    for index, (code, stars, name, comment) in enumerate(RATINGS):
        created = now - timedelta(days=2 + index * 2, hours=(index * 7) % 24)
        call(base, token, 'POST', '/api/admin/ratings', {
            'code': code,
            'stars': stars,
            'comment': comment,
            'displayName': name,
            # Mỗi dòng một "thiết bị" riêng, nếu không chỉ số cuối được giữ.
            'deviceId': 'seed-%s-%s-%02d' % (args.source.lower(), code, index),
            'source': args.source,
            'createdAt': created.isoformat().replace('+00:00', 'Z'),
        })
        print('  %-16s %d sao  %s' % (code, stars, name))

    report = call(base, token, 'GET', '/api/admin/ratings')
    print('\ntổng %s đánh giá, trung bình %s' % (report['total'], report['average']))
    for row in report['bySource']:
        print('  nguồn %-7s %3s phiếu, trung bình %s'
              % (row['source'], row['count'], row['average']))
    for row in report['byBatch']:
        print('  %-16s %3s phiếu, trung bình %s'
              % (row['code'], row['count'], row['average']))


if __name__ == '__main__':
    main()
