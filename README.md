# ViNeat

ViNeat là prototype Flutter cho quản lý thực phẩm gia đình: theo dõi tủ lạnh,
scan hóa đơn, gợi ý món ăn, danh sách đi chợ và báo cáo giảm lãng phí.

## Chạy bản demo Android

1. Cài Flutter stable và Android SDK, sau đó kiểm tra bằng `flutter doctor`.
2. Chạy `flutter pub get` để cài `shared_preferences`.
3. Kết nối máy Android hoặc mở emulator rồi chạy `flutter run`.
4. Tạo APK demo bằng `flutter build apk --release`.

## Luồng demo khuyến nghị

Checklist thao tác và tiêu chí nghiệm thu nằm trong
[`DEMO_CHECKLIST.md`](DEMO_CHECKLIST.md).

1. Mở **Tủ lạnh**, bấm dấu `+` và thêm một thực phẩm mới. Thống kê và cảnh báo
   thay đổi ngay lập tức.
2. Mở **Scan**, chọn ảnh từ thư viện hoặc nút chụp; nếu quyền camera/ảnh bị từ
   chối, bộ xử lý tự chuyển sang hóa đơn mẫu. Bỏ/chọn từng dòng rồi bấm
   **Thêm vào tủ**.
3. Mở **Món ăn**, tìm một món và xem chi tiết; nút **Đã nấu xong** hiển thị
   phản hồi trực quan.
4. Mở **Đi chợ**, thêm món, đánh dấu đã mua, xóa và thử **Hoàn tác**. Danh sách
   và tủ lạnh được lưu cục bộ trên Android qua `shared_preferences`.
5. Mở **Báo cáo** để trình bày các biểu đồ và thành tựu mẫu.

## Ghi chú hiện trạng

- Bản hiện tại là demo local-first, chưa kết nối backend production.
- Workspace hiện không chứa file Proposal hoặc source backend riêng; schema
  Supabase bên dưới được dựng theo các màn hình và luồng dữ liệu đang có trong
  Flutter để không chặn buổi demo.
- Migration Supabase nền tảng nằm trong
  `supabase/migrations/202609200001_initial_schema.sql`; migration này chưa
  được áp dụng vào project hosted trong môi trường hiện tại.
- Dữ liệu tủ lạnh và danh sách đi chợ được lưu trên thiết bị; nếu cache hỏng,
  app tự quay về dữ liệu mẫu để vẫn mở được.
- Scan dùng ML Kit OCR trên Android/iOS, sau đó parser nhận diện cửa hàng,
  ngày mua, dòng sản phẩm, số lượng và giá. Người dùng có thể sửa kết quả
  trước khi thêm vào tủ; dữ liệu vẫn được lưu cục bộ cho tới khi nối Supabase.

## Kiểm chứng hiện tại

- `flutter analyze`: không có issue.
- `flutter test`: pass widget test `renders the five-screen ViNeat shell`.
- `flutter build apk --release`: pass; APK nằm tại
  `build/app/outputs/flutter-apk/app-release.apk` (khoảng 53 MB).
