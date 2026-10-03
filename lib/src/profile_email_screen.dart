import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_services.dart';
import 'auth_error_messages.dart';
import 'email_validation.dart';

/// Reauthenticate the original owner before requesting any email mutation.
/// Supabase alone verifies tokens and commits the new address.
class ProfileEmailScreen extends StatefulWidget {
  const ProfileEmailScreen({super.key});
  @override
  State<ProfileEmailScreen> createState() => _ProfileEmailScreenState();
}

class _ProfileEmailScreenState extends State<ProfileEmailScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _form = GlobalKey<FormState>();
  late final _user = AppServices.client.auth.currentUser!;
  int _step = 0;
  bool _busy = false;
  String? _error;
  String _target = '';
  bool _oldChangeConfirmed = false;
  bool _ownerVerified = false;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy ||
        (!_ownerVerified && !_form.currentState!.validate()) ||
        (_step == 2 && !_form.currentState!.validate())) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = AppServices.client.auth;
    try {
      if (_step == 0) {
        _target = _email.text.trim();
        await auth.signInWithOtp(email: _user.email!, shouldCreateUser: false);
        if (mounted) setState(() => _step = 1);
      } else if (_step == 1) {
        if (!_ownerVerified) {
          final response = await auth.verifyOTP(
            email: _user.email!,
            token: _code.text.trim(),
            type: OtpType.email,
          );
          if (response.user?.id != _user.id ||
              response.user?.email?.toLowerCase() !=
                  _user.email!.toLowerCase()) {
            throw StateError('Không xác minh được chủ tài khoản.');
          }
          _ownerVerified = true;
        }
        if ((await auth.getUser()).user?.id != _user.id) {
          throw StateError('Phiên đăng nhập đã thay đổi.');
        }
        await auth.updateUser(
          UserAttributes(email: _target),
          emailRedirectTo: appOAuthRedirect,
        );
        _code.clear();
        if (mounted) setState(() => _step = 2);
      } else {
        await auth.verifyOTP(
          email: _oldChangeConfirmed ? _target : _user.email!,
          token: _code.text.trim(),
          type: OtpType.emailChange,
        );
        final current = (await auth.getUser()).user;
        if (current?.id != _user.id) {
          throw StateError('Tài khoản đã thay đổi. Vui lòng đăng nhập lại.');
        }
        if (current?.email?.toLowerCase() == _target.toLowerCase()) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã đổi email đăng nhập')),
          );
          Navigator.pop(context);
        } else {
          _code.clear();
          if (mounted) setState(() => _oldChangeConfirmed = true);
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(
          () => _error = vietnameseAuthError(
            e,
            action: _step == 0 ? 'send' : 'verify',
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Chưa hoàn tất. Kiểm tra kết nối và thử lại. Email chỉ đổi khi máy chủ xác nhận.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Đổi email')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Icon(
          Icons.mark_email_read_outlined,
          size: 56,
          color: Color(0xFF079669),
        ),
        const SizedBox(height: 16),
        Text(
          _step == 0
              ? 'Bảo vệ tài khoản của bạn'
              : _step == 1
              ? 'Xác nhận email cũ'
              : 'Xác nhận thay đổi',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Text(
          _step == 0
              ? 'Gửi mã đến ${_user.email} trước khi yêu cầu đổi email.'
              : _step == 1
              ? 'Nhập mã đăng nhập vừa gửi đến ${_user.email}. Sau đó hệ thống gửi xác nhận đổi email.'
              : 'Xác nhận đổi email tại cả hai hộp thư. Nhập mã đổi email gửi tới ${_oldChangeConfirmed ? _target : _user.email}. Nếu đã xác nhận bằng liên kết, bấm Kiểm tra trạng thái.',
          style: const TextStyle(fontSize: 16, height: 1.5),
        ),
        const SizedBox(height: 24),
        if (_step == 2)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Nhập mã từ email mới'),
            subtitle: const Text(
              'Chọn nếu email cũ đã được xác nhận bằng liên kết.',
            ),
            value: _oldChangeConfirmed,
            onChanged: _busy
                ? null
                : (v) => setState(() {
                    _oldChangeConfirmed = v ?? false;
                    _code.clear();
                  }),
          ),
        Form(
          key: _form,
          child: _step == 0
              ? TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email mới',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      validateLoginEmail(v ?? '') ??
                      ((v ?? '').trim().toLowerCase() ==
                              _user.email!.toLowerCase()
                          ? 'Email mới phải khác email hiện tại.'
                          : null),
                )
              : TextFormField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Mã xác nhận trong email',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      RegExp(r'^\d{6,10}$').hasMatch((v ?? '').trim())
                      ? null
                      : 'Nhập đúng mã số trong email.',
                ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(
            _busy
                ? 'Đang xử lý…'
                : _step == 0
                ? 'Gửi mã tới email cũ'
                : 'Xác nhận mã',
          ),
        ),
        if (_step == 2)
          TextButton(
            onPressed: _busy
                ? null
                : () async {
                    try {
                      final current =
                          (await AppServices.client.auth.getUser()).user;
                      if (!mounted || !context.mounted) return;
                      if (current?.id == _user.id &&
                          current?.email?.toLowerCase() ==
                              _target.toLowerCase()) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Đã đổi email đăng nhập'),
                          ),
                        );
                        Navigator.pop(context);
                      } else {
                        setState(
                          () => _error =
                              'Chưa xác nhận đủ. Hãy kiểm tra cả email cũ và mới.',
                        );
                      }
                    } catch (_) {
                      if (mounted) {
                        setState(
                          () =>
                              _error = 'Chưa kiểm tra được. Vui lòng thử lại.',
                        );
                      }
                    }
                  },
            child: const Text('Kiểm tra trạng thái'),
          ),
        if (_step == 1 && !_ownerVerified)
          TextButton(
            onPressed: _busy
                ? null
                : () => setState(() {
                    _step = 0;
                    _code.clear();
                    _error = null;
                  }),
            child: const Text('Nhập lại email / yêu cầu mã mới'),
          ),
      ],
    ),
  );
}
