import 'package:supabase_flutter/supabase_flutter.dart';

/// Never show a raw server error to people signing in. Supabase's codes are
/// more reliable than the English message, especially for email quotas.
String vietnameseAuthError(AuthException error, {required String action}) {
  final code = error.code?.toLowerCase();
  final message = error.message.toLowerCase();

  if (code == 'email_address_not_authorized' ||
      message.contains('email address not authorized')) {
    return 'Email này chưa được phép nhận mã từ Supabase. Chủ dự án cần cấu hình dịch vụ gửi email hoặc thêm địa chỉ này vào nhóm được phép.';
  }
  if (code == 'email_address_invalid' ||
      message.contains('invalid email') ||
      message.contains('email address is invalid')) {
    return 'Địa chỉ email này chưa được Supabase chấp nhận. Hãy kiểm tra lại hoặc dùng email khác.';
  }
  if (code == 'over_email_send_rate_limit') {
    return 'Supabase đang giới hạn gửi mã tới email này. Đây là giới hạn gửi thư, không phải do bạn bấm quá nhanh. Vui lòng thử lại sau.';
  }
  if (code == 'over_request_rate_limit') {
    return 'Supabase đang giới hạn yêu cầu từ kết nối này. Vui lòng đợi vài phút rồi thử lại.';
  }
  if (error.statusCode == '429' ||
      message.contains('rate limit') ||
      message.contains('too many')) {
    return action == 'send'
        ? 'Supabase đang tạm giới hạn gửi mã đăng nhập. Vui lòng thử lại sau; nếu lỗi kéo dài, chủ dự án cần kiểm tra hạn mức email và cấu hình SMTP.'
        : 'Supabase đang tạm giới hạn yêu cầu đăng nhập. Vui lòng đợi vài phút rồi thử lại.';
  }
  if (code == 'otp_expired' ||
      message.contains('expired') ||
      message.contains('invalid otp') ||
      message.contains('token')) {
    return 'Mã xác thực không đúng hoặc đã hết hạn. Hãy kiểm tra email và thử lại.';
  }
  if (code == 'email_provider_disabled' || code == 'otp_disabled') {
    return 'Đăng nhập bằng mã email chưa được bật trên Supabase. Chủ dự án cần kiểm tra cấu hình Auth.';
  }
  if (code == 'provider_disabled' ||
      code == 'oauth_provider_not_supported' ||
      message.contains('provider disabled')) {
    return action == 'google'
        ? 'Đăng nhập Google chưa được bật trên Supabase. Vui lòng dùng email sau khi dịch vụ gửi mã được cấu hình.'
        : 'Đăng nhập bằng email hiện chưa khả dụng. Vui lòng thử lại sau.';
  }
  if (action == 'google') {
    return 'Chưa đăng nhập được bằng Google. Vui lòng thử lại.';
  }
  if (action == 'verify') {
    return 'Chưa xác thực được mã. Hãy kiểm tra mã rồi thử lại.';
  }
  return 'Chưa gửi được mã xác thực. Kiểm tra email và thử lại sau.';
}
