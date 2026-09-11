// Lưu một file do app tự sinh xuống máy người dùng.
//
// Chỉ web mới có cách làm thật, nên phần cài đặt nằm ở bản `_web`; các nền
// tảng khác dùng bản stub để mã vẫn biên dịch và test vẫn chạy trên VM.
export 'file_download_stub.dart'
    if (dart.library.js_interop) 'file_download_web.dart';
