# -*- coding: utf-8 -*-
"""Lui ngày của một lô về quá khứ rồi công bố lại.

Hai lô TM-2026-003 và TB-2026-003 đang ghi ngày sản xuất tháng 11 trong khi
hôm nay mới 26/10: hồ sơ truy xuất không được nói về việc chưa xảy ra. Script
dời toàn bộ mốc thời gian của lô đi cùng một số ngày nên khoảng cách giữa các
công đoạn giữ nguyên, rồi công bố lại để bản ghi trên chuỗi khớp dữ liệu mới.
"""
import json, os, sys, urllib.request
from datetime import datetime, timedelta

sys.stdout.reconfigure(encoding='utf-8')
ROOT = r'C:\Users\sontm\coded\com-tule'
BASE = 'https://tule-trace.sontm.workers.dev'
TOK = open(os.path.join(ROOT, 'worker', '.admin-token.txt'), encoding='utf-8').read().strip()
DRY = '--dry' in sys.argv

def call(method, path, body=None):
    data = json.dumps(body, ensure_ascii=False).encode() if body is not None else None
    r = urllib.request.Request(BASE + path, data=data, method=method, headers={
        'Authorization': 'Bearer ' + TOK, 'Content-Type': 'application/json',
        'User-Agent': 'tule-trace-tools/1.0'})
    with urllib.request.urlopen(r) as f:
        return json.load(f)

def shift(text, days):
    if not text:
        return text
    return (datetime.strptime(text, '%d.%m.%Y') + timedelta(days=days)).strftime('%d.%m.%Y')

JOBS = [
    {'code': 'TM-2026-003', 'days': -14, 'name': 'Ô mai táo mèo - mẻ cuối tháng 10'},
    {'code': 'TB-2026-003', 'days': -14, 'name': 'Thịt trâu gác bếp - mẻ cuối tháng 10'},
]

for job in JOBS:
    code, days = job['code'], job['days']
    pub = call('GET', '/api/public/traces/' + code)
    adm = call('GET', '/api/admin/product-batches/%s/trace' % code)
    print('==', code, pub['productionDate'], '->', shift(pub['productionDate'], days))
    patch = {'name': job['name'],
             'productionDate': shift(pub['productionDate'], days),
             'expiryDate': shift(pub.get('expiryDate'), days)}
    print('  lô:', patch)
    if not DRY:
        call('PATCH', '/api/admin/product-batches/' + code, patch)

    for pi, ai in zip(pub.get('ingredients', []), adm.get('ingredients', [])):
        body = {}
        if pi.get('harvestDate'):
            body['harvestDate'] = shift(pi['harvestDate'], days)
        if pi.get('receivedDate'):
            body['receivedDate'] = shift(pi['receivedDate'], days)
        if body:
            print('  nguyên liệu', ai['id'], body)
            if not DRY:
                call('PATCH', '/api/admin/ingredient-batches/%d' % ai['id'], body)
        for pe, ae in zip(pi.get('processEvents', []), ai.get('processEvents', [])):
            if pe.get('eventDate'):
                print('   công đoạn', ae['id'], pe['eventDate'], '->', shift(pe['eventDate'], days))
                if not DRY:
                    call('PATCH', '/api/admin/process-events/%d' % ae['id'],
                         {'eventDate': shift(pe['eventDate'], days)})

    for pe, ae in zip(pub.get('batchEvents', []), adm.get('batchEvents', [])):
        if pe.get('eventDate'):
            print('   công đoạn lô', ae['id'], pe['eventDate'], '->', shift(pe['eventDate'], days))
            if not DRY:
                call('PATCH', '/api/admin/process-events/%d' % ae['id'],
                     {'eventDate': shift(pe['eventDate'], days)})

    if DRY:
        print('  (dry) sẽ công bố lại')
    else:
        res = call('POST', '/api/admin/product-batches/%s/publish' % code, {})
        print('  công bố lại: bản', res['version'], res['sha256'][:12])
