import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'app_services.dart';
import 'household_data_repository.dart';
import 'fridge_showcase.dart';
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
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF7FBF9),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SmartFridgeShowcase(
                  inventoryCount: 3,
                  expiringCount: 1,
                  height: 190,
                  preview: true,
                  active: false,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Đang chuẩn bị căn bếp của bạn',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'ViNeat đang khôi phục phiên đăng nhập an toàn.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF667085)),
                ),
                const SizedBox(height: 22),
                const SizedBox(
                  width: 150,
                  child: LinearProgressIndicator(minHeight: 4, color: _green),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
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
                const SmartFridgeShowcase(
                  inventoryCount: 3,
                  expiringCount: 1,
                  height: 210,
                  preview: true,
                  // Show the interactive model on sign-in while keeping the
                  // form immediately available below it.
                  active: true,
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
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 6,
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
  List<FoodSummary>? _pendingDemoImport;
  String? _demoHouseholdId;
  String? _demoImportError;
  bool _demoImportBusy = false;

  @override
  void initState() {
    super.initState();
    _households = _prepareHouseholdData();
  }

  Future<List<Household>> _prepareHouseholdData() async {
    await restoreLocalDemoData();
    final localDemo = await localDemoPreviewSnapshot();
    final households = await HouseholdService.instance.restoreActive();
    if (households.isEmpty) {
      _pendingDemoImport = null;
      replaceInventoryFromRemote(records: const [], events: const []);
      replaceShoppingFromRemote(items: const [], checked: const {});
      return households;
    }
    try {
      final snapshot = await HouseholdDataRepository.instance
          .loadActiveHousehold();
      final householdId = HouseholdService.instance.active.value?.id;
      if (snapshot.inventory.isEmpty &&
          householdId != null &&
          localDemo.isNotEmpty &&
          !await HouseholdDataRepository.instance.hasImportedDemoInventory(
            householdId,
          )) {
        _pendingDemoImport = localDemo;
        _demoHouseholdId = householdId;
        return households;
      }
      _pendingDemoImport = null;
      _demoHouseholdId = null;
      replaceInventoryFromRemote(
        records: snapshot.inventory,
        events: snapshot.events,
      );
      replaceShoppingFromRemote(
        items: snapshot.shopping.map((item) => item.item).toList(),
        checked: snapshot.shopping
            .where((entry) => entry.checked)
            .map((entry) => entry.item.id)
            .toSet(),
      );
    } catch (_) {
      _pendingDemoImport = null;
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

  Future<void> _finishDemoImport({required bool import}) async {
    final householdId = _demoHouseholdId;
    final localDemo = _pendingDemoImport;
    if (_demoImportBusy || householdId == null || localDemo == null) return;
    setState(() {
      _demoImportBusy = true;
      _demoImportError = null;
    });
    try {
      final records = import
          ? localDemo.map(InventoryItemRecord.fromSummary).toList()
          : const <InventoryItemRecord>[];
      await HouseholdDataRepository.instance.importDemoInventory(
        householdId: householdId,
        items: records,
      );
      if (HouseholdService.instance.active.value?.id != householdId) {
        throw StateError('The active household changed during import.');
      }
      final snapshot = await HouseholdDataRepository.instance
          .loadActiveHousehold();
      replaceInventoryFromRemote(
        records: snapshot.inventory,
        events: snapshot.events,
      );
      replaceShoppingFromRemote(
        items: snapshot.shopping.map((item) => item.item).toList(),
        checked: snapshot.shopping
            .where((entry) => entry.checked)
            .map((entry) => entry.item.id)
            .toSet(),
      );
      if (mounted) {
        setState(() {
          _pendingDemoImport = null;
          _demoHouseholdId = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _demoImportError =
              'Chưa lưu được lựa chọn. Dữ liệu mẫu trên thiết bị vẫn còn; hãy thử lại khi có mạng.',
        );
      }
    } finally {
      if (mounted) setState(() => _demoImportBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Household>>(
    future: _households,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _HouseholdSetup(onChanged: _refresh, initialError: true);
      }
      if (!snapshot.hasData) {
        return const _AuthSplash();
      }
      if (_pendingDemoImport != null) {
        return _DemoImportChoice(
          items: _pendingDemoImport!,
          busy: _demoImportBusy,
          error: _demoImportError,
          onImport: () => _finishDemoImport(import: true),
          onStartEmpty: () => _finishDemoImport(import: false),
        );
      }
      if (snapshot.data!.isEmpty) return _HouseholdSetup(onChanged: _refresh);
      return const AppShell();
    },
  );
}

class _DemoImportChoice extends StatelessWidget {
  const _DemoImportChoice({
    required this.items,
    required this.busy,
    required this.onImport,
    required this.onStartEmpty,
    this.error,
  });

  final List<FoodSummary> items;
  final bool busy;
  final String? error;
  final VoidCallback onImport;
  final VoidCallback onStartEmpty;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF7FBF9),
    appBar: AppBar(title: const Text('Dữ liệu ban đầu')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Icon(Icons.inventory_2_outlined, size: 54, color: _green),
            const SizedBox(height: 14),
            const Text(
              'Bạn muốn bắt đầu như thế nào?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: _ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tủ lạnh mẫu trên thiết bị có ${items.length} món. Bạn có thể nhập một lần vào gia đình này để mọi thành viên cùng xem, hoặc bắt đầu với tủ trống. Lựa chọn này không thể lặp lại.',
              textAlign: TextAlign.center,
              style: const TextStyle(height: 1.45, color: Color(0xFF667085)),
            ),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Xem trước dữ liệu',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    ...items
                        .take(5)
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.eco_outlined,
                                  size: 17,
                                  color: _green,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  item.detail,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF667085),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    if (items.length > 5)
                      Text(
                        'và ${items.length - 5} món khác',
                        style: const TextStyle(color: Color(0xFF667085)),
                      ),
                  ],
                ),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(
                error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: busy ? null : onImport,
                icon: busy
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.download_done_outlined),
                label: const Text('Nhập dữ liệu mẫu vào gia đình'),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: busy ? null : onStartEmpty,
              child: const Text('Bắt đầu với tủ trống'),
            ),
          ],
        ),
      ),
    ),
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
