# Hướng dẫn cấu hình HAProxy Load Balancing cho cụm Kubernetes

Trong một cụm Kubernetes thực tế (đặc biệt là dạng on-premise hoặc làm Lab), bạn thường cần một điểm vào (Entry point) duy nhất đứng trước cụm K8s. Mục tiêu là:
1. **Cân bằng tải cho Kubernetes API Server** (để quản lý cụm, giao tiếp `kubectl`).
2. **Cân bằng tải cho Ingress Controllers** (để định tuyến traffic vào các ứng dụng chạy bên trong như HTTP/HTTPS).

Giải pháp phổ biến là dùng 1 máy ảo (VM) độc lập cài đặt **HAProxy**.

## 1. Cài đặt HAProxy trên máy chủ Load Balancer
Giả sử bạn đang dùng Ubuntu/Debian trên con server đóng vai trò HAProxy:

```bash
sudo apt update
sudo apt install haproxy -y
```

## 2. Sửa file cấu hình HAProxy
Cấu hình mặc định của HAProxy nằm tại `/etc/haproxy/haproxy.cfg`.
Sao lưu lại file cũ:
```bash
sudo cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.bak
```

Sau đó mở file để chỉnh sửa:
```bash
sudo nano /etc/haproxy/haproxy.cfg
```

## 3. Cấu hình mẫu cho HAProxy tới cụm Kubernetes
Dưới đây là một cấu hình mẫu. Ta sẽ cấu hình cân bằng tải lớp TCP (Layer 4) cho cả API server và Ingress (HTTP, HTTPS).

Kiến trúc mạng thực tế của bạn:
- **IP của các Nodes K8s**: `192.168.81.101` (master), `192.168.81.102` (worker1), `192.168.81.103` (worker2).
- **NodePort của Ingress**: `31202` (HTTP) và `30237` (HTTPS).

Dưới đây là cấu hình HAProxy dựa trên thiết lập thực tế của bạn:

```haproxy
global
    log /dev/log local0
    log /dev/log local1 notice

defaults
    log global
    mode tcp
    timeout connect 10s
    timeout client  30s
    timeout server  30s

# ========================================================
# 1. LOAD BALANCING CHO HTTP INGRESS (PORT 80 -> NodePort 31202)
# ========================================================
frontend http_front
    bind *:80
    default_backend ingress_http

backend ingress_http
    balance roundrobin
    server master  192.168.81.101:31202 check
    server worker1 192.168.81.102:31202 check
    server worker2 192.168.81.103:31202 check

# ========================================================
# 2. LOAD BALANCING CHO HTTPS INGRESS (PORT 443 -> NodePort 30237)
# ========================================================
frontend https_front
    bind *:443
    default_backend ingress_https

backend ingress_https
    balance roundrobin
    server master  192.168.81.101:30237 check
    server worker1 192.168.81.102:30237 check
    server worker2 192.168.81.103:30237 check

# ========================================================
# 3. LOAD BALANCING CHO KUBERNETES API SERVER (Tuỳ chọn)
# Nếu bạn muốn dùng HAProxy làm load balancer cho kubectl
# ========================================================
# frontend k8s_api_frontend
#     bind *:6443
#     default_backend k8s_api_backend
# 
# backend k8s_api_backend
#     balance roundrobin
#     # Khai báo các master nodes (ở đây bạn có 1 master)
#     server master 192.168.81.101:6443 check

# ========================================================
# HAPROXY STATS DASHBOARD
# ========================================================
frontend stats
    bind *:8404
    mode http
    stats enable
    stats uri /
    stats refresh 10s
    stats auth admin:admin123

```

## 4. Khởi động lại HAProxy
Sau khi cấu hình xong, kiểm tra xem file cấu hình có lỗi cú pháp không:
```bash
sudo haproxy -c -f /etc/haproxy/haproxy.cfg
```

Nếu trả về `Configuration file is valid`, hãy restart dịch vụ:
```bash
sudo systemctl restart haproxy
sudo systemctl enable haproxy
```

## 5. Kiểm tra hoạt động
1. **HAProxy Stats Dashboard**: Mở trình duyệt truy cập `http://192.168.1.100:8404` (với user `admin` / pass `admin123`) để xem đồ thị và trạng thái các node (Up/Down).
2. **Kubernetes API**: Sửa lại `server` endpoint trong file `~/.kube/config` của bạn thành `https://192.168.1.100:6443` và chạy `kubectl get nodes` để test truy cập cụm thông qua load balancer.
3. **Ứng dụng Ingress**: Trỏ các domain ảo vào file `/etc/hosts` (như `rancher.local.test 192.168.1.100`). Khi bạn gõ vào trình duyệt, traffic sẽ đi qua HAProxy -> Ingress Controller trên Worker -> Pod ứng dụng tương ứng.
