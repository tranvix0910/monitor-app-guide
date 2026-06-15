# 🔭 Observability Lab — Giám Sát Hệ Thống Chuẩn SRE

Bộ tài liệu hướng dẫn xây dựng hệ thống giám sát (Observability) từ đầu đến cuối cho dự án **WineApp** trên Kubernetes, đạt chuẩn **Google SRE**. Bao gồm: Prometheus, Grafana, Alertmanager, và tích hợp thông báo qua Telegram.

> ⚠️ **Phải hoàn thành Phase 1 trước!** Cụm Kubernetes phải đang chạy mới có thể thực hiện các bước trong repo này.
> 👉 **[LabServers Repository](https://github.com/tranvix0910/LabServers)** — Vagrant + VMware · K8s v1.30 · HAProxy · 1 Master + 2 Workers

---

## 📌 Vị Trí Trong Hệ Thống

```
┌──────────────────────────────────────────────────────────────┐
│   PHASE 1: 🏠 LabServers (tranvix0910/LabServers)              │
│   Vagrant · VMware · K8s v1.30 · Calico CNI                │
│   IPs: .100 (HAProxy) .101 (Master) .102-.103 (Workers)     │
└─────────────────────────────┬────────────────────────────────┘
                              │ vagrant up
                              ▼
┌──────────────────────────────────────────────────────────────┐
│   PHASE 2: 🔭 Observability (tranvix0910/Observability) ← Bạn đang ở đây │
│   Prometheus · Grafana · Alertmanager · WineApp · Telegram    │
└──────────────────────────────────────────────────────────────┘
```


---

## 📐 Kiến Trúc Tổng Quan

```
[User]
  ▼
[HAProxy - Load Balancer :80/:443]
  ▼
[Ingress Nginx Controller - NodePort]
  ├──► [Namespace: wineapp]
  │       ├── Frontend (React/Nginx) :80 + metrics :9113
  │       ├── Backend (Node.js)      :4000 + /metrics
  │       └── MongoDB                :27017 + Mongo Exporter :9216
  │
  └──► [Namespace: monitoring]
          ├── Prometheus  (Thu thập metrics)
          ├── Grafana     (Vẽ Dashboard)
          └── Alertmanager (Gửi thông báo qua Telegram)
```

---

## 📚 Danh Sách Tài Liệu (Theo Thứ Tự Triển Khai)

| # | File | Mô tả |
|---|------|--------|
| 00 | [WineApp End-to-End Deployment Guide](./00%20-%20WineApp%20End-to-End%20Deployment%20Guide.md) | 🗺️ **Master Guide** — Tổng quan toàn bộ quy trình |
| 01 | [Configure HAProxy for K8s](./01%20-%20Configure%20HAProxy%20for%20K8s.md) | Load Balancer đứng trước cụm K8s |
| 02 | [Add Hosts on macOS](./02%20-%20Add%20Hosts%20on%20macOS.md) | Trỏ domain ảo về đúng IP |
| 03 | [Install Rancher](./03%20-%20Install%20Rancher.md) | Cài Ingress Nginx, Cert-Manager, Rancher |
| 04 | [Install Prometheus](./04%20-%20Install%20Prometheus.md) | Cài kube-prometheus-stack (Prometheus + Grafana + Alertmanager) |
| 05 | [Install Node Exporter](./05%20-%20Install%20Node%20Exporter.md) | Expose Node Exporter ra ngoài |
| 06 | [Monitor ShoeHub](./06%20-%20Monitor%20ShoeHub.md) | Ví dụ ServiceMonitor cho dự án ShoeHub |
| 07 | [Deploy and Monitor WineApp](./07%20-%20Deploy%20and%20Monitor%20WineApp.md) | Triển khai WineApp + kết nối Prometheus |
| 08 | [Grafana Best Practices](./08%20-%20Grafana%20Best%20Practices.md) | Triết lý thiết kế Dashboard (USE, RED, Golden Signals) |
| 09 | [WineApp Dashboard Guide](./09%20-%20WineApp%20Dashboard%20Guide.md) | Hướng dẫn tạo Dashboard WineApp từng bước |
| 10 | [WineApp Alerts](./10%20-%20WineApp%20Alerts.md) | Cảnh báo SLO Burn Rate + Hạ tầng |
| 11 | [Telegram Alerts](./11%20-%20Telegram%20Alerts.md) | Tích hợp Alertmanager → Telegram |
| 12 | [Observability Concepts Summary](./12%20-%20Observability%20Concepts%20Summary.md) | 📚 Tổng hợp toàn bộ khái niệm |

---

## 📁 Cấu Trúc Thư Mục

```
Observability/
├── 00~12 - *.md             # Tài liệu hướng dẫn (theo thứ tự)
├── WineApp-Deploy-K8s/      # K8s manifests cho WineApp
│   ├── wineapp-k8s.yaml          # Deployment: Frontend, Backend, MongoDB
│   ├── wineapp-servicemonitor.yaml   # ServiceMonitor cho Prometheus
│   ├── wineapp-infra-alerts.yaml     # Alert rules (Pod Down, CPU, RAM)
│   └── alertmanager-config.yaml      # Cấu hình gửi Telegram
├── wineapp-backend/         # Mã nguồn Backend (repo riêng)
├── wineapp-frontend/        # Mã nguồn Frontend (repo riêng)
├── assets/
│   └── Architecture.png     # Sơ đồ kiến trúc
└── build_and_push.sh        # Script build & push Docker image
```

---

## 🚀 Quick Start

```bash
# 1. Infrastructure
sudo systemctl restart haproxy

# 2. Monitoring Stack
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring
kubectl apply -f observability-ingress.yaml

# 3. Deploy WineApp
kubectl apply -f WineApp-Deploy-K8s/wineapp-k8s.yaml
kubectl apply -f WineApp-Deploy-K8s/wineapp-servicemonitor.yaml

# 4. Alerting
kubectl apply -f WineApp-Deploy-K8s/wineapp-infra-alerts.yaml
kubectl apply -f WineApp-Deploy-K8s/alertmanager-config.yaml

# 5. Verify
kubectl get pods -n wineapp
kubectl get pods -n monitoring
kubectl get prometheusrule -n wineapp
kubectl get alertmanagerconfig -n wineapp
```

---

## 🧰 Tech Stack

| Tool | Vai trò |
|------|---------|
| **Kubernetes** | Container orchestration |
| **HAProxy** | Load Balancer (Layer 4) |
| **Rancher** | K8s management UI |
| **Prometheus** | Time-series metrics database |
| **Grafana** | Dashboard & visualization |
| **Alertmanager** | Alert routing & notification |
| **Telegram Bot** | Alert delivery channel |

---

*Hệ thống này được xây dựng theo chuẩn **Google SRE** với đầy đủ SLI/SLO/Error Budget và kỹ thuật Multi-window Burn Rate Alerting.*
