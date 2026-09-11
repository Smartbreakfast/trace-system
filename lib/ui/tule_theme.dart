import 'package:flutter/material.dart';

/// Bảng màu thương hiệu Tú Lệ.
///
/// Hai biến thể cam: [componentOrange] dùng cho mảng nền và icon lớn,
/// [brandOrangeText] dùng cho chữ nhỏ vì bản gốc chỉ đạt tỉ lệ tương phản
/// 3.2:1 trên nền trắng (dưới ngưỡng WCAG AA 4.5:1).
const componentInk = Color(0xFF17352A);
const componentLeaf = Color(0xFF8BBF76);
const componentCream = Color(0xFFF7F5ED);
const componentOrange = Color(0xFFE2703A);
const brandOrangeText = Color(0xFFA84B1B);
const brandInkSoft = Color(0xFF10251F);
const brandMuted = Color(0xFF5A6560);
const brandLine = Color(0x14173529);
const brandSurface = Colors.white;
const brandPanel = Color(0xFFE8F0E5);

/// Màu và số đo của thanh điều hướng, lấy đúng từ `assets/css/style.css` của
/// trang giới thiệu smartbreakfast.store. Trang này là một hệ thống khác chạy
/// trên tên miền con, nhưng với người dùng nó phải là cùng một website, nên
/// thanh trên phải trùng đến từng màu chứ không chỉ trùng thứ tự mục.
///
/// Chỉ dùng cho thanh điều hướng và chân trang; thân trang truy xuất vẫn giữ
/// bảng màu riêng ở trên.
const landingTeal = Color(0xFF007E88);
const landingTealBright = Color(0xFF0096A0);
const landingTealInk = Color(0xFF00666E);
const landingInk = Color(0xFF14201F);
const landingInk2 = Color(0xFF4E5B59);
const landingInk3 = Color(0xFF7C8785);
const landingLine = Color(0xFFE6E1D6);
const landingLine2 = Color(0xFFD3CCBD);

/// Nền trang truy xuất: xanh lá rất nhạt, đủ để nói "nông sản, tự nhiên" mà
/// không nhuộm màu lên ảnh sản phẩm. Thẻ vẫn trắng nên chữ và ảnh giữ nguyên
/// độ tương phản; chỉ khoảng nền quanh chúng đổi tông.
///
/// Màn quản trị vẫn dùng [componentCream]: đó là chỗ làm việc mỗi ngày, không
/// phải chỗ kể chuyện thương hiệu.
const traceGroundTop = Color(0xFFF6F6F1);
const traceGroundBottom = Color(0xFFEEF0E7);

/// Font chữ. `BeVietnamPro` cho toàn bộ giao diện, `Lora` cho tiêu đề lớn.
const brandFont = 'BeVietnamPro';
const displayFont = 'Lora';

/// Màu nhấn cho từng nguyên liệu, dùng chung giữa explorer và management.
const ingredientAccents = <Color>[
  Color(0xFF6BA56D),
  Color(0xFFB65C45),
  Color(0xFFE2A545),
  Color(0xFF876B9E),
];

const ingredientIcons = <IconData>[
  Icons.grass,
  Icons.spa,
  Icons.eco,
  Icons.local_florist,
];

/// Ngưỡng breakpoint dùng thống nhất toàn app thay vì rải magic number.
abstract final class Breakpoints {
  static const compact = 640.0;
  static const medium = 900.0;
  static const contentMaxWidth = 1600.0;

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < compact;
  static bool isWide(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= medium;

  /// Padding ngang của vùng nội dung theo bề rộng màn hình.
  static double gutter(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= medium) return 55;
    if (width >= compact) return 32;
    return 20;
  }
}

ThemeData buildTuleTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: componentInk,
    onPrimary: Colors.white,
    primaryContainer: brandPanel,
    onPrimaryContainer: componentInk,
    secondary: brandOrangeText,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFFFF0E3),
    onSecondaryContainer: brandOrangeText,
    tertiary: componentLeaf,
    onTertiary: componentInk,
    error: Color(0xFFA02A22),
    onError: Colors.white,
    errorContainer: Color(0xFFFBE6E4),
    onErrorContainer: Color(0xFF7A1F19),
    surface: componentCream,
    onSurface: componentInk,
    surfaceContainerHighest: Color(0xFFEDEBE1),
    onSurfaceVariant: brandMuted,
    outline: Color(0x3319362B),
    outlineVariant: brandLine,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: brandFont,
  );

  return base.copyWith(
    scaffoldBackgroundColor: componentCream,
    textTheme: base.textTheme.apply(
      bodyColor: componentInk,
      displayColor: componentInk,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: brandSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: brandLine),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: brandLine),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: componentInk, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFA02A22)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFA02A22), width: 2),
      ),
      labelStyle: const TextStyle(color: brandMuted),
      helperStyle: const TextStyle(color: brandMuted, fontSize: 12),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: componentInk,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: componentInk,
        minimumSize: const Size(0, 44),
        side: const BorderSide(color: Color(0x3319362B)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: brandOrangeText,
        minimumSize: const Size(0, 44),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: brandInkSoft,
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      width: 420,
    ),
    dividerTheme: const DividerThemeData(color: brandLine, space: 1),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: brandSurface,
      side: const BorderSide(color: brandLine),
      labelStyle: const TextStyle(color: componentInk, fontSize: 12),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: brandInkSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(color: Colors.white, fontSize: 12),
    ),
  );
}

/// Tiêu đề của cả một màn, lớn hơn tiêu đề khối một bậc.
const pageTitleStyle = TextStyle(
  fontSize: 25,
  fontWeight: FontWeight.w700,
  color: componentInk,
  letterSpacing: -.2,
);

/// Tiêu đề kể chuyện: tên lô, tên nguyên liệu trên trang khách. Dùng serif để
/// trang truy xuất không mang giọng của một bảng điều khiển.
const displayTitleStyle = TextStyle(
  fontFamily: displayFont,
  fontSize: 22,
  fontWeight: FontWeight.w600,
  color: componentInk,
  height: 1.25,
);

const sectionTitleStyle = TextStyle(
  fontSize: 19,
  fontWeight: FontWeight.w800,
  color: componentInk,
  letterSpacing: -.2,
);

const sectionCaptionStyle = TextStyle(
  color: brandMuted,
  fontSize: 14,
  height: 1.45,
);

/// Kiểu chữ cho mã lô và mã băm.
///
/// Không dùng họ 'monospace': trên web không có font hệ thống nào được nạp
/// sẵn, nên CanvasKit đi tải Roboto và Noto Sans từ fonts.gstatic.com, tốn
/// 257KB chỉ để hiện một dòng mã. Dùng chính font của trang với chữ số đều
/// bề ngang cho ra cùng hiệu quả canh cột mà không tải thêm gì.
const monoStyle = TextStyle(
  fontFamily: brandFont,
  color: componentInk,
  fontWeight: FontWeight.w700,
  letterSpacing: .6,
  fontFeatures: [FontFeature.tabularFigures()],
);
