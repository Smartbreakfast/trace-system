# Flutter tự giữ phần engine của nó. Thêm luật cho thư viện quét mã: ML Kit
# nạp lớp qua reflection nên không được đổi tên.
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_barcode.** { *; }
