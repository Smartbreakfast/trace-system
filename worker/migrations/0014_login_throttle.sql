-- Hãm số lần thử mật khẩu.
--
-- Màn đăng nhập quản trị mở ra internet, mà PBKDF2 dù chậm cũng chỉ làm việc
-- dò mật khẩu đắt hơn chứ không chặn được. Hai cột dưới đây cho phép khoá tạm
-- một tài khoản sau vài lần nhập sai liên tiếp, rồi tự mở lại.
--
-- Chỉ đếm theo tài khoản, không đếm theo địa chỉ IP: đây là hệ thống của hai
-- cơ sở, vài người dùng, không phải chỗ cần chống tấn công phân tán.

ALTER TABLE users ADD COLUMN failed_attempts INTEGER NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN locked_until TEXT;
