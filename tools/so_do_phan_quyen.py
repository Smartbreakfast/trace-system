# -*- coding: utf-8 -*-
"""Vẽ sơ đồ phân quyền vai trò của Tú Lệ Trace ra PNG để dán vào báo cáo.

    python tools/so_do_phan_quyen.py

Ra tệp tai-lieu/anh/so-do-phan-quyen.png (300 dpi, nền trắng, chữ đen) để chèn
vào tài liệu Word. Sơ đồ đọc theo ba tầng: người dùng -> vai trò -> việc được
làm, cộng một cột cho người mua (không có tài khoản).

Nguồn sự thật là bảng quyền trong worker/src/auth.ts. Sửa quyền ở đó thì sửa
cả danh sách dưới đây, nếu không sơ đồ nói một đằng hệ thống làm một nẻo.
"""
import os

import matplotlib

matplotlib.use('Agg')
import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.patches import FancyArrowPatch, FancyBboxPatch  # noqa: E402

# Tìm font có chữ tiếng Việt. Dùng font mặc định thì dấu rụng hết thành ô vuông.
for family in ('Times New Roman', 'Segoe UI', 'Arial', 'DejaVu Sans'):
    try:
        matplotlib.font_manager.findfont(family, fallback_to_default=False)
    except Exception:
        continue
    plt.rcParams['font.family'] = family
    break

INK = '#15241c'
LINE = '#9aa8a0'
LEAF = '#2f6f4e'
MUTED = '#5d6b63'

ROLES = [
    (
        'QUẢN TRỊ HỆ THỐNG',
        '1 tài khoản',
        [
            'Thấy dữ liệu của mọi cơ sở',
            'Tạo, khoá, đặt lại mật khẩu tài khoản',
            'Quản lý danh mục sản phẩm',
            'Gửi tay mã băm lên blockchain',
            'Xem nhật ký toàn hệ thống',
        ],
    ),
    (
        'PHỤ TRÁCH CƠ SỞ',
        '1 tài khoản mỗi cơ sở',
        [
            'Chỉ thấy dữ liệu cơ sở mình',
            'Tạo lô, khai nguyên liệu',
            'Công bố lô (chốt bản, sinh mã băm)',
            'Xem nhật ký của cơ sở mình',
            'Không quản lý được tài khoản',
        ],
    ),
    (
        'NHÂN VIÊN CÔNG ĐOẠN',
        'nhiều tài khoản mỗi cơ sở',
        [
            'Chỉ thấy dữ liệu cơ sở mình',
            'Khai công đoạn mình làm',
            'Đính ảnh, tài liệu công đoạn',
            'Không tạo lô, không công bố',
            'Không xem nhật ký, không xoá',
        ],
    ),
]


def box(ax, x, y, width, height, face, edge, radius=0.018):
    ax.add_patch(
        FancyBboxPatch(
            (x, y),
            width,
            height,
            boxstyle=f'round,pad=0,rounding_size={radius}',
            linewidth=1.1,
            facecolor=face,
            edgecolor=edge,
        )
    )


def arrow(ax, start, end, style='-|>', color=LINE, dashed=False):
    ax.add_patch(
        FancyArrowPatch(
            start,
            end,
            arrowstyle=style,
            mutation_scale=11,
            linewidth=1.1,
            color=color,
            linestyle='dashed' if dashed else 'solid',
            shrinkA=0,
            shrinkB=0,
        )
    )


def draw():
    figure, ax = plt.subplots(figsize=(9.6, 7.4))
    ax.set_xlim(0, 1)
    ax.set_ylim(0, 1)
    ax.axis('off')
    figure.patch.set_facecolor('white')

    ax.text(
        0.5,
        0.975,
        'PHÂN QUYỀN VAI TRÒ – HỆ THỐNG TÚ LỆ TRACE',
        ha='center',
        va='top',
        fontsize=13,
        fontweight='bold',
        color=INK,
    )
    ax.text(
        0.5,
        0.941,
        'Quyền do máy chủ kiểm ở từng lệnh gọi API, không phải chỉ ẩn nút trên giao diện',
        ha='center',
        va='top',
        fontsize=8.5,
        color=MUTED,
    )

    # --- hàng vai trò ---
    width, gap = 0.29, 0.035
    left = (1 - (width * 3 + gap * 2)) / 2
    top, height = 0.86, 0.40
    centers = []
    for index, (title, note, duties) in enumerate(ROLES):
        x = left + index * (width + gap)
        box(ax, x, top - height, width, height, '#f7f9f7', LINE)
        # Dải màu đầu thẻ, đậm dần theo mức quyền.
        shade = ['#2f6f4e', '#4e8468', '#7aa893'][index]
        box(ax, x, top - 0.062, width, 0.062, shade, shade)
        ax.text(
            x + width / 2,
            top - 0.031,
            title,
            ha='center',
            va='center',
            fontsize=9.2,
            fontweight='bold',
            color='white',
        )
        ax.text(
            x + width / 2,
            top - 0.082,
            note,
            ha='center',
            va='center',
            fontsize=7.6,
            color=MUTED,
            style='italic',
        )
        for line, duty in enumerate(duties):
            can = not duty.startswith('Không')
            ax.text(
                x + 0.016,
                top - 0.118 - line * 0.052,
                ('+ ' if can else '–  ') + duty,
                ha='left',
                va='top',
                fontsize=8.1,
                color=INK if can else '#7a1f19',
            )
        centers.append(x + width / 2)

    # --- nguồn dữ liệu chung ---
    data_y, data_h = 0.255, 0.10
    box(ax, left, data_y, width * 3 + gap * 2, data_h, '#eef3ef', LEAF)
    ax.text(
        0.5,
        data_y + data_h - 0.028,
        'DỮ LIỆU LÔ CỦA TỪNG CƠ SỞ (Cloudflare D1 + R2)',
        ha='center',
        va='center',
        fontsize=9,
        fontweight='bold',
        color=INK,
    )
    ax.text(
        0.5,
        data_y + 0.03,
        'Mọi truy vấn của hai vai trò dưới đều bị lọc theo cơ sở ngay trong câu SQL:\n'
        'người của cơ sở này gọi API với mã lô của cơ sở kia thì bị từ chối 403',
        ha='center',
        va='center',
        fontsize=8,
        color=MUTED,
        linespacing=1.5,
    )

    for center in centers:
        arrow(ax, (center, top - height), (center, data_y + data_h))

    # --- niêm phong và nhật ký ---
    seal_y, seal_h = 0.105, 0.10
    box(ax, left, seal_y, width * 1.62, seal_h, '#f7f9f7', LINE)
    ax.text(
        left + 0.016,
        seal_y + seal_h - 0.026,
        'BẢN CÔNG BỐ ĐÃ NIÊM PHONG',
        ha='left',
        va='center',
        fontsize=8.6,
        fontweight='bold',
        color=INK,
    )
    ax.text(
        left + 0.016,
        seal_y + 0.026,
        'SHA-256 của hồ sơ lô, neo lên blockchain VBSN.\n'
        'Chỉ phụ trách cơ sở và quản trị tạo được bản này.',
        ha='left',
        va='center',
        fontsize=7.8,
        color=MUTED,
        linespacing=1.5,
    )

    log_x = left + width * 1.62 + gap
    box(ax, log_x, seal_y, (left + width * 3 + gap * 2) - log_x, seal_h, '#f7f9f7', LINE)
    ax.text(
        log_x + 0.016,
        seal_y + seal_h - 0.026,
        'NHẬT KÝ THAO TÁC',
        ha='left',
        va='center',
        fontsize=8.6,
        fontweight='bold',
        color=INK,
    )
    ax.text(
        log_x + 0.016,
        seal_y + 0.026,
        'Ai, vai trò gì, làm gì, lúc nào. Nằm ngoài\nvùng băm nên không đổi mã băm của lô.',
        ha='left',
        va='center',
        fontsize=7.8,
        color=MUTED,
        linespacing=1.5,
    )

    arrow(ax, (left + width * 0.8, data_y), (left + width * 0.8, seal_y + seal_h))
    arrow(ax, (log_x + 0.09, data_y), (log_x + 0.09, seal_y + seal_h), dashed=True)

    # --- người mua: không có tài khoản ---
    ax.text(
        0.5,
        0.055,
        'NGƯỜI MUA: quét mã QR xem hồ sơ và kiểm chứng mã băm, không cần tài khoản.\n'
        'Chỉ đọc bản đã công bố và gửi đánh giá sao; không thấy màn quản trị.',
        ha='center',
        va='center',
        fontsize=8.2,
        color=INK,
        linespacing=1.6,
    )

    target = os.path.join('tai-lieu', 'anh', 'so-do-phan-quyen.png')
    os.makedirs(os.path.dirname(target), exist_ok=True)
    figure.savefig(target, dpi=300, facecolor='white', bbox_inches='tight')
    print('đã ghi %s (%.0f KB)' % (target, os.path.getsize(target) / 1024))
    return target


if __name__ == '__main__':
    draw()
