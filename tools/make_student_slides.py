# -*- coding: utf-8 -*-
"""Bộ slide "Chúng em đã làm sản phẩm này thế nào".

Khác với `make_slides.py` (bản kỹ thuật gửi khách): bản này kể lại quá trình
làm bằng giọng của chính nhóm học sinh, mỗi khái niệm khó đều quy về một hình
ảnh quen thuộc trước khi gọi tên thật, và có hẳn ba slide kể những chỗ làm sai.

    python tools/make_student_slides.py [thư mục ảnh]

Ảnh mặc định lấy ở `docs/ppt-hoc-sinh/`. Chụp lại bằng script trong
`tools/` hoặc bằng tay, giữ nguyên tên file trong bảng ASSETS bên dưới.
"""
import os
import sys

from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE
from pptx.enum.text import PP_ALIGN
from pptx.util import Emu, Inches, Pt

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
IMG = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, 'docs', 'ppt-hoc-sinh')
OUT = os.path.join(ROOT, 'tai-lieu', 'Tu-Le-Trace-Cach-chung-em-lam.pptx')

INK = RGBColor(0x17, 0x35, 0x2A)
INK_SOFT = RGBColor(0x2C, 0x4C, 0x3E)
ORANGE = RGBColor(0xE2, 0x70, 0x3A)
ORANGE_INK = RGBColor(0xA8, 0x4B, 0x1B)
BG = RGBColor(0xF6, 0xF6, 0xF1)
WHITE = RGBColor(0xFF, 0xFF, 0xFF)
LINE = RGBColor(0xD5, 0xDA, 0xCC)
MUTED = RGBColor(0x5C, 0x6B, 0x61)
GREEN_SOFT = RGBColor(0xEF, 0xF7, 0xEC)
GREEN_EDGE = RGBColor(0xCB, 0xE3, 0xC0)
TEAL = RGBColor(0x00, 0x7E, 0x88)

FONT = 'Segoe UI'
W, H = Inches(13.333), Inches(7.5)
ML = Inches(0.85)          # lề trái
CW = W - ML * 2            # bề ngang vùng nội dung

prs = Presentation()
prs.slide_width, prs.slide_height = W, H
BLANK = prs.slide_layouts[6]


# ----------------------------------------------------------------- tiện ích
def slide(bg=BG):
    s = prs.slides.add_slide(BLANK)
    back = s.shapes.add_shape(MSO_SHAPE.RECTANGLE, 0, 0, W, H)
    back.fill.solid()
    back.fill.fore_color.rgb = bg
    back.line.fill.background()
    back.shadow.inherit = False
    return s


def text(s, left, top, width, height, runs, align=PP_ALIGN.LEFT):
    """runs: list các (chuỗi, thuộc tính). Trả về textbox để tính chiều cao."""
    tb = s.shapes.add_textbox(left, top, width, height)
    tf = tb.text_frame
    tf.word_wrap = True
    tf.margin_left = tf.margin_right = tf.margin_top = tf.margin_bottom = 0
    for i, (content, opts) in enumerate(runs):
        p = tf.paragraphs[0] if i == 0 else tf.add_paragraph()
        p.alignment = align
        p.space_after = Pt(opts.get('space', 6))
        p.line_spacing = opts.get('line', 1.18)
        run = p.add_run()
        run.text = content
        f = run.font
        f.name = FONT
        f.size = Pt(opts.get('size', 18))
        f.bold = opts.get('bold', False)
        f.color.rgb = opts.get('color', INK)
    return tb


def box(s, left, top, width, height, fill=WHITE, edge=LINE, radius=True, line_w=1.0):
    shape = s.shapes.add_shape(
        MSO_SHAPE.ROUNDED_RECTANGLE if radius else MSO_SHAPE.RECTANGLE,
        left, top, width, height)
    shape.fill.solid()
    shape.fill.fore_color.rgb = fill
    if edge is None:
        shape.line.fill.background()
    else:
        shape.line.color.rgb = edge
        shape.line.width = Pt(line_w)
    shape.shadow.inherit = False
    if radius:
        shape.adjustments[0] = 0.08
    return shape


def head(s, eyebrow, title, sub=None, width=None, sub_width=None):
    """Tiêu đề chuẩn của một slide nội dung.

    Trả về toạ độ y ngay dưới khối tiêu đề. Tiêu đề dài thì xuống dòng, nên
    phải đo ước lượng số dòng: đặt ảnh theo một con số cứng là có ngày ảnh
    đè lên chữ.
    """
    width = width or CW
    sub_width = sub_width or width
    y = Inches(0.62)
    if eyebrow:
        text(s, ML, y, width, Inches(0.3),
             [(eyebrow.upper(), dict(size=13, bold=True, color=ORANGE_INK, space=0))])
        y += Inches(0.36)
    text(s, ML, y, width, Inches(0.9),
         [(title, dict(size=34, bold=True, color=INK, space=2))])
    # Cỡ 34pt trên nền Segoe UI: khoảng 2,7 ký tự cho mỗi 0,1 inch bề ngang.
    per_line = max(int(width / Inches(0.1) * 0.37), 20)
    y += Inches(0.72) * max(1, -(-len(title) // per_line))
    if sub:
        lines = max(1, -(-len(sub) // max(int(sub_width / Inches(0.1) * 0.72), 30)))
        text(s, ML, y, sub_width, Inches(0.5) * lines,
             [(sub, dict(size=17, color=MUTED, line=1.3))])
        y += Inches(0.34) * lines + Inches(0.14)
    return y + Inches(0.16)


def picture(s, name, left, top, width=None, height=None):
    path = os.path.join(IMG, name)
    if not os.path.exists(path):
        print('  THIẾU ẢNH:', name)
        return None
    return s.shapes.add_picture(path, left, top, width=width, height=height)


def shot(s, name, top, max_w=None, max_h=None, left=None):
    """Đặt ảnh chụp màn hình, canh giữa, viền mảnh cho ra dáng cửa sổ."""
    from PIL import Image
    path = os.path.join(IMG, name)
    if not os.path.exists(path):
        print('  THIẾU ẢNH:', name)
        return
    w, h = Image.open(path).size
    max_w = max_w or CW
    max_h = max_h or (H - top - Inches(0.55))
    scale = min(max_w / w, max_h / h)
    tw, th = int(w * scale), int(h * scale)
    x = left if left is not None else int((W - tw) / 2)
    frame = box(s, Emu(x - 12000), Emu(top - 12000), Emu(tw + 24000), Emu(th + 24000),
                fill=WHITE, edge=LINE)
    frame.shadow.inherit = False
    s.shapes.add_picture(path, Emu(x), Emu(top), width=Emu(tw), height=Emu(th))


def bullets(s, items, left, top, width, size=17, gap=Inches(0.52), dot=ORANGE):
    y = top
    for item in items:
        d = s.shapes.add_shape(MSO_SHAPE.OVAL, left, y + Inches(0.09), Pt(7), Pt(7))
        d.fill.solid()
        d.fill.fore_color.rgb = dot
        d.line.fill.background()
        d.shadow.inherit = False
        tb = text(s, left + Inches(0.26), y, width - Inches(0.26), Inches(0.4),
                  [(item, dict(size=size, color=INK_SOFT, line=1.28))])
        lines = max(1, int(len(item) / (width / Inches(0.104))) + 1)
        y += max(gap, Inches(0.3) * lines)
    return y


def footer(s, note):
    text(s, ML, H - Inches(0.62), CW, Inches(0.3),
         [(note, dict(size=12, color=MUTED, space=0))])


def card(s, left, top, width, height, title, body, tint=WHITE, edge=LINE,
         title_color=INK, size=16):
    box(s, left, top, width, height, fill=tint, edge=edge)
    text(s, left + Inches(0.28), top + Inches(0.22), width - Inches(0.56), Inches(0.4),
         [(title, dict(size=17, bold=True, color=title_color, space=4))])
    text(s, left + Inches(0.28), top + Inches(0.66), width - Inches(0.56),
         height - Inches(0.9), [(body, dict(size=size, color=MUTED, line=1.3))])


# --------------------------------------------------------------- slide 1
def s_cover():
    s = slide(INK)
    text(s, ML, Inches(2.05), CW, Inches(0.4),
         [('DỰ ÁN KHOA HỌC KỸ THUẬT', dict(size=14, bold=True,
                                           color=RGBColor(0x8B, 0xBF, 0x76), space=0))])
    text(s, ML, Inches(2.55), Inches(10.2), Inches(1.8),
         [('Chúng em đã làm\nsản phẩm này thế nào',
           dict(size=52, bold=True, color=WHITE, line=1.1, space=0))])
    text(s, ML, Inches(4.6), Inches(9.6), Inches(1.0),
         [('Tú Lệ Trace — hệ thống truy xuất nguồn gốc nông sản ứng dụng blockchain',
           dict(size=20, color=RGBColor(0xC4, 0xD6, 0xCA), line=1.35))])
    line = box(s, ML, Inches(5.5), Inches(1.4), Pt(3), fill=ORANGE, edge=None, radius=False)
    line.shadow.inherit = False
    text(s, ML, Inches(5.85), Inches(9.6), Inches(0.8),
         [('Sản phẩm đang chạy thật: trace.smartbreakfast.store',
           dict(size=16, color=RGBColor(0x9F, 0xB8, 0xA8)))])


# --------------------------------------------------------------- slide 2
def s_baitoan():
    s = slide()
    y = head(s, 'Bắt đầu từ đâu', 'Câu hỏi chúng em không trả lời được',
             width=Inches(7.2))
    text(s, ML, y, Inches(6.6), Inches(2.4),
         [('"Làm sao em biết gói này đúng là cốm Tú Lệ thật?"',
           dict(size=26, bold=True, color=ORANGE_INK, line=1.25, space=14)),
          ('Đó là câu một cô bán hàng hỏi nhóm em trong buổi bán thử. '
           'Trên bao bì có ghi vùng nguyên liệu, nhưng chữ in trên bao bì thì '
           'ai in chẳng được.', dict(size=17, color=INK_SOFT, line=1.4))])
    y2 = y + Inches(2.5)
    bullets(s, [
        'Nhiều sản phẩm có QR, quét ra một trang web của chính người bán.',
        'Người bán sửa thông tin lúc nào cũng được, không ai biết.',
        'Người mua không có cách nào tự kiểm tra.',
    ], ML, y2, Inches(6.6))
    shot(s, 'p7-dien-thoai.png', Inches(1.3), max_w=Inches(4.2),
         max_h=Inches(5.3), left=Inches(8.4))
    footer(s, 'Bài toán: không phải hiển thị thông tin, mà là làm cho thông tin đó kiểm chứng được.')


# --------------------------------------------------------------- slide 3
def s_ytuong():
    s = slide()
    y = head(s, 'Ý tưởng', 'Ba bước, kể bằng ngôn ngữ đời thường',
             'Chúng em không phát minh ra blockchain. Chúng em chỉ dùng nó đúng một việc: '
             'làm chứng rằng hồ sơ không bị sửa sau ngày công bố.')
    w = (CW - Inches(0.6)) / 3
    steps = [
        ('1 · Hồ sơ', 'Mỗi lô có một hồ sơ: nguyên liệu, công đoạn, ảnh, phiếu kiểm nghiệm. '
                      'Giống một quyển lý lịch của gói ngũ cốc.'),
        ('2 · Vân tay', 'Máy đọc cả hồ sơ rồi tính ra một dãy 64 ký tự — vân tay của hồ sơ. '
                        'Sửa một dấu phẩy là vân tay khác hẳn.'),
        ('3 · Sổ chung', 'Vân tay được ghi lên blockchain: một quyển sổ mà ai cũng đọc được '
                         'và không ai tẩy được, kể cả nhóm em.'),
    ]
    for i, (title, body) in enumerate(steps):
        left = ML + (w + Inches(0.3)) * i
        card(s, left, y, w, Inches(2.5), title, body,
             tint=WHITE if i < 2 else GREEN_SOFT,
             edge=LINE if i < 2 else GREEN_EDGE,
             title_color=INK if i < 2 else RGBColor(0x2C, 0x6B, 0x3F))
    text(s, ML, y + Inches(2.85), CW, Inches(0.8),
         [('Người mua quét QR → đọc hồ sơ → máy tính lại vân tay → so với vân tay trên sổ chung. '
           'Khớp thì hiện ĐÃ XÁC MINH, lệch thì hiện DỮ LIỆU SAI LỆCH.',
           dict(size=17, color=INK_SOFT, line=1.35))])
    footer(s, 'Blockchain không chứa hồ sơ. Nó chỉ giữ vân tay và mốc thời gian.')


# --------------------------------------------------------------- slide 4
def s_chia():
    s = slide()
    y = head(s, 'Chia việc', 'Chúng em bổ sản phẩm thành bốn mảnh',
             'Nhìn tổng thể thì rất to. Bổ ra bốn mảnh thì mảnh nào cũng làm được.')
    w = (CW - Inches(0.75)) / 4
    parts = [
        ('Tủ hồ sơ', 'Nơi chứa dữ liệu: lô, nguyên liệu, công đoạn, ảnh.', 'Cloudflare D1 + R2'),
        ('Ô cửa', 'Nơi nhận yêu cầu và trả dữ liệu đúng phần được phép.', 'Worker + Hono'),
        ('Chỗ nhập liệu', 'Màn cho người vận hành khai báo và công bố lô.', 'Flutter Web'),
        ('Trang người mua', 'Trang mở ra khi quét QR, phải thật nhẹ.', 'HTML dựng sẵn'),
    ]
    for i, (title, body, tech) in enumerate(parts):
        left = ML + (w + Inches(0.25)) * i
        box(s, left, y, w, Inches(2.75))
        text(s, left + Inches(0.24), y + Inches(0.26), w - Inches(0.48), Inches(0.4),
             [(str(i + 1), dict(size=15, bold=True, color=ORANGE, space=2))])
        text(s, left + Inches(0.24), y + Inches(0.62), w - Inches(0.48), Inches(0.4),
             [(title, dict(size=19, bold=True, color=INK, space=6))])
        text(s, left + Inches(0.24), y + Inches(1.12), w - Inches(0.48), Inches(1.0),
             [(body, dict(size=15, color=MUTED, line=1.3))])
        text(s, left + Inches(0.24), y + Inches(2.25), w - Inches(0.48), Inches(0.3),
             [(tech, dict(size=13, bold=True, color=TEAL, space=0))])
    text(s, ML, y + Inches(3.1), CW, Inches(0.6),
         [('Bốn mảnh này chạy hết trên Cloudflare, không thuê máy chủ riêng: '
           'nhóm học sinh không có ai trực máy chủ lúc nửa đêm, và khi không ai quét mã thì '
           'hệ thống gần như không tốn tiền.', dict(size=17, color=INK_SOFT, line=1.35))])


def s_vscode():
    s = slide()
    y = head(s, 'Chỗ ngồi làm', 'Đây là màn hình lúc bọn em làm',
             'Cây thư mục bên trái chính là bốn mảnh vừa nói: worker là ô cửa và tủ hồ sơ, '
             'lib là màn quản trị, web là trang cho người mua.')
    shot(s, 'v1-code-index.png', y, max_h=Inches(4.0))
    footer(s, 'Mở bằng Visual Studio Code. Mỗi lần lưu file là trang tự tải lại để xem kết quả ngay.')


def s_hop_dong():
    s = slide()
    y = head(s, 'Phần lõi', 'Hợp đồng thông minh: ngắn hơn bọn em tưởng',
             'Cả hợp đồng chỉ khai báo vài sự kiện. Không có vòng lặp, không có tính toán phức tạp: '
             'nó chỉ ghi nhận rằng vân tay này đã tồn tại vào lúc này.')
    shot(s, 'v2-code-contract.png', y, max_h=Inches(3.9))
    footer(s, 'contracts/TuleTrace.sol — ngôn ngữ Solidity, dịch ra rồi nạp lên mạng Besu một lần duy nhất.')


# --------------------------------------------------------------- slide 5-6
def s_tu_ho_so():
    s = slide()
    y = head(s, 'Mảnh 1', 'Tủ hồ sơ: dạy máy hiểu một lô hàng gồm những gì',
             'Việc đầu tiên là vẽ ra các bảng dữ liệu. Một lô có nhiều nguyên liệu, '
             'mỗi nguyên liệu có nhiều công đoạn, mỗi công đoạn có nhiều ảnh.')
    shot(s, 'code-schema.png', y, max_w=Inches(7.4), max_h=Inches(3.4), left=int(ML))
    right = ML + Inches(7.75)
    card(s, right, y, CW - Inches(7.75), Inches(3.4), 'Vì sao viết ra giấy trước',
         'Bọn em đổi cấu trúc bảng ba lần trong hai tuần đầu. Mỗi lần đổi là phải sửa lại '
         'cả phần nhập liệu lẫn phần hiển thị.\n\n'
         'Bài học: vẽ xong mô hình dữ liệu rồi hẵng viết code giao diện.')
    footer(s, 'worker/schema.sql — 6 bảng: lô, nguyên liệu, công đoạn, ảnh, bản công bố, hàng chờ lên chuỗi.')


def s_o_cua():
    s = slide()
    y = head(s, 'Mảnh 2', 'Ô cửa: mỗi câu hỏi một địa chỉ',
             'API là nơi bên ngoài hỏi và bên trong trả lời. Mỗi đường dẫn làm đúng một việc.')
    shot(s, 'code-api.png', y, max_w=Inches(8.2), max_h=Inches(3.6), left=int(ML))
    right = ML + Inches(8.55)
    card(s, right, y, CW - Inches(8.55), Inches(4.0), 'waitUntil là gì',
         'Gửi giao dịch lên blockchain mất vài giây. Bắt người vận hành ngồi đợi thì họ '
         'tưởng máy treo.\n\n'
         'waitUntil trả lời "đã xong" ngay, rồi máy chủ vẫn âm thầm gửi nốt giao dịch.',
         size=15)
    footer(s, 'worker/src/index.ts')


# --------------------------------------------------------------- slide 7-8
def s_nhap_lieu():
    s = slide()
    y = head(s, 'Mảnh 3', 'Chỗ nhập liệu: làm cho người vận hành')
    shot(s, 'a3-man-lam-viec.png', y, max_h=Inches(4.2))
    footer(s, 'Mỗi lô một màn làm việc duy nhất. Bản đầu chia ba tab, người dùng thử bị lạc nên bọn em gộp lại.')


def s_nhap_lieu2():
    s = slide()
    y = head(s, 'Mảnh 3', 'Khai từng công đoạn: ai làm, bao nhiêu kg')
    shot(s, 'a7-cong-doan.png', y, max_h=Inches(4.2))
    footer(s, 'Khối lượng vào và ra là thứ giúp phát hiện gian lận: 100 kg nguyên liệu không thể ra 300 kg thành phẩm.')


# --------------------------------------------------------------- slide 9-10
def s_trang_mua():
    s = slide()
    y = head(s, 'Mảnh 4', 'Trang cho người mua: mở trong một giây')
    shot(s, 'p2-ho-so-lo.png', y, max_h=Inches(4.2))
    footer(s, 'Người quét mã đứng giữa chợ, sóng yếu. Trang phải hiện chữ trước, đẹp sau.')


def s_so_do():
    s = slide()
    y = head(s, 'Mảnh 4', 'Sơ đồ quy trình: máy tự vẽ từ dữ liệu',
             'Bọn em không vẽ tay sơ đồ này. Code đọc danh sách công đoạn rồi tự xếp chỗ, '
             'nên thêm một công đoạn là sơ đồ tự mọc thêm một ô.')
    shot(s, 'p3-so-do.png', y, max_w=Inches(7.3), max_h=Inches(3.5), left=int(ML))
    shot(s, 'code-tree.png', y, max_w=Inches(4.9), max_h=Inches(3.5),
         left=int(ML + Inches(7.6)))
    footer(s, 'worker/src/page/tree.ts — sơ đồ là SVG sinh ngay tại máy chủ, không cần thư viện vẽ đồ thị.')


# --------------------------------------------------------------- slide 11
def s_van_tay():
    s = slide()
    y = head(s, 'Phần lõi', 'Vân tay dữ liệu: thử ngay tại đây')
    shot(s, 'fig-van-tay.png', y, max_h=Inches(4.0))
    footer(s, 'SHA-256: cùng một nội dung luôn ra cùng một vân tay; đổi một ký tự thì ra vân tay hoàn toàn khác.')


def s_van_tay_code():
    s = slide()
    y = head(s, 'Phần lõi', 'Một chi tiết nhỏ mà sai là hỏng hết',
             'Hai máy đọc cùng một hồ sơ nhưng sắp xếp khoá khác nhau sẽ ra hai vân tay khác nhau. '
             'Nên trước khi băm, phải sắp mọi khoá theo đúng một thứ tự.')
    shot(s, 'code-hash.png', y, max_w=Inches(8.2), max_h=Inches(3.6), left=int(ML))
    right = ML + Inches(8.55)
    card(s, right, y, CW - Inches(8.55), Inches(3.6), 'Ví dụ đời thường',
         'Giống như xếp giấy tờ vào hồ sơ xin học: hai bộ cùng nội dung nhưng xếp khác thứ tự '
         'thì người kiểm tra thấy khác nhau.\n\nSắp theo bảng chữ cái là hết chuyện.')
    footer(s, 'worker/src/canonical.ts')


# --------------------------------------------------------------- slide 13-14
def s_blockchain():
    s = slide()
    y = head(s, 'Phần lõi', 'Ghi vân tay lên blockchain',
             'Hợp đồng thông minh của nhóm em chỉ làm một việc: ghi nhận "vân tay này, của lô này, '
             'vào lúc này". Không ghi hồ sơ, không ghi thông tin cá nhân.')
    shot(s, 'code-chain.png', y, max_w=Inches(7.9), max_h=Inches(3.2), left=int(ML))
    card(s, ML + Inches(8.25), y, CW - Inches(8.25), Inches(3.2), 'Vì sao chỉ gửi vân tay',
         'Dữ liệu trên chuỗi thì không xoá được nữa. Đẩy cả hồ sơ lên là đẩy luôn tên người, '
         'số điện thoại, và mọi lỗi chính tả — vĩnh viễn.\n\n'
         'Gửi mỗi vân tay thì vẫn chứng minh được hồ sơ không bị sửa.', size=15)
    footer(s, 'Mạng VBSN Besu, chainId 84001 — cùng nền công nghệ với EBSI của châu Âu.')


def s_giao_dich():
    s = slide()
    y = head(s, 'Bằng chứng', 'Giao dịch thật, ai cũng mở xem được')
    shot(s, 'c1-giao-dich.png', y, max_h=Inches(4.1))
    footer(s, 'Phí một lần ghi: 0,0000057 VNX. Xác nhận trong chưa tới 2 giây.')


# --------------------------------------------------------------- slide 15-16
def s_hoan_thanh():
    s = slide()
    y = head(s, 'Kết nối lại', 'Một nút bấm, bốn việc chạy',
             'Người vận hành chỉ thấy nút "Hoàn thành lô". Bên dưới là gom hồ sơ, tính vân tay, '
             'lưu thành phiên bản mới, và gửi lên chuỗi.')
    shot(s, 'a9-lich-su-qr.png', y, max_h=Inches(3.9))
    footer(s, 'Mỗi lần công bố là một phiên bản mới. Bản cũ không bị ghi đè, vẫn mở lại xem được.')


def s_qr():
    s = slide()
    y = head(s, 'Kết nối lại', 'In QR lên bao bì rồi quét thử')
    shot(s, 'p1-trang-chu.png', y, max_w=Inches(7.5), max_h=Inches(3.9), left=int(ML))
    right = ML + Inches(7.85)
    card(s, right, y, CW - Inches(7.85), Inches(3.9), 'Thử trên điện thoại thật',
         'Bọn em in mã QR ra giấy, dán lên hộp, rồi nhờ các bạn trong lớp quét thử bằng máy '
         'của các bạn.\n\n'
         'Ba bạn quét bằng 3G ở nhà và bảo "lâu quá" — đó là lý do có slide sau.')
    footer(s, 'Mã QR chứa đúng địa chỉ trace.smartbreakfast.store/t/<mã lô>.')


# --------------------------------------------------------------- slide 17-19
def s_loi1():
    s = slide()
    y = head(s, 'Chỗ làm sai số 1', 'Trang nặng 18 giây trên mạng yếu',
             'Bản đầu bọn em viết trang cho người mua bằng Flutter, cùng công nghệ với màn quản trị. '
             'Máy tính ở nhà mở nhanh nên không ai để ý.')
    shot(s, 'fig-toc-do.png', y, max_h=Inches(3.6))
    footer(s, 'Cách sửa: trang cho người mua viết lại bằng HTML dựng sẵn ở máy chủ. Màn quản trị vẫn giữ Flutter.')


def s_loi2():
    s = slide()
    y = head(s, 'Chỗ làm sai số 2', 'Một con số bọn em tự nghĩ ra')
    text(s, ML, y, Inches(7.2), Inches(3.4),
         [('Trong dữ liệu có trường "bán kính vùng trồng: 4,5 km".',
           dict(size=20, bold=True, color=INK, space=10)),
          ('Không ai đo con số đó cả. Lúc tạo dữ liệu mẫu, bọn em điền đại một số cho trang '
           'trông đầy đặn, rồi quên mất.', dict(size=17, color=INK_SOFT, line=1.4, space=12)),
          ('Đến lúc định vẽ nó thành một vòng tròn trên bản đồ thì mới phát hiện: '
           'nếu ban giám khảo hỏi "4,5 km này đo ở đâu ra?", bọn em không có câu trả lời.',
           dict(size=17, color=INK_SOFT, line=1.4, space=12)),
          ('Cách sửa: xoá hẳn trường đó khỏi hệ thống, và thay bằng ảnh bản đồ hành chính của xã — '
           'thứ tra lại được.', dict(size=17, bold=True, color=ORANGE_INK, line=1.4))])
    shot(s, 'p5-vung-nguyen-lieu.png', y, max_w=Inches(4.7), max_h=Inches(3.6),
         left=int(ML + Inches(7.6)))
    footer(s, 'Một hệ thống nói về tính trung thực thì không được có một con số bịa nào, dù nhỏ.')


def s_loi3():
    s = slide()
    y = head(s, 'Chỗ làm sai số 3', 'Giao dịch bị từ chối, máy chỉ nói "lỗi"')
    left_items = [
        'Bốn lô công bố xong nhưng không lên được chuỗi. Máy chỉ báo đúng một dòng: '
        '"RPC Request failed".',
        'Bọn em đọc lại tài liệu mạng: mỗi giao dịch phải trả phí tối thiểu 0,1 gwei.',
        'Thư viện đang tự tính phí theo công thức chung và ra 8 wei — thấp hơn mức tối thiểu '
        'hơn mười triệu lần.',
        'Cách sửa: hỏi thẳng máy chủ mạng xem giá gas hiện tại là bao nhiêu, rồi cộng thêm 25%.',
    ]
    bullets(s, left_items, ML, y, Inches(7.2), size=17, gap=Inches(0.78))
    card(s, ML + Inches(7.6), y, CW - Inches(7.6), Inches(3.4), 'Bài học',
         'Thông báo lỗi ngắn không có nghĩa là lỗi nhỏ.\n\n'
         'Bọn em phải tự viết một đoạn thử riêng, gọi thẳng vào mạng để nó nói ra con số thật, '
         'mới tìm được nguyên nhân.')
    footer(s, 'Sau khi sửa: cả bốn lô lên chuỗi trong lần gửi lại đầu tiên.')


# --------------------------------------------------------------- slide 20
def s_ai():
    s = slide()
    y = head(s, 'Nói cho rõ', 'Chúng em dùng AI như thế nào',
             'Nhóm em có dùng công cụ AI hỗ trợ viết code. Đây là phần bọn em muốn nói thẳng.')
    w = (CW - Inches(0.4)) / 2
    card(s, ML, y, w, Inches(3.1), 'AI giúp phần nào',
         '• Gợi ý cú pháp và viết nhanh những đoạn lặp đi lặp lại.\n'
         '• Giải thích lỗi khi bọn em đọc không hiểu.\n'
         '• Đề xuất cách làm khi bọn em bí.')
    card(s, ML + w + Inches(0.4), y, w, Inches(3.1), 'Phần người phải tự quyết',
         '• Chọn dữ liệu nào được công bố, dữ liệu nào không.\n'
         '• Quyết định bỏ con số bán kính tự bịa.\n'
         '• Đối chiếu quy trình sản xuất thật với từng công đoạn trong hệ thống.\n'
         '• Thử trên điện thoại thật và nghe người dùng chê.',
         tint=GREEN_SOFT, edge=GREEN_EDGE, title_color=RGBColor(0x2C, 0x6B, 0x3F))
    text(s, ML, y + Inches(3.4), CW, Inches(0.8),
         [('AI viết được câu lệnh, nhưng không biết cốm Tú Lệ rang ở bao nhiêu độ, và cũng không '
           'biết con số nào trong hồ sơ là thật. Phần đó là việc của nhóm em.',
           dict(size=18, color=INK_SOFT, line=1.35))])


# --------------------------------------------------------------- slide 21
def s_ket():
    s = slide(INK)
    text(s, ML, Inches(1.15), CW, Inches(0.4),
         [('KẾT', dict(size=14, bold=True, color=RGBColor(0x8B, 0xBF, 0x76), space=0))])
    text(s, ML, Inches(1.6), Inches(11.4), Inches(0.9),
         [('Chúng em học được gì', dict(size=40, bold=True, color=WHITE, space=0))])
    items = [
        ('Chia nhỏ thì làm được', 'Một hệ thống truy xuất nghe rất to, nhưng bổ thành bốn mảnh '
                                  'thì mảnh nào cũng vừa sức một nhóm học sinh.'),
        ('Trung thực là một quyết định kỹ thuật', 'Xoá một con số tự bịa khó hơn thêm nó vào, '
                                                  'vì phải công bố lại toàn bộ và tốn thêm giao dịch.'),
        ('Phải thử ở nơi người dùng thật đứng', 'Trang chạy nhanh trên máy ở nhà mà mất 18 giây '
                                                'ngoài chợ thì vẫn là trang hỏng.'),
    ]
    y = Inches(2.85)
    for title, body in items:
        text(s, ML, y, Inches(11.4), Inches(0.4),
             [(title, dict(size=21, bold=True, color=RGBColor(0xC4, 0xD6, 0xCA), space=4))])
        text(s, ML, y + Inches(0.42), Inches(11.0), Inches(0.6),
             [(body, dict(size=16, color=RGBColor(0x9F, 0xB8, 0xA8), line=1.3))])
        y += Inches(1.25)
    text(s, ML, Inches(6.65), CW, Inches(0.4),
         [('Việc tiếp theo: tài khoản riêng cho từng người vận hành, app cho điện thoại, '
           'và để mỗi hợp tác xã tự ký phần của mình.',
           dict(size=15, color=RGBColor(0x8B, 0xA8, 0x95)))])


for build in [
    s_cover, s_baitoan, s_ytuong, s_chia, s_vscode,
    s_tu_ho_so, s_o_cua, s_nhap_lieu, s_nhap_lieu2,
    s_trang_mua, s_so_do, s_van_tay, s_van_tay_code,
    s_blockchain, s_hop_dong, s_giao_dich, s_hoan_thanh, s_qr,
    s_loi1, s_loi2, s_loi3, s_ai, s_ket,
]:
    build()

prs.save(OUT)
print('Đã lưu', OUT, '—', len(prs.slides.__iter__.__self__._sldIdLst), 'slide')
