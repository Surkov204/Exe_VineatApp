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
3. **Scan hóa đơn**: vào `Scan`, chọn ảnh thư viện hoặc nút camera. Nếu máy
   không cấp quyền hoặc không có ảnh, app chạy hóa đơn mẫu. Bỏ chọn một dòng,
   bấm `Thêm vào tủ`, quay lại Tủ lạnh để kiểm tra.
4. **Món ăn**: mở một món, xem nguyên liệu/các bước, bấm `Đã nấu xong` và
   `Chia sẻ` để thấy phản hồi trực quan.
5. **Đi chợ**: thêm món, đánh dấu đã mua, xóa rồi bấm `Hoàn tác`. Thoát/mở lại
   app để chứng minh danh sách cục bộ còn nguyên.
6. **Báo cáo**: mở báo cáo sau khi đã thêm/xóa món; giá trị trong tủ, giá trị
   hết hạn và tỉ lệ lãng phí phải bám theo dữ liệu hiện tại.
7. **An toàn demo**: vào Hồ sơ → `Đặt lại tủ lạnh mẫu` để quay về trạng thái
   ban đầu nếu cần chạy lại kịch bản.

## Tiêu chí chấp nhận

- Không có nút chính nào bấm mà không có phản hồi.
- Tab chuyển bằng fade/slide nhẹ; nút và card có ripple/active state.
- Scan có trạng thái xử lý; lỗi camera/ảnh không làm kẹt luồng demo.
- Thống kê và báo cáo không dùng ngày/giá trị cứng đã lỗi thời.
- Dữ liệu demo được lưu cục bộ; cache hỏng không làm app không mở được.
- Migration backend nằm ở
  `supabase/migrations/202609200001_initial_schema.sql` và chưa được xem là
  backend production cho đến khi chạy `supabase db push` và nối repository.

## Sau buổi demo

1. Chạy migration Supabase, thêm auth/household sync và repository layer.
2. Nối lịch sử OCR với các trạng thái `processing/review/failed` vào Supabase.
3. Khi danh sách đủ dài, bổ sung skeleton loading, infinite scroll và cache
   phân trang; không dùng parallax cho các màn hình nghiệp vụ ngắn nếu không
   giúp thao tác rõ hơn.
