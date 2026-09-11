# Bản ghi trace.smartbreakfast.store

Gửi người quản lý tên miền `smartbreakfast.store`.

Hệ thống truy xuất nguồn gốc đã chạy sẵn và đã nhận tên miền này ở phía
Cloudflare bên kia. Việc còn lại nằm trong zone `smartbreakfast.store`: thêm
đúng một bản ghi CNAME. Không đụng tới landing hay `www`.

## Bản ghi cần tạo

| Trường | Giá trị |
| --- | --- |
| Type | `CNAME` |
| Name | `trace` (Cloudflare tự hiểu thành `trace.smartbreakfast.store`) |
| Target | `tule-trace.pages.dev` |
| Proxy status | **DNS only**, mây xám |
| TTL | Auto |

## Proxy phải tắt

Đây là chỗ duy nhất làm hỏng cả việc. Cloudflare chặn CNAME có proxy trỏ sang
tài khoản khác, mà tên miền đích nằm ở tài khoản khác thật.

- **Mây xám, DNS only** — đúng. Cloudflare chỉ trả bản ghi, không đứng giữa.
- **Mây vàng, Proxied** — sai. Trang sẽ trả `Error 1014 CNAME Cross-User Banned`.

## Đường đi trên dashboard

1. Mở Cloudflare, chọn tên miền `smartbreakfast.store`.
2. Vào **DNS**, mục **Records**, bấm **Add record**.
3. Điền theo bảng trên, bấm vào biểu tượng mây để nó chuyển thành xám.
4. Bấm **Save**.

Chứng chỉ SSL do Cloudflare tự cấp sau khi bản ghi sống, thường trong vài phút,
chậm nhất khoảng 15 phút. Không cần thao tác gì thêm.

## Kiểm tra

```bash
# phải trả về 200
curl -sS -o /dev/null -w "%{http_code}\n" https://trace.smartbreakfast.store/

# phải trả về JSON có "ok":true
curl -s https://trace.smartbreakfast.store/api/health
```

| Hiện tượng | Nghĩa là |
| --- | --- |
| `Error 1014` | Bản ghi vẫn đang bật proxy. Chuyển về DNS only |
| SSL handshake failure | Chứng chỉ chưa cấp xong, chờ thêm |
| Không phân giải được | Bản ghi chưa lan truyền, thường dưới 5 phút |

## Bản ghi này cho và không cho gì

| Hạng mục | Ai giữ |
| --- | --- |
| Nội dung tại `trace.smartbreakfast.store` | Bên triển khai, chạy trên tài khoản Cloudflare riêng |
| Phần còn lại của tên miền | Bên triển khai không có bất kỳ quyền nào |
| Muốn ngắt | Xoá bản ghi CNAME này, subdomain tắt ngay |

Lý do vì sao chỉ có cách này: mục 5 của `DEPLOY.md`.
