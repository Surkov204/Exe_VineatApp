# ViNeat — checklist demo luồng cơ bản

## Chuẩn bị

```powershell
flutter pub get
flutter analyze
flutter test
flutter run
```

Nếu trình diễn bằng APK:

```powershell
flutter build apk --release
```

## Kịch bản 5–7 phút

1. **Tủ lạnh**: mở app, cho người xem thấy thống kê và cảnh báo. Bấm `+`,
   nhập một món mới, lưu; số lượng, cảnh báo và tổng giá trị phải đổi ngay.
2. **Chi tiết món**: chạm một món, chỉnh số lượng/giá, lưu; quay lại danh sách
   và kiểm tra dữ liệu đã cập nhật. Thử xóa nếu cần.
3. **Scan hóa đơn**: vào `Scan`, chọn ảnh thư viện hoặc chụp bằng camera; kiểm
   tra OCR rồi sửa/chọn dòng trước khi bấm `Thêm vào tủ`. Nếu từ chối quyền,
   dùng `Hóa đơn mẫu` hoặc `Nhập thủ công` trong thẻ phương thức đầu vào.
4. **Món ăn**: mở một món, xem nguyên liệu/các bước, bấm `Đã nấu xong` và
   `Chia sẻ` để thấy phản hồi trực quan.
5. **Đi chợ**: thêm món, đánh dấu đã mua, xóa rồi bấm `Hoàn tác`. Thoát/mở lại
   app để chứng minh danh sách cục bộ còn nguyên.
6. **Báo cáo**: mở báo cáo sau khi đã thêm/xóa món; kiểm tra các KPI tồn kho
   đang lấy dữ liệu hiện tại. Biểu đồ lịch sử và mục tiêu còn là minh họa mẫu,
   không trình bày như số liệu đã theo dõi thực tế.
7. **An toàn demo**: vào Hồ sơ → `Đặt lại tủ lạnh mẫu` để quay về trạng thái
   ban đầu nếu cần chạy lại kịch bản.

## Tiêu chí chấp nhận

- Các luồng cốt lõi: thêm/sửa thực phẩm, scan/mẫu/thủ công, quản lý mua sắm và
  chuyển về Trang chủ đều có thể thao tác; chức năng chưa hỗ trợ phải được
  nhận diện rõ là chưa khả dụng.
- Tab chuyển bằng fade/slide nhẹ; nút và card có ripple/active state.
- Scan có trạng thái xử lý; lỗi camera/ảnh không làm kẹt luồng demo.
- Thống kê và báo cáo không dùng ngày/giá trị cứng đã lỗi thời.
- Dữ liệu demo được lưu cục bộ; cache hỏng không làm app không mở được.
- Schema/migration nằm ở `supabase/migrations/`. Chưa được áp dụng/kiểm thử trên
  project Supabase hosted, và app chưa nối đăng nhập hay đồng bộ từ xa.

## Sau buổi demo

1. Cấu hình Supabase Auth/URL/key, áp dụng và kiểm thử migration trên project
   riêng; sau đó mới nối household sync và repository layer.
2. Nối lịch sử OCR với các trạng thái `processing/review/failed` vào Supabase.
3. Khi danh sách đủ dài, bổ sung skeleton loading, infinite scroll và cache
   phân trang; không dùng parallax cho các màn hình nghiệp vụ ngắn nếu không
   giúp thao tác rõ hơn.
