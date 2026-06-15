# Các Thực Hành Tốt Nhất (Best Practices) Cho Grafana Dashboard

Tài liệu này cung cấp các hướng dẫn để xây dựng và quản lý Grafana Dashboard một cách hiệu quả, từ việc chọn thông số giám sát đến quản lý vòng đời của Dashboard.

## 1. Các Chiến Lược Giám Sát Phổ Biến

Khi hệ thống ngày càng lớn, bạn cần một chiến lược để quyết định những gì thực sự quan trọng cần giám sát. 

### Phương pháp USE (Dành cho Phần cứng/Hạ tầng)
USE cho biết "máy móc của bạn đang ổn đến mức nào". Nó dùng để tìm **nguyên nhân** của vấn đề.
*   **Utilization (Mức độ sử dụng):** Tỷ lệ phần trăm thời gian tài nguyên bận rộn (ví dụ: % sử dụng CPU).
*   **Saturation (Độ bão hòa):** Khối lượng công việc tài nguyên phải xử lý, thường là độ dài hàng đợi (queue) hoặc tải (load) của node.
*   **Errors (Lỗi):** Số lượng các sự kiện lỗi xảy ra.

### Phương pháp RED (Dành cho Dịch vụ/Microservices)
RED cho biết "người dùng của bạn đang hài lòng đến mức nào". Nên dùng RED để thiết lập **Cảnh báo (Alerts)** vì nó báo cáo các triệu chứng ảnh hưởng trực tiếp đến người dùng.
*   **Rate (Tỷ lệ):** Số lượng Requests mỗi giây.
*   **Errors (Lỗi):** Số lượng Requests bị thất bại.
*   **Duration (Thời lượng):** Thời gian xử lý request (độ trễ/latency).

### The Four Golden Signals (4 Tín Hiệu Vàng của Google SRE)
Dành cho các hệ thống tương tác trực tiếp với người dùng.
*   **Latency (Độ trễ):** Thời gian xử lý 1 request.
*   **Traffic (Lưu lượng):** Mức độ nhu cầu (tải) đang đè lên hệ thống.
*   **Errors (Lỗi):** Tỷ lệ request lỗi.
*   **Saturation (Độ bão hòa):** Hệ thống đang "đầy" tới mức nào.

---

## 2. Các Cấp Độ Trưởng Thành Trong Quản Lý Dashboard

### Mức Thấp (Trạng thái mặc định - Hầu hết đều bắt đầu từ đây)
* Ai cũng có quyền sửa Dashboard.
* Rất nhiều Dashboard bị copy rác, ít được tái sử dụng.
* Các Dashboard dùng 1 lần cứ tồn tại mãi mãi.
* Mất rất nhiều thời gian bới tìm Dashboard vì không có quy hoạch.
* Cảnh báo (Alert) không trỏ link trực tiếp đến Dashboard tương ứng.

### Mức Trung Bình (Bắt đầu có phương pháp)
* **Tránh rác bằng Variables:** Thay vì tạo 10 Dashboard cho 10 cụm máy chủ, hãy dùng Biến (Variables) ở thanh trên cùng để chọn/lọc máy chủ.
* Dashboard được thiết kế theo phân cấp (Drill-down) từ tổng quan xuống chi tiết.
* Màu sắc có ý nghĩa (Xanh là Tốt, Đỏ là Lỗi) và có cài đặt Ngưỡng (Thresholds) rõ ràng. Đồng bộ hoá các trục Y (ví dụ: CPU luôn để mốc 100% để dễ so sánh).
* Cảnh báo sẽ cung cấp sẵn link bấm thẳng vào Dashboard để theo dõi.
* JSON của Dashboard bắt đầu được đưa vào quản lý phiên bản (Version Control).

### Mức Cao (Sử dụng tối ưu hóa)
* Thường xuyên dọn dẹp các Dashboard rác không còn sử dụng.
* Các Dashboard chính thức phải được phê duyệt trước khi thêm vào danh sách chuẩn.
* Tự động sinh Dashboard bằng code (ví dụ: Jsonnet, Python) để đảm bảo đồng nhất về thiết kế.
* Không sửa giao diện trực tiếp trên trình duyệt. Người dùng chỉ xem và chuyển đổi góc nhìn qua Variables.
* Có môi trường Test riêng để thử nghiệm Dashboard trước khi đưa lên môi trường thật.

---

## 3. Best Practices Khi Tạo Mới Dashboard

* **Dashboard phải kể một câu chuyện hoặc trả lời một câu hỏi:** Đi từ thông tin lớn xuống thông tin nhỏ (từ trái qua phải, từ trên xuống dưới). Nếu câu hỏi là "Máy chủ nào đang tèo?", đừng hiển thị thông số của tất cả các máy, chỉ hiển thị máy đang gặp sự cố.
* **Giảm tải nhận thức (Cognitive Load):** Biểu đồ phải dễ hiểu ngay lập tức. Người trực ca lúc 2h sáng không nên phải suy nghĩ mất 5 phút mới hiểu biểu đồ này nói gì.
* **Viết tài liệu (Documentation):** Thêm các bảng Text Panel bằng Markdown để ghi chú mục đích của Dashboard, hoặc ghi chú vào cài đặt từng Panel (sẽ hiện chữ `i` ở góc để người khác đọc được).
* **Sử dụng trục Y bên Trái và Phải:** Cần thiết khi bạn vẽ 2 thông số khác nhau hoàn toàn về đơn vị đo (ví dụ: % CPU và Số lượng request).
* **Tránh lạm dụng Stacked Graph (Biểu đồ chồng):** Nó rất dễ gây hiểu lầm và che lấp dữ liệu quan trọng. Nên tắt tính năng này trừ khi thực sự cần thiết.

---

## 4. Best Practices Khi Quản Lý Dashboard

* **Đặt tên có ý nghĩa:** Gắn thêm tiền tố `TEST:` hoặc `TMP:` vào tên nếu bạn đang tạo nháp, và **phải nhớ xoá nó đi** khi thử nghiệm xong. Nên ghi tên/initials của bạn vào Dashboard để người khác biết ai là chủ sở hữu.
* **Đừng Copy Dashboard một cách vô tội vạ:** Copy khiến bạn bỏ lỡ các bản vá lỗi hoặc tính năng mới cập nhật từ bản gốc. Nếu chỉ cần góc nhìn khác, hãy dùng Variables hoặc URL Parameters.
* **Cẩn thận với Tags:** Nếu bắt buộc phải Copy Dashboard, nhớ sửa Tên và **Đừng copy các Tag**, vì nó sẽ làm loạn bộ máy tìm kiếm Dashboard gốc của hệ thống.
* **Tạo trung tâm điều hướng:** Sử dụng Text Panel, Dashboard Links, hoặc Data Links để liên kết các Dashboard liên quan lại với nhau, giúp người dùng nhảy từ Dashboard này sang Dashboard khác dễ dàng.
