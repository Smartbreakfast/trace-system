import '../models/trace_models.dart';
import '../ui/tule_theme.dart';

/// Bộ dữ liệu mẫu offline.
///
/// Trước đây explorer im lặng rơi về bộ này khi API lỗi, nghĩa là khách quét QR
/// có thể đọc số liệu bịa ra mà tưởng là hồ sơ thật. Với một sản phẩm bán bằng
/// niềm tin thì đó là lỗi nặng nhất, nên giờ demo chỉ bật khi có `?demo=1`
/// trên URL và luôn kèm nhãn cảnh báo.
const demoCode = 'TL-2026-001';

const demoBatch = ProductBatch(
  name: 'Tú Lệ Smart Breakfast',
  code: demoCode,
  productionDate: '12.08.2026',
  expiryDate: '12.08.2027',
  description:
      'Bột ngũ cốc dinh dưỡng từ nông sản bản địa. Hồ sơ được admin ghi nhận theo từng công đoạn.',
  status: 'PUBLISHED',
  facilityName: 'Trung tâm Phát triển và Giao dịch Công nghệ thành phố Hà Nội',
  latitude: 21.0278,
  longitude: 105.8342,
);

final demoIngredients = <Ingredient>[
  Ingredient(
    name: 'Cốm Tú Lệ',
    origin: 'Tú Lệ, Yên Bái',
    icon: ingredientIcons[0],
    color: ingredientAccents[0],
    summary: 'Hạt nếp nương xanh, dẻo thơm và là linh hồn của công thức.',
    supplier: 'Hợp tác xã Tú Lệ',
    latitude: 21.7167,
    longitude: 104.2333,
    harvestDate: '10.08.2026',
    receivedDate: '11.08.2026',
    events: const [
      ProcessEvent(
        title: 'Thu hoạch lúa nếp nương',
        description: 'Gặt tay tại ruộng bậc thang, chọn bông chín tới.',
        eventDate: '10.08.2026',
        enteredBy: 'admin',
      ),
      ProcessEvent(
        title: 'Rang cốm',
        description:
            'Rang chảo ở 100°C tới khi cốm nở, ngả màu và dậy mùi. Đảo đều tay '
            'để cốm không cháy.',
        eventDate: '11.08.2026',
        enteredBy: 'admin',
      ),
      ProcessEvent(
        title: 'Nghiền mịn thành bột cốm',
        description: 'Nghiền hai lần, rây qua lưới 120 mesh. Thu 135g bột từ 500g cốm.',
        eventDate: '12.08.2026',
        enteredBy: 'admin',
      ),
    ],
  ),
  Ingredient(
    name: 'Lạc đỏ Lục Yên',
    origin: 'Lục Yên, Yên Bái',
    icon: ingredientIcons[1],
    color: ingredientAccents[1],
    summary: 'Hạt lạc bản địa giàu đạm thực vật, tạo vị bùi tự nhiên.',
    supplier: 'Tổ hợp tác Lục Yên',
    latitude: 22.1,
    longitude: 104.7167,
    harvestDate: '08.08.2026',
    receivedDate: '10.08.2026',
    events: const [
      ProcessEvent(
        title: 'Tiếp nhận và chọn lạc',
        description: 'Cân nhận, loại hạt lép và hạt hư.',
        eventDate: '10.08.2026',
        enteredBy: 'admin',
      ),
      ProcessEvent(
        title: 'Ngâm lạc',
        description: 'Ngâm 2-3 giờ trong nước sạch cho mềm hạt và giảm mùi hăng.',
        eventDate: '11.08.2026',
        enteredBy: 'admin',
      ),
      ProcessEvent(
        title: 'Nghiền mịn và lọc lấy sữa lạc',
        description: 'Xay cùng nước rồi lọc tách bã, tránh xay lâu làm nóng hỗn hợp.',
        eventDate: '11.08.2026',
        enteredBy: 'admin',
      ),
      ProcessEvent(
        title: 'Sấy phun thành bột lạc',
        description: 'Bổ sung maltodextrin rồi sấy phun. Thu 205g bột từ 1000g lạc.',
        eventDate: '12.08.2026',
        enteredBy: 'admin',
      ),
    ],
  ),
  Ingredient(
    name: 'Chuối tiêu xanh',
    origin: 'Bảo Thắng, Lào Cai',
    icon: ingredientIcons[2],
    color: ingredientAccents[2],
    summary: 'Chuối tiêu khoảng 9 tuần, dùng lúc còn xanh để giữ tinh bột kháng.',
    supplier: 'Vùng trồng VietGAP Bảo Thắng',
    latitude: 22.3667,
    longitude: 104.1833,
    harvestDate: '09.08.2026',
    receivedDate: '10.08.2026',
    events: const [
      ProcessEvent(
        title: 'Chọn và bóc vỏ chuối',
        description: 'Chuối tiêu khoảng 9 tuần, bỏ quả dập, quả quá xanh hoặc đã chín.',
        eventDate: '09.08.2026',
        enteredBy: 'admin',
      ),
      ProcessEvent(
        title: 'Nghiền mịn và lọc',
        description: 'Xay cùng nước theo tỷ lệ, lọc tách bã bằng rây sạch.',
        eventDate: '11.08.2026',
        enteredBy: 'admin',
      ),
      ProcessEvent(
        title: 'Sấy phun thành bột chuối',
        description: 'Bổ sung maltodextrin rồi sấy phun. Thu 210g bột từ 1000g chuối.',
        eventDate: '12.08.2026',
        enteredBy: 'admin',
      ),
    ],
  ),
  Ingredient(
    name: 'Khoai môn Lục Yên',
    origin: 'Lâm Thượng, Lục Yên, Yên Bái',
    icon: ingredientIcons[3],
    color: ingredientAccents[3],
    summary: 'Khoai môn bản địa cho kết cấu dẻo mịn và hương thơm đặc trưng.',
    supplier: 'Hộ sản xuất Lâm Thượng',
    latitude: 22.1667,
    longitude: 104.75,
    harvestDate: '09.08.2026',
    receivedDate: '11.08.2026',
    events: const [
      ProcessEvent(
        title: 'Làm sạch, gọt vỏ và thái',
        description:
            'Rửa nhiều lần, gọt hết vỏ, thái lát dày 0,5-1cm rồi chế biến ngay '
            'để không thâm.',
        eventDate: '09.08.2026',
        enteredBy: 'admin',
      ),
      ProcessEvent(
        title: 'Nghiền và thuỷ phân',
        description: 'Nghiền cùng nước, bổ sung enzyme amylase, giữ 80-90°C trong 60 phút.',
        eventDate: '11.08.2026',
        enteredBy: 'admin',
      ),
      ProcessEvent(
        title: 'Sấy phun thành bột khoai môn',
        description: 'Lọc cặn, bổ sung maltodextrin rồi sấy phun. Thu 320g bột từ 500g khoai.',
        eventDate: '12.08.2026',
        enteredBy: 'admin',
      ),
    ],
  ),
];

final demoTrace = TraceRecord(
  batch: demoBatch,
  ingredients: demoIngredients,
  integrity: const IntegrityRecord(
    status: IntegrityStatus.notPublished,
    version: 0,
  ),
  isDemo: true,
);
