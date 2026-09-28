import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'app_services.dart';
import 'household_data_repository.dart';
import 'inventory_store.dart';

const _green = Color(0xFF079669);
const _ink = Color(0xFF203044);

class AppEntry extends StatelessWidget {
  const AppEntry({super.key});

  @override
  Widget build(BuildContext context) {
    if (AppServices.initializationError case final error?) {
      return _StartupError(message: error);
    }
    if (!AppServices.configured) return const AppShell();
    return StreamBuilder<AuthState>(
      stream: AppServices.client.auth.onAuthStateChange,
      initialData: AuthState(
        AuthChangeEvent.initialSession,
        AppServices.client.auth.currentSession,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            snapshot.data == null) {
          return const _AuthSplash();
        }
        if (AppServices.client.auth.currentSession == null) {
          return const LoginScreen();
        }
        return const HouseholdGate();
      },
    );
  }
}

class _AuthSplash extends StatelessWidget {
  const _AuthSplash();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _StartupError extends StatelessWidget {
  const _StartupError({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, color: _green, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Chưa kết nối được ViNeat',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Kiểm tra cấu hình Supabase rồi mở lại ứng dụng.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    ),
  );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _otp = TextEditingController();
  bool _sent = false;
  bool _busy = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _email.dispose();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _email.text.trim();
    if (!email.contains('@') || email.endsWith('@')) {
      setState(() => _error = 'Vui lòng nhập địa chỉ email hợp lệ.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await AppServices.client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: true,
      );
      if (!mounted) return;
      setState(() {
        _sent = true;
        _notice = 'Mã xác thực đã được gửi đến $email.';
      });
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = _humanize(error.message));
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Không gửi được mã. Thử lại sau nhé.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyCode() async {
    final code = _otp.text.trim();
    if (code.length < 6) {
      setState(() => _error = 'Nhập mã gồm 6 chữ số trong email.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppServices.client.auth.verifyOTP(
        email: _email.text.trim(),
        token: code,
        type: OtpType.email,
      );
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = _humanize(error.message));
    } catch (_) {
      if (mounted) setState(() => _error = 'Mã không hợp lệ hoặc đã hết hạn.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _google() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppServices.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: appOAuthRedirect,
      );
    } on AuthException catch (error) {
      if (mounted) setState(() => _error = _humanize(error.message));
    } catch (_) {
      if (mounted) setState(() => _error = 'Chưa mở được đăng nhập Google.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _humanize(String value) {
    if (value.toLowerCase().contains('rate limit')) {
      return 'Bạn thao tác hơi nhanh. Vui lòng đợi một chút rồi thử lại.';
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF7FBF9),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
              children: [
                const SizedBox(height: 16),
                Container(
                  height: 230,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE8FBF4), Color(0xFFD4F5E8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        right: 24,
                        top: 24,
                        child: Icon(
                          Icons.eco_outlined,
                          size: 74,
                          color: _green.withValues(alpha: .1),
                        ),
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 74,
                            height: 74,
                            decoration: BoxDecoration(
                              color: _green,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: _green.withValues(alpha: .22),
                                  blurRadius: 24,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.eco,
                              color: Colors.white,
                              size: 38,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'ViNeat',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              color: _ink,
                            ),
                          ),
                          const Text(
                            'Bếp gọn hơn, bữa ăn vui hơn',
                            style: TextStyle(color: Color(0xFF667085)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Chào mừng bạn về nhà',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Đăng nhập để cùng gia đình quản lý thực phẩm, lên món và giảm lãng phí.',
                  style: TextStyle(height: 1.45, color: Color(0xFF667085)),
                ),
                const SizedBox(height: 22),
                if (!_sent) ...[
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Email của bạn',
                      prefixIcon: Icon(Icons.mail_outline),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendCode(),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: _busy ? null : _sendCode,
                      child: _busy
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Tiếp tục bằng email'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _google,
                    icon: const Icon(Icons.g_mobiledata, size: 27),
                    label: const Text('Tiếp tục với Google'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                  ),
                ] else ...[
                  TextField(
                    controller: _otp,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    maxLength: 8,
                    decoration: const InputDecoration(
                      labelText: 'Mã xác thực trong email',
                      prefixIcon: Icon(Icons.password),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _verifyCode(),
                  ),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: _busy ? null : _verifyCode,
                      child: _busy
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Xác nhận và đăng nhập'),
                    ),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                            _sent = false;
                            _otp.clear();
                            _notice = null;
                          }),
                    child: const Text('Đổi email'),
                  ),
                ],
                AnimatedSwitcher(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 220),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position:
                          Tween(
                            begin: const Offset(0, .08),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                      child: child,
                    ),
                  ),
                  child: _error != null
                      ? _MessageBanner(
                          key: const ValueKey('error'),
                          text: _error!,
                          error: true,
                        )
                      : _notice != null
                      ? _MessageBanner(
                          key: const ValueKey('notice'),
                          text: _notice!,
                        )
                      : const SizedBox.shrink(key: ValueKey('empty')),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Mã xác thực có thời hạn. ViNeat không bao giờ yêu cầu bạn gửi mật khẩu qua tin nhắn.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: Color(0xFF98A2B3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({super.key, required this.text, this.error = false});
  final String text;
  final bool error;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: error ? const Color(0xFFFFF1F0) : const Color(0xFFE8FBF4),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      text,
      style: TextStyle(color: error ? Colors.red.shade800 : _green),
    ),
  );
}

class HouseholdGate extends StatefulWidget {
  const HouseholdGate({super.key});
  @override
  State<HouseholdGate> createState() => _HouseholdGateState();
}

class _HouseholdGateState extends State<HouseholdGate> {
  late Future<List<Household>> _households;

  @override
  void initState() {
    super.initState();
    _households = _prepareHouseholdData();
  }

  Future<List<Household>> _prepareHouseholdData() async {
    final households = await HouseholdService.instance.restoreActive();
    if (households.isEmpty) {
      replaceInventoryFromRemote(records: const [], events: const []);
      replaceShoppingFromRemote(items: const [], checked: const {});
      return households;
    }
    try {
      final snapshot = await HouseholdDataRepository.instance
          .loadActiveHousehold();
      replaceInventoryFromRemote(
        records: snapshot.inventory,
        events: snapshot.events,
      );
      replaceShoppingFromRemote(
        items: snapshot.shopping.map((item) => item.item).toList(),
        checked: snapshot.shopping
            .asMap()
            .entries
            .where((entry) => entry.value.checked)
            .map((entry) => entry.key)
            .toSet(),
      );
    } catch (_) {
      replaceInventoryFromRemote(records: const [], events: const []);
      replaceShoppingFromRemote(items: const [], checked: const {});
      HouseholdDataRepository.instance.syncStatus.value =
          'Chưa tải được dữ liệu gia đình. Kiểm tra kết nối và mở lại tab Hồ sơ để thử lại.';
    }
    return households;
  }

  void _refresh() => setState(() {
    _households = _prepareHouseholdData();
  });

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Household>>(
    future: _households,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _HouseholdSetup(onChanged: _refresh, initialError: true);
      }
      if (!snapshot.hasData) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (snapshot.data!.isEmpty) return _HouseholdSetup(onChanged: _refresh);
      return const AppShell();
    },
  );
}

class _HouseholdSetup extends StatefulWidget {
  const _HouseholdSetup({required this.onChanged, this.initialError = false});
  final VoidCallback onChanged;
  final bool initialError;
  @override
  State<_HouseholdSetup> createState() => _HouseholdSetupState();
}

class _HouseholdSetupState extends State<_HouseholdSetup> {
  final _name = TextEditingController(text: 'Gia đình của tôi');
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(Future<Household> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      widget.onChanged();
    } catch (error) {
      if (mounted) setState(() => _error = _friendlyFamilyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    try {
      await AppServices.client.auth.signOut();
    } catch (_) {
      if (mounted) setState(() => _error = 'Chưa đăng xuất được. Thử lại nhé.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF7FBF9),
    appBar: AppBar(
      title: const Text('Thiết lập gia đình'),
      actions: [
        TextButton(onPressed: _signOut, child: const Text('Đăng xuất')),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 22),
            const Icon(Icons.diversity_3_outlined, size: 64, color: _green),
            const SizedBox(height: 18),
            const Text(
              'Tủ lạnh chung của cả nhà',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w900,
                color: _ink,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tạo một gia đình mới hoặc nhập mã mời. Chỉ thành viên được mời mới xem được dữ liệu.',
              textAlign: TextAlign.center,
              style: TextStyle(height: 1.45, color: Color(0xFF667085)),
            ),
            const SizedBox(height: 22),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Tạo gia đình',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _name,
                      maxLength: 60,
                      decoration: const InputDecoration(
                        labelText: 'Tên gia đình',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _run(
                              () =>
                                  HouseholdService.instance.create(_name.text),
                            ),
                      icon: const Icon(Icons.add_home_outlined),
                      label: const Text('Tạo và tiếp tục'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Tham gia bằng mã',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _code,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Mã gia đình',
                        hintText: 'Ví dụ: A1B2C3D4E5F6A7B8',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _run(
                              () => HouseholdService.instance.join(_code.text),
                            ),
                      icon: const Icon(Icons.group_add_outlined),
                      label: const Text('Tham gia gia đình'),
                    ),
                  ],
                ),
              ),
            ),
            if (_busy) const LinearProgressIndicator(minHeight: 2),
            if (widget.initialError && _error == null)
              const _MessageBanner(
                text:
                    'Chưa tải được danh sách gia đình. Kiểm tra kết nối rồi thử lại.',
                error: true,
              ),
            if (_error != null) _MessageBanner(text: _error!, error: true),
            TextButton(
              onPressed: _busy ? null : widget.onChanged,
              child: const Text('Thử tải lại'),
            ),
          ],
        ),
      ),
    ),
  );
}

String _friendlyFamilyError(Object error) {
  final value = error.toString();
  if (value.toLowerCase().contains('invalid household invite code')) {
    return 'Mã gia đình không đúng hoặc đã được đổi. Hãy kiểm tra lại với người mời.';
  }
  if (value.toLowerCase().contains('jwt') ||
      value.toLowerCase().contains('unauthorized')) {
    return 'Phiên đăng nhập hết hạn. Hãy đăng nhập lại.';
  }
  return 'Chưa cập nhật được gia đình. Kiểm tra mạng rồi thử lại.';
}
