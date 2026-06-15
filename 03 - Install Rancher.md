# Hướng dẫn cài đặt Rancher trên Kubernetes

Hướng dẫn này bao gồm các bước chuẩn bị từ việc cài đặt Nginx Ingress Controller (chạy dưới dạng NodePort), Cert-Manager và cuối cùng là cài đặt Rancher theo đúng kiến trúc của bạn.

## 1. Cài đặt Ingress Nginx (Kiểu NodePort)

Thêm repository và tải biểu đồ (chart) Nginx Ingress về:

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
```

Tìm kiếm và tải source chart về máy để tuỳ chỉnh:

```bash
helm search repo nginx
helm pull ingress-nginx/ingress-nginx
tar -xzvf ingress-nginx-*.tgz
```

Chỉnh sửa file `values.yaml` của Ingress Nginx:

```bash
vi ingress-nginx/values.yaml
```
*Bạn cần tìm và sửa các thông số sau trong file `values.yaml` (dùng để chuyển từ LoadBalancer sang định tuyến NodePort cố định):*
- Đổi `type: LoadBalancer` thành `type: NodePort`
- Đổi `nodePort http: ""` thành `http: "30080"` (dưới mục nodePort)
- Đổi `nodePort https: ""` thành `https: "30443"` (dưới mục nodePort)

Tạo namespace và tiến hành cài đặt Ingress Controller:

```bash
kubectl create ns ingress-nginx
helm -n ingress-nginx install ingress-nginx -f ingress-nginx/values.yaml ingress-nginx
```

## 2. Cài đặt Cert-Manager

Cert-Manager dùng để tự động quản lý chứng chỉ SSL/TLS cho Rancher:

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update

helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true \
  --set startupapicheck.enabled=false \
  --set webhook.hostNetwork=true \
  --set webhook.securePort=10260
```

## 3. Cài đặt Rancher

Thêm repository của Rancher:

```bash
# Thêm repository stable (khuyến nghị cho production)
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable

# Hoặc thêm repository latest (cho testing)
# helm repo add rancher-latest https://releases.rancher.com/server-charts/latest

# Cập nhật repository
helm repo update
```

Tạo namespace quản trị cho Rancher:

```bash
kubectl create namespace cattle-system
```

Chạy lệnh cài đặt Rancher với cấu hình đã thiết lập sẵn (tích hợp với Ingress Nginx):

```bash
helm install rancher rancher-stable/rancher \
  --namespace cattle-system \
  --set hostname=rancher.tranvix.click \
  --set bootstrapPassword=admin \
  --set ingress.tls.source=rancher \
  --set ingress.ingressClassName=nginx \
  --set global.cattle.psp.enabled=false
```

---
*Ghi chú: Đảm bảo rằng tên miền `rancher.tranvix.click` đã được khai báo DNS (hoặc file hosts) trỏ về đúng cụm máy chủ hoặc Load Balancer của bạn.*

```bash
helm upgrade rancher rancher-stable/rancher \
  --namespace cattle-system \
  --set hostname=rancher.tranvix.click \
  --set bootstrapPassword=admin \
  --set ingress.tls.source=rancher \
  --set ingress.ingressClassName=nginx \
  --set global.cattle.psp.enabled=false
```

## 4. Xử lý sự cố (Troubleshooting) thường gặp

### Lỗi 1: Cài đặt Rancher thất bại do `cert-manager webhook`
**Triệu chứng:** Khi chạy `helm install rancher`, báo lỗi `failed to verify certificate: x509: certificate signed by unknown authority`.

**Nguyên nhân:** Webhook của cert-manager chưa khởi tạo xong hoặc chứng chỉ bị kẹt.

**Cách khắc phục:** Xoá cấu hình webhook và khởi động lại pod để cert-manager tự động cấp lại chứng chỉ:
```bash
kubectl delete validatingwebhookconfiguration cert-manager-webhook
kubectl delete mutatingwebhookconfiguration cert-manager-webhook
kubectl rollout restart deployment cert-manager-webhook -n cert-manager
kubectl rollout status deployment cert-manager-webhook -n cert-manager
```
Sau đó chạy lại lệnh cài đặt/upgrade Rancher.

### Lỗi 2: Lỗi "API Aggregation not ready" khi truy cập giao diện
**Triệu chứng:** Truy cập vào web báo lỗi "API Aggregation not ready". Kiểm tra `kubectl get pods -A` thấy các pod `fleet-controller` và `gitjob` ở namespace `cattle-fleet-system` bị `CrashLoopBackOff`.

**Nguyên nhân:** Rancher chưa khởi động hoàn toàn nên các pod của Fleet (GitOps) bị lỗi khi kết nối tới Kubernetes API hoặc Rancher Webhook.

**Cách khắc phục:**
1. Hãy kiên nhẫn chờ thêm 3-5 phút, các pod thường sẽ tự động khôi phục khi Rancher đã sẵn sàng.
2. Nếu đợi quá lâu không hết, hãy ép khởi động lại các pod bị kẹt để chúng kết nối lại:
```bash
kubectl delete pods -n cattle-fleet-system --all
kubectl delete pods -n cattle-system -l app=rancher-webhook
```
Sau đó f5 lại trang web vài lần.

### Lỗi 3: Prometheus báo đỏ (down) các target Control Plane
**Triệu chứng:** Trong màn hình Targets của Prometheus, các mục như `kube-controller-manager`, `kube-scheduler`, `etcd`, `kube-proxy` báo lỗi đỏ (0/1 up) với lý do Connection Refused.

**Nguyên nhân:** Mặc định các thành phần quản trị (Control Plane) của Kubernetes tự dựng bằng `kubeadm` chỉ mở port metrics ở `127.0.0.1` (localhost) nên Prometheus (từ pod khác) không thể gọi vào để lấy metrics được.

**Cách khắc phục:**
Chạy cụm lệnh dưới đây trên node Master để cấu hình lại các thành phần này mở port `0.0.0.0` (cho phép Prometheus thu thập metrics):

```bash
# 1. Sửa Kube Controller Manager và Kube Scheduler
sudo sed -i 's/--bind-address=127.0.0.1/--bind-address=0.0.0.0/g' /etc/kubernetes/manifests/kube-controller-manager.yaml
sudo sed -i 's/--bind-address=127.0.0.1/--bind-address=0.0.0.0/g' /etc/kubernetes/manifests/kube-scheduler.yaml

# 2. Sửa Etcd (Đổi port metrics của etcd)
sudo sed -i 's/--listen-metrics-urls=http:\/\/127.0.0.1:2381/--listen-metrics-urls=http:\/\/0.0.0.0:2381/g' /etc/kubernetes/manifests/etcd.yaml

# 3. Sửa Kube Proxy và tự động tải lại
kubectl get configmap kube-proxy -n kube-system -o yaml | \
sed -e 's/metricsBindAddress: ""/metricsBindAddress: 0.0.0.0:10249/' \
    -e 's/metricsBindAddress: 127.0.0.1:10249/metricsBindAddress: 0.0.0.0:10249/' | \
kubectl apply -f -
kubectl rollout restart daemonset kube-proxy -n kube-system
```
Đợi khoảng 1-2 phút để các thành phần khởi động lại và Prometheus quét lại metrics, các target sẽ chuyển sang trạng thái xanh (UP).
