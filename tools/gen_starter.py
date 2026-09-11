# -*- coding: utf-8 -*-
"""Sinh starterIngredients() trong Dart từ đúng bảng bước ở process-steps.mjs.

Một nguồn sự thật: sơ đồ quy trình. Chép tay sang Dart là kiểu gì cũng lệch.
"""
import io
import re

SRC = 'C:/Users/sontm/coded/com-tule/worker/scripts/process-steps.mjs'
DART = 'C:/Users/sontm/coded/com-tule/lib/models/ingredient_draft.dart'

raw = io.open(SRC, encoding='utf-8').read()


def steps_of(branch):
    start = raw.index('%s: [' % branch)
    depth = 0
    for i in range(start, len(raw)):
        if raw[i] == '[':
            depth += 1
        elif raw[i] == ']':
            depth -= 1
            if depth == 0:
                block = raw[start:i + 1]
                break
    return re.findall(r"\[\s*'((?:[^'\\]|\\.)*)',\s*'((?:[^'\\]|\\.)*)',?\s*\]", block)


BRANCHES = {
    'com': ('Cốm Tú Lệ', 'Tú Lệ, Yên Bái', 'Hợp tác xã Tú Lệ', 21.7167, 104.2333, 4.5,
            'Hạt nếp nương xanh, dẻo thơm và là linh hồn của công thức.'),
    'lac': ('Lạc đỏ Lục Yên', 'Lục Yên, Yên Bái', 'Tổ hợp tác Lục Yên', 22.1, 104.7167, 6,
            'Hạt lạc bản địa giàu đạm thực vật, tạo vị bùi tự nhiên.'),
    'chuoi': ('Chuối tiêu xanh', 'Bảo Thắng, Lào Cai', 'Vùng trồng VietGAP Bảo Thắng',
              22.3667, 104.1833, 5,
              'Chuối tiêu khoảng 9 tuần, dùng lúc còn xanh để giữ tinh bột kháng.'),
    'khoai': ('Khoai môn Lục Yên', 'Lâm Thượng, Lục Yên, Yên Bái', 'Hộ sản xuất Lâm Thượng',
              22.1667, 104.75, 3.5,
              'Khoai môn bản địa cho kết cấu dẻo mịn và hương thơm đặc trưng.'),
}

out = ["""/// Bốn nguyên liệu của Tú Lệ Smart Breakfast kèm toàn bộ công đoạn theo sơ đồ
/// quy trình sản xuất, mô tả lấy nguyên từ thuyết minh trong tài liệu.
///
/// Tạo lô mới bằng bộ này thì người vận hành chỉ còn việc tải ảnh lên. Bảng gốc
/// nằm ở worker/scripts/process-steps.mjs; sinh lại bằng tools/gen_starter.py
/// mỗi khi quy trình đổi, đừng sửa tay hai nơi.
List<IngredientDraft> starterIngredients() => ["""]

for branch, (name, origin, supplier, lat, lng, radius, summary) in BRANCHES.items():
    steps = steps_of(branch)
    if not steps:
        raise SystemExit('không đọc được bước của ' + branch)
    out.append('  IngredientDraft(')
    out.append("    name: '%s'," % name)
    out.append("    origin: '%s'," % origin)
    out.append("    supplier: '%s'," % supplier)
    out.append('    latitude: %s,' % lat)
    out.append('    longitude: %s,' % lng)
    out.append("    summary: '%s'," % summary)
    out.append('    steps: [')
    for title, description in steps:
        out.append('      (')
        out.append("        title: '%s'," % title.replace("'", r"\'"))
        out.append("        description:")
        out.append("            '%s'," % description.replace("'", r"\'"))
        out.append('      ),')
    out.append('    ],')
    out.append('  ),')

out.append('];')

new_block = '\n'.join(out) + '\n'

dart = io.open(DART, encoding='utf-8').read()
head = dart[:dart.index('/// Bốn nguyên liệu của Tú Lệ Smart Breakfast')]
io.open(DART, 'w', encoding='utf-8').write(head + new_block)
print('đã sinh lại starterIngredients với',
      sum(len(steps_of(b)) for b in BRANCHES), 'bước')
