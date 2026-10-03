import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'auth_error_messages.dart';
import 'app_services.dart';
import 'email_validation.dart';
import 'household_data_repository.dart';
import 'inventory_store.dart';
import 'registration_screen.dart';
import 'vineat_logo.dart';

const _green = Color(0xFF079669);
const _ink = Color(0xFF203044);
const _allowDemoImport = bool.fromEnvironment('VINEAT_ALLOW_DEMO_IMPORT');

class AppEntry extends StatelessWidget {
  const AppEntry({super.key});

  @override
  Widget build(BuildContext context) {
    if (debugOtpDemoEnabled) {
      return ValueListenableBuilder<bool>(
        valueListenable: debugDemoAuthenticated,
        builder: (context, authenticated, _) => authenticated
            ? const AppShell()
            : LoginScreen(onDemoAuthenticated: AppServices.signInDebugDemo),
      );
    }
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
                const VineatLogo(width: 180),
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
  const LoginScreen({super.key, this.onDemoAuthenticated});

  final Future<void> Function()? onDemoAuthenticated;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _email = TextEditingController();
  final _otp = TextEditingController();
  late final AnimationController _intro;
  bool _introStarted = false;
  bool _sent = false;
  bool _busy = false;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_introStarted) return;
    _introStarted = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _intro.value = 1;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _intro.forward();
      });
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _email.dispose();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _email.text.trim();
    final validationError = validateLoginEmail(
      email,
      cloudAuth: !debugOtpDemoEnabled,
    );
    if (validationError != null) {
      setState(() {
        _error = validationError;
        _notice = null;
      });
      return;
    }
    if (debugOtpDemoEnabled) {
      if (email.toLowerCase() != debugDemoEmail.toLowerCase()) {
        setState(() => _error = 'Không thể gửi mã cho địa chỉ email này.');
        return;
      }
      setState(() {
        _busy = true;
        _error = null;
        _notice = null;
      });
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      setState(() {
        _busy = false;
        _sent = true;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await AppServices.client.auth
          .signInWithOtp(email: email, shouldCreateUser: true)
          .timeout(const Duration(seconds: 12));
      if (!mounted) return;
      setState(() {
        _sent = true;
        _notice = 'Mã xác thực đã được gửi đến $email.';
      });
    } on AuthException catch (error) {
      if (mounted) {
        setState(() => _error = vietnameseAuthError(error, action: 'send'));
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Chưa gửi được mã. Kiểm tra kết nối mạng rồi thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyCode() async {
    final code = _otp.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = 'Nhập đúng mã 6 chữ số trong email.');
      return;
    }
    if (debugOtpDemoEnabled) {
      setState(() {
        _busy = true;
        _error = null;
      });
      await Future<void>.delayed(const Duration(milliseconds: 180));
      if (!mounted) return;
      final valid =
          _email.text.trim().toLowerCase() == debugDemoEmail.toLowerCase() &&
          code == debugDemoOtp;
      if (!valid) {
        setState(() {
          _busy = false;
          _error = 'Email hoặc mã xác thực chưa chính xác.';
        });
        return;
      }
      try {
        await widget.onDemoAuthenticated?.call();
      } catch (_) {
        if (mounted) {
          setState(() => _error = 'Chưa đăng nhập được. Vui lòng thử lại.');
        }
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await AppServices.client.auth
          .verifyOTP(
            email: _email.text.trim(),
            token: code,
            type: OtpType.email,
          )
          .timeout(const Duration(seconds: 12));
    } on AuthException catch (error) {
      if (mounted) {
        setState(() => _error = vietnameseAuthError(error, action: 'verify'));
      }
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
      if (mounted) {
        setState(() => _error = vietnameseAuthError(error, action: 'google'));
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Chưa mở được đăng nhập Google.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF7FBF9),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: AnimatedBuilder(
                animation: _intro,
                builder: (context, _) {
                  // Hold the full lockup on screen, spin once in perspective,
                  // then move it to its resting place above the form.
                  final raw = reduceMotion ? 1.0 : _intro.value;
                  final spin = Curves.easeInOutCubic.transform(
                    ((raw - .22) / .40).clamp(0.0, 1.0),
                  );
                  final progress = reduceMotion
                      ? 1.0
                      : Curves.easeInOutCubic.transform(
                          ((raw - .62) / .38).clamp(0.0, 1.0),
                        );
                  final startWidth = math.min(200.0, viewport.maxWidth * .52);
                  final logoWidth = startWidth + (112 - startWidth) * progress;
                  final startHeight = startWidth * 635 / 800;
                  final centerSpacer = math.max(
                    0.0,
                    (viewport.maxHeight - startHeight) / 2 - 16,
                  );
                  final formSpacer = math.max(
                    20.0,
                    (viewport.maxHeight - 520) / 2 - 36,
                  );
                  final formProgress = reduceMotion
                      ? 1.0
                      : Curves.easeOutCubic.transform(
                          ((raw - .68) / .26).clamp(0.0, 1.0),
                        );
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    children: [
                      SizedBox(
                        height: centerSpacer * (1 - progress) + 36 * progress,
                      ),
                      Center(
                        child: Transform(
                          key: const ValueKey('login-logo-motion'),
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, .0015)
                            ..rotateY(math.pi * 2 * spin)
                            ..rotateX(.07 * math.sin(math.pi * spin)),
                          child: VineatLogo(width: logoWidth),
                        ),
                      ),
                      SizedBox(height: formSpacer),
                      IgnorePointer(
                        ignoring: formProgress < .98,
                        child: Opacity(
                          opacity: formProgress,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Chào mừng bạn về nhà',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: _ink,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Đăng nhập để cùng gia đình quản lý thực phẩm, lên món và giảm lãng phí.',
                                style: TextStyle(
                                  height: 1.45,
                                  color: Color(0xFF667085),
                                ),
                              ),
                              const SizedBox(height: 18),
                              if (!_sent) ...[
                                TextField(
                                  controller: _email,
                                  keyboardType: TextInputType.emailAddress,
                                  autocorrect: false,
                                  textCapitalization: TextCapitalization.none,
                                  textInputAction: TextInputAction.done,
                                  autofillHints: const [AutofillHints.email],
                                  decoration: const InputDecoration(
                                    labelText: 'Email của bạn',
                                    prefixIcon: Icon(Icons.mail_outline),
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.all(
                                        Radius.circular(14),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.all(
                                        Radius.circular(14),
                                      ),
                                      borderSide: BorderSide(
                                        color: Color(0xFFE4E9E7),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.all(
                                        Radius.circular(14),
                                      ),
                                      borderSide: BorderSide(
                                        color: _green,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                  onSubmitted: (_) => _sendCode(),
                                  onChanged: (_) {
                                    if (_error != null) {
                                      setState(() => _error = null);
                                    }
                                  },
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 50,
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
                                if (!debugOtpDemoEnabled) ...[
                                  const SizedBox(height: 10),
                                  OutlinedButton.icon(
                                    onPressed: _busy ? null : _google,
                                    icon: const Icon(
                                      Icons.g_mobiledata,
                                      size: 27,
                                    ),
                                    label: const Text('Tiếp tục với Google'),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size.fromHeight(48),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                ],
                              ] else ...[
                                TextField(
                                  controller: _otp,
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.done,
                                  autofillHints: const [
                                    AutofillHints.oneTimeCode,
                                  ],
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  maxLength: 6,
                                  decoration: const InputDecoration(
                                    labelText: 'Mã xác thực',
                                    prefixIcon: Icon(Icons.password),
                                    filled: true,
                                    fillColor: Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.all(
                                        Radius.circular(14),
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.all(
                                        Radius.circular(14),
                                      ),
                                      borderSide: BorderSide(
                                        color: Color(0xFFE4E9E7),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.all(
                                        Radius.circular(14),
                                      ),
                                      borderSide: BorderSide(
                                        color: _green,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                  onSubmitted: (_) => _verifyCode(),
                                ),
                                SizedBox(
                                  height: 50,
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
                                transitionBuilder: (child, animation) =>
                                    FadeTransition(
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
                                    : const SizedBox.shrink(
                                        key: ValueKey('empty'),
                                      ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Giữ mã xác thực của bạn riêng tư. ViNeat không bao giờ yêu cầu bạn gửi mật khẩu qua tin nhắn.',
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
                    ],
                  );
                },
              ),
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
    width: double.infinity,
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: error ? const Color(0xFFFFF1F0) : const Color(0xFFE8FBF4),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      text,
      textAlign: TextAlign.center,
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
  bool _needsRegistration = false;
  bool _choosingFamily = false;
  String? _familyChoiceError;
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
    final user = AppServices.client.auth.currentUser;
    if (user == null) throw StateError('No authenticated user.');
    final profile = await AppServices.client
        .from('profiles')
        .select('display_name')
        .eq('id', user.id)
        .maybeSingle();
    if (profile == null) {
      throw StateError('Missing profile for signed-in user.');
    }
    final households = await HouseholdService.instance.restoreActive();
    // A legacy account may still have the old default profile name while
    // already belonging to a family; do not make it register a second time.
    _needsRegistration = profileNeedsRegistration(
      profile,
      hasHousehold: households.isNotEmpty,
    );
    if (_needsRegistration) return const [];

    // A new login has no saved choice; only a restored choice may skip this
    // picker. Never load another family's inventory before the choice.
    if (HouseholdService.instance.active.value == null &&
        households.isNotEmpty) {
      return households;
    }

    if (_allowDemoImport) await restoreLocalDemoData();
    final localDemo = _allowDemoImport
        ? await localDemoPreviewSnapshot()
        : const <FoodSummary>[];
    if (households.isEmpty) {
      _pendingDemoImport = null;
      replaceInventoryFromRemote(records: const [], events: const []);
      replaceShoppingFromRemote(items: const [], checked: const {});
      return households;
    }
    try {
      await restorePendingInventoryAdds();
      final snapshot = await HouseholdDataRepository.instance
          .loadActiveHousehold();
      final householdId = HouseholdService.instance.active.value?.id;
      if (_allowDemoImport &&
          snapshot.inventory.isEmpty &&
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

  void _finishRegistration() {
    _refresh();
  }

  Future<void> _chooseFamily(Household household) async {
    if (_choosingFamily) return;
    setState(() {
      _choosingFamily = true;
      _familyChoiceError = null;
    });
    try {
      await HouseholdService.instance.select(household);
      _refresh();
    } catch (_) {
      if (mounted) {
        setState(
          () => _familyChoiceError =
              'Chưa mở được gia đình này. Kiểm tra kết nối rồi thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _choosingFamily = false);
    }
  }

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
    key: ObjectKey(_households),
    future: _households,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return _HouseholdSetup(onChanged: _refresh, initialError: true);
      }
      if (!snapshot.hasData) {
        return const _AuthSplash();
      }
      if (_needsRegistration) {
        return RegistrationScreen(
          email: AppServices.client.auth.currentUser?.email ?? '',
          onCompleted: _finishRegistration,
        );
      }
      if (HouseholdService.instance.active.value == null &&
          snapshot.data!.isNotEmpty) {
        return HouseholdPicker(
          households: snapshot.data!,
          busy: _choosingFamily,
          error: _familyChoiceError,
          onSelected: _chooseFamily,
          onSignOut: () => AppServices.signOut(),
        );
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
      if (snapshot.data!.isEmpty) {
        return _HouseholdSetup(onChanged: _finishRegistration);
      }
      return const AppShell();
    },
  );
}

class HouseholdPicker extends StatelessWidget {
  const HouseholdPicker({
    super.key,
    required this.households,
    required this.onSelected,
    required this.onSignOut,
    this.busy = false,
    this.error,
  });

  final List<Household> households;
  final ValueChanged<Household> onSelected;
  final VoidCallback onSignOut;
  final bool busy;
  final String? error;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF7FBF9),
    appBar: AppBar(
      backgroundColor: const Color(0xFFF7FBF9),
      actions: [
        TextButton(
          onPressed: busy ? null : onSignOut,
          child: const Text('Đăng xuất'),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            const Center(child: VineatLogo(width: 110)),
            const SizedBox(height: 24),
            const Text(
              'Chọn gia đình của bạn',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Mỗi gia đình có tủ lạnh và danh sách đi chợ riêng. Bạn có thể đổi gia đình sau trong Hồ sơ.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF667085), height: 1.4),
            ),
            const SizedBox(height: 24),
            for (final household in households) ...[
              Card(
                child: ListTile(
                  key: ValueKey('choose-family-${household.id}'),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFE2F8EF),
                    child: Icon(Icons.home_outlined, color: _green),
                  ),
                  title: Text(
                    household.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    household.role == 'owner' ? 'Chủ gia đình' : 'Thành viên',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 17),
                  onTap: busy ? null : () => onSelected(household),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (busy) const LinearProgressIndicator(minHeight: 3),
            if (error != null) ...[
              const SizedBox(height: 14),
              Text(
                error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    ),
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
      await AppServices.signOut();
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
