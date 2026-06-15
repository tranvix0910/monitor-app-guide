# Hướng dẫn Add Hosts trên macOS

File `/etc/hosts` được sử dụng trên máy tính để ánh xạ thủ công các tên miền (domain) tĩnh thành các địa chỉ IP cụ thể, trước khi máy tính thực hiện việc truy vấn phân giải tên miền lên các máy chủ DNS thông thường.

Điều này rất hữu ích khi bạn làm Lab, kiểm thử các dịch vụ, hoặc muốn trỏ một tên miền ảo (ví dụ: `rancher.local.test`) tới một địa chỉ IP (ví dụ IP của máy ảo, của load balancer hoặc Kubernetes ingress).

## 1. Mở Terminal
Mở ứng dụng Terminal trên máy Mac của bạn bằng cách dùng Spotlight Search (`Cmd + Space`), gõ `Terminal` và nhấn Enter.

## 2. Mở file /etc/hosts để chỉnh sửa
File `/etc/hosts` yêu cầu quyền quản trị (root) để có thể thay đổi. Sử dụng trình soạn thảo `nano` với lệnh `sudo` như sau:

```bash
sudo nano /etc/hosts
```
*Lưu ý: Hệ thống sẽ yêu cầu bạn nhập mật khẩu đăng nhập của máy tính Mac. Trong lúc gõ mật khẩu, màn hình sẽ không hiển thị ký tự nào (do bảo mật), bạn cứ gõ xong và nhấn Enter.*

## 3. Thêm bản ghi mới
Bên trong màn hình nano, bạn sẽ thấy một số cấu hình mặc định (như `127.0.0.1 localhost`).
Di chuyển con trỏ chuột xuống cuối file bằng phím mũi tên.

Thêm bản ghi theo cú pháp `[Địa chỉ IP] [Tên miền]`, cách nhau bởi phím Space hoặc Tab.
Ví dụ, bạn muốn trỏ domain ảo cho Rancher tới địa chỉ IP của một Load Balancer (ví dụ 192.168.1.100):

```text
192.168.1.100    rancher.local.test
192.168.1.100    grafana.local.test
```

## 4. Lưu và Thoát
Khi đã nhập xong:
1. Bấm tổ hợp phím `Ctrl + O` (chữ O không phải số 0) để yêu cầu Lưu file.
2. Nhấn `Enter` để xác nhận việc ghi đè vào file `/etc/hosts`.
3. Bấm tổ hợp phím `Ctrl + X` để thoát khỏi trình soạn thảo nano.

## 5. Xóa bộ nhớ cache DNS (Flush DNS Cache)
Để hệ điều hành macOS nhận diện ngay lập tức các cấu hình vừa được cập nhật mà không phải chờ đợi, bạn cần chạy lệnh flush DNS cache:

```bash
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
```

## 6. Kiểm tra lại (Verify)
Thử ping tới tên miền mà bạn vừa thêm để xem nó có trả về đúng IP đã thiết lập hay không:

```bash
ping rancher.local.test
```

Nếu kết quả trả về đúng địa chỉ IP (ví dụ 192.168.1.100), nghĩa là bạn đã Add hosts thành công!
Bây giờ bạn có thể mở trình duyệt và truy cập tên miền bình thường.
