# 📚 Cẩm Nang Trọn Bộ: Các Khái Niệm Observability (Giám Sát Hệ Thống)

Dưới đây là bức tranh toàn cảnh và tổng hợp tất cả các khái niệm (Concepts) mà bạn đã trải qua trong suốt quá trình xây dựng hệ thống giám sát từ số 0 cho đến khi đạt chuẩn chuyên nghiệp của Google SRE.

---

## 1. Nền Tảng Giám Sát (Monitoring Foundation)
*   **Prometheus:** "Trái tim" của hệ thống. Đây là một Database dạng chuỗi thời gian (Time-series Database). Nó hoạt động theo cơ chế **Pull-model** (Chủ động đi thu thập dữ liệu). Cứ mỗi 15 giây, Prometheus sẽ đi gõ cửa các máy chủ để lấy số liệu về.
*   **Prometheus Operator:** Phiên bản "thông minh" của Prometheus chạy trên Kubernetes. Thay vì cấu hình file YAML rườm rà, Operator cho phép bạn dùng các Custom Resource (CRD) như `ServiceMonitor`, `PrometheusRule` để quản lý.
*   **Node Exporter:** Một con "Điệp viên" được cài lên các máy chủ vật lý (Linux/EC2). Nhiệm vụ của nó là đọc các chỉ số phần cứng (CPU, RAM, Ổ cứng, Mạng) và dịch ra ngôn ngữ mà Prometheus có thể hiểu được.

## 2. Kiến Trúc Mạng & Kubernetes
*   **HAProxy (High Availability Proxy):** Bộ cân bằng tải (Load Balancer). Nó đứng ở cửa ngõ, nhận Traffic từ người dùng và chia đều lực tải cho các Node trong cụm Kubernetes.
*   **Rancher:** Nền tảng quản lý cụm Kubernetes có giao diện (GUI) cực kỳ trực quan. Giúp kỹ sư DevOps dễ dàng nhìn thấy các Pod, Node, Deployment mà không cần gõ lệnh `kubectl` mỏi tay.
*   **ServiceMonitor:** Khái niệm cực kỳ quan trọng của Prometheus Operator. Đây là chiếc "Bản đồ" chỉ đường cho Prometheus biết: *"Ứng dụng của tôi đang nằm ở Label này, cổng (port) này, hãy đến đó mà thu thập số liệu!"*.

## 3. Trực Quan Hóa Dữ Liệu (Data Visualization)
*   **Grafana:** "Đôi mắt" của hệ thống. Grafana không tự lưu trữ dữ liệu, nó kết nối với Prometheus để vẽ ra các biểu đồ (Dashboard) đẹp mắt.
*   **Grafana Best Practices:** 
    *   **USE Method** (Utilization, Saturation, Errors): Dùng để đo lường *Hạ tầng* (CPU, RAM, Disk).
    *   **RED Method** (Rate, Errors, Duration): Dùng để đo lường *Ứng dụng/API* (Số lượng Request, Số lỗi 5xx, Thời gian phản hồi).
    *   Luôn sử dụng Biến (Variables) trong Grafana để Dashboard có thể tái sử dụng cho nhiều môi trường (Dev/Prod).

## 4. Ngôn Ngữ Truy Vấn PromQL
*   **Rate vs Irrate:** Hàm tính toán "Tốc độ". 
    *   `rate()`: Làm mượt biểu đồ, dùng để xem xu hướng lâu dài (VD: Tính số Request/giây).
    *   `irrate()`: Nhạy bén với thay đổi, dùng để soi các đỉnh chóp (Spike) tăng đột biến.
*   **Absent():** Hàm kiểm tra sự vắng mặt. Nếu một Pod bị chết và không trả về số liệu `up`, hàm `absent()` sẽ trả về `1` để kích hoạt báo động sập server.
*   *Lưu ý cốt tử:* Hàm `absent()` sẽ tự động **xóa bỏ toàn bộ Label**, do đó phải nhét cứng Label (như `namespace="wineapp"`) vào trong hàm để Alertmanager nhận diện được.

## 5. Triết Lý Vận Hành SRE (Site Reliability Engineering)
*   **SLI (Service Level Indicator):** Chỉ số đo lường thực tế (Ví dụ: 99.5% API trả về thành công).
*   **SLO (Service Level Objective):** Mục tiêu cam kết với sếp/khách hàng (Ví dụ: Cam kết phải đạt 99.9%).
*   **Error Budget (Ngân sách lỗi):** Số lỗi tối đa bạn được phép vi phạm trong 1 tháng (Ví dụ: 0.1%).
*   **Multi-window Burn Rate:** Tuyệt chiêu của Google. Thay vì cảnh báo tĩnh ("Lỗi > 5% thì báo"), kỹ thuật này tính toán **Tốc độ đốt ngân sách lỗi**. 
    *   **Fast Burn:** Lỗi cháy rực rỡ, đốt 2% ngân sách trong 1 giờ -> Cảnh báo Đỏ (Gọi dậy giữa đêm).
    *   **Slow Burn:** Lỗi rỉ rả, đốt 5% ngân sách trong 6 giờ -> Cảnh báo Vàng (Mai lên công ty sửa).

## 6. Hệ Thống Cảnh Báo (Alerting)
*   **PrometheusRule:** File định nghĩa các luật (Rules) cho Prometheus. Bao gồm *Recording Rules* (tính toán sẵn dữ liệu nặng để tiết kiệm CPU) và *Alerting Rules* (kích hoạt lỗi).
*   **Trạng thái Alert:**
    *   `Inactive`: Mọi thứ bình thường.
    *   `Pending`: Lỗi vừa xảy ra, nhưng đang chờ xác nhận (chưa qua mốc thời gian `for: 1m`).
    *   `Firing`: Lỗi được xác nhận, bắn sang Alertmanager.
*   **Alertmanager:** "Điều phối viên" tổng đài. Nhiệm vụ chính:
    *   **Grouping:** Gom 10 cái lỗi giống nhau lại thành 1 tin nhắn để chống Spam (Alert Fatigue).
    *   **Routing:** Phân luồng. Lỗi Critical thì gửi vào kênh A, Lỗi Warning thì gửi vào kênh B.
    *   **Silencing:** Tạm thời "bịt miệng" hệ thống báo động để kỹ sư yên tĩnh sửa Code hoặc bảo trì Server cuối tuần.
*   **AlertmanagerConfig (CRD):** Cách cấu hình luồng thông báo bằng YAML trong K8s. *Lưu ý bắt buộc:* Nó hoạt động dựa trên Namespace. Cảnh báo bị mất nhãn Namespace thì AlertmanagerConfig sẽ phớt lờ.
*   **Telegram/Slack Integration:** Sử dụng `telegramConfigs` kết nối qua BotFather (Bot Token) và ID người dùng (Chat ID) để tự động bắn thông báo lỗi thẳng vào điện thoại.

---
*Hành trình vừa qua của bạn chính là toàn bộ quy trình mà một Kỹ sư DevOps/SRE thực thụ ở các công ty lớn đang vận hành mỗi ngày!*
