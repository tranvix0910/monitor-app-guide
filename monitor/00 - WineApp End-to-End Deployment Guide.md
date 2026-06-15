# 🍷 WineApp Observability: Hướng Dẫn Triển Khai End-to-End

Tài liệu này là **cẩm nang duy nhất bạn cần**, tổng hợp toàn bộ quy trình triển khai hệ thống giám sát chuẩn SRE cho dự án WineApp — từ bước cài đặt máy chủ vật lý cho đến khi nhận được thông báo qua Telegram khi có sự cố xảy ra.

---

## Kiến Trúc Tổng Quan

```
[User]
  |
  ▼
[HAProxy - Load Balancer :80/:443]
  |
  ▼
[Ingress Nginx Controller - NodePort]
  |
  ├──► [Namespace: wineapp]
  │       ├── Frontend (React/Nginx) :80 + metrics :9113
  │       ├── Backend (Node.js)      :4000 + /metrics
  │       └── MongoDB                :27017 + Mongo Exporter :9216
  │
  └──► [Namespace: monitoring]
          ├── Prometheus (Pull metrics từ 3 app trên)
          ├── Grafana (Vẽ Dashboard)
          └── Alertmanager (Gửi thông báo qua Telegram)
```

---

## GIAI ĐOẠN 1: Chuẩn Bị Hạ Tầng

### Bước 1.1 — Cài đặt HAProxy (Load Balancer)

> **Mục đích:** Đứng trước cụm K8s, đón nhận traffic từ người dùng và phân phối vào các Worker Node.

Cài HAProxy trên một máy chủ Ubuntu riêng biệt:

```bash
sudo apt update && sudo apt install haproxy -y
sudo cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.bak
sudo nano /etc/haproxy/haproxy.cfg
```

Dán cấu hình sau vào (thay IP của các Node K8s của bạn):

```haproxy
global
    log /dev/log local0

defaults
    log global
    mode tcp
    timeout connect 10s
    timeout client  30s
    timeout server  30s

# HTTP: Port 80 -> Ingress NodePort 31202
frontend http_front
    bind *:80
    default_backend ingress_http

backend ingress_http
    balance roundrobin
    server master  192.168.81.101:31202 check
    server worker1 192.168.81.102:31202 check
    server worker2 192.168.81.103:31202 check

# HTTPS: Port 443 -> Ingress NodePort 30237
frontend https_front
    bind *:443
    default_backend ingress_https

backend ingress_https
    balance roundrobin
    server master  192.168.81.101:30237 check
    server worker1 192.168.81.102:30237 check
    server worker2 192.168.81.103:30237 check

# HAProxy Stats Dashboard: http://IP:8404
frontend stats
    bind *:8404
    mode http
    stats enable
    stats uri /
    stats refresh 10s
    stats auth admin:admin123
```

Kiểm tra cấu hình và khởi động:

```bash
sudo haproxy -c -f /etc/haproxy/haproxy.cfg   # Phải thấy "Configuration file is valid"
sudo systemctl restart haproxy
sudo systemctl enable haproxy
```

---

### Bước 1.2 — Cấu hình file `/etc/hosts` trên máy Mac

> **Mục đích:** Trỏ các tên miền ảo về đúng IP của HAProxy để trình duyệt nhận ra.

```bash
sudo nano /etc/hosts
```

Thêm các dòng sau vào cuối file (thay `192.168.81.100` bằng IP của HAProxy):

```text
192.168.81.100    rancher.tranvix.click
192.168.81.100    grafana.tranvix.click
192.168.81.100    prometheus.tranvix.click
192.168.81.100    wineapp.tranvix.click
```

Lưu (`Ctrl+O` → Enter → `Ctrl+X`), sau đó flush DNS cache:

```bash
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
```

Kiểm tra: `ping rancher.tranvix.click` — phải trả về đúng IP của HAProxy.

---

## GIAI ĐOẠN 2: Cài Đặt Nền Tảng Kubernetes

### Bước 2.1 — Cài đặt Ingress Nginx (NodePort)

> **Mục đích:** Ingress Controller là "người gác cổng" bên trong K8s, nhận traffic từ HAProxy và phân phối vào đúng Service.

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Tải về để tuỳ chỉnh
helm pull ingress-nginx/ingress-nginx
tar -xzvf ingress-nginx-*.tgz
vi ingress-nginx/values.yaml
```

Sửa trong `values.yaml`:
- `type: LoadBalancer` → `type: NodePort`
- `nodePort http: ""` → `http: "30080"`
- `nodePort https: ""` → `https: "30443"`

```bash
kubectl create ns ingress-nginx
helm -n ingress-nginx install ingress-nginx -f ingress-nginx/values.yaml ingress-nginx
```

---

### Bước 2.2 — Cài đặt Cert-Manager

> **Mục đích:** Tự động quản lý chứng chỉ SSL/TLS (bắt buộc cho Rancher).

```bash
helm repo add jetstack https://charts.jetstack.io && helm repo update

helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true \
  --set startupapicheck.enabled=false \
  --set webhook.hostNetwork=true \
  --set webhook.securePort=10260
```

---

### Bước 2.3 — Cài đặt Rancher

> **Mục đích:** Giao diện quản lý cụm K8s trực quan, giúp theo dõi Pod, Deployment, Log... mà không cần gõ `kubectl`.

```bash
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
helm repo update
kubectl create namespace cattle-system

helm install rancher rancher-stable/rancher \
  --namespace cattle-system \
  --set hostname=rancher.tranvix.click \
  --set bootstrapPassword=admin \
  --set ingress.tls.source=rancher \
  --set ingress.ingressClassName=nginx \
  --set global.cattle.psp.enabled=false
```

Kiểm tra Rancher đã lên chưa:

```bash
kubectl get pods -n cattle-system
```

Truy cập `https://rancher.tranvix.click` từ trình duyệt.

> **⚠️ Xử lý lỗi thường gặp:**
> - **cert-manager webhook lỗi:** `kubectl delete validatingwebhookconfiguration cert-manager-webhook && kubectl rollout restart deployment cert-manager-webhook -n cert-manager`
> - **fleet-controller CrashLoop:** `kubectl delete pods -n cattle-fleet-system --all` rồi chờ thêm 3-5 phút.

---

## GIAI ĐOẠN 3: Cài Đặt Stack Giám Sát (Observability)

### Bước 3.1 — Cài đặt kube-prometheus-stack

> **Mục đích:** Một lệnh duy nhất cài luôn bộ tứ hoàn hảo: **Prometheus + Grafana + Alertmanager + Node Exporter**.

```bash
# Cài Helm nếu chưa có
sudo apt-get install curl gpg apt-transport-https --yes
# (Xem hướng dẫn chi tiết trong file "1 - Install Prometheus.md")

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

kubectl create namespace monitoring

helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring
```

Chờ tất cả Pod chạy ổn định:

```bash
kubectl get pods -n monitoring
# Chờ đến khi tất cả đều hiện STATUS: Running
```

---

### Bước 3.2 — Expose Giao Diện Web Qua Ingress

Tạo file `observability-ingress.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: observability-ingress
  namespace: monitoring
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
    - host: prometheus.tranvix.click
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: prometheus-kube-prometheus-prometheus
                port:
                  number: 9090
    - host: grafana.tranvix.click
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: prometheus-grafana
                port:
                  number: 80
```

```bash
kubectl apply -f observability-ingress.yaml
```

Lấy mật khẩu Grafana:

```bash
kubectl get secret --namespace monitoring prometheus-grafana \
  -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
```

Truy cập `http://grafana.tranvix.click` — user: `admin`, pass: lấy từ lệnh trên.

---

### Bước 3.3 — Sửa lỗi Control Plane bị đỏ trên Prometheus

> **Triệu chứng:** Các target `kube-controller-manager`, `kube-scheduler`, `etcd` bị DOWN (đỏ).

Chạy các lệnh sau trên **Node Master**:

```bash
# Sửa Kube Controller Manager và Kube Scheduler
sudo sed -i 's/--bind-address=127.0.0.1/--bind-address=0.0.0.0/g' \
  /etc/kubernetes/manifests/kube-controller-manager.yaml
sudo sed -i 's/--bind-address=127.0.0.1/--bind-address=0.0.0.0/g' \
  /etc/kubernetes/manifests/kube-scheduler.yaml

# Sửa Etcd
sudo sed -i 's/--listen-metrics-urls=http:\/\/127.0.0.1:2381/--listen-metrics-urls=http:\/\/0.0.0.0:2381/g' \
  /etc/kubernetes/manifests/etcd.yaml

# Sửa Kube Proxy
kubectl get configmap kube-proxy -n kube-system -o yaml | \
  sed -e 's/metricsBindAddress: ""/metricsBindAddress: 0.0.0.0:10249/' \
      -e 's/metricsBindAddress: 127.0.0.1:10249/metricsBindAddress: 0.0.0.0:10249/' | \
  kubectl apply -f -
kubectl rollout restart daemonset kube-proxy -n kube-system
```

---

### Bước 3.4 — (Tuỳ chọn) Expose Node Exporter

> **Mục đích:** Truy cập thẳng vào dữ liệu raw metrics từ máy chủ vật lý.

```bash
# Kiểm tra tên service đã có sẵn
kubectl get svc -n monitoring | grep node-exporter
```

Tạo `node-exporter-ingress.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: node-exporter-ingress
  namespace: monitoring
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
    - host: node-exporter.tranvix.click
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: prometheus-prometheus-node-exporter
                port:
                  number: 9100
```

```bash
kubectl apply -f node-exporter-ingress.yaml
```

---

## GIAI ĐOẠN 4: Triển Khai Ứng Dụng WineApp

### Bước 4.1 — Deploy Ứng Dụng

> **Mục đích:** Đưa Frontend, Backend, và MongoDB lên K8s.

```bash
kubectl apply -f "WineApp-Deploy-K8s/wineapp-k8s.yaml"
```

Kiểm tra:

```bash
kubectl get pods -n wineapp
# Đặc biệt chú ý: Pod mongo phải hiện "Ready 2/2" (bao gồm cả Sidecar Exporter)
```

> **💡 Lưu ý về Mongo Exporter (Sidecar Pattern):**
> MongoDB không có endpoint `/metrics` sẵn. Chúng ta dùng mô hình **Sidecar Pattern**: nhốt thêm container `mongo-exporter` vào cùng Pod với MongoDB.
> Container exporter đọc dữ liệu từ `localhost:27017` (cùng network namespace) và phát ra metrics ở cổng `9216`.
>
> ```yaml
> - name: mongo-exporter
>   image: percona/mongodb_exporter:0.39.0
>   args:
>   - --mongodb.uri=mongodb://127.0.0.1:27017
>   - --collect-all
>   - --compatible-mode   # Quan trọng: Giữ tên biến chuẩn cũ như mongodb_connections
>   ports:
>   - containerPort: 9216
> ```

---

### Bước 4.2 — Kết Nối WineApp Với Prometheus (ServiceMonitor)

> **Mục đích:** Tạo "Tấm vé mời" cho Prometheus biết phải đến đâu cào dữ liệu.

> **⚠️ Cảnh báo quan trọng nhất:** Label `release: prometheus` trong metadata là BẮT BUỘC. Nếu thiếu, Prometheus sẽ phớt lờ hoàn toàn file này.

```bash
kubectl apply -f "WineApp-Deploy-K8s/wineapp-servicemonitor.yaml"
```

Nghiệm thu trên Prometheus UI → **Status → Targets**:

Bạn phải thấy 3 Target sau ở trạng thái xanh **UP**:
- `wineapp/wineapp-mongo-monitor/0`
- `wineapp/wineapp-backend-monitor/0`
- `wineapp/wineapp-frontend-monitor/0`

Xác nhận MongoDB đang hoạt động:

```bash
# Thử truy vấn trực tiếp trên Prometheus → Graph tab
mongodb_connections
# Nếu có dữ liệu trả về là thành công!
```

---

## GIAI ĐOẠN 5: Xây Dựng Dashboard Grafana

### Bước 5.1 — Tạo Biến (Variables) — Tuyệt Đối Không Bỏ Qua

> **Triết lý:** Không bao giờ tạo nhiều Dashboard cho nhiều môi trường. Dùng Variables để tái sử dụng 1 Dashboard cho mọi Namespace.

1. Vào **Dashboard Settings (⚙️) → Variables → Add variable**.
2. **Biến `namespace`:** Type = `Query`, Query type = `Classic query`, Query = `label_values(namespace)`.
3. **Biến `pod`:** Type = `Query`, Query type = `Classic query`, Query = `label_values(up{namespace="$namespace"}, pod)`. Bật **Multi-value** và **Include All**.

---

### Bước 5.2 — Xây Dựng Dashboard Theo Phương Pháp SRE

Dashboard được chia 3 **Rows** theo luồng dữ liệu:

#### 🔵 ROW 1: FRONTEND (Phương pháp RED)

| Panel | Visualization | PromQL |
|-------|---------------|--------|
| Active Connections | `Stat` | `sum(nginx_connections_active{namespace="$namespace"})` |
| 5xx Errors | `Time series` (màu đỏ) | `sum(rate(nginx_http_requests_total{namespace="$namespace", status=~"5.."}[5m]))` |
| Traffic (Trục Y kép) | `Time series` | Query A: `rate(nginx_http_requests_total...)` / Query B: `rate(container_network_receive_bytes...)` |

**Cách tách Trục Y:** Vào **Overrides → Add field override → Fields with name** → gõ `Bandwidth` → **Axis → Placement: Right** → **Unit: bytes/sec**.

#### 🟡 ROW 2: BACKEND (4 Tín Hiệu Vàng của Google SRE)

| Panel | Visualization | PromQL |
|-------|---------------|--------|
| Latency p95 | `Time series` | `histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{namespace="$namespace"}[5m])) by (le, route))` |
| CPU & RAM | `Time series` (Trục Y kép) | CPU: `sum(rate(container_cpu_usage_seconds_total{pod=~".*backend.*"}[5m])) by (pod)` |
| Error Rate % | `Stat` | `sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m])) * 100` |

**Chuẩn hoá Trục Y cho CPU/RAM:**
- Trục Trái (CPU): Unit = `Percent (0.0-1.0)`, Max = `1`.
- Trục Phải (RAM): Overrides → Unit = `Data > bytes (IEC)`.

#### 🟢 ROW 3: DATABASE — MongoDB (Phương pháp USE)

| Panel | Visualization | PromQL |
|-------|---------------|--------|
| Active Connections | `Time series` | `mongodb_connections{namespace="$namespace", state="current"}` |

> **Mẹo "No data":** Điền số `0` vào **Standard options → No value** để biểu đồ lỗi hiển thị `0` thay vì trống rỗng.

---

## GIAI ĐOẠN 6: Cài Đặt Hệ Thống Cảnh Báo (Alerting)

### Bước 6.1 — Deploy Alert Rules (PrometheusRule)

**File 1: SLO Burn Rate Alerts** — Kỹ thuật đỉnh cao của Google SRE

```bash
kubectl apply -f "WineApp-Deploy-K8s/wineapp-alerts.yaml"
```

Hai loại cảnh báo Burn Rate:
- **Fast Burn (`severity: page`):** Tiêu thụ 2% Error Budget trong 1 giờ. Burn Rate > 14.4 trong **cả 1h VÀ 5 phút gần nhất** → Cảnh báo đỏ khẩn cấp.
- **Slow Burn (`severity: warning`):** Tiêu thụ 5% Error Budget trong 6 giờ. Burn Rate > 6 trong **cả 6h VÀ 30 phút gần nhất** → Cảnh báo vàng.

**File 2: Infrastructure Alerts** — Cảnh báo hạ tầng cơ bản

```bash
kubectl apply -f "WineApp-Deploy-K8s/wineapp-infra-alerts.yaml"
```

| Alert | Điều kiện | Severity |
|-------|-----------|----------|
| `BackendPodDown` | `absent(up{pod=~".*backend.*", namespace="wineapp"})` trong 1 phút | critical |
| `FrontendPodDown` | `absent(up{pod=~".*frontend.*", namespace="wineapp"})` trong 1 phút | critical |
| `MongoPodDown` | `absent(up{pod=~".*mongo.*", namespace="wineapp"})` trong 1 phút | critical |
| `HighCPUUsage` | CPU > 80% trong 2 phút | warning |
| `HighMemoryUsage` | RAM > 80% limit trong 2 phút | warning |

> **⚠️ Bẫy thường gặp với `absent()`:** Hàm này tự động **xoá toàn bộ Label**, khiến AlertmanagerConfig không nhận ra cảnh báo. Bắt buộc phải nhét cứng `namespace="wineapp"` vào bên trong hàm `absent()`.

**Vòng đời của Alert:**
```
Inactive → (Điều kiện vi phạm) → Pending → (Qua mốc "for:") → Firing → (Gửi sang Alertmanager)
```

---

### Bước 6.2 — Tạo Telegram Bot

1. Tìm **@BotFather** trên Telegram → `/newbot` → Đặt tên → Lưu **Bot Token**.
2. Tìm **@userinfobot** → Lấy **Chat ID** của bạn.
3. Nhắn một tin bất kỳ cho Bot của bạn để kích hoạt (bấm nút START).

---

### Bước 6.3 — Cấu Hình Alertmanager (Gửi Thông Báo Telegram)

Cập nhật file `WineApp-Deploy-K8s/alertmanager-config.yaml` với Bot Token và Chat ID thực tế của bạn, sau đó:

```bash
kubectl apply -f "WineApp-Deploy-K8s/alertmanager-config.yaml"
```

Cơ chế điều hướng (Routing):

```
Prometheus --[Firing]--> Alertmanager
                              |
                    [groupWait: 30s] (Gom lỗi giống nhau)
                              |
              ┌───────────────┴────────────────┐
              │                                │
    severity: critical                 severity: warning
              │                                │
   [telegram-critical]               [telegram-warning]
   🚨 Tin nhắn đỏ gấp               ⚠️ Tin nhắn vàng
```

> **⚠️ Lưu ý trường `chatID`:** Phải viết hoa chữ ID (`chatID`), không phải `chatId`. Đây là quy định của Prometheus Operator `v1alpha1`.

---

### Bước 6.4 — Kiểm Tra Toàn Bộ Hệ Thống (Chaos Engineering)

Giả lập lỗi để xác nhận Alertmanager hoạt động:

```bash
# Tắt Backend để kích hoạt cảnh báo
kubectl scale deployment wineapp-backend --replicas=0 -n wineapp

# Chờ 1-2 phút rồi kiểm tra trên Prometheus UI → Alerts tab
# Cảnh báo "BackendPodDown" phải chuyển: Pending → Firing
# Telegram của bạn sẽ rung lên!

# Bật lại sau khi test xong
kubectl scale deployment wineapp-backend --replicas=1 -n wineapp
# → Alertmanager sẽ gửi thêm tin nhắn "Đã phục hồi" (Resolved)
```

---

## GIAI ĐOẠN 7: Vận Hành Hằng Ngày (Day-2 Operations)

### Silence — Tạm Tắt Cảnh Báo Khi Đang Sửa Lỗi

Khi bạn nhận được cảnh báo lúc 2h sáng và cần 2 tiếng để sửa:
1. Mở Alertmanager UI → Tìm cảnh báo đang Firing.
2. Bấm **Silence** → Đặt thời gian (2h) → Confirm.
3. Hệ thống sẽ không gửi thêm tin nhắn nào cho đến khi hết giờ Silence.

### Planned Maintenance — Bảo Trì Có Kế Hoạch

Trước khi tắt server bảo trì cuối tuần:
1. Tạo **Silence rule** trước với khung giờ bảo trì.
2. Toàn bộ cảnh báo trong khung giờ đó sẽ bị chặn.
3. Sau giờ bảo trì, xoá Silence rule để hệ thống tự động bảo vệ trở lại.

---

## Tổng Hợp Lệnh Triển Khai (Quick Reference)

```bash
# ===== INFRASTRUCTURE =====
sudo systemctl restart haproxy

# ===== MONITORING STACK =====
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring
kubectl apply -f observability-ingress.yaml

# ===== APPLICATION =====
kubectl apply -f "WineApp-Deploy-K8s/wineapp-k8s.yaml"
kubectl apply -f "WineApp-Deploy-K8s/wineapp-servicemonitor.yaml"

# ===== ALERTING =====
kubectl apply -f "WineApp-Deploy-K8s/wineapp-alerts.yaml"
kubectl apply -f "WineApp-Deploy-K8s/wineapp-infra-alerts.yaml"
kubectl apply -f "WineApp-Deploy-K8s/alertmanager-config.yaml"

# ===== VERIFY =====
kubectl get pods -n wineapp
kubectl get pods -n monitoring
kubectl get prometheusrule -n wineapp
kubectl get alertmanagerconfig -n wineapp
```
