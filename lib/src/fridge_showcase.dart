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
    this.onInventoryTap,
    this.onExpiringTap,
    this.preview = false,
    this.active = true,
    this.height = 168,
  });

  final int inventoryCount;
  final int expiringCount;
  final VoidCallback? onInventoryTap;
  final VoidCallback? onExpiringTap;
  final bool preview;
  final bool active;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      gradient: const LinearGradient(
        colors: [Color(0xFFEAFBF4), Color(0xFFDDF5EB), Color(0xFFF4FBF7)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      border: Border.all(color: const Color(0xFFD7F0E5)),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 350;
        return Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: constraints.maxWidth * .38,
              child: _FridgeViewer(active: active),
            ),
            Positioned(
              left: constraints.maxWidth * .39,
              right: 14,
              top: 17,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ViNeat',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF203044),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    narrow ? 'Tủ lạnh gia đình' : 'Bếp gọn hơn, bữa ăn vui hơn',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF667085),
                    ),
                  ),
                  const SizedBox(height: 13),
                  _InfoChip(
                    icon: Icons.kitchen_outlined,
                    label: '$inventoryCount món đang có',
                    onTap: onInventoryTap,
                  ),
                  const SizedBox(height: 7),
                  _InfoChip(
                    icon: Icons.timer_outlined,
                    label: '$expiringCount cần ưu tiên',
                    foreground: const Color(0xFF9A5A00),
                    background: const Color(0xFFFFF4D8),
                    onTap: onExpiringTap,
                  ),
                ],
              ),
            ),
            Positioned(
              right: 12,
              bottom: 7,
              child: Text(
                preview
                    ? 'Hình minh họa · dữ liệu mẫu'
                    : 'Dữ liệu cập nhật theo thao tác',
                style: TextStyle(
                  fontSize: 8.5,
                  color: const Color(0xFF667085).withValues(alpha: .82),
                ),
              ),
            ),
          ],
        );
      },
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
  Timer? _loadWatchdog;
  bool _modelLoaded = false;
  bool _fallback = false;
  bool _appResumed = true;

  bool get _supportsModelViewerPlatform =>
      kIsWeb || Platform.isAndroid || Platform.isIOS;
  bool get _canRender3d =>
      widget.active &&
      _appResumed &&
      !_fallback &&
      _supportsModelViewerPlatform;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startLoadWatchdog();
  }

  @override
  void didUpdateWidget(covariant _FridgeViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active == oldWidget.active) return;
    _loadWatchdog?.cancel();
    if (widget.active) {
      _modelLoaded = false;
      _fallback = false;
      _startLoadWatchdog();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final resumed = state == AppLifecycleState.resumed;
    if (_appResumed == resumed) return;
    _appResumed = resumed;
    if (resumed && widget.active && !_modelLoaded) _startLoadWatchdog();
    if (!resumed) _loadWatchdog?.cancel();
    if (mounted) setState(() {});
  }

  void _startLoadWatchdog() {
    _loadWatchdog?.cancel();
    if (!_canRender3d || _modelLoaded) return;
    _loadWatchdog = Timer(const Duration(seconds: 12), () {
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
    _loadWatchdog?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_canRender3d) return const _FridgeRender();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
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
          autoRotate: !reduceMotion,
          autoRotateDelay: 1800,
          rotationPerSecond: '5deg',
          cameraOrbit: '22deg 74deg 2.55m',
          minCameraOrbit: 'auto 40deg 2.1m',
          maxCameraOrbit: 'auto 140deg 4m',
          minFieldOfView: '28deg',
          maxFieldOfView: '58deg',
          cameraTarget: '0m 0m 0m',
          interactionPrompt: InteractionPrompt.whenFocused,
          loading: Loading.lazy,
          reveal: Reveal.auto,
          environmentImage: 'neutral',
          shadowIntensity: 0.55,
          shadowSoftness: 0.75,
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
    required this.label,
    this.foreground = const Color(0xFF087A58),
    this.background = Colors.white,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final Color foreground;
  final Color background;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: background,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: foreground),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: foreground,
                ),
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
