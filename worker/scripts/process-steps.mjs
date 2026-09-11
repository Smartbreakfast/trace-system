// Quy trình sản xuất theo sơ đồ và thuyết minh trong docs/.
//
// Đây là bản chép lại đầy đủ, không rút gọn: từng ô trong sơ đồ là một công
// đoạn, kể cả những ô là kết quả trung gian (dịch khoai môn, sữa lạc, bột cốm),
// và mô tả giữ nguyên phần Mục đích / Tiến hành / Lưu ý của tài liệu. Người
// vận hành nhập lô mới chỉ còn việc tải ảnh lên.

export const INGREDIENT_STEPS = {
  com: [
    [
      'Rang',
      'Mục đích: làm chín và tạo hương vị đặc trưng. Tiến hành: cho cốm vào chảo rang ở nhiệt độ 100°C, đến khi cốm nở, hơi ngả màu và có mùi thơm. Lưu ý: đảo đều tay trong suốt quá trình rang để cốm không bị cháy.',
    ],
    [
      'Xay',
      'Mục đích: đưa cốm đã rang về dạng bột. Tiến hành: nghiền hai lần rồi rây qua lưới 120 mesh. Lưu ý: bột phải mịn đều, không còn hạt lớn.',
    ],
    [
      'Bột cốm',
      'Thành phẩm của nhánh cốm. Định mức: 500g cốm cho ra khoảng 135g bột.',
    ],
  ],
  lac: [
    [
      'Ngâm',
      'Mục đích: làm mềm hạt, giảm mùi hăng và loại bỏ tạp chất. Tiến hành: ngâm 2-3 giờ trong nước sạch. Lưu ý: loại bỏ hạt lép, hạt hư trước khi ngâm.',
    ],
    [
      'Xay',
      'Mục đích: giải phóng chất dinh dưỡng trong hạt. Tiến hành: xay nghiền cùng nước theo tỷ lệ thích hợp. Lưu ý: không xay quá lâu làm tăng nhiệt của hỗn hợp.',
    ],
    [
      'Lọc',
      'Mục đích: tách bã ra khỏi dịch. Tiến hành: lọc bằng vải lọc, rây hoặc máy lọc. Lưu ý: dụng cụ lọc phải sạch.',
    ],
    [
      'Sữa lạc',
      'Mục đích: tạo nguyên liệu bổ sung protein và chất béo cho công thức. Tiến hành: thu phần dịch sau lọc. Lưu ý: tránh để sữa lạc bị tách lớp.',
    ],
    [
      'Sấy phun',
      'Mục đích: đưa dịch về dạng bột. Tiến hành: lọc bỏ cặn bẩn, bổ sung maltodextrin rồi tiến hành sấy phun.',
    ],
    [
      'Phối trộn',
      'Mục đích: mẻ bột đồng nhất trước khi nhập kho. Tiến hành: trộn đều toàn bộ bột lạc thu được của mẻ.',
    ],
    [
      'Bột lạc',
      'Thành phẩm của nhánh lạc. Định mức: 1000g lạc cho ra khoảng 205g bột.',
    ],
  ],
  chuoi: [
    [
      'Bóc vỏ',
      'Mục đích: loại bỏ phần không sử dụng. Tiến hành: chọn chuối tiêu khoảng 9 tuần, bóc sạch vỏ. Lưu ý: không dùng quả dập nát, quá xanh hoặc đã chín.',
    ],
    [
      'Nghiền mịn',
      'Mục đích: giải phóng chất dinh dưỡng. Tiến hành: xay cùng nước theo tỷ lệ thích hợp. Lưu ý: không xay quá lâu làm tăng nhiệt.',
    ],
    [
      'Lọc',
      'Mục đích: tách bã ra khỏi dịch. Tiến hành: lọc bằng vải lọc, rây hoặc máy lọc. Lưu ý: dụng cụ lọc phải sạch.',
    ],
    [
      'Sấy phun',
      'Mục đích: đưa dịch về dạng bột. Tiến hành: lọc bỏ cặn bẩn, bổ sung maltodextrin rồi tiến hành sấy phun.',
    ],
    [
      'Bột chuối',
      'Thành phẩm của nhánh chuối. Định mức: 1000g chuối cho ra khoảng 210g bột.',
    ],
  ],
  khoai: [
    [
      'Làm sạch, bỏ vỏ',
      'Mục đích: loại bỏ đất cát, tạp chất, vi sinh vật bám trên bề mặt và lớp vỏ nhiều chất xơ để sản phẩm có màu đẹp. Tiến hành: chọn củ tươi, không dập nát, không sâu bệnh; rửa sạch bằng nước nhiều lần; gọt bỏ hoàn toàn lớp vỏ ngoài. Lưu ý: không ngâm khoai quá lâu vì dễ mất chất dinh dưỡng, gọt xong phải chế biến ngay để tránh thâm đen.',
    ],
    [
      'Thái',
      'Mục đích: giảm kích thước nguyên liệu, giúp quá trình hấp và nghiền nhanh hơn. Tiến hành: thái khoai thành lát dày khoảng 0,5-1cm.',
    ],
    [
      'Nghiền mịn',
      'Mục đích: phá vỡ cấu trúc mô tế bào và tạo hỗn hợp đồng nhất. Tiến hành: nghiền cùng nước theo tỷ lệ thích hợp. Lưu ý: hỗn hợp phải mịn, không còn cục lớn.',
    ],
    [
      'Thuỷ phân',
      'Mục đích: phân giải tinh bột thành đường đơn và dextrin, giúp sản phẩm dễ tiêu hoá và có vị ngọt tự nhiên. Tiến hành: bổ sung enzyme amylase, duy trì nhiệt độ 80-90°C trong 60 phút. Lưu ý: theo dõi nhiệt độ để enzyme hoạt động tốt.',
    ],
    [
      'Dịch khoai môn',
      'Mục đích: bán thành phẩm dạng dịch trước khi sấy. Tiến hành: thu toàn bộ dịch sau thuỷ phân.',
    ],
    [
      'Sấy phun',
      'Mục đích: đưa dịch về dạng bột. Tiến hành: lọc bỏ cặn bẩn, bổ sung maltodextrin rồi tiến hành sấy phun.',
    ],
    [
      'Bột khoai môn',
      'Thành phẩm của nhánh khoai môn. Định mức: 500g khoai cho ra khoảng 320g bột.',
    ],
  ],
};

export const BATCH_STEPS = [
  [
    'Phối trộn',
    'Mục đích: tạo sản phẩm đồ uống có hương vị đặc trưng và giá trị dinh dưỡng cao. Tiến hành: trộn bột khoai môn, bột lạc, bột chuối và bột cốm cùng bột kem sữa và bột vani theo định mức của công thức.',
  ],
  [
    'Đóng gói',
    'Mục đích: bảo quản sản phẩm. Tiến hành: đóng gói 30g mỗi gói, 20 gói một hộp, hàn kín miệng gói. Thành phẩm có màu sắc đặc trưng, mùi thơm của khoai môn, lạc và cốm, vị ngọt dịu.',
  ],
];

/// Tên cũ của các công đoạn đã nhập trước khi có sơ đồ đầy đủ.
///
/// Đổi tên tại chỗ thay vì tạo mới: công đoạn cũ đang mang ảnh, xoá đi tạo lại
/// là mất ảnh. Khoá là tên chuẩn trong sơ đồ, giá trị là những tên từng dùng.
export const STEP_ALIASES = {
  'Rang': ['Rang cốm', 'Nổ bỏng và làm sạch'],
  'Xay': [
    'Nghiền mịn thành bột cốm',
    'Nghiền thành bột mịn',
    'Nghiền mịn và lọc lấy sữa lạc',
    'Xay với nước',
  ],
  'Ngâm': ['Ngâm lạc', 'Tách vỏ và làm sạch'],
  'Bóc vỏ': ['Chọn và bóc vỏ chuối', 'Bóc vỏ và thái mỏng', 'Chọn chuối xanh VietGAP'],
  'Nghiền mịn': ['Nghiền mịn và lọc', 'Nghiền và thuỷ phân'],
  'Làm sạch, bỏ vỏ': ['Làm sạch, gọt vỏ và thái', 'Thu hoạch tại vùng trồng'],
  'Sấy phun': [
    'Sấy phun thành bột lạc',
    'Sấy phun thành bột chuối',
    'Sấy phun thành bột khoai môn',
  ],
  'Phối trộn': ['Phối trộn thành phần'],
  'Đóng gói': ['Đóng gói sản phẩm'],
};

/// Ghép tên nguyên liệu trong database với nhánh quy trình tương ứng. Tên có
/// thể khác đôi chút giữa các lô nên khớp theo từ khoá, không so nguyên chuỗi.
export function stepsForIngredient(name = '') {
  const folded = name.toLowerCase();
  if (folded.includes('cốm')) return INGREDIENT_STEPS.com;
  if (folded.includes('lạc')) return INGREDIENT_STEPS.lac;
  if (folded.includes('chuối')) return INGREDIENT_STEPS.chuoi;
  if (folded.includes('khoai')) return INGREDIENT_STEPS.khoai;
  return null;
}
