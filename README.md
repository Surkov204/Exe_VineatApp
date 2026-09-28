# ViNeat

ViNeat là prototype Flutter cho quản lý thực phẩm gia đình: theo dõi tủ lạnh,
scan hóa đơn, gợi ý món ăn, danh sách đi chợ và báo cáo giảm lãng phí.

## Chạy bản demo Android

1. Cài Flutter stable và Android SDK, sau đó kiểm tra bằng `flutter doctor`.
2. Chạy `flutter pub get` để cài thư viện lưu cục bộ, chọn ảnh và OCR.
3. Kết nối máy Android hoặc mở emulator rồi chạy `flutter run`.
4. Tạo APK demo bằng `flutter build apk --release`.

## Luồng demo khuyến nghị

Checklist thao tác và tiêu chí nghiệm thu nằm trong
[`DEMO_CHECKLIST.md`](DEMO_CHECKLIST.md).

1. Lần đầu mở app, đi qua hướng dẫn 5 trang; có thể mở lại tại Hồ sơ → Trợ giúp.
2. Mở **Tủ lạnh**, bấm dấu `+` và thêm một thực phẩm mới. Thống kê và cảnh báo
   thay đổi ngay lập tức.
3. Mở **Scan**, chọn ảnh thư viện hoặc chụp hóa đơn, rồi rà soát/sửa các dòng
   OCR trước khi bấm **Thêm vào tủ**. Nếu quyền camera/ảnh bị từ chối, chọn
   **Hóa đơn mẫu** hoặc **Nhập thủ công** trong thẻ phương thức đầu vào.
4. Mở **Món ăn**, tìm một món và xem chi tiết; nút **Đã nấu xong** hiển thị
   phản hồi trực quan.
5. Mở **Đi chợ**, thêm món, đánh dấu đã mua, xóa và thử **Hoàn tác**. Danh sách
   và tủ lạnh được lưu cục bộ trên Android qua `shared_preferences`.
6. Mở **Báo cáo** để xem thống kê hiện tại; các biểu đồ lịch sử chưa có dữ liệu
   sẽ được gắn nhãn minh họa, không đại diện cho số liệu thật.

## Ghi chú hiện trạng

- Bản hiện tại là demo local-first, chưa kết nối backend production.
- Workspace hiện không chứa file Proposal hoặc source backend riêng; schema
  Supabase bên dưới được dựng theo các màn hình và luồng dữ liệu đang có trong
  Flutter để không chặn buổi demo.
- Schema nền tảng và migration bảo vệ luồng mã gia đình nằm trong
  `supabase/migrations/`. Chúng chưa được áp dụng vào project hosted; app hiện
  chưa có đăng nhập, repository từ xa hoặc đồng bộ giữa nhiều thiết bị.
- Dữ liệu tủ lạnh và danh sách đi chợ được lưu trên thiết bị; nếu cache hỏng,
  app tự quay về dữ liệu mẫu để vẫn mở được.
- Scan dùng ML Kit OCR trên Android/iOS, sau đó parser nhận diện cửa hàng,
  ngày mua, dòng sản phẩm, số lượng và giá. Người dùng có thể sửa kết quả
  trước khi thêm vào tủ; dữ liệu vẫn được lưu cục bộ cho tới khi nối Supabase.

## Kiểm chứng hiện tại

- `dart analyze lib test`: không có issue.
- `flutter test --no-pub`: 9 bài unit/widget pass; bao phủ điều hướng 5 tab,
  hướng dẫn lần đầu, 320×568/360×640, tablet 900×800, luồng mua sắm, báo cáo,
  chọn ảnh và parser OCR hóa đơn tiếng Việt.
- `flutter build apk --release --no-pub`: pass; tạo
  `build/app/outputs/flutter-apk/app-release.apk` (85.4 MB, APK đa kiến trúc,
  ký debug để demo local; chưa dùng phát hành cửa hàng ứng dụng).
