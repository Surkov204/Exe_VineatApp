import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

/// Interactive GLB showcase with a lightweight Flutter fallback. The viewer is
/// created only on visible mobile/web surfaces and is suspended off-tab.
class SmartFridgeShowcase extends StatelessWidget {
  const SmartFridgeShowcase({
    super.key,
    required this.inventoryCount,
    required this.expiringCount,
    required this.freshCount,
    required this.expiredCount,
    this.statisticsKey,
    this.onInventoryTap,
    this.onExpiringTap,
    this.preview = false,
    this.active = true,
    this.height = 190,
  });

  final int inventoryCount;
  final int expiringCount;
  final int freshCount;
  final int expiredCount;
  final Key? statisticsKey;
  final VoidCallback? onInventoryTap;
  final VoidCallback? onExpiringTap;
  final bool preview;
  final bool active;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      gradient: const LinearGradient(
        colors: [Color(0xFFEAFBF4), Color(0xFFDDF5EB), Color(0xFFF4FBF7)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      border: Border.all(color: const Color(0xFFD7F0E5)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x10087958),
          blurRadius: 18,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - value)),
          child: child,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tổng quan tủ lạnh',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF203044),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Thực phẩm của gia đình, trong tầm tay',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF667085),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(minHeight: height),
                child: Row(
                  children: [
                    SizedBox(
                      width: (constraints.maxWidth * .30).clamp(76, 112),
                      height: height,
                      child: Semantics(
                        button: true,
                        label: 'Mở thực phẩm trong tủ lạnh',
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            key: const ValueKey('open-fridge-inventory'),
                            onTap: onInventoryTap,
                            borderRadius: BorderRadius.circular(18),
                            child: Column(
                              children: [
                                Expanded(
                                  child: IgnorePointer(
                                    child: _FridgeViewer(active: active),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(18, 12, 10, 9),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _InfoChip(
                              icon: Icons.kitchen_outlined,
                              count: inventoryCount,
                              label: 'Tổng số món',
                              large: true,
                              onTap: onInventoryTap,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                key: statisticsKey,
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: LayoutBuilder(
                  builder: (context, bounds) {
                    final columns =
                        bounds.maxWidth < 300 ||
                            MediaQuery.textScalerOf(context).scale(1) > 1.25
                        ? 2
                        : 3;
                    final width =
                        (bounds.maxWidth - (columns - 1) * 8) / columns;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        SizedBox(
                          width: width,
                          child: _InfoChip(
                            icon: Icons.eco_outlined,
                            count: freshCount,
                            label: 'Còn tươi',
                            background: const Color(0xFFE9FAF0),
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: _InfoChip(
                            icon: Icons.timer_outlined,
                            count: expiringCount,
                            label: 'Sắp hết hạn',
                            foreground: const Color(0xFF9A5A00),
                            background: const Color(0xFFFFF4D8),
                            onTap: onExpiringTap,
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: _InfoChip(
                            icon: Icons.cancel_outlined,
                            count: expiredCount,
                            label: 'Đã hết hạn',
                            foreground: const Color(0xFFB42318),
                            background: const Color(0xFFFFF0F1),
                            onTap: onExpiringTap,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _FridgeViewer extends StatefulWidget {
  const _FridgeViewer({required this.active});

  final bool active;

  @override
  State<_FridgeViewer> createState() => _FridgeViewerState();
}

class _FridgeViewerState extends State<_FridgeViewer>
    with WidgetsBindingObserver {
  static const _modelLoadTimeout = Duration(seconds: 7);

  Timer? _viewerStartDelay;
  Timer? _loadWatchdog;
  bool _viewerReady = false;
  bool _modelLoaded = false;
  bool _fallback = false;
  bool _appResumed = true;

  bool get _supportsModelViewerPlatform =>
      kIsWeb ||
      Platform.isIOS ||
      // Android debug emulators often expose an incomplete WebGL surface.
      // Keep local demos responsive with the lightweight Flutter model; the
      // interactive GLB remains enabled for profile and release builds.
      (Platform.isAndroid && !kDebugMode);
  bool get _canRender3d =>
      widget.active &&
      _appResumed &&
      _viewerReady &&
      !_fallback &&
      _supportsModelViewerPlatform;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleViewerStart();
  }

  @override
  void didUpdateWidget(covariant _FridgeViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active == oldWidget.active) return;
    _viewerStartDelay?.cancel();
    _loadWatchdog?.cancel();
    if (widget.active) {
      _modelLoaded = false;
      _fallback = false;
      _viewerReady = false;
      _scheduleViewerStart();
    } else {
      _viewerReady = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final resumed = state == AppLifecycleState.resumed;
    if (_appResumed == resumed) return;
    _appResumed = resumed;
    if (resumed && widget.active && !_fallback) {
      _modelLoaded = false;
      _viewerReady = false;
      _scheduleViewerStart();
    }
    if (!resumed) {
      _viewerStartDelay?.cancel();
      _loadWatchdog?.cancel();
      _viewerReady = false;
      _modelLoaded = false;
    }
    if (mounted) setState(() {});
  }

  void _scheduleViewerStart() {
    _viewerStartDelay?.cancel();
    if (!_supportsModelViewerPlatform ||
        !widget.active ||
        !_appResumed ||
        _fallback) {
      return;
    }
    // Let the first useful Flutter frame appear before constructing the
    // Android WebView used by model_viewer_plus.
    _viewerStartDelay = Timer(const Duration(milliseconds: 450), () {
      if (!mounted || !widget.active || !_appResumed || _fallback) return;
      setState(() => _viewerReady = true);
      _startLoadWatchdog();
    });
  }

  void _startLoadWatchdog() {
    _loadWatchdog?.cancel();
    if (!_canRender3d || _modelLoaded) return;
    _loadWatchdog = Timer(_modelLoadTimeout, () {
      if (mounted && !_modelLoaded) setState(() => _fallback = true);
    });
  }

  void _handleModelStatus(dynamic message) {
    if (!mounted) return;
    final status = message is String ? message : message.message as String?;
    if (status == 'loaded') {
      _loadWatchdog?.cancel();
      setState(() => _modelLoaded = true);
    } else if (status == 'error') {
      _loadWatchdog?.cancel();
      setState(() => _fallback = true);
    }
  }

  @override
  void dispose() {
    _viewerStartDelay?.cancel();
    _loadWatchdog?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_canRender3d) return const _FridgeRender();
    return Stack(
      fit: StackFit.expand,
      children: [
        const _FridgeRender(),
        ModelViewer(
          key: const ValueKey('vineat-fridge-model-viewer'),
          src: 'assets/models/vineat-smart-fridge.glb',
          alt: 'Mô hình tủ lạnh ViNeat có thể xoay và thu phóng',
          backgroundColor: Colors.transparent,
          ar: false,
          cameraControls: true,
          disablePan: true,
          // Keep manual camera controls, but avoid continuous WebView/GPU
          // work while the user is reading the dashboard.
          autoRotate: false,
          autoRotateDelay: 1800,
          rotationPerSecond: '5deg',
          // This GLB is about 1.9 m tall. A wider default camera distance
          // keeps the full appliance inside the narrow mobile showcase.
          cameraOrbit: '22deg 74deg 3.65m',
          minCameraOrbit: 'auto 40deg 2.1m',
          maxCameraOrbit: 'auto 140deg 4.6m',
          minFieldOfView: '28deg',
          maxFieldOfView: '58deg',
          cameraTarget: '0m 0m 0m',
          interactionPrompt: InteractionPrompt.whenFocused,
          loading: Loading.lazy,
          reveal: Reveal.auto,
          environmentImage: 'neutral',
          shadowIntensity: 0,
          shadowSoftness: 0,
          debugLogging: false,
          javascriptChannels: {
            JavascriptChannel(
              'ViNeatFridgeStatus',
              onMessageReceived: _handleModelStatus,
            ),
          },
          relatedJs: '''
            const fridge = document.querySelector('model-viewer');
            if (fridge) {
              fridge.addEventListener('load', () => ViNeatFridgeStatus.postMessage('loaded'), { once: true });
              fridge.addEventListener('error', () => ViNeatFridgeStatus.postMessage('error'), { once: true });
            }
          ''',
        ),
        if (!_modelLoaded)
          Positioned(
            left: 12,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.82),
                shape: BoxShape.circle,
              ),
              child: const SizedBox.square(
                dimension: 12,
                child: CircularProgressIndicator(strokeWidth: 1.8),
              ),
            ),
          ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.count,
    required this.label,
    this.foreground = const Color(0xFF087A58),
    this.background = Colors.white,
    this.onTap,
    this.large = false,
  });
  final IconData icon;
  final int count;
  final String label;
  final Color foreground;
  final Color background;
  final VoidCallback? onTap;
  final bool large;

  @override
  Widget build(BuildContext context) => Material(
    color: background,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: large ? 18 : 7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: foreground),
                const SizedBox(width: 3),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: large ? 24 : 20,
                    fontWeight: FontWeight.w900,
                    color: foreground,
                  ),
                ),
              ],
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _FridgeRender extends StatelessWidget {
  const _FridgeRender();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.only(left: 5, top: 13, bottom: 18),
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, .0018)
          ..rotateY(-.16)
          ..rotateZ(-.015),
        child: SizedBox(
          width: 92,
          height: 132,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                right: -8,
                top: 4,
                bottom: 1,
                width: 11,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFB5CFC3), Color(0xFF8DA99D)],
                    ),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Colors.white,
                      Color(0xFFE7F0EC),
                      Color(0xFFD1E2D9),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFC3D7CC)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x203A6150),
                      blurRadius: 13,
                      offset: Offset(3, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Row(
                        children: [
                          const Spacer(),
                          Container(
                            width: 4,
                            height: 32,
                            margin: const EdgeInsets.only(right: 7),
                            decoration: BoxDecoration(
                              color: const Color(0xFF9EB7AA),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(height: 2, color: const Color(0xFFC1D3C9)),
                    Expanded(
                      flex: 6,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.eco_rounded,
                            size: 35,
                            color: const Color(
                              0xFF079669,
                            ).withValues(alpha: .82),
                          ),
                          Positioned(
                            bottom: 8,
                            child: Container(
                              width: 5,
                              height: 22,
                              decoration: BoxDecoration(
                                color: const Color(0xFF9EB7AA),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
