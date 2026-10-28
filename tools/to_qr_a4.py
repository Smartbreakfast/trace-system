# -*- coding: utf-8 -*-
"""Dựng một trang A4 gồm địa chỉ website và mã QR của từng lô đang công bố.

Danh sách lô đọc thẳng từ bản đang chạy chứ không chép tay: tờ giấy in ra là
để người cầm quét thật, nên nó phải đúng với hệ thống tại thời điểm in. Lô nào
chưa công bố thì không có trên trang truy xuất công khai nên cũng không in.

Mã QR chỉ chứa địa chỉ công khai của lô, không chứa khoá hay mã đăng nhập nào.

Chạy: python tools/to_qr_a4.py          → out/qr-a4.html và out/qr-a4.pdf
      python tools/to_qr_a4.py --docx   → thêm out/qr-a4.docx

Bản .docx theo đúng khổ hồ sơ dự thi khoa học kỹ thuật như tools/md_sang_docx.py
(A4, lề trái 3cm, phải 2cm, trên dưới 2cm, Times New Roman) để dán thẳng vào
phụ lục báo cáo mà không phải chỉnh lại định dạng.
"""
import base64
import io
import json
import os
import subprocess
import sys
import urllib.request

import qrcode
import qrcode.image.svg
from docx import Document
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml.ns import qn
from docx.shared import Cm, Pt, RGBColor

sys.stdout.reconfigure(encoding='utf-8')

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'out')
SITE = 'https://trace.smartbreakfast.store'
CHROME = r'C:\Program Files\Google\Chrome\Application\chrome.exe'


def fetch(path):
    req = urllib.request.Request(SITE + path,
                                 headers={'User-Agent': 'tule-trace-tools/1.0'})
    with urllib.request.urlopen(req) as f:
        return json.load(f)


def qr_svg(text):
    """Mã QR dạng SVG: in ra giấy sắc nét ở mọi khổ, không vỡ như ảnh bitmap."""
    img = qrcode.make(text, image_factory=qrcode.image.svg.SvgPathImage,
                      box_size=10, border=0)
    buf = io.BytesIO()
    img.save(buf)
    return 'data:image/svg+xml;base64,' + base64.b64encode(buf.getvalue()).decode()


def qr_png(text, path):
    """Mã QR dạng ảnh. Word không nhúng được SVG nên bản .docx phải dùng PNG;
    để box_size cao cho ảnh đủ điểm ảnh, in ra giấy không bị răng cưa."""
    qrcode.make(text, box_size=14, border=0).save(path)
    return path


def data_uri(path, mime):
    with open(path, 'rb') as f:
        return 'data:%s;base64,%s' % (mime, base64.b64encode(f.read()).decode())


def build():
    catalog = fetch('/api/public/catalog')
    fonts = {
        'reg': data_uri(os.path.join(ROOT, 'assets', 'fonts',
                                     'BeVietnamPro-Regular.ttf'), 'font/ttf'),
        'semi': data_uri(os.path.join(ROOT, 'assets', 'fonts',
                                      'BeVietnamPro-SemiBold.ttf'), 'font/ttf'),
    }
    logo = data_uri(os.path.join(ROOT, 'assets', 'brand', 'logo-mark.png'),
                    'image/png')

    lots = 0
    sections = []
    for product in catalog:
        cards = []
        for batch in product['batches']:
            lots += 1
            url = '%s/t/%s' % (SITE, batch['code'])
            cards.append(
                '<figure class="lo"><img src="%s" alt="Mã QR lô %s">'
                '<figcaption><b>%s</b><span>%s</span></figcaption></figure>'
                % (qr_svg(url), batch['code'], batch['code'],
                   batch.get('productionDate') or ''))
        sections.append(
            '<section><h2>%s</h2><div class="hang">%s</div></section>'
            % (product['name'], ''.join(cards)))

    html = TEMPLATE % {
        'reg': fonts['reg'], 'semi': fonts['semi'], 'logo': logo,
        'site_qr': qr_svg(SITE), 'site': SITE,
        'sections': ''.join(sections), 'lots': lots,
    }

    os.makedirs(OUT, exist_ok=True)
    page = os.path.join(OUT, 'qr-a4.html')
    with open(page, 'w', encoding='utf-8') as f:
        f.write(html)
    print('đã ghi', page, '-', lots, 'lô')

    if '--docx' in sys.argv:
        tmp = os.path.join(OUT, 'qr-png')
        os.makedirs(tmp, exist_ok=True)
        doc = os.path.join(OUT, 'qr-a4.docx')
        build_docx(catalog, doc, tmp)
        print('đã ghi', doc)

    pdf = os.path.join(OUT, 'qr-a4.pdf')
    try:
        subprocess.run([CHROME, '--headless', '--disable-gpu',
                        '--no-pdf-header-footer', '--print-to-pdf=' + pdf,
                        'file:///' + page.replace(os.sep, '/')],
                       check=True, capture_output=True, timeout=120)
        print('đã ghi', pdf)
    except Exception as error:
        print('không dựng được PDF (%s); mở file html rồi Ctrl+P' % error)


BODY_FONT = 'Times New Roman'
INK = RGBColor(0x17, 0x35, 0x29)
MUTED = RGBColor(0x5A, 0x65, 0x60)


def chu(paragraph, text, size=13, bold=False, color=INK):
    run = paragraph.add_run(text)
    run.bold = bold
    run.font.size = Pt(size)
    run.font.color.rgb = color
    return run


def build_docx(catalog, path, tmp):
    document = Document()
    style = document.styles['Normal']
    style.font.name = BODY_FONT
    style.element.rPr.rFonts.set(qn('w:eastAsia'), BODY_FONT)
    style.paragraph_format.space_after = Pt(4)
    style.paragraph_format.line_spacing = 1.0
    for section in document.sections:
        section.left_margin, section.right_margin = Cm(3), Cm(2)
        section.top_margin, section.bottom_margin = Cm(2), Cm(2)

    title = document.add_paragraph()
    chu(title, 'TÚ LỆ TRACE - MÃ QR TRUY XUẤT NGUỒN GỐC', size=14, bold=True)
    sub = document.add_paragraph()
    chu(sub, 'Quét mã trên mỗi lô để xem hồ sơ sản xuất của chính lô đó.',
        size=12, color=MUTED)

    # Địa chỉ website đứng riêng một bảng hai cột: mã QR bên trái, chữ bên phải.
    web = document.add_table(rows=1, cols=2)
    web.alignment = WD_TABLE_ALIGNMENT.LEFT
    cell = web.rows[0].cells[0]
    cell.width = Cm(4)
    anh = cell.paragraphs[0]
    anh.alignment = WD_ALIGN_PARAGRAPH.CENTER
    anh.add_run().add_picture(qr_png(SITE, os.path.join(tmp, 'site.png')),
                              width=Cm(3.4))
    cell = web.rows[0].cells[1]
    cell.width = Cm(12)
    chu(cell.paragraphs[0], 'Địa chỉ website', size=12, bold=True)
    chu(cell.add_paragraph(), 'trace.smartbreakfast.store', size=14, bold=True)
    chu(cell.add_paragraph(),
        'Quét mã bên trái để mở trang tra cứu. Nhập mã lô in trên bao bì vào ô '
        'tìm kiếm là ra hồ sơ, không cần tài khoản.', size=11, color=MUTED)

    lots = 0
    for product in catalog:
        heading = document.add_paragraph()
        heading.paragraph_format.space_before = Pt(10)
        chu(heading, product['name'], size=13, bold=True)

        batches = product['batches']
        rows = (len(batches) + 3) // 4
        table = document.add_table(rows=rows, cols=4)
        table.alignment = WD_TABLE_ALIGNMENT.LEFT
        for index, batch in enumerate(batches):
            lots += 1
            cell = table.rows[index // 4].cells[index % 4]
            cell.width = Cm(4)
            url = '%s/t/%s' % (SITE, batch['code'])
            anh = cell.paragraphs[0]
            anh.alignment = WD_ALIGN_PARAGRAPH.CENTER
            anh.add_run().add_picture(
                qr_png(url, os.path.join(tmp, batch['code'] + '.png')),
                width=Cm(3.4))
            ma = cell.add_paragraph()
            ma.alignment = WD_ALIGN_PARAGRAPH.CENTER
            chu(ma, batch['code'], size=11, bold=True)
            ngay = cell.add_paragraph()
            ngay.alignment = WD_ALIGN_PARAGRAPH.CENTER
            chu(ngay, batch.get('productionDate') or '', size=10, color=MUTED)

    cuoi = document.add_paragraph()
    cuoi.paragraph_format.space_before = Pt(12)
    chu(cuoi, '%d lô đang công bố tại thời điểm in. Mỗi mã QR mở thẳng hồ sơ '
        'của một lô: nguyên liệu, từng công đoạn kèm khối lượng vào ra, hình '
        'ảnh và kết quả đối chiếu với bản ghi đã neo trên blockchain.' % lots,
        size=11, color=MUTED)

    document.save(path)
    return lots


TEMPLATE = """<!doctype html>
<html lang="vi"><meta charset="utf-8">
<title>Tú Lệ Trace - mã QR truy xuất</title>
<style>
@font-face { font-family: BeVietnam; src: url(%(reg)s); font-weight: 400 }
@font-face { font-family: BeVietnam; src: url(%(semi)s); font-weight: 600 }
@page { size: A4; margin: 0 }
* { box-sizing: border-box }
body { margin: 0; font-family: BeVietnam, sans-serif; color: #17352A;
       -webkit-print-color-adjust: exact; print-color-adjust: exact }
.trang { width: 210mm; height: 297mm; padding: 13mm 14mm 10mm;
         display: flex; flex-direction: column }
header { display: flex; align-items: center; gap: 4mm;
         border-bottom: 0.4mm solid #17352A; padding-bottom: 3.5mm }
header img { width: 13mm; height: 13mm }
h1 { font-size: 15pt; font-weight: 600; margin: 0; letter-spacing: -0.2pt }
header p { margin: 1mm 0 0; font-size: 8.5pt; color: #5A6560 }
.web { display: flex; align-items: center; gap: 6mm; margin: 6mm 0 2mm;
       padding: 5mm; background: #F7F5ED; border-radius: 2mm }
.web img { width: 30mm; height: 30mm }
.web b { display: block; font-size: 8pt; font-weight: 600; color: #A84B1B;
         letter-spacing: 0.6pt; text-transform: uppercase }
.web a { display: block; font-size: 13pt; font-weight: 600; margin: 1.5mm 0;
         color: #17352A; text-decoration: none }
.web p { margin: 0; font-size: 8.5pt; color: #5A6560; line-height: 1.5 }
section { margin-top: 7mm }
h2 { font-size: 11.5pt; font-weight: 600; margin: 0 0 2.5mm;
     padding-bottom: 1.5mm; border-bottom: 0.3mm solid rgba(23,53,41,.14) }
.hang { display: flex; gap: 6mm }
.lo { margin: 0; width: 38mm; text-align: center }
.lo img { width: 38mm; height: 38mm; display: block }
.lo figcaption { margin-top: 1.5mm }
.lo b { display: block; font-size: 9.5pt; font-weight: 600;
        letter-spacing: 0.2pt }
.lo span { display: block; font-size: 8.5pt; color: #5A6560; margin-top: 0.5mm }
footer { margin-top: auto; padding-top: 3mm; font-size: 7.5pt; color: #5A6560;
         border-top: 0.3mm solid rgba(23,53,41,.14); line-height: 1.6 }
</style>
<div class="trang">
  <header>
    <img src="%(logo)s" alt="">
    <div>
      <h1>Tú Lệ Trace - mã QR truy xuất nguồn gốc</h1>
      <p>Quét mã trên mỗi lô để xem hồ sơ sản xuất của chính lô đó.</p>
    </div>
  </header>

  <div class="web">
    <img src="%(site_qr)s" alt="Mã QR trang chủ">
    <div>
      <b>Địa chỉ website</b>
      <a href="%(site)s">trace.smartbreakfast.store</a>
      <p>Quét mã bên trái để mở trang tra cứu. Nhập mã lô in trên bao bì
        vào ô tìm kiếm là ra hồ sơ, không cần tài khoản.</p>
    </div>
  </div>

  %(sections)s

  <footer>
    %(lots)s lô đang công bố tại thời điểm in. Mỗi mã QR mở thẳng hồ sơ của
    một lô: nguyên liệu, từng công đoạn kèm khối lượng vào ra, hình ảnh và
    kết quả đối chiếu với bản ghi đã neo trên blockchain.
  </footer>
</div>
</html>"""

if __name__ == '__main__':
    build()
