import 'trace_models.dart';

/// Một công đoạn trong bản nháp: tên bước và mô tả đi kèm.
typedef ProcessStepDraft = ({String title, String description});

/// Bản nháp nguyên liệu đang soạn trong Management.
///
/// Bản cũ chỉ cho tick chọn bốn nguyên liệu cứng trong `mock_data`, mọi thứ
/// admin gõ vào đều bị bỏ đi và request gửi lên dùng ngày tháng hardcode.
class IngredientDraft {
  IngredientDraft({
    this.name = '',
    this.origin = '',
    this.supplier = '',
    this.harvestDate = '',
    this.receivedDate = '',
    this.summary = '',
    this.latitude,
    this.longitude,
    this.areaGeoJson,
    List<ProcessStepDraft>? steps,
  }) : steps = steps ?? <ProcessStepDraft>[];

  String name;
  String origin;
  String supplier;
  String harvestDate;
  String receivedDate;
  String summary;

  /// Toạ độ vùng trồng. Bỏ trống thì bản đồ rơi về tâm tỉnh suy từ [origin],
  /// và trang công khai nói rõ đó là vị trí tương đối.
  double? latitude;
  double? longitude;

  /// Vùng tự khoanh trên bản đồ, GeoJSON. Có thì thắng bán kính.
  String? areaGeoJson;

  /// Công đoạn kèm mô tả. Mô tả lấy sẵn từ tài liệu quy trình để người vận
  /// hành không phải gõ lại phần Mục đích / Tiến hành / Lưu ý cho từng lô.
  List<ProcessStepDraft> steps;

  bool get isValid => name.trim().isNotEmpty && origin.trim().isNotEmpty;

  IngredientDraft copy() => IngredientDraft(
    name: name,
    origin: origin,
    supplier: supplier,
    harvestDate: harvestDate,
    receivedDate: receivedDate,
    summary: summary,
    latitude: latitude,
    longitude: longitude,
    areaGeoJson: areaGeoJson,
    steps: List.of(steps),
  );

  Map<String, dynamic> toApi(Object productBatchId) => {
    'productBatchId': productBatchId,
    'name': name.trim(),
    'origin': origin.trim(),
    'supplier': supplier.trim(),
    'harvestDate': harvestDate.trim(),
    'receivedDate': receivedDate.trim(),
    'summary': summary.trim(),
    'latitude': latitude,
    'longitude': longitude,
    'areaGeoJson': areaGeoJson,
  };

  factory IngredientDraft.fromIngredient(Ingredient item) => IngredientDraft(
    name: item.name,
    origin: item.origin,
    supplier: item.supplier,
    harvestDate: item.harvestDate,
    receivedDate: item.receivedDate,
    summary: item.summary,
    latitude: item.latitude,
    longitude: item.longitude,
    areaGeoJson: item.areaGeoJson,
    steps: [
      for (final event in item.events)
        (title: event.title, description: event.description),
    ],
  );
}

/// Bốn nguyên liệu của Tú Lệ Smart Breakfast kèm toàn bộ công đoạn theo sơ đồ
/// quy trình sản xuất, mô tả lấy nguyên từ thuyết minh trong tài liệu.
///
/// Tạo lô mới bằng bộ này thì người vận hành chỉ còn việc tải ảnh lên. Bảng gốc
/// nằm ở worker/scripts/process-steps.mjs; sinh lại bằng tools/gen_starter.py
/// mỗi khi quy trình đổi, đừng sửa tay hai nơi.
List<IngredientDraft> starterIngredients() => [
  IngredientDraft(
    name: 'Cốm Tú Lệ',
    origin: 'Tú Lệ, Yên Bái',
    supplier: 'Hợp tác xã Tú Lệ',
    latitude: 21.7167,
    longitude: 104.2333,
    summary: 'Hạt nếp nương xanh, dẻo thơm và là linh hồn của công thức.',
    steps: [
      (
        title: 'Rang',
        description:
            'Mục đích: làm chín và tạo hương vị đặc trưng. Tiến hành: cho cốm vào chảo rang ở nhiệt độ 100°C, đến khi cốm nở, hơi ngả màu và có mùi thơm. Lưu ý: đảo đều tay trong suốt quá trình rang để cốm không bị cháy.',
      ),
      (
        title: 'Xay',
        description:
            'Mục đích: đưa cốm đã rang về dạng bột. Tiến hành: nghiền hai lần rồi rây qua lưới 120 mesh. Lưu ý: bột phải mịn đều, không còn hạt lớn.',
      ),
      (
        title: 'Bột cốm',
        description:
            'Thành phẩm của nhánh cốm. Định mức: 500g cốm cho ra khoảng 135g bột.',
      ),
    ],
  ),
  IngredientDraft(
    name: 'Lạc đỏ Lục Yên',
    origin: 'Lục Yên, Yên Bái',
    supplier: 'Tổ hợp tác Lục Yên',
    latitude: 22.1,
    longitude: 104.7167,
    summary: 'Hạt lạc bản địa giàu đạm thực vật, tạo vị bùi tự nhiên.',
    steps: [
      (
        title: 'Ngâm',
        description:
            'Mục đích: làm mềm hạt, giảm mùi hăng và loại bỏ tạp chất. Tiến hành: ngâm 2-3 giờ trong nước sạch. Lưu ý: loại bỏ hạt lép, hạt hư trước khi ngâm.',
      ),
      (
        title: 'Xay',
        description:
            'Mục đích: giải phóng chất dinh dưỡng trong hạt. Tiến hành: xay nghiền cùng nước theo tỷ lệ thích hợp. Lưu ý: không xay quá lâu làm tăng nhiệt của hỗn hợp.',
      ),
      (
        title: 'Lọc',
        description:
            'Mục đích: tách bã ra khỏi dịch. Tiến hành: lọc bằng vải lọc, rây hoặc máy lọc. Lưu ý: dụng cụ lọc phải sạch.',
      ),
      (
        title: 'Sữa lạc',
        description:
            'Mục đích: tạo nguyên liệu bổ sung protein và chất béo cho công thức. Tiến hành: thu phần dịch sau lọc. Lưu ý: tránh để sữa lạc bị tách lớp.',
      ),
      (
        title: 'Sấy phun',
        description:
            'Mục đích: đưa dịch về dạng bột. Tiến hành: lọc bỏ cặn bẩn, bổ sung maltodextrin rồi tiến hành sấy phun.',
      ),
      (
        title: 'Phối trộn',
        description:
            'Mục đích: mẻ bột đồng nhất trước khi nhập kho. Tiến hành: trộn đều toàn bộ bột lạc thu được của mẻ.',
      ),
      (
        title: 'Bột lạc',
        description:
            'Thành phẩm của nhánh lạc. Định mức: 1000g lạc cho ra khoảng 205g bột.',
      ),
    ],
  ),
  IngredientDraft(
    name: 'Chuối tiêu xanh',
    origin: 'Bảo Thắng, Lào Cai',
    supplier: 'Vùng trồng VietGAP Bảo Thắng',
    latitude: 22.3667,
    longitude: 104.1833,
    summary:
        'Chuối tiêu khoảng 9 tuần, dùng lúc còn xanh để giữ tinh bột kháng.',
    steps: [
      (
        title: 'Bóc vỏ',
        description:
            'Mục đích: loại bỏ phần không sử dụng. Tiến hành: chọn chuối tiêu khoảng 9 tuần, bóc sạch vỏ. Lưu ý: không dùng quả dập nát, quá xanh hoặc đã chín.',
      ),
      (
        title: 'Nghiền mịn',
        description:
            'Mục đích: giải phóng chất dinh dưỡng. Tiến hành: xay cùng nước theo tỷ lệ thích hợp. Lưu ý: không xay quá lâu làm tăng nhiệt.',
      ),
      (
        title: 'Lọc',
        description:
            'Mục đích: tách bã ra khỏi dịch. Tiến hành: lọc bằng vải lọc, rây hoặc máy lọc. Lưu ý: dụng cụ lọc phải sạch.',
      ),
      (
        title: 'Sấy phun',
        description:
            'Mục đích: đưa dịch về dạng bột. Tiến hành: lọc bỏ cặn bẩn, bổ sung maltodextrin rồi tiến hành sấy phun.',
      ),
      (
        title: 'Bột chuối',
        description:
            'Thành phẩm của nhánh chuối. Định mức: 1000g chuối cho ra khoảng 210g bột.',
      ),
    ],
  ),
  IngredientDraft(
    name: 'Khoai môn Lục Yên',
    origin: 'Lâm Thượng, Lục Yên, Yên Bái',
    supplier: 'Hộ sản xuất Lâm Thượng',
    latitude: 22.1667,
    longitude: 104.75,
    summary: 'Khoai môn bản địa cho kết cấu dẻo mịn và hương thơm đặc trưng.',
    steps: [
      (
        title: 'Làm sạch, bỏ vỏ',
        description:
            'Mục đích: loại bỏ đất cát, tạp chất, vi sinh vật bám trên bề mặt và lớp vỏ nhiều chất xơ để sản phẩm có màu đẹp. Tiến hành: chọn củ tươi, không dập nát, không sâu bệnh; rửa sạch bằng nước nhiều lần; gọt bỏ hoàn toàn lớp vỏ ngoài. Lưu ý: không ngâm khoai quá lâu vì dễ mất chất dinh dưỡng, gọt xong phải chế biến ngay để tránh thâm đen.',
      ),
      (
        title: 'Thái',
        description:
            'Mục đích: giảm kích thước nguyên liệu, giúp quá trình hấp và nghiền nhanh hơn. Tiến hành: thái khoai thành lát dày khoảng 0,5-1cm.',
      ),
      (
        title: 'Nghiền mịn',
        description:
            'Mục đích: phá vỡ cấu trúc mô tế bào và tạo hỗn hợp đồng nhất. Tiến hành: nghiền cùng nước theo tỷ lệ thích hợp. Lưu ý: hỗn hợp phải mịn, không còn cục lớn.',
      ),
      (
        title: 'Thuỷ phân',
        description:
            'Mục đích: phân giải tinh bột thành đường đơn và dextrin, giúp sản phẩm dễ tiêu hoá và có vị ngọt tự nhiên. Tiến hành: bổ sung enzyme amylase, duy trì nhiệt độ 80-90°C trong 60 phút. Lưu ý: theo dõi nhiệt độ để enzyme hoạt động tốt.',
      ),
      (
        title: 'Dịch khoai môn',
        description:
            'Mục đích: bán thành phẩm dạng dịch trước khi sấy. Tiến hành: thu toàn bộ dịch sau thuỷ phân.',
      ),
      (
        title: 'Sấy phun',
        description:
            'Mục đích: đưa dịch về dạng bột. Tiến hành: lọc bỏ cặn bẩn, bổ sung maltodextrin rồi tiến hành sấy phun.',
      ),
      (
        title: 'Bột khoai môn',
        description:
            'Thành phẩm của nhánh khoai môn. Định mức: 500g khoai cho ra khoảng 320g bột.',
      ),
    ],
  ),
];

/// Hai công đoạn diễn ra ở xưởng, có trong mọi lô: phối trộn và đóng gói.
/// Nội dung lấy từ mục 5 và 6 của thuyết minh quy trình.
List<ProcessStepDraft> facilitySteps() => [
  (
    title: 'Phối trộn',
    description:
        'Mục đích: tạo sản phẩm đồ uống có hương vị đặc trưng và giá trị dinh dưỡng cao. Tiến hành: trộn bột khoai môn, bột lạc, bột chuối và bột cốm cùng bột kem sữa và bột vani theo định mức của công thức.',
  ),
  (
    title: 'Đóng gói',
    description:
        'Mục đích: bảo quản sản phẩm. Tiến hành: đóng gói 30g mỗi gói, 20 gói một hộp, hàn kín miệng gói. Thành phẩm có màu sắc đặc trưng, mùi thơm của khoai môn, lạc và cốm, vị ngọt dịu.',
  ),
];
