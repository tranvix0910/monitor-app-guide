# Hướng dẫn giám sát (Monitor) dự án ShoeHub với Prometheus

Để hệ thống giám sát Prometheus có thể tự động thu thập số liệu (metrics) từ dự án ShoeHub, chúng ta sẽ sử dụng một tài nguyên (Custom Resource) của Prometheus Operator gọi là `ServiceMonitor`.

## 1. Chuẩn bị file cấu hình ServiceMonitor

`ServiceMonitor` sẽ dựa vào các nhãn (labels) để tự động phát hiện Service của ShoeHub và lấy dữ liệu. Trong file cấu hình của ShoeHub, Service đã được đánh nhãn `app: shoehub` và khai báo port tên là `metrics`.

Tạo một file mới tên là `k8s-shoehub-monitor.yaml` trong thư mục `ShoeHubV2` với nội dung sau:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: shoehub-monitor
  namespace: shoehub
  labels:
    # Label này giúp Prometheus Operator nhận diện được ServiceMonitor này.
    # Thông thường, nếu bạn dùng kube-prometheus-stack, tên release mặc định sẽ là "prometheus".
    release: prometheus 
spec:
  # Selector dùng để dò tìm đúng Service của dự án
  selector:
    matchLabels:
      app: shoehub 
  endpoints:
  - port: metrics    # Phải trùng với tên port (name) đã khai báo trong Service
    path: /metrics   # Đường dẫn API trả về metrics của ứng dụng
    interval: 15s    # Tần suất lấy dữ liệu (scrape interval)
```

## 2. Áp dụng cấu hình vào cụm

Sử dụng `kubectl` để áp dụng cấu hình ServiceMonitor vừa tạo vào Kubernetes:

```bash
kubectl apply -f ShoeHubV2/k8s-shoehub-monitor.yaml
```

## 3. Kiểm tra kết quả trên Prometheus

Sau khi apply, Prometheus Operator sẽ tự động nạp cấu hình mới. Bạn cần chờ khoảng 1-2 phút và thực hiện kiểm tra:

1. Truy cập vào giao diện web của **Prometheus**.
2. Trên thanh menu trên cùng, chọn **Status** > **Targets**.
3. Kéo xuống tìm mục có tên dạng `serviceMonitor/shoehub/shoehub-monitor/0`.
4. Kiểm tra cột State, nếu hiển thị trạng thái màu xanh là **UP**, nghĩa là Prometheus đã kết nối thành công vào ShoeHub và đang kéo (scrape) metrics về hệ thống.

## 4. Trực quan hoá dữ liệu với Grafana

Sau khi hoàn tất việc thu thập dữ liệu bằng Prometheus, bước tiếp theo bạn cần làm là:
1. Đăng nhập vào giao diện **Grafana**.
2. Tạo một **Dashboard** mới.
3. Thêm các Panel (biểu đồ) và sử dụng ngôn ngữ truy vấn **PromQL** để lọc và hiển thị các số liệu từ ShoeHub (ví dụ: truy vấn các biến có tiền tố `shoehub_...`).
