# Hướng Dẫn Chuyên Sâu Tạo Dashboard WineApp (Tuân thủ Best Practices)

Tài liệu này là bản hướng dẫn "cầm tay chỉ việc", áp dụng triệt để các nguyên tắc trong file `08 - Grafana Best Practices.md` để tạo ra một Dashboard hoàn hảo cho dự án WineApp. Đặc biệt, tài liệu đã được bổ sung các "mẹo thực chiến" để giải quyết các lỗi thường gặp trong quá trình cấu hình.

---

## Nguyên Tắc Số 1: "Tạo Biến (Variables) Để Tránh Rác"
Tuyệt đối không tạo nhiều Dashboard cho các môi trường khác nhau. Thay vào đó, thiết lập các biến ở đầu trang.

1. Bấm `Dashboard settings` (Bánh răng) ➔ **Variables** ➔ **Add variable**.
2. **Tạo Biến Namespace:**
   * **Name:** `namespace`
   * **Type:** `Query`
   * **Data source:** Prometheus
   * **Query type:** Chọn **Classic query** (Bắt buộc chọn cái này ở menu xổ xuống để hiện ra ô nhập code).
   * **Query:** Dán đoạn code này vào ô trống: `label_values(namespace)`
3. **Tạo Biến Pod:**
   * **Name:** `pod` 
   * **Type:** `Query` 
   * **Query type:** Chọn **Classic query**.
   * **Query:** `label_values(up{namespace="$namespace"}, pod)` 
   * Bật `Multi-value` và `Include All`.

---

## Nguyên Tắc Số 2: "Kể một câu chuyện (Storytelling)"
Dashboard sẽ được chia thành các **Rows (Hàng)** theo luồng dữ liệu (Data Flow): từ lúc khách hàng chạm vào Frontend, đi xuống Backend, và chọc vào Database Mongo.

> 💡 **Mẹo xử lý lỗi "No data" ở các biểu đồ:**
> * Đối với biểu đồ đếm LỖI (như 5xx Errors), "No data" là **TIN VUI** vì hệ thống không có lỗi nào cả. Để hiển thị đẹp hơn, hãy vào **Standard options > No value** và gõ số `0`.
> * Đối với các biểu đồ khác, hãy đảm bảo bạn đã bấm nút **Run queries** (góc trên bên phải ô code) để tải dữ liệu, hoặc thử truy cập vào web để tạo "traffic giả".

### ROW 1: FRONTEND (Nginx) - Phương pháp RED

#### Panel 1: Tổng Người Dùng Đang Truy Cập (Active Connections)
*   **Mục đích:** Trả lời nhanh câu hỏi "Web đang vắng hay đông?".
*   **Visualization:** Chọn `Stat`.
*   **Query:** `sum(nginx_connections_active{namespace="$namespace"})`
*   **Best Practices:** Dùng `Stat` để giảm tải nhận thức. Cài Threshold: Base: Xanh, 1000: Vàng, 5000: Đỏ.

#### Panel 2: Tỷ lệ Lỗi Trải Nghiệm Người Dùng (Frontend 5xx Errors)
*   **Visualization:** Chọn `Time series`.
*   **Query:** `sum(rate(nginx_http_requests_total{namespace="$namespace", status=~"5.."}[5m]))`
*   **Legend:** Gõ `5xx Errors` (Tuyệt đối KHÔNG dùng ngoặc nhọn `{{ }}`).
*   **Best Practices:** Đổi Line color thành **Đỏ Tĩnh (Fixed Red)**. Điền `0` vào mục *No value*.

#### Panel 3: Lưu Lượng Băng Thông (Frontend Traffic) - 🌟 Thực Hành Tách Trục Y kép
*   **Visualization:** Chọn `Time series`.
*   **Query A (Request):** `sum(rate(nginx_http_requests_total{namespace="$namespace"}[5m]))`
    *   **Legend:** `Requests`
*   **Query B (Băng thông):** Bấm **+ Add query**. Code: `sum(rate(container_network_receive_bytes_total{namespace="$namespace", pod=~".*frontend.*"}[5m]))`
    *   **Legend:** `Bandwidth`
*   **BẮT BUỘC:** Bấm nút **Run queries** để Grafana tải dữ liệu và ghi nhận 2 cái tên này.

**Cách thực hiện Tách Trục Y (Overrides):**
1. Vào **Standard options > Unit**, chọn `Requests/sec (rps)`. (Lúc này cả A và B đều bị ép thành rps).
2. Cuộn xuống dưới cùng tìm mục **Overrides** ➔ Bấm **+ Add field override**.
3. Chọn **Fields with name**.
    * *Mẹo:* Nếu danh sách xổ xuống chỉ có `Time` và `Value`, hãy **tự gõ chữ `Bandwidth`** vào ô tìm kiếm rồi nhấn **Enter**. Grafana vẫn sẽ nhận dạng được!
4. Bấm **+ Add override property** ➔ Tìm chọn **Axis > Placement** ➔ Đổi thành `Right` (Trục bên phải).
5. Bấm **+ Add override property** lần nữa ➔ Tìm chọn **Standard options > Unit** ➔ Gõ tìm `bytes` ➔ Chọn `Data rate > bytes/sec (SI)`.

---

### ROW 2: BACKEND (Node.js API) - 4 Tín Hiệu Vàng (Four Golden Signals)

#### Panel 4: Độ Trễ API (Latency p95)
*   **Visualization:** Chọn `Time series`.
*   **Query:** `histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{namespace="$namespace", app="wineapp-backend"}[5m])) by (le, route))`
*   **Legend:** `{{route}}` (Ở đây DÙNG ngoặc nhọn vì route là một biến động của Prometheus).
*   **Best Practices:** Kẻ đường ngang báo động (Threshold line) màu Đỏ ở mốc `2` (giây). Tắt Stacked Graph.

#### Panel 5: Tài nguyên Backend (CPU & RAM) - 🌟 Chuẩn Hoá Trục Y
*   **Query A (CPU):** `sum(rate(container_cpu_usage_seconds_total{namespace="$namespace", pod=~".*backend.*"}[5m])) by (pod)`
    *   **Legend:** `CPU Usage`
*   **Query B (RAM):** `sum(container_memory_usage_bytes{namespace="$namespace", pod=~".*backend.*"}) by (pod)`
    *   **Legend:** `RAM Usage`
*   **BẮT BUỘC:** Bấm **Run queries**.

**Cách Chuẩn Hoá và Tách Trục:**
1. Cài đặt trục Trái cho CPU: Vào **Standard options > Unit**, chọn `Percent (0.0-1.0)`. Mục **Max**, gõ số `1` (Giới hạn trần biểu đồ là 1 Core để phát hiện CPU full 100%).
2. Vào **Overrides** ➔ **Add field override** ➔ **Fields with name**. Gõ chữ `RAM Usage` rồi Enter (Mặc kệ danh sách có hay không).
3. Đổi **Axis > Placement** thành `Right`.
4. Đổi **Standard options > Unit** thành `Data > bytes (IEC)` (Bắt buộc dùng IEC vì RAM tính theo nhị phân 1024).

#### Panel 6: Tỷ lệ thất bại API (Errors)
*   **Visualization:** Chọn `Stat`.
*   **Query:** Tính tỷ lệ %. `sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m])) * 100`
*   **Best Practices:** Unit là `Percent (0-100)`. Threshold > 5% là màu Đỏ. No value = 0.

---

### ROW 3: DATABASE (MongoDB) - Phương pháp USE

#### Panel 7: Lượng Kết Nối (MongoDB Connections)
*   **Visualization:** Chọn `Time series`.
*   **Query:** `mongodb_connections{namespace="$namespace", state="current"}` 
    *(Lưu ý: Nếu dùng percona/mongodb_exporter v0.39+, hãy đảm bảo đã cấu hình cờ `--compatible-mode` trong k8s deployment để lấy được biến này).*
*   **Best Practices:** Kẻ đường Threshold ở mức max connections (ví dụ: 100) để theo dõi Saturation.

---

## Nguyên Tắc Số 3: "Viết Tài Liệu (Write it down) & Tạo Liên Kết (Links)"

1. **Thêm Documentation Panel:** Tạo Panel kiểu `Text` ở góc trên cùng bên phải, nội dung Markdown:
   ```markdown
   > **Mục đích:** Theo dõi trải nghiệm người dùng WineApp theo chuẩn RED.
   > **Hướng xử lý sự cố:**
   > 1. Nếu API Latency > 2s: Hãy kiểm tra Panel RAM của Backend xem có bị tràn bộ nhớ không.
   > 2. Nếu Frontend có mã lỗi 5xx: Click vào liên kết bên dưới để nhảy sang Dashboard kiểm tra Log.
   ```
2. **Tạo Data Links:** Vào Dashboard Settings ➔ **Links** ➔ Add Dashboard Link. Trỏ link sang Dashboard `K8s Node Infrastructure` để kiểm tra máy ảo EC2 khi cần.

---
*Hoàn thành file hướng dẫn. Hãy lưu lại Dashboard với tiền tố rõ ràng như `WineApp / 03. Service RED Metrics` để tránh Sprawl.*
