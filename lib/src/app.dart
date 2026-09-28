import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_tutorial.dart';
import 'app_services.dart';
import 'auth_screens.dart';
import 'household_data_repository.dart';
import 'screens.dart';

class VineatApp extends StatelessWidget {
  const VineatApp({super.key});

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF079669);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ViNeat',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF9FAFB),
        colorScheme: ColorScheme.fromSeed(
          seedColor: green,
          primary: green,
          surface: Colors.white,
        ),
        fontFamily: 'Roboto',
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
        splashFactory: InkSparkle.splashFactory,
        visualDensity: VisualDensity.standard,
        textTheme: const TextTheme(
          headlineSmall: TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F2937),
          ),
          titleLarge: TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F2937),
          ),
          titleMedium: TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF253043),
          ),
          bodyMedium: TextStyle(color: Color(0xFF586477)),
        ),
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            side: BorderSide(color: Color(0xFFEEF0F3)),
          ),
        ),
      ),
      home: const AppEntry(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell>
    with SingleTickerProviderStateMixin {
  static const _pageKeys = ['home', 'scan', 'recipes', 'shopping', 'reports'];
  static const _pageTips = [
    (
      'Mẹo tủ lạnh',
      'Thêm thực phẩm, theo dõi hạn dùng và mở một món để sửa hoặc ghi nhận đã dùng.',
    ),
    (
      'Mẹo quét hóa đơn',
      'Chụp hoặc chọn hóa đơn, rà lại từng dòng rồi mới xác nhận nhập vào tủ.',
    ),
    (
      'Mẹo gợi ý món ăn',
      'Tìm món theo nguyên liệu đang có; mở công thức để xem phần còn thiếu.',
    ),
    (
      'Mẹo đi chợ',
      'Thêm món cần mua. Đánh dấu đã mua để chuyển món vào tủ lạnh.',
    ),
    (
      'Mẹo báo cáo',
      'Số liệu phản ánh các lần thêm, dùng và bỏ thực phẩm đã xác nhận.',
    ),
  ];
  int _index = 0;
  int _transitionDirection = 1;
  bool _showPageTip = false;
  late final AnimationController _tabTransition;

  static const _pages = [
    FridgeScreen(),
    ScanScreen(),
    RecipesScreen(),
    ShoppingScreen(),
    ReportsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _tabTransition = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: 1,
    );
    tutorialPageRequest.addListener(_handleTutorialRequest);
    WidgetsBinding.instance.addPostFrameCallback((_) => _showTipIfNeeded(0));
  }

  void _handleTutorialRequest() {
    final requested = tutorialPageRequest.value;
    if (requested == null) return;
    _selectTab(requested);
    tutorialPageRequest.value = null;
  }

  Future<void> _showTipIfNeeded(int index) async {
    final preferences = await SharedPreferences.getInstance();
    var seen =
        preferences.getBool('vineat_page_tutorial_${_pageKeys[index]}_v1') ??
        false;
    if (!seen && AppServices.configured) {
      try {
        seen = await HouseholdDataRepository.instance.isTutorialPageCompleted(
          _pageKeys[index],
        );
        if (seen) {
          await preferences.setBool(
            'vineat_page_tutorial_${_pageKeys[index]}_v1',
            true,
          );
        }
      } catch (_) {
        // Keep first-use help available even when the network is offline.
      }
    }
    if (mounted && _index == index && !seen) {
      setState(() => _showPageTip = true);
    }
  }

  Future<void> _dismissPageTip() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(
      'vineat_page_tutorial_${_pageKeys[_index]}_v1',
      true,
    );
    if (AppServices.configured) {
      unawaited(
        HouseholdDataRepository.instance
            .markTutorialPageCompleted(_pageKeys[_index])
            .catchError((_) {}),
      );
    }
    if (mounted) setState(() => _showPageTip = false);
  }

  @override
  void dispose() {
    tutorialPageRequest.removeListener(_handleTutorialRequest);
    _tabTransition.dispose();
    super.dispose();
  }

  void _selectTab(int value) {
    if (value == _index) return;
    setState(() {
      _transitionDirection = value > _index ? 1 : -1;
      _index = value;
      _showPageTip = false;
    });
    _showTipIfNeeded(value);
    if (MediaQuery.of(context).disableAnimations) {
      _tabTransition.value = 1;
    } else {
      _tabTransition.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final useRail = MediaQuery.sizeOf(context).width >= 720;
    return Scaffold(
      body: Column(
        children: [
          ValueListenableBuilder<String?>(
            valueListenable: HouseholdDataRepository.instance.syncStatus,
            builder: (context, status, _) => status == null
                ? const SizedBox.shrink()
                : Material(
                    color: status.startsWith('Đang')
                        ? const Color(0xFFE8F2FF)
                        : const Color(0xFFFFF4E5),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 7, 4, 7),
                      child: Row(
                        children: [
                          Icon(
                            status.startsWith('Đang')
                                ? Icons.sync
                                : Icons.cloud_off_outlined,
                            size: 18,
                            color: status.startsWith('Đang')
                                ? Colors.blueGrey
                                : Colors.deepOrange,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              status,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Ẩn thông báo',
                            visualDensity: VisualDensity.compact,
                            onPressed: () =>
                                HouseholdDataRepository
                                        .instance
                                        .syncStatus
                                        .value =
                                    null,
                            icon: const Icon(Icons.close, size: 18),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          if (_showPageTip)
            _PageCoachCard(
              title: _pageTips[_index].$1,
              description: _pageTips[_index].$2,
              onDismiss: _dismissPageTip,
            ),
          Expanded(
            child: Row(
              key: const ValueKey('app-body-row'),
              children: [
                if (useRail)
                  NavigationRail(
                    selectedIndex: _index,
                    onDestinationSelected: _selectTab,
                    labelType: NavigationRailLabelType.all,
                    backgroundColor: Colors.white,
                    indicatorColor: const Color(0xFFE7F8F1),
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home),
                        label: Text('Trang chủ'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.document_scanner_outlined),
                        label: Text('Scan'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.restaurant_menu),
                        label: Text('Món ăn'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.shopping_basket_outlined),
                        label: Text('Đi chợ'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.bar_chart_rounded),
                        label: Text('Báo cáo'),
                      ),
                    ],
                  ),
                Expanded(
                  child: AnimatedBuilder(
                    animation: _tabTransition,
                    child: SizedBox.expand(
                      child: IndexedStack(
                        index: _index,
                        children: [
                          for (var i = 0; i < _pages.length; i++)
                            TickerMode(enabled: i == _index, child: _pages[i]),
                        ],
                      ),
                    ),
                    builder: (context, child) {
                      final progress = Curves.easeOutCubic.transform(
                        _tabTransition.value,
                      );
                      return Opacity(
                        opacity: .88 + (.12 * progress),
                        child: Transform.translate(
                          offset: Offset(
                            _transitionDirection * 10 * (1 - progress),
                            0,
                          ),
                          child: child,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: useRail
          ? null
          : NavigationBar(
              height: 68,
              selectedIndex: _index,
              backgroundColor: Colors.white,
              indicatorColor: const Color(0xFFE7F8F1),
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              onDestinationSelected: _selectTab,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Trang chủ',
                ),
                NavigationDestination(
                  icon: Icon(Icons.document_scanner_outlined),
                  label: 'Scan',
                ),
                NavigationDestination(
                  icon: Icon(Icons.restaurant_menu),
                  label: 'Món ăn',
                ),
                NavigationDestination(
                  icon: Icon(Icons.shopping_basket_outlined),
                  label: 'Đi chợ',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bar_chart_rounded),
                  label: 'Báo cáo',
                ),
              ],
            ),
    );
  }
}

class _PageCoachCard extends StatelessWidget {
  const _PageCoachCard({
    required this.title,
    required this.description,
    required this.onDismiss,
  });

  final String title;
  final String description;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedSize(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        decoration: BoxDecoration(
          color: const Color(0xFFE8FBF4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFC9F1E1)),
        ),
        child: Row(
          children: [
            const Icon(Icons.lightbulb_outline, color: Color(0xFF079669)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF253043),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: Color(0xFF586477),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            TextButton(onPressed: onDismiss, child: const Text('Đã hiểu')),
          ],
        ),
      ),
    );
  }
}
