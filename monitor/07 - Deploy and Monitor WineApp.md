# Hướng Dẫn Toàn Tập: Triển Khai và Giám Sát Dự Án WineApp trên Kubernetes

Tài liệu này tổng hợp toàn bộ quy trình từ lúc đưa mã nguồn WineApp lên cụm Kubernetes (K8s) cho đến khi thiết lập hệ thống giám sát (Observability) hoàn chỉnh với Prometheus và Grafana.

---

## Phần 1: Kiến Trúc Triển Khai (Deployment Architecture)

Dự án WineApp được thiết kế theo kiến trúc Microservices cơ bản, bao gồm 3 thành phần chính nằm trong Namespace `wineapp`:

1.  **Frontend (Nginx):** Phục vụ giao diện người dùng tĩnh. Chạy trên cổng 80 và xuất metric ở cổng 9113.
2.  **Backend (Node.js API):** Xử lý logic và API. Chạy trên cổng 4000 và xuất metric tại `/metrics`.
3.  **Database (MongoDB):** Nơi lưu trữ dữ liệu rượu vang. Chạy trên cổng 27017.

**💡 Điểm nhấn Giám Sát (Observability):**
Để Prometheus có thể thu thập được thông số của MongoDB, chúng ta sử dụng kiến trúc **Sidecar Pattern**. Cụ thể, một container phụ tên là `mongo-exporter` được nhốt chung vào cùng một Pod với `mongo`. Nhờ đó, nó có thể đọc dữ liệu trực tiếp từ `localhost:27017` một cách an toàn nhất.

---

## Phần 2: Triển Khai Ứng Dụng lên Kubernetes

Toàn bộ cấu hình của ứng dụng nằm trong file `../wineapp-manifest/wineapp-k8s.yaml`.

### 1. Lưu ý quan trọng về Mongo Exporter
Trong quá trình triển khai, việc chọn đúng phiên bản Exporter là cực kỳ quan trọng để tránh lỗi `CrashLoopBackOff` hoặc `exec format error` (lỗi kiến trúc chip ARM/AMD).

Cấu hình chuẩn nhất cho Exporter của Mongo 4.2 là:
```yaml
      - name: mongo-exporter
        image: percona/mongodb_exporter:0.39.0
        args:
        - --mongodb.uri=mongodb://127.0.0.1:27017
        - --collect-all
        - --compatible-mode
        ports:
        - containerPort: 9216
```
*   `percona/mongodb_exporter:0.39.0`: Hỗ trợ đa nền tảng (cả máy Mac M1/M2/M3 và Server x86).
*   `--collect-all`: Ép Exporter lấy toàn bộ thông số rác rưởi nhất của DB.
*   `--compatible-mode`: **Đặc biệt quan trọng**. Cờ này ép Exporter phải đặt tên biến theo chuẩn cũ (ví dụ: `mongodb_connections`), giúp ta dễ dàng vẽ biểu đồ trên Grafana mà không phải học lại toàn bộ tên metric mới.

### 2. Thực thi triển khai
Sử dụng lệnh sau để đẩy toàn bộ ứng dụng lên K8s:
```bash
kubectl apply -f "../wineapp-manifest/wineapp-k8s.yaml"
```
Kiểm tra lại xem các Pod đã ở trạng thái `Running` (đặc biệt là Pod Mongo phải hiện `Ready 2/2`):
```bash
kubectl get pods -n wineapp
```

---

## Phần 3: Kết Nối Ứng Dụng Với Prometheus (ServiceMonitor)

Bởi vì chúng ta đang dùng **Prometheus Operator** (bản cài đặt xịn xò qua kube-prometheus-stack), Prometheus sẽ rất "chảnh" và KHÔNG tự động đi cào (scrape) số liệu dù bạn có thêm chú thích `prometheus.io/scrape: "true"` vào Pod.

Thay vào đó, bạn phải tạo cho nó một "Tấm vé mời" gọi là **ServiceMonitor**.

### 1. Cấu hình ServiceMonitor
Tạo và áp dụng file `wineapp-servicemonitor.yaml` với nội dung khai báo 3 "phễu hút" dữ liệu cho Mongo, Backend và Frontend.

**Cảnh báo (Label Mismatch):**
Prometheus Operator mặc định chỉ đọc những thẻ ServiceMonitor có dán nhãn trùng với cấu hình của nó. Hãy đảm bảo thẻ `release` khớp chính xác (thường là `release: prometheus`):
```yaml
metadata:
  labels:
    release: prometheus # NHÃN NÀY LÀ BẮT BUỘC ĐỂ PROMETHEUS CHỊU ĐỌC
```

### 2. Thực thi kết nối
```bash
kubectl apply -f "../wineapp-manifest/wineapp-servicemonitor.yaml"
```

### 3. Nghiệm thu trên Prometheus
1. Mở giao diện web của Prometheus.
2. Vào menu **Status ➔ Targets**.
3. Bạn phải nhìn thấy 3 cụm Pool mới tên là `wineapp/wineapp-mongo-monitor/0`, `wineapp/wineapp-backend-monitor/0`, và `wineapp/wineapp-frontend-monitor/0` ở trạng thái màu xanh **UP**.
4. Qua tab Graph, gõ chữ `mongodb_` và xem danh sách xổ ra. Nếu thấy chữ `mongodb_connections`, chúc mừng bạn đã thành công!

---

## Phần 4: Vẽ Biểu Đồ Giám Sát Trên Grafana

Sau khi dữ liệu đã đổ về Prometheus, bước cuối cùng là biến những con số khô khan đó thành các biểu đồ trực quan để tiện theo dõi sức khoẻ hệ thống.

Quá trình vẽ biểu đồ này yêu cầu tuân thủ nghiêm ngặt các Tiêu chuẩn SRE của Google (Google SRE Best Practices). Để xem hướng dẫn chi tiết từng bước click chuột, tạo biến, chia trục Y kép, hãy chuyển sang đọc 2 tài liệu sau:

*   👉 **[08 - Grafana Best Practices.md](./08%20-%20Grafana%20Best%20Practices.md):** Đọc để hiểu tư duy kể chuyện, giảm tải nhận thức và các nguyên tắc thiết kế Dashboard.
*   👉 **[09 - WineApp Dashboard Guide.md](./09%20-%20WineApp%20Dashboard%20Guide.md):** Cầm tay chỉ việc cấu hình từng Panel cho WineApp (Đã đính kèm sẵn các đoạn code PromQL lấy độ trễ API, CPU, RAM).
