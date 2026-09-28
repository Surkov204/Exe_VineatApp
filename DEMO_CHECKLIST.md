# ViNeat — checklist demo luồng đầu-cuối

## Chuẩn bị trước buổi demo

- Local demo: chạy `flutter analyze`, `flutter test`, rồi `flutter run` hoặc cài
  `build/app/outputs/flutter-apk/app-release.apk`.
- Demo cloud: áp dụng migrations, deploy Edge Function `household`, cấu hình
  email OTP/Google redirect và chạy app với URL + publishable/anon key như hướng
  dẫn trong README. Kiểm tra sẵn ít nhất hai tài khoản thử nghiệm.
- Cấp quyền camera/ảnh trước nếu sẽ trình diễn scan hóa đơn thật. Luôn chuẩn bị
  phương thức nhập mẫu/thủ công làm đường lui.

## Kịch bản 5–7 phút

1. **Onboarding và điều hướng**: lần đầu vào từng tab, coachmark làm sáng thao tác
   chính; bấm “Tiếp” để đi theo luồng hoặc “Bỏ qua”. Không gian nội dung không bị
   co lại; mở Hồ sơ → Trợ giúp để xem tour 5 bước lần nữa. Chuyển tab rồi quay về
   Trang chủ. Ở tablet, xác nhận thanh điều hướng đổi thành rail.
2. **Tủ lạnh**: thêm hoặc mở một món; thử cập nhật, ghi nhận đã sử dụng và xem
   phản hồi. Xoay/thu phóng mô hình tủ lạnh; chuyển tab qua lại để kiểm tra viewer
   tạm dừng ngoài màn hình. Danh sách vẫn cuộn được đến các món cuối màn hình.
3. **Scan**: chụp/chọn hóa đơn, rà soát và bỏ chọn dòng sai trước khi nhập. Nếu
   không cấp quyền, dùng hóa đơn mẫu hoặc nhập thủ công.
4. **Món ăn**: mở công thức, kiểm tra nguyên liệu có sẵn/thiếu; thêm nguyên liệu
   thiếu sang Đi chợ. Khi xác nhận đã nấu, chọn chính xác các lượng đã dùng.
5. **Đi chợ**: thêm món, đánh dấu mua và xác nhận món đã chuyển vào Tủ lạnh; thử
   bỏ đánh dấu nếu cần. Ở cloud demo sau khi áp dụng migration Realtime, kiểm tra
   thiết bị thứ hai thấy thay đổi tự đồng bộ, không cần đóng/mở lại tab.
6. **Báo cáo**: xác nhận tổng kho, sử dụng/lãng phí và hoạt động phản ánh các thao
   tác vừa xác nhận. Món mẫu không được tính là lịch sử sử dụng.
7. **Gia đình (cloud demo)**: tài khoản A tạo gia đình và chia sẻ mã; tài khoản B
   đăng nhập, nhập mã để tham gia. Chủ nhà xem trước rồi chọn nhập dữ liệu mẫu một
   lần hoặc bắt đầu tủ trống; đổi gia đình, phân vai trò và xóa thành viên ở Hồ sơ.
   Có thể đổi mã mời; mã cũ sẽ hết hiệu lực ngay.

## Tiêu chí chấp nhận

- Không có tràn ngang/đè nội dung ở 320×568, 360×640, 393×852 và tablet; tab
  Trang chủ luôn quay lại đúng màn hình.
- Loading và lỗi có phản hồi; thao tác mua hàng, nấu ăn, tiêu thụ không tạo dữ
  liệu trùng hoặc báo cáo giả.
- Ảnh chọn được xem trước; nếu ảnh local chưa đồng bộ hoặc URL ảnh hết hạn, app
  vẫn có ảnh dự phòng và thao tác không bị chặn.
- Hiệu ứng ngắn, tắt khi người dùng bật Reduce Motion; chuyển động không chặn
  thao tác hoặc kéo dài loading.
- Recipe card và trang chi tiết dùng đúng ảnh món; mô hình GLB có poster/fallback
  nếu WebView hoặc asset không tải được.
- Không phát hành/debug demo với `service_role`, Google client secret hoặc dữ liệu
  thật của thành viên gia đình.

## Những gì test local chưa thể xác minh

Email thật, Google OAuth callback, RLS/storage trên project hosted và đồng bộ thực
giữa hai thiết bị cần Project URL + publishable/anon key, provider settings và
thiết bị/emulator. Không có credentials trong repo; việc chạy `flutter test` không
thay thế các kiểm tra này.
