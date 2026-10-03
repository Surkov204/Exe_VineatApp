# ViNeat

ViNeat là prototype Flutter quản lý thực phẩm gia đình: tủ lạnh, scan hóa đơn,
gợi ý món ăn, danh sách đi chợ, báo cáo sử dụng/lãng phí và chia sẻ dữ liệu gia đình.

## Chạy app với Supabase cloud

App mặc định kết nối project Supabase cloud của ViNeat bằng Project URL và
publishable key công khai. Không cần Docker hay `supabase start` để chạy bằng
Android Studio. Cần Flutter stable và Android SDK (hoặc emulator/thiết bị Android):

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

File đầu ra: `build/app/outputs/flutter-apk/app-release.apk`. APK này dùng để demo,
ký debug; không dùng để phát hành cửa hàng.

## Chạy với Supabase

1. Trong Supabase Auth → Email Templates → Magic Link, cấu hình nội dung thư có
   `{{ .Token }}` vì màn hình ViNeat yêu cầu OTP 6 số (không dùng magic link mặc
   định). Bật email signup/OTP và Google provider. Thêm các redirect URI vào
   danh sách Redirect URLs: `com.vineat.team.vineat_app://login-callback` cho
   Release, `com.vineat.team.vineat_app.preview://login-callback` cho Debug và
   `com.vineat.team.vineat_app.profile://login-callback` cho Profile.
2. Cài Supabase CLI, liên kết project rồi áp dụng các migration theo thứ tự:

   ```powershell
   supabase link --project-ref <project-ref>
   supabase db push
   supabase functions deploy household
   ```

3. Chạy app bằng `flutter run` để dùng project ViNeat mặc định. Chỉ truyền Dart
   defines nếu cần trỏ sang project Supabase khác:

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
tủ lạnh/đi chợ/sự kiện qua Supabase. Sau khi xác thực OTP, tài khoản có hồ sơ
mặc định được yêu cầu điền họ tên, vai trò và chế độ ăn; mã gia đình là tùy chọn.
Nhập mã để dùng chung dữ liệu với gia đình đã có, hoặc đặt tên gia đình mới nếu
không có mã. Gia đình cloud mới bắt đầu với kho trống; chỉ bật tính năng nhập
dữ liệu mẫu khi chủ động chạy với `--dart-define=VINEAT_ALLOW_DEMO_IMPORT=true`.
RLS giới hạn dữ liệu theo thành viên; ảnh gia đình nằm trong storage bucket private.
Project URL và publishable key trong app là thông tin public; chúng không thay thế
RLS hoặc quyền đăng nhập. Không có `service_role` hay Google client secret trong
repository. Cần kiểm thử đăng nhập và đồng bộ trên project hosted bằng hai tài
khoản thật; bộ test widget/local không chứng minh các luồng cloud hoạt động.

### Backend local cho Android Emulator (chỉ dùng khi chủ động thử offline)

Để demo cả đăng nhập và dữ liệu gia đình mà chưa cần project cloud, cần Docker
Desktop, Supabase CLI và Android Emulator:

```powershell
npx supabase start
npx supabase test db --local
```

Ở Android Studio, thêm hai Dart defines vào cấu hình chạy Debug. Lấy giá trị
`ANON_KEY` do `npx supabase start` in ra (hoặc `npx supabase status -o env`):

```text
SUPABASE_URL=http://10.0.2.2:54321
SUPABASE_PUBLISHABLE_KEY=<local-anon-key>
```

`10.0.2.2` là địa chỉ máy Windows từ Android Emulator. HTTP này chỉ được bật
trong Debug cho loopback/emulator; build Release từ chối URL không mã hóa. Email
OTP của Supabase local xem trong Mailpit tại `http://localhost:54324`. Local
Google OAuth chưa có client credentials nên cần project cloud để demo Google.
Không đưa `SECRET_KEY`, `service_role` hoặc Google client secret vào app; không
chia sẻ log `supabase status` vì trong đó có khóa local đặc quyền.

Supabase local dùng template tiếng Việt tại `supabase/templates/magic_link.html`
để gửi OTP 6 số khớp với màn hình đăng nhập. Hosted project cũng phải cấu hình
Magic Link template tương đương trong dashboard; nếu giữ template mặc định chỉ
gửi magic link thì màn hình nhập mã sẽ không thể đăng nhập.

`npx supabase db reset --local` sẽ xóa dữ liệu database local rồi áp lại toàn bộ
migration; chỉ dùng nếu có thể bỏ dữ liệu demo đang lưu. Không thêm `--linked`.

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
- Lần đầu mở từng trang có coachmark làm nổi bật thao tác thật; có thể đi tiếp,
  bỏ qua và mở lại tour 5 bước từ Hồ sơ → Trợ giúp. Tiến độ lưu cục bộ và đồng bộ
  khi tài khoản online.
- Danh mục món ăn/công thức hiện là catalog cục bộ; phần gợi ý kiểm tra nguyên liệu
  từ tủ lạnh, nút thêm nguyên liệu thiếu vào danh sách đi chợ; ảnh món được đóng gói
  dạng WebP riêng theo món để không phụ thuộc mạng.
- Khi project Supabase bật Realtime và đã áp dụng migration, thay đổi tủ lạnh, đi chợ
  và hoạt động gia đình được làm mới tự động trên các thiết bị đang mở cùng gia đình.
- OCR xử lý ảnh trên thiết bị. Các dòng đã xác nhận có thể nhập vào kho local hoặc
  household đã đăng nhập; chưa có job OCR nền hay quản trị lịch sử hóa đơn đầy đủ.
- Trang chủ có tủ lạnh GLB tương tác xoay/thu phóng, kèm ảnh dựng native làm poster
  và fallback nếu model không tải kịp; viewer chỉ chạy khi tab đang hiển thị. Model
  procedural có script tái tạo tại `tooling/build_fridge_model.py`. `model_viewer_plus`
  dùng WebView trên Android, vì vậy Android yêu cầu minSdk 24 và cấu hình mạng chỉ
  cho phép HTTP nội bộ đến localhost/127.0.0.1 của viewer; cần đo hiệu năng trên máy
  Android thật trước khi chốt trải nghiệm 3D cho thiết bị cấu hình thấp.
- File Proposal và backend riêng không có trong workspace hiện tại. Schema trong
  `supabase/migrations/` được dựng theo luồng hiện có của ứng dụng và cần đối chiếu
  Proposal/backend gốc trước khi coi là schema production.

## Kiểm chứng

Chạy `flutter analyze` và `flutter test`. Widget tests bao phủ onboarding, chuyển tab,
layout nhỏ, tablet, nhập món, mua hàng → tủ lạnh, công thức → đi chợ, dùng thực phẩm
→ báo cáo và chọn ảnh; unit tests bao phủ parser OCR hóa đơn tiếng Việt. Kiểm tra
đăng nhập OAuth, email thật, RLS/storage và đồng bộ giữa hai tài khoản cần project
Supabase cùng thiết bị/emulator có cấu hình provider.
