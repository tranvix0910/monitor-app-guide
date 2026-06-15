# Hướng Dẫn Tích Hợp Telegram Với Alertmanager

Để Alertmanager có thể tự động gửi tin nhắn báo động (Alerts) vào ứng dụng Telegram của bạn, chúng ta cần đóng vai trò là một nhà phát triển (Developer) giao tiếp với API của Telegram để lấy 2 thông tin cốt lõi:
1.  **Bot Token:** Bạn cần tạo một con Bot để nó thay mặt hệ thống gửi tin nhắn.
2.  **Chat ID:** Mã định danh của bạn (hoặc nhóm chat của bạn) để con Bot biết cần gửi tin nhắn cho ai.

Hãy làm theo từng bước cực kỳ đơn giản dưới đây:

---

## Bước 1: Tạo Bot và Lấy `Bot Token`

1. Mở ứng dụng Telegram trên máy tính hoặc điện thoại.
2. Tìm kiếm người dùng có tên là **`@BotFather`** (Có dấu tích xanh chính chủ).
3. Gửi tin nhắn: `/newbot`
4. BotFather sẽ hỏi bạn muốn đặt tên con Bot là gì. Bạn hãy gõ tên (Ví dụ: `WineApp Alert Bot`).
5. BotFather sẽ hỏi tiếp Username (ID) của con Bot (Phải kết thúc bằng chữ `bot`). Bạn hãy gõ tên viết liền không dấu (Ví dụ: `wineapp_alert_bot`).
6. Nếu thành công, BotFather sẽ gửi lại cho bạn một chuỗi ký tự rất dài gọi là **HTTP API Token** (Ví dụ: `123456789:ABCDEFGHIJKLMNOPQRSTUVWXYZ`).
7. **Lưu Token này lại!** Đây chính là `Bot Token`.

---

## Bước 2: Bấm "Start" để làm quen với Bot

Theo luật chống Spam của Telegram, Bot không được phép chủ động nhắn tin cho người lạ. Bạn (chủ nhân) phải nhắn tin cho nó trước thì nó mới được quyền trả lời.
1. Nhấp vào đường link dẫn đến con Bot của bạn do BotFather vừa gửi (Ví dụ: `t.me/wineapp_alert_bot`).
2. Bấm nút **START** ở dưới cùng màn hình (Hoặc gõ `/start`).
3. Gửi một tin nhắn bất kỳ cho nó (Ví dụ: `Hello bot ơi`).

---

## Bước 3: Lấy `Chat ID` của bạn

Bạn cần biết ID của chính mình để hệ thống nhắm đúng mục tiêu.
1. Hãy tìm kiếm con bot tên là **`@userinfobot`** trên Telegram.
2. Bấm **START**.
3. Nó sẽ trả về cho bạn thông tin cá nhân của bạn. Dòng `Id:` (Ví dụ: `123456789`) chính là **Chat ID** của bạn.
4. **Lưu Chat ID này lại!**

*(Mẹo: Nếu bạn muốn gửi vào một Group Chat có nhiều người, hãy add con Bot của bạn và con `@RawDataBot` vào chung một group, nó sẽ in ra Chat ID của Group đó).*

---

## Bước 4: Điền thông tin vào Kubernetes

Sau khi đã có 2 bí kíp trên trong tay, bạn hãy mở file **`alertmanager-config.yaml`** trong mã nguồn lên.

1. **Ở cấu hình Secret:** Thay thế chữ `YOUR_BOT_TOKEN_HERE` bằng đoạn mã Token bạn lấy ở **Bước 1**.
2. **Ở cấu hình AlertmanagerConfig:** Tìm 2 dòng `chatId: 123456789` và thay thế con số bằng ID thật của bạn vừa lấy ở **Bước 3**.
3. Cuối cùng, chạy lệnh áp dụng vào K8s:
```bash
kubectl apply -f "../wineapp-manifest/alertmanager-config.yaml"
```

Chúc mừng bạn! Từ nay mọi sự cố cháy nổ của hệ thống sẽ nhảy thẳng vào Telegram của bạn một cách nhanh nhất!
