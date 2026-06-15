# Hướng dẫn cài đặt và cấu hình Node Exporter trên Kubernetes

## LƯU Ý QUAN TRỌNG

Nếu bạn đã cài đặt hệ thống giám sát bằng **kube-prometheus-stack** (theo hướng dẫn số 1), thì **Node Exporter đã được cài đặt sẵn** tự động dưới dạng DaemonSet (nghĩa là nó đã chạy trên tất cả các worker nodes). Bạn **không cần** phải cài đặt lại nữa!

Dựa theo việc bạn vừa thêm domain `node-exporter.tranvix.click` vào file `/etc/hosts`, tôi hiểu là bạn đang muốn truy cập (expose) service của Node Exporter ra bên ngoài. 

Vì vậy, dưới đây tôi sẽ chia làm 2 trường hợp để bạn có thể áp dụng:

---

## Trường hợp 1: Bạn đã có sẵn Node Exporter (Từ kube-prometheus-stack)

Mục tiêu bây giờ chỉ là tạo thêm một **Ingress** để định tuyến traffic từ domain `node-exporter.tranvix.click` thẳng vào service của Node Exporter đang có sẵn.

1. Kiểm tra tên service của Node Exporter (thường nằm ở port 9100):
```bash
kubectl get svc -n monitoring | grep node-exporter
```
*(Giả sử tên service là `prometheus-prometheus-node-exporter`)*

2. Tạo file `node-exporter-ingress.yaml` với nội dung:
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
                name: prometheus-prometheus-node-exporter # Đổi lại nếu tên service của bạn khác
                port:
                  number: 9100
```

3. Áp dụng cấu hình:
```bash
kubectl apply -f node-exporter-ingress.yaml
```

**Hoàn tất:** Bây giờ bạn có thể mở trình duyệt và truy cập: `http://node-exporter.tranvix.click/metrics` để xem dữ liệu (metrics) thô mà các node trả về.

---

## Trường hợp 2: Cài đặt Node Exporter hoàn toàn độc lập (Standalone)

Nếu bạn cấu hình trên một cụm K8s mới hoàn toàn chưa có Prometheus stack, bạn có thể cài Node Exporter riêng lẻ qua Helm:

**1. Thêm Helm repository:**
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

**2. Tạo namespace và cài đặt:**
```bash
helm install node-exporter prometheus-community/prometheus-node-exporter \
  --namespace monitoring \
  --create-namespace
```

**3. Expose bằng Ingress (tuỳ chọn):**
Tương tự trường hợp 1, nếu muốn trỏ domain `node-exporter.tranvix.click` vào đây, bạn tạo Ingress trỏ về backend service tên là `node-exporter-prometheus-node-exporter` ở cổng `9100`.

```bash
root@k8s-master:~# curl localhost:9100/metrics | grep node_cpu_seconds_total
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0# HELP node_cpu_seconds_total Seconds the CPUs spent in each mode.
# TYPE node_cpu_seconds_total counter
node_cpu_seconds_total{cpu="0",mode="idle"} 27630.87
node_cpu_seconds_total{cpu="0",mode="iowait"} 95.73
node_cpu_seconds_total{cpu="0",mode="irq"} 0
node_cpu_seconds_total{cpu="0",mode="nice"} 0.04
node_cpu_seconds_total{cpu="0",mode="softirq"} 143.92
node_cpu_seconds_total{cpu="0",mode="steal"} 0
node_cpu_seconds_total{cpu="0",mode="system"} 623.46
node_cpu_seconds_total{cpu="0",mode="user"} 1640.86
node_cpu_seconds_total{cpu="1",mode="idle"} 27665.71
node_cpu_seconds_total{cpu="1",mode="iowait"} 124.07
node_cpu_seconds_total{cpu="1",mode="irq"} 0
node_cpu_seconds_total{cpu="1",mode="nice"} 0.01
node_cpu_seconds_total{cpu="1",mode="softirq"} 78.58
node_cpu_seconds_total{cpu="1",mode="steal"} 0
node_cpu_seconds_total{cpu="1",mode="system"} 630.56
node_cpu_seconds_total{cpu="1",mode="user"} 1675.78
100 77855    0 77855    0     0  3506k      0 --:--:-- --:--:-- --:--:-- 3620k
root@k8s-master:~# 
```