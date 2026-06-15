# Hướng dẫn cài đặt Prometheus trên Kubernetes

Cách phổ biến và chuẩn nhất hiện nay để cài đặt Prometheus trên Kubernetes là sử dụng Helm chart **kube-prometheus-stack** (trước đây là prometheus-operator). Chart này sẽ tự động cài đặt toàn bộ stack bao gồm Prometheus, Grafana, Alertmanager, và các exporter cần thiết.

## 1. Điều kiện tiên quyết
- Cụm Kubernetes đang hoạt động (ví dụ: Minikube, Kind, EKS, GKE, AKS...).
- Đã cài đặt công cụ [kubectl](https://kubernetes.io/docs/tasks/tools/) và cấu hình kết nối tới cụm K8s thành công.
- Đã cài đặt [Helm 3](https://helm.sh/docs/intro/install/) (Package manager cho Kubernetes).

- Instal Helm

```bash
HELM_BUILDKITE_APT_KEY_ID="DDF78C3E6EBB2D2CC223C95C62BA89D07698DBC6"

sudo apt-get install curl gpg apt-transport-https --yes

curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey > "${TMPDIR:-/tmp}/helm.gpg"

# Ensure that the key ID matches to prevent a repository compromise from establishing an attacker controlled key
if [ "$(gpg --show-keys --with-colons "${TMPDIR:-/tmp}/helm.gpg" | awk -F: '$1 == "fpr" {print $10}' | head -n 1)" != "${HELM_BUILDKITE_APT_KEY_ID}" ]; then echo "ERROR: Unexpected Helm APT key ID: potential key compromise"; exit 1; fi

cat "${TMPDIR:-/tmp}/helm.gpg" | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list

sudo apt-get update
sudo apt-get install helm
```

## 2. Thêm Helm Repository
Thêm repository của Prometheus Community và cập nhật danh sách các chart:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

## 3. Tạo Namespace
Nên tạo một namespace riêng biệt (ví dụ: `monitoring`) để quản lý các thành phần liên quan đến giám sát (observability):

```bash
kubectl create namespace monitoring
```

## 4. Cài đặt kube-prometheus-stack
Chạy lệnh sau để cài đặt stack vào namespace `monitoring` vừa tạo:

```bash
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring
```

Sau khi cài xong, Helm sẽ in ra các lệnh tham khảo để truy cập nhanh:

- **Lấy mật khẩu Grafana:**
```bash
kubectl --namespace monitoring get secrets prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo
```

- **Truy cập Grafana qua port-forward:**
```bash
export POD_NAME=$(kubectl --namespace monitoring get pod -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=prometheus" -oname)
kubectl --namespace monitoring port-forward $POD_NAME 3000
```

- **Hoặc lấy mật khẩu từ secret:**
```bash
kubectl get secret --namespace monitoring -l app.kubernetes.io/component=admin-secret -o jsonpath="{.items[0].data.admin-password}" | base64 --decode ; echo
```

*Trong đó: `prometheus` là tên release (release name) mà chúng ta đặt cho bản cài đặt này.*

## 5. Kiểm tra trạng thái cài đặt
Quá trình khởi tạo các Pod có thể mất vài phút. Bạn kiểm tra trạng thái bằng lệnh:

```bash
kubectl get pods -n monitoring
```

Khi tất cả các pod có trạng thái là `Running` (hoặc đã Ready), quá trình cài đặt đã hoàn tất thành công.

## 6. Truy cập vào giao diện quản lý (UI)
Mặc định, các service của Prometheus và Grafana không được expose ra ngoài cụm (chỉ sử dụng kiểu ClusterIP). Để truy cập nhanh từ máy cá nhân, chúng ta sẽ dùng tính năng Port Forwarding.

### 6.1. Truy cập Prometheus UI
Forward port từ service của Prometheus ra máy local:
```bash
kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090 -n monitoring
```
Sau đó mở trình duyệt và truy cập: [http://localhost:9090](http://localhost:9090)

### 6.2. Truy cập Grafana UI (Dashboard)
Forward port từ service của Grafana:
```bash
kubectl port-forward svc/prometheus-grafana 8080:80 -n monitoring
```
Sau đó mở trình duyệt và truy cập: [http://localhost:8080](http://localhost:8080)
- **Tên đăng nhập (Username)** mặc định: `admin`
- **Mật khẩu (Password)** mặc định: `prom-operator`

## Tóm tắt các thành phần chính đã được cài đặt
- **Prometheus**: Core server thực hiện thu thập và lưu trữ các metric chuỗi thời gian (time-series).
- **Grafana**: Giao diện hiển thị, tạo các dashboard trực quan. Chart này đã cấu hình sẵn Prometheus làm Data Source mặc định và cung cấp sẵn rất nhiều dashboard giám sát Kubernetes (Node, Pod, API server...).
- **Alertmanager**: Công cụ quản lý và định tuyến các cảnh báo (alert) ra các kênh như Slack, Email, PagerDuty...
- **Node Exporter**: Agent chạy trên từng worker node để thu thập các metric phần cứng và hệ điều hành (CPU, RAM, Disk, Network).
- **Kube-state-metrics**: Thành phần theo dõi và xuất ra metric về trạng thái của chính các đối tượng Kubernetes (Deployments, Pods, Services...).
## 7. Truy cập thông qua Ingress Nginx

Thay vì sử dụng Port Forwarding thủ công mỗi lần, bạn có thể tạo một đối tượng Ingress để định tuyến domain ảo (hoặc domain thật) trực tiếp đến dịch vụ của Prometheus và Grafana. Đảm bảo rằng bạn đã cài đặt Nginx Ingress Controller trên cụm.

Tạo một file có tên `observability-ingress.yaml` với nội dung sau:

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
    - host: prometheus.tranvix.click # Đổi thành tên miền của bạn
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: prometheus-kube-prometheus-prometheus
                port:
                  number: 9090
    - host: grafana.tranvix.click # Đổi thành tên miền của bạn
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

Sau đó áp dụng cấu hình Ingress này vào cụm:
```bash
kubectl apply -f observability-ingress.yaml
```

**Bước cuối cùng:**
Nếu bạn dùng domain ảo chưa có thực, hãy mở file `/etc/hosts` trên máy Mac/Windows của bạn (xem hướng dẫn ở file số 3) và ánh xạ IP của máy chủ Load Balancer (HAProxy) hoặc IP của Worker Node vào hai tên miền trên:
```text
192.168.81.100    prometheus.tranvix.click
192.168.81.100    grafana.tranvix.click
```
*(Thay `192.168.81.100` bằng IP thực tế của bạn).*

Bây giờ bạn đã có thể truy cập trực tiếp bằng trình duyệt qua địa chỉ `http://prometheus.tranvix.click` và `http://grafana.tranvix.click`!

## 8. Xem tài khoản và mật khẩu đăng nhập Grafana

Trong quá trình triển khai, mật khẩu admin mặc định có thể được thiết lập ngầm qua biến môi trường. Để xem chính xác tài khoản và mật khẩu Grafana đang sử dụng, bạn có thể kiểm tra trực tiếp từ bên trong Pod.

**Bước 1: Tìm tên Pod của Grafana**
```bash
kubectl get pods -n monitoring | grep grafana
```
*(Kết quả sẽ hiển thị một tên pod có dạng `prometheus-grafana-xxxx`)*

**Bước 2: Kiểm tra biến môi trường bảo mật**
Thay thế `prometheus-grafana-xxxx` bằng tên Pod thực tế bạn vừa lấy được ở trên và chạy lệnh sau:
```bash
kubectl exec -it -n monitoring prometheus-grafana-xxxx -- env | grep GF_SECURITY
```

Hoặc:

```bash
kubectl get secret --namespace monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
```

Nếu kết quả trả về có dạng:

```text
GF_SECURITY_ADMIN_USER=admin
GF_SECURITY_ADMIN_PASSWORD=prom-operator
```

Thì có nghĩa là Grafana đang dùng tài khoản `admin` và mật khẩu nằm trong biến `GF_SECURITY_ADMIN_PASSWORD` (ở đây là `prom-operator`). Bạn sử dụng thông tin này để đăng nhập vào UI của Grafana nhé!
