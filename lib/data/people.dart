import 'geo_lookup.dart' show foldVietnamese;

/// Nhóm học sinh thực hiện đề tài, cũng là người ghi nhận các công đoạn.
///
/// Ảnh chân dung đã cắt tròn và thu về 96px, xem tools/make_people_icons.py.
const teamMembers = <({String name, String role, String asset})>[
  (
    name: 'Trịnh Gia Nhi',
    role: '12 Chuyên Sinh',
    asset: 'assets/people/trinh-gia-nhi.png',
  ),
  (
    name: 'Phạm Hà Giang',
    role: '11D2 NH',
    asset: 'assets/people/pham-ha-giang.png',
  ),
  (
    name: 'Phạm Vũ Dũng',
    role: '10 Chuyên Anh1',
    asset: 'assets/people/pham-vu-dung.png',
  ),
  (
    name: 'Vũ Sơn Hải',
    role: '10 Chuyên Tin',
    asset: 'assets/people/vu-son-hai.png',
  ),
  (
    name: 'Nguyễn Tuấn Vũ',
    role: '10T1 NH',
    asset: 'assets/people/nguyen-tuan-vu.png',
  ),
];

/// Tìm người theo tên đã ghi trong hồ sơ.
///
/// So khớp sau khi bỏ dấu: dữ liệu nhập tay có thể thiếu dấu hoặc thừa khoảng
/// trắng, mà một cái tên gõ sai dấu vẫn là cùng một người.
({String name, String role, String asset})? personFor(String name) {
  final folded = foldVietnamese(name);
  if (folded.isEmpty) return null;
  for (final member in teamMembers) {
    if (foldVietnamese(member.name) == folded) return member;
  }
  return null;
}
