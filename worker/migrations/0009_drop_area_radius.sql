-- Bỏ cột bán kính vùng trồng.
--
-- Giá trị trong cột này là ước lượng demo lúc seed, không đo đạc từ thực địa.
-- Một con số không ai kiểm chứng được nằm cạnh những dữ liệu đã neo lên chuỗi
-- thì sớm muộn cũng có người đọc nó như số thật. Vùng nguyên liệu giờ thể hiện
-- bằng ảnh bản đồ hành chính của xã, thứ tra lại được.
ALTER TABLE ingredient_batches DROP COLUMN area_radius_km;
