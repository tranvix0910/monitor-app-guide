# Hướng dẫn kết nối WineApp với Prometheus (ServiceMonitor)

Để hệ thống giám sát Prometheus có thể tự động thu thập số liệu (metrics) từ dự án WineApp, chúng ta sử dụng một Custom Resource của Prometheus Operator gọi là `ServiceMonitor`.

> 💡 **Tại sao cần ServiceMonitor?** Vì chúng ta dùng **Prometheus Operator** (cài qua kube-prometheus-stack), Prometheus sẽ KHÔNG tự động scrape dù bạn có thêm annotation `prometheus.io/scrape: "true"`. Bạn phải tạo "tấm vé mời" là `ServiceMonitor` để Prometheus chịu đọc.

---

## 1. Kiến trúc WineApp và các endpoint metrics

WineApp có **3 thành phần** cần giám sát, mỗi thành phần một ServiceMonitor riêng:

| Thành phần | Namespace | Port | Path |
|------------|-----------|------|------|
| **Frontend** (Nginx) | `wineapp` | `9113` (nginx-exporter) | `/metrics` |
| **Backend** (Node.js) | `wineapp` | `4000` | `/metrics` |
| **MongoDB** (Sidecar) | `wineapp` | `9216` (mongo-exporter) | `/metrics` |

---

## 2. File cấu hình ServiceMonitor

File `../wineapp-manifest/wineapp-servicemonitor.yaml` khai báo cả 3 monitor:

```yaml
# --- ServiceMonitor cho Frontend (Nginx Exporter) ---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: wineapp-frontend-monitor
  namespace: wineapp
  labels:
    release: prometheus   # BẮT BUỘC — phải khớp với release name của kube-prometheus-stack
spec:
  selector:
    matchLabels:
      app: wineapp-frontend
  endpoints:
  - port: metrics        # Tên port trong Service (nginx-exporter :9113)
    path: /metrics
    interval: 15s
---
# --- ServiceMonitor cho Backend (Node.js /metrics) ---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: wineapp-backend-monitor
  namespace: wineapp
  labels:
    release: prometheus
spec:
  selector:
    matchLabels:
      app: wineapp-backend
  endpoints:
  - port: metrics        # Port :4000, path /metrics
    path: /metrics
    interval: 15s
---
# --- ServiceMonitor cho MongoDB (Sidecar Exporter :9216) ---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: wineapp-mongo-monitor
  namespace: wineapp
  labels:
    release: prometheus
spec:
  selector:
    matchLabels:
      app: wineapp-mongo
  endpoints:
  - port: metrics        # Port :9216 (percona/mongodb_exporter)
    path: /metrics
    interval: 15s
```

> ⚠️ **Bẫy quan trọng nhất:** Label `release: prometheus` là **BẮT BUỘC**. Prometheus Operator mặc định chỉ đọc ServiceMonitor có label trùng với release name của nó. Nếu thiếu label này, Prometheus sẽ phớt lờ hoàn toàn file cấu hình.

---

## 3. Áp dụng cấu hình vào cụm

```bash
kubectl apply -f "../wineapp-manifest/wineapp-servicemonitor.yaml"
```

---

## 4. Kiểm tra kết quả trên Prometheus UI

Sau khi apply, chờ khoảng 1-2 phút rồi kiểm tra:

1. Mở `http://prometheus.tranvix.click` → menu **Status → Targets**.
2. Bạn phải thấy **3 target xanh (UP)**:
   - `wineapp/wineapp-frontend-monitor/0`
   - `wineapp/wineapp-backend-monitor/0`
   - `wineapp/wineapp-mongo-monitor/0`

Xác nhận dữ liệu MongoDB đang chảy về:
```bash
# Trên Prometheus UI → Graph tab, gõ:
mongodb_connections
# Nếu kết quả có dữ liệu → thành công!
```

---

## 5. Xử lý sự cố thường gặp

### Target không xuất hiện (0 UP)
**Nguyên nhân:** Label `release` không khớp.

```bash
# Kiểm tra release name thực tế
kubectl get prometheus -n monitoring -o jsonpath='{.items[0].spec.serviceMonitorSelector}'
# Nếu output là {"matchLabels":{"release":"prometheus"}} → label phải là release: prometheus
```

### MongoDB target UP nhưng không có data
**Nguyên nhân:** Thiếu flag `--compatible-mode` trong mongo-exporter container.

```yaml
# Trong wineapp-k8s.yaml, đảm bảo mongo-exporter có:
args:
- --mongodb.uri=mongodb://127.0.0.1:27017
- --collect-all
- --compatible-mode   # ← BẮT BUỘC để lấy được mongodb_connections
```

### Namespace mismatch
ServiceMonitor phải cùng namespace với Application (`wineapp`), không phải namespace `monitoring`.

---

*Sau khi cả 3 target đều xanh, chuyển sang **[07 - Deploy and Monitor WineApp.md](./07%20-%20Deploy%20and%20Monitor%20WineApp.md)** để hoàn thiện phần còn lại.*
