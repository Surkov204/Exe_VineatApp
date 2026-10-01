import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_tutorial.dart';
import 'app_services.dart';
import 'diet_preferences.dart';
import 'family_settings.dart';
import 'global_search.dart';
import 'expiry_assistant.dart';
import 'profile_email_screen.dart';
import 'fridge_cleanup_screen.dart';

const _green = Color(0xFF079669);
const _ink = Color(0xFF253043);
const _muted = Color(0xFF667085);

class _ProfileEditResult {
  const _ProfileEditResult({required this.name, required this.role});

  final String name;
  final String role;
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String name = AppServices.configured ? 'Bạn' : 'Mẹ';
  String role = AppServices.configured ? 'Thành viên' : 'Chủ tủ';
  DietKind diet = DietKind.normal;
  bool _savingDiet = false;
  bool _signOutBusy = false;
  ExpiryPreferences expiryPrefs = const ExpiryPreferences();
  bool _savingExpiry = false;

  @override
  void initState() {
    super.initState();
    ExpiryPreferences.load()
        .then((value) {
          if (mounted) setState(() => expiryPrefs = value);
        })
        .catchError((_) {});
    if (AppServices.configured) {
      unawaited(_loadCloudProfile());
    } else {
      unawaited(
        SharedPreferences.getInstance()
            .then((prefs) {
              if (mounted) {
                setState(
                  () => name =
                      prefs.getString('vineat.local.profile_name') ?? name,
                );
              }
            })
            .catchError((_) {}),
      );
    }
  }

  Future<void> _loadCloudProfile() async {
    final userId = AppServices.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final profile = await AppServices.client
          .from('profiles')
          .select('display_name,role_label,diet')
          .eq('id', userId)
          .maybeSingle();
      if (profile == null || !mounted) return;
      setState(() {
        name = profile['display_name'] as String? ?? name;
        role = profile['role_label'] as String? ?? role;
        diet = DietKind.fromId(profile['diet'] as String?);
      });
      applyPreferredDiet(diet);
    } catch (_) {
      if (mounted) {
        _message('Chưa tải được hồ sơ. Kiểm tra kết nối rồi thử lại.');
      }
    }
  }

  Future<void> _setExpiry(bool enabled, bool automatic) async {
    if (_savingExpiry) return;
    setState(() => _savingExpiry = true);
    final next = ExpiryPreferences(enabled: enabled, automatic: automatic);
    try {
      await next.save();
      if (mounted) setState(() => expiryPrefs = next);
    } catch (_) {
      if (mounted) {
        _message('Chưa lưu được cài đặt hạn dùng. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _savingExpiry = false);
    }
  }

  Future<void> _setDiet(DietKind choice) async {
    if (_savingDiet || diet == choice) return;
    final previous = diet;
    setState(() => diet = choice);
    if (!AppServices.configured) {
      applyPreferredDiet(choice);
      return;
    }
    final userId = AppServices.client.auth.currentUser?.id;
    if (userId == null) {
      setState(() => diet = previous);
      return;
    }
    setState(() => _savingDiet = true);
    try {
      await AppServices.client
          .from('profiles')
          .update({'diet': choice.id})
          .eq('id', userId);
      applyPreferredDiet(choice);
    } catch (_) {
      if (!mounted) return;
      setState(() => diet = previous);
      _message('Chưa lưu được chế độ ăn. Thử lại nhé.');
    } finally {
      if (mounted) setState(() => _savingDiet = false);
    }
  }

  Future<void> _editProfile() async {
    final result = await showDialog<_ProfileEditResult>(
      context: context,
      builder: (_) => _ProfileEditDialog(name: name, role: role),
    );
    if (mounted) setState(() {});
    if (result != null && result.name.isNotEmpty && mounted) {
      if (AppServices.configured) {
        final userId = AppServices.client.auth.currentUser?.id;
        if (userId == null) return;
        try {
          await AppServices.client
              .from('profiles')
              .update({
                'display_name': result.name,
                'role_label': result.role.isEmpty ? role : result.role,
              })
              .eq('id', userId);
        } catch (_) {
          if (mounted) _message('Chưa lưu được hồ sơ. Thử lại nhé.');
          return;
        }
      } else {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('vineat.local.profile_name', result.name);
        } catch (_) {
          if (mounted) _message('Chưa lưu được tên. Vui lòng thử lại.');
          return;
        }
      }
      if (!mounted) return;
      setState(() {
        name = result.name;
        role = result.role.isEmpty ? role : result.role;
      });
      AppServices.inventoryActorName = result.name;
      _message('Đã cập nhật tên hiển thị');
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(text, textAlign: TextAlign.center)));
  }

  Future<void> _signOut() async {
    if (_signOutBusy) return;
    setState(() => _signOutBusy = true);
    try {
      if (debugOtpDemoEnabled) {
        await AppServices.signOutDebugDemo();
      } else {
        await AppServices.signOut();
      }
      applyPreferredDiet(DietKind.normal);
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (_) {
      if (mounted) _message('Chưa đăng xuất được. Vui lòng thử lại.');
    } finally {
      if (mounted) setState(() => _signOutBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFFAFAFB),
    appBar: AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      leading: IconButton(
        tooltip: 'Quay lại',
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(Icons.arrow_back),
      ),
      titleSpacing: 0,
      title: const Text('Cài đặt'),
      actions: [
        IconButton.filledTonal(
          onPressed: () => showGlobalSearch(context),
          icon: const Icon(Icons.search),
          style: IconButton.styleFrom(backgroundColor: const Color(0xFFF3F4F6)),
        ),
        const SizedBox(width: 10),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Panel(
          title: 'Hồ sơ cá nhân',
          child: Row(
            children: [
              const CircleAvatar(
                radius: 34,
                backgroundColor: Color(0xFFCBF7E2),
                foregroundColor: _green,
                child: Icon(Icons.person_outline, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: _ink,
                      ),
                    ),
                    Text(
                      AppServices.configured
                          ? (AppServices.client.auth.currentUser?.email ?? role)
                          : role,
                      style: const TextStyle(fontSize: 14, color: _muted),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: _editProfile,
                      child: const Text(
                        'Chỉnh sửa hồ sơ',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: _green,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (debugOtpDemoEnabled || AppServices.configured) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _signOutBusy ? null : _signOut,
            icon: _signOutBusy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout),
            label: Text(_signOutBusy ? 'Đang đăng xuất…' : 'Đăng xuất'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: Colors.redAccent,
            ),
          ),
        ],
        const SizedBox(height: 14),
        _Panel(
          title: 'Chế độ ăn uống',
          child: DietSelectorField(
            value: diet,
            enabled: !_savingDiet,
            onChanged: _setDiet,
          ),
        ),
        const SizedBox(height: 14),
        _Panel(
          title: 'Hạn dùng thông minh',
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Gợi ý hạn dùng'),
                subtitle: const Text('Tham khảo FoodSafety.gov, bảo quản ≤4°C'),
                value: expiryPrefs.enabled,
                onChanged: _savingExpiry
                    ? null
                    : (v) => _setExpiry(v, expiryPrefs.automatic),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Tự điền ngày gợi ý'),
                subtitle: const Text(
                  'Chỉ khi biết loại/trạng thái món và chưa chọn ngày. Luôn kiểm tra bao bì.',
                ),
                value: expiryPrefs.automatic,
                onChanged: _savingExpiry || !expiryPrefs.enabled
                    ? null
                    : (v) => _setExpiry(true, v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Panel(
          title: 'Dọn tủ lạnh',
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFE1F7ED),
              child: Icon(Icons.kitchen_outlined, color: _green),
            ),
            title: const Text('Ưu tiên thực phẩm sắp hết hạn'),
            subtitle: const Text('Xem hạn dùng và món có thể nấu'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const FridgeCleanupScreen(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _Panel(title: 'Gia đình', child: const FamilySettings()),
        const SizedBox(height: 14),
        _Panel(
          title: 'Trợ giúp',
          child: _LinkRow(
            'Xem hướng dẫn từng trang',
            () => showAppTutorial(
              context,
              onStepChanged: (index) => tutorialPageRequest.value = index,
            ),
          ),
        ),
        const SizedBox(height: 14),
        _Panel(
          title: 'Về ViNeat',
          child: Column(children: [const _AboutRow('Phiên bản', '1.0.0')]),
        ),
        const SizedBox(height: 30),
      ],
    ),
  );
}

class _ProfileEditDialog extends StatefulWidget {
  const _ProfileEditDialog({required this.name, required this.role});
  final String name, role;
  @override
  State<_ProfileEditDialog> createState() => _ProfileEditDialogState();
}

class _ProfileEditDialogState extends State<_ProfileEditDialog> {
  late final _name = TextEditingController(text: widget.name);
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Chỉnh sửa hồ sơ'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _name,
              maxLength: 60,
              validator: (v) => (v ?? '').trim().isEmpty
                  ? 'Vui lòng nhập tên hiển thị.'
                  : null,
              decoration: const InputDecoration(
                labelText: 'Tên hiển thị',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Email đăng nhập', style: TextStyle(color: _muted)),
            const SizedBox(height: 6),
            Text(
              AppServices.configured
                  ? (AppServices.client.auth.currentUser?.email ??
                        'Chưa đăng nhập')
                  : 'Chế độ trên thiết bị',
            ),
            if (AppServices.configured &&
                AppServices.client.auth.currentUser?.email != null)
              TextButton.icon(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ProfileEmailScreen(),
                    ),
                  );
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.verified_user_outlined),
                label: const Text('Đổi email có xác nhận'),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(
              context,
              _ProfileEditResult(name: _name.text.trim(), role: widget.role),
            );
          }
        },
        child: const Text('Lưu'),
      ),
    ],
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    color: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: Color(0xFFEEF0F3)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: _ink,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    ),
  );
}

class _AboutRow extends StatelessWidget {
  const _AboutRow(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: Color(0xFF667085))),
        ),
        Text(value, style: const TextStyle(color: _muted)),
      ],
    ),
  );
}

class _LinkRow extends StatelessWidget {
  const _LinkRow(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Color(0xFF667085)),
            ),
          ),
          const Icon(Icons.chevron_right, color: _muted, size: 18),
        ],
      ),
    ),
  );
}
