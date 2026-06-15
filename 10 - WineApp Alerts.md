# Hệ Thống Cảnh Báo SRE Đỉnh Cao: Multi-window Burn Rate

Đây là kỹ thuật cảnh báo được kỹ sư Google SRE sáng tạo ra nhằm chấm dứt chuỗi ngày "báo động giả" gây mệt mỏi (Alert Fatigue) cho team vận hành. Thay vì tạo các luật cảnh báo cứng ngắc (Static thresholds) như "Nếu CPU > 90% thì báo động" hay "Lỗi > 5% thì réo tên", phương pháp này dựa hoàn toàn vào **Trải nghiệm người dùng (SLO/SLI)** và **Ngân sách lỗi (Error Budget)**.

---

## 1. Khái Niệm Cốt Lõi

*   **SLO (Service Level Objective):** Mục tiêu chất lượng dịch vụ. Ví dụ: "Dự án WineApp cam kết 99.9% API trả về thành công".
*   **Error Budget:** Ngân sách lỗi. Nếu SLO là 99.9%, chúng ta được phép có **0.1%** lỗi trong tháng đó (thường tính trong cửa sổ 30 ngày).
*   **Burn Rate:** Tốc độ đốt ngân sách. Nếu bạn xài hết ngân sách 0.1% đó trong 30 ngày (Burn rate = 1), bạn vừa khít chỉ tiêu. Nếu bạn xài nhanh hơn (ví dụ: mất 2% ngân sách chỉ trong 1 tiếng), hệ thống đang bốc cháy (Burn rate cao) và cần phải dập lửa ngay lập tức.

---

## 2. Kỹ Thuật Multi-window (Đa Khung Thời Gian)

Tại sao lại phải dùng nhiều khung thời gian?
Giả sử có một đợt lỗi tăng vọt 100% nhưng chỉ kéo dài đúng 2 giây (do giật mạng) rồi hết. Tổng số lượng lỗi là vô cùng nhỏ, không ảnh hưởng tới trải nghiệm của ai cả. Nếu bạn cài cảnh báo "Lỗi > 5% trong 5 phút" thì kỹ sư sẽ bị gọi dậy giữa đêm một cách vô nghĩa.

**Giải pháp của Google:** So sánh chéo giữa khung thời gian dài và khung thời gian ngắn.

1.  **Fast Burn (Cấp cứu - Gọi điện thoại lúc nửa đêm):** Tiêu thụ 2% tổng ngân sách tháng chỉ trong 1 giờ.
    *   Yêu cầu: Burn Rate vượt ngưỡng 14.4 lần trong **cả 1 giờ** VÀ **5 phút gần nhất**.
    *   Giải thích: Lỗi phải tồn tại đủ lâu (1 giờ) để gây ảnh hưởng đáng kể (2% ngân sách), VÀ hiện tại nó vẫn còn đang diễn ra (5 phút) thì mới gọi người dậy sửa. Nếu 5 phút gần nhất hệ thống đã tự khỏi thì để kỹ sư ngủ tiếp.
2.  **Slow Burn (Thảnh thơi - Tạo vé Jira sửa sau):** Tiêu thụ 5% tổng ngân sách tháng trong 6 giờ.
    *   Yêu cầu: Burn Rate vượt ngưỡng 6 lần trong **cả 6 giờ** VÀ **30 phút gần nhất**.
    *   Giải thích: Lỗi rất nhỏ, rỉ rả kéo dài, không làm sập hệ thống ngay. Chỉ cần đẩy thông báo vào Slack hoặc tạo Ticket để mai sửa.

---

## 3. Cách Triển Khai trên Kubernetes

Trong K8s, để tạo Alert cho Prometheus, chúng ta sẽ khai báo một tệp YAML với định dạng `PrometheusRule`. Tệp này chia làm 2 phần:

1.  **Recording Rules:** Vì tính toán hàm `sum(rate(...))` cho khoảng thời gian lớn như 1 giờ, 6 giờ tốn rất nhiều CPU của máy chủ Prometheus. Do đó, chúng ta bảo Prometheus cứ mỗi 15 giây hãy âm thầm tính sẵn các con số này và lưu lại dưới dạng một biến ảo (Ví dụ: `job:http_requests:error_rate5m`).
2.  **Alerting Rules:** Lấy các biến ảo ở trên ra so sánh chéo để tạo cảnh báo `FastBurn` và `SlowBurn`.

Để áp dụng các cấu hình này, hãy triển khai file `wineapp-alerts.yaml`!

---

## 4. Quản lý Điều hướng (Alertmanager)

Khi Prometheus phát hiện sự cố, nó sẽ gửi tín hiệu cho **Alertmanager**. Nhiệm vụ của Alertmanager là:
*   **Gom nhóm (Grouping):** Đợi 30 giây để gom các lỗi giống nhau thành 1 tin nhắn duy nhất, tránh tình trạng "dội bom" tin nhắn.
*   **Điều hướng (Routing):** Tùy vào độ nghiêm trọng (`severity`) để gửi vào đúng nơi:
    *   Lỗi `critical` (Fast Burn / Hạ tầng sập): Gửi thẳng vào kênh Slack báo động `#sre-critical` với chuông reo.
    *   Lỗi `warning` (Slow Burn / Cảnh báo tài nguyên): Gửi vào kênh theo dõi `#sre-warning`.
*   **Giải quyết (Resolved):** Tự động báo tin xanh lá cây khi lỗi đã được sửa xong.

Để thiết lập luồng điều hướng này, hãy triển khai file cấu hình `alertmanager-config.yaml`.

---

## 5. Hướng Dẫn Kích Hoạt & Vận Hành Thực Tế

### Bước 1: Kích hoạt Hệ thống Cảnh báo
Bạn cần cài đặt các quy tắc (Rule) và luồng điều hướng (Route) vào cụm Kubernetes của bạn:
```bash
# 1. Kích hoạt SLO Burn Rate Alerts
kubectl apply -f "WineApp-Deploy-K8s/wineapp-alerts.yaml"

# 2. Kích hoạt Cảnh báo Hạ tầng Cơ bản (CPU, RAM, Pod Down)
kubectl apply -f "WineApp-Deploy-K8s/wineapp-infra-alerts.yaml"

# 3. Kích hoạt Luồng điều hướng gửi tin nhắn (Alertmanager)
kubectl apply -f "WineApp-Deploy-K8s/alertmanager-config.yaml"
```

### Bước 2: Diễn tập (Chaos Engineering)
Hãy tự đóng vai hacker để kiểm tra hệ thống:
1.  **Gây lỗi:** Dùng lệnh `kubectl scale deployment wineapp-backend --replicas=0 -n wineapp` để tắt Backend.
2.  **Chờ 1 phút:** Truy cập giao diện Prometheus, bạn sẽ thấy lỗi `BackendPodDown` chuyển từ `Pending` sang `Firing`.
3.  **Kiểm tra Slack:** Bạn sẽ nhận được thông báo đỏ chót réo gọi vào điện thoại.
4.  **Sửa lỗi:** Scale lại replicas lên 1. Vài phút sau, Alertmanager sẽ nhắn báo lại "Đã phục hồi".

### Bước 3: Vận hành Hằng ngày (Day-2 Operations)
Trong thực tế, bạn sẽ dùng giao diện Web của Alertmanager để xử lý 2 việc chính:
1.  **Silence (Tạm tắt cảnh báo):** Khi bạn đã nắm được lỗi và đang trong quá trình sửa chữa, hãy nhấn Silence để hệ thống không nhắc lại mỗi 5 phút.
2.  **Bảo trì định kỳ:** Đặt hẹn giờ Silence trước khi tắt máy chủ bảo trì cuối tuần để không bị spam tin nhắn báo sập.
