# HỆ THỐNG MÁY CHỦ BẢN QUYỀN KEY & XÁC THỰC - PHUCVN STUDIO
Dành riêng cho ứng dụng iOS **3105 x PHUCVN**

---

## 1. TỔNG QUAN HỆ THỐNG
Hệ thống xác thực bản quyền hai lớp hoàn chỉnh bao gồm:
1. **Ứng dụng iOS 3105 x PHUCVN**: Tích hợp màn hình chặn bản quyền Cyberpunk (`KeyGatekeeperView`). Khi mở app, nếu chưa kích hoạt Key hoặc Key hết hạn thì người dùng bắt buộc phải nhập Key bản quyền mới vào được app.
2. **Máy chủ Server Key (`serverkey/`)**: Viết bằng PHP thuần không cần cài đặt SQL phức tạp (dùng cơ sở dữ liệu file JSON siêu nhẹ, tốc độ phản hồi tính bằng mili-giây).
3. **Trang Quản trị Admin (`admin.php`)**: Đăng nhập quản lý toàn bộ hệ thống, sinh mã Key, xem thiết bị đang dùng, đặt lại HWID khi khách đổi máy mới, theo dõi nhật ký vi phạm.

---

## 2. CÁC TÍNH NĂNG NỔI BẬT
- **5 Loại thời hạn Key bản quyền**:
  - `1h` (Dùng thử 1 giờ)
  - `1d` (Dùng thử 1 ngày - 24 giờ)
  - `7d` (Gói tuần 7 ngày)
  - `30d` (Gói tháng 30 ngày)
  - `permanent` (Gói Vĩnh Viễn)
- **Ràng buộc phần cứng HWID (Hardware Identifier)**: Mỗi Key chỉ kích hoạt được trên đúng 1 chiếc iPhone/iPad. Ngăn chặn triệt để tình trạng chia sẻ Key.
- **Tính năng Đổi máy / Reset HWID**: Trong trang Admin, chỉ cần 1 cú click nút "Đổi máy", Key sẽ được giải phóng khỏi HWID cũ để khách hàng kích hoạt sang máy mới mà không làm mất thời hạn còn lại của Key.
- **Tùy chỉnh máy chủ trên app**: Người dùng có thể nhấn biểu tượng Bánh Răng (Settings) trên màn hình nhập Key để đổi sang link Server của bạn (`https://domain-cua-ban.com/api.php`).
- **Hỗ trợ Test Master Key Offline**: Khi chưa kịp upload server lên mạng, các mã Key kiểm thử được tích hợp sẵn để bạn test trực tiếp trên máy mà không sợ bị chặn.

---

## 3. DANH SÁCH MÃ KEY TEST CÓ SẴN
| Mã Key | Loại Thời Hạn | Cấp Độ | Trạng Thái |
| :--- | :--- | :--- | :--- |
| `PHUCVN-LIFE-TEST-0001` | Vĩnh Viễn | VIP | Sẵn sàng sử dụng |
| `PHUCVN-30D-TEST-0001` | 30 Ngày | VIP | Sẵn sàng sử dụng |
| `PHUCVN-7D-TEST-0001` | 7 Ngày | VIP | Sẵn sàng sử dụng |
| `PHUCVN-1D-TEST-0001` | 1 Ngày | VIP | Sẵn sàng sử dụng |
| `PHUCVN-1H-TEST-0001` | 1 Giờ | VIP | Sẵn sàng sử dụng |

---

## 4. HƯỚNG DẪN TRIỂN KHAI LÊN HOSTING (cPanel, DirectAdmin, VPS, v.v.)
1. **Nén thư mục `serverkey/`**: Nén toàn bộ nội dung trong thư mục `serverkey` thành file `.zip`.
2. **Tải lên Hosting**:
   - Mở File Manager trong cPanel / Hosting của bạn.
   - Tải file zip lên thư mục `public_html` (hoặc thư mục con ví dụ `public_html/key/`).
   - Giải nén (Extract) file zip.
3. **Phân quyền thư mục**:
   - Đảm bảo thư mục `data/` có quyền ghi (`chmod 755` hoặc `chmod 777`).
4. **Đăng nhập Quản Trị Admin**:
   - Truy cập: `https://domain-cua-ban.com/admin.php`
   - Tài khoản mặc định: `admin`
   - Mật khẩu mặc định: `admin123`
   *(Sau khi đăng nhập, bạn có thể đổi mật khẩu và tên hệ thống trong mục Cài đặt hệ thống)*.
5. **Cổng API cho App iOS**:
   - Link API: `https://domain-cua-ban.com/api.php`
   - Trên app iOS 3105 x PHUCVN: Nhấn vào icon Cài đặt ở góc trên phải màn hình nhập Key -> Nhập link này vào và bấm **"Lưu địa chỉ Server"**.
