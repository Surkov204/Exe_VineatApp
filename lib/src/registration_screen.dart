import 'package:flutter/material.dart';

import 'app_services.dart';
import 'diet_preferences.dart';
import 'vineat_logo.dart';

const _green = Color(0xFF079669);
const _ink = Color(0xFF203044);
const _textHintLocales = [Locale('vi', 'VN'), Locale('en', 'US')];

enum _FamilyMode { join, create }

/// The auth trigger creates this placeholder for a new email account.
/// Existing users with a completed name skip the registration form.
bool profileNeedsRegistration(
  Map<String, dynamic>? profile, {
  bool hasHousehold = false,
}) {
  if (hasHousehold) return false;
  final name = (profile?['display_name'] as String? ?? '').trim();
  return name.isEmpty || name == 'Bạn';
}

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({
    super.key,
    required this.email,
    required this.onCompleted,
  });

  final String email;
  final VoidCallback onCompleted;

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _role = TextEditingController();
  final _familyCode = TextEditingController();
  final _familyName = TextEditingController();
  DietKind _diet = DietKind.normal;
  _FamilyMode? _familyMode;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _role.dispose();
    _familyCode.dispose();
    _familyName.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_familyMode == null) {
      setState(() => _error = 'Chọn đã có mã gia đình hoặc tạo gia đình mới.');
      return;
    }
    if (_name.text.trim().length < 2) {
      setState(() => _error = 'Nhập họ và tên ít nhất 2 ký tự.');
      return;
    }
    if (_familyMode == _FamilyMode.join && _familyCode.text.trim().isEmpty) {
      setState(() => _error = 'Nhập mã gia đình được người thân chia sẻ.');
      return;
    }
    if (_familyMode == _FamilyMode.create && _familyName.text.trim().isEmpty) {
      setState(() => _error = 'Nhập tên gia đình mới.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    final user = AppServices.client.auth.currentUser;
    if (user == null) {
      setState(
        () => _error = 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppServices.client
          .from('profiles')
          .update({
            'display_name': _name.text.trim(),
            'role_label': _role.text.trim().isEmpty
                ? 'Thành viên'
                : _role.text.trim(),
            'diet': _diet.id,
          })
          .eq('id', user.id)
          .select('id')
          .single();
      if (_familyMode == _FamilyMode.join) {
        await HouseholdService.instance.join(_familyCode.text.trim());
      } else {
        await HouseholdService.instance.create(_familyName.text.trim());
      }
      applyPreferredDiet(_diet);
      widget.onCompleted();
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().toLowerCase();
      setState(() {
        _error = message.contains('invalid household invite code')
            ? 'Mã gia đình không đúng hoặc đã hết hạn. Hãy xin mã mới từ người mời.'
            : message.contains('permission denied for table profiles')
            ? 'Máy chủ chưa cho phép cập nhật hồ sơ. Vui lòng liên hệ quản trị viên.'
            : 'Chưa lưu được hồ sơ hoặc gia đình. Vui lòng thử lại sau.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF7FBF9),
    appBar: AppBar(
      backgroundColor: const Color(0xFFF7FBF9),
      title: const Text('Hoàn tất đăng ký'),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => AppServices.signOut(),
          child: const Text('Đăng xuất'),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              const Center(child: VineatLogo(width: 92)),
              const SizedBox(height: 18),
              const Text(
                'Rất vui được đón bạn vào ViNeat',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Hoàn thiện hồ sơ rồi tạo gia đình mới hoặc nhập mã để dùng chung tủ lạnh với người thân.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF667085), height: 1.4),
              ),
              const SizedBox(height: 22),
              TextFormField(
                initialValue: widget.email,
                enabled: false,
                decoration: const InputDecoration(
                  labelText: 'Email đã xác thực',
                  prefixIcon: Icon(Icons.verified_user_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const ValueKey('registration-full-name'),
                controller: _name,
                autofocus: false,
                maxLength: 60,
                keyboardType: TextInputType.text,
                hintLocales: _textHintLocales,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Họ và tên *',
                  hintText: 'Tên mọi người trong gia đình sẽ thấy',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (value) => (value?.trim().length ?? 0) < 2
                    ? 'Nhập họ và tên ít nhất 2 ký tự.'
                    : null,
              ),
              const SizedBox(height: 4),
              TextFormField(
                key: const ValueKey('registration-role'),
                controller: _role,
                maxLength: 40,
                keyboardType: TextInputType.text,
                hintLocales: _textHintLocales,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Vai trò trong nhà (không bắt buộc)',
                  hintText: 'Ví dụ: Mẹ, Bố, Con',
                  prefixIcon: Icon(Icons.family_restroom_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 4),
              DietSelectorField(
                value: _diet,
                enabled: !_busy,
                onChanged: (value) => setState(() => _diet = value),
              ),
              const SizedBox(height: 22),
              const Divider(),
              const SizedBox(height: 12),
              const Text(
                'Gia đình của bạn',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Chọn một cách tham gia. Mỗi người có chế độ ăn riêng; gia đình dùng chung thực đơn và tủ lạnh.',
                style: TextStyle(color: Color(0xFF667085), height: 1.4),
              ),
              const SizedBox(height: 10),
              CheckboxListTile(
                key: const ValueKey('registration-join-family'),
                value: _familyMode == _FamilyMode.join,
                onChanged: _busy
                    ? null
                    : (checked) => setState(() {
                        _familyMode = checked == true ? _FamilyMode.join : null;
                        _error = null;
                      }),
                title: const Text('Đã có mã gia đình'),
                subtitle: const Text('Nhập mã mời để tham gia cùng người thân'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              if (_familyMode == _FamilyMode.join) ...[
                const SizedBox(height: 8),
                TextFormField(
                  key: const ValueKey('registration-family-code'),
                  controller: _familyCode,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Mã gia đình *',
                    prefixIcon: Icon(Icons.group_add_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => (value?.trim().isEmpty ?? true)
                      ? 'Nhập mã gia đình được người thân chia sẻ.'
                      : null,
                ),
              ],
              CheckboxListTile(
                key: const ValueKey('registration-create-family'),
                value: _familyMode == _FamilyMode.create,
                onChanged: _busy
                    ? null
                    : (checked) => setState(() {
                        _familyMode = checked == true
                            ? _FamilyMode.create
                            : null;
                        _error = null;
                      }),
                title: const Text('Chưa có gia đình'),
                subtitle: const Text(
                  'Tạo gia đình mới và nhận mã để mời người khác',
                ),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              if (_familyMode == _FamilyMode.create) ...[
                const SizedBox(height: 8),
                TextFormField(
                  key: const ValueKey('registration-family-name'),
                  controller: _familyName,
                  maxLength: 60,
                  keyboardType: TextInputType.text,
                  hintLocales: _textHintLocales,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Tên gia đình mới *',
                    hintText: 'Gia đình của tôi',
                    prefixIcon: Icon(Icons.home_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => (value?.trim().isEmpty ?? true)
                      ? 'Nhập tên gia đình mới.'
                      : null,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _busy ? null : _submit,
                  style: FilledButton.styleFrom(backgroundColor: _green),
                  child: _busy
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(switch (_familyMode) {
                          _FamilyMode.join => 'Hoàn tất và tham gia gia đình',
                          _FamilyMode.create => 'Hoàn tất và tạo gia đình',
                          null => 'Chọn cách tham gia gia đình',
                        }),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
