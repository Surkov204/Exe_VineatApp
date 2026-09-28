# ViNeat

ViNeat là prototype Flutter quản lý thực phẩm gia đình: tủ lạnh, scan hóa đơn,
gợi ý món ăn, danh sách đi chợ, báo cáo sử dụng/lãng phí và chia sẻ dữ liệu gia đình.

## Chạy demo local

Không cần Supabase để trình diễn các luồng local-first. Cần Flutter stable và Android
SDK (hoặc emulator/thiết bị Android):

```powershell
flutter pub get
flutter analyze
flutter test
flutter run
```

Tạo APK cài thử:

```powershell
flutter build apk --release
```

File đầu ra: `build/app/outputs/flutter-apk/app-release.apk`. APK này dùng để demo
local, ký debug; không dùng để phát hành cửa hàng.

## Chạy với Supabase

1. Cấu hình email OTP và Google trong Supabase Auth. Thêm redirect URI
   `com.vineat.team.vineat_app://login-callback` vào danh sách Redirect URLs.
2. Cài Supabase CLI, liên kết project rồi áp dụng các migration theo thứ tự:

   ```powershell
   supabase link --project-ref <project-ref>
   supabase db push
   supabase functions deploy household
   ```

3. Chạy app với URL và khóa public của project (anon/publishable):

   ```powershell
   flutter run `
     --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co `
     --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable-or-anon-key>
   ```

   Có thể dùng `SUPABASE_ANON_KEY` thay cho `SUPABASE_PUBLISHABLE_KEY` để tương
   thích project dùng khóa anon cũ. Không đưa `service_role` hoặc Google client
   secret vào app hay build arguments.

Khi đã cấu hình, app dùng email OTP/Google, tạo hoặc tham gia gia đình bằng mã,
chọn gia đình đang hoạt động, xem/quản lý vai trò thành viên, và đồng bộ
tủ lạnh/đi chợ/sự kiện qua Supabase. Khi một gia đình mới chưa có kho, mỗi gia
đình chỉ được hỏi một lần để xem trước rồi nhập dữ liệu mẫu hoặc bắt đầu tủ trống.
RLS giới hạn dữ liệu theo thành viên; ảnh gia đình nằm trong storage bucket private.
Không có credentials của project trong repository, vì vậy chưa thể xác minh luồng
đăng nhập và đồng bộ trên project hosted chỉ bằng bộ test local.

## Kịch bản demo

Checklist 5–7 phút và các tiêu chí nghiệm thu ở
[`DEMO_CHECKLIST.md`](DEMO_CHECKLIST.md).

Luồng gợi ý: hoàn tất hướng dẫn → thêm thực phẩm → quét/chỉnh hóa đơn → xem món ăn
và nguyên liệu còn thiếu → đánh dấu món đi chợ đã mua → xác nhận đã dùng thực phẩm
→ xem báo cáo. Mẫu mặc định được dùng khi chạy local; các sự kiện sử dụng/lãng phí
trong báo cáo chỉ xuất hiện sau thao tác xác nhận, không giả làm lịch sử thực tế.

## Trạng thái và giới hạn đã biết

- Bố cục mobile dùng thanh tab cố định; màn hình rộng chuyển qua navigation rail.
  Các trang giữ trạng thái khi đổi tab, nội dung cuộn trong vùng riêng và chuyển tab
  bằng hiệu ứng ngắn, tự tắt khi thiết bị bật giảm chuyển động.
- Mỗi trang có thẻ hướng dẫn gọn ở lần đầu truy cập; tour 5 bước có thể mở lại từ
  Hồ sơ → Trợ giúp. Tiến độ từng trang lưu cục bộ và đồng bộ khi tài khoản online.
- Danh mục món ăn/công thức hiện là catalog cục bộ; phần gợi ý kiểm tra nguyên liệu
  từ tủ lạnh và nút thêm nguyên liệu thiếu vào danh sách đi chợ.
- OCR xử lý ảnh trên thiết bị. Các dòng đã xác nhận có thể nhập vào kho local hoặc
  household đã đăng nhập; chưa có job OCR nền hay quản trị lịch sử hóa đơn đầy đủ.
- Chưa có file GLB gốc được cấp phép trong source. Màn đăng nhập và Trang chủ dùng
  hình tủ lạnh phối cảnh dựng native bằng Flutter làm fallback nhẹ, không tải WebView
  hay giả nhận đó là mô hình GLB. Cần cung cấp GLB nếu muốn thay bằng model 3D thật.
- File Proposal và backend riêng không có trong workspace hiện tại. Schema trong
  `supabase/migrations/` được dựng theo luồng hiện có của ứng dụng và cần đối chiếu
  Proposal/backend gốc trước khi coi là schema production.

## Kiểm chứng

Chạy `flutter analyze` và `flutter test`. Widget tests bao phủ onboarding, chuyển tab,
layout nhỏ, tablet, nhập món, mua hàng → tủ lạnh, công thức → đi chợ, dùng thực phẩm
→ báo cáo và chọn ảnh; unit tests bao phủ parser OCR hóa đơn tiếng Việt. Kiểm tra
đăng nhập OAuth, email thật, RLS/storage và đồng bộ giữa hai tài khoản cần project
Supabase cùng thiết bị/emulator có cấu hình provider.
