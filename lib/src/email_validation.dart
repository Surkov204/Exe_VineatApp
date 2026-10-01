/// Returns a clear Vietnamese message when an address cannot receive an OTP.
/// Unicode letters and combining marks are accepted in both parts; the mail
/// provider remains the final authority for internationalized addresses.
String? validateLoginEmail(String input, {bool cloudAuth = true}) {
  final email = input.trim();
  if (email.isEmpty) return 'Vui lòng nhập địa chỉ email của bạn.';
  if (email.length > 254 || email.contains(RegExp(r'\s'))) {
    return 'Email không được chứa khoảng trắng và phải ngắn hơn 255 ký tự.';
  }
  final parts = email.split('@');
  if (parts.length != 2 || parts[0].isEmpty || parts[1].isEmpty) {
    return 'Email cần đúng dạng ten@mien.com.';
  }
  final local = parts[0];
  final domain = parts[1];
  final localPattern = RegExp(
    r"^[\p{L}\p{M}\p{N}!#$%&'*+/=?^_`{|}~.-]+$",
    unicode: true,
  );
  final domainLabel = RegExp(r'^[\p{L}\p{M}\p{N}-]+$', unicode: true);
  final labels = domain.split('.');
  final validLocal =
      local.length <= 64 &&
      !local.startsWith('.') &&
      !local.endsWith('.') &&
      !local.contains('..') &&
      localPattern.hasMatch(local);
  final validDomain =
      labels.length >= 2 &&
      labels.every(
        (label) =>
            label.isNotEmpty &&
            label.length <= 63 &&
            !label.startsWith('-') &&
            !label.endsWith('-') &&
            domainLabel.hasMatch(label),
      ) &&
      labels.last.length >= 2;
  if (!validLocal || !validDomain) {
    return 'Email chưa đúng định dạng. Ví dụ: ten@mien.com.';
  }
  if (cloudAuth && email.toLowerCase() == 'demo@vineat.test') {
    return 'Email demo@vineat.test không có hộp thư để nhận mã. Hãy dùng email thật của bạn.';
  }
  return null;
}
