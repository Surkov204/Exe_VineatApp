import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_tutorial.dart';
import 'app_services.dart';
import 'auth_screens.dart';
import 'household_data_repository.dart';
import 'inventory_store.dart';
import 'screens.dart';

final RouteObserver<ModalRoute<dynamic>> appRouteObserver =
    RouteObserver<ModalRoute<dynamic>>();

class VineatApp extends StatelessWidget {
  const VineatApp({super.key});

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF079669);
    return MaterialApp(
      navigatorObservers: [appRouteObserver],
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

class _PageTip {
  const _PageTip({required this.title, required this.description});

  final String title;
  final String description;
}

class _AppShellState extends State<AppShell>
    with SingleTickerProviderStateMixin, RouteAware {
  static const _pageKeys = ['home', 'scan', 'recipes', 'shopping', 'reports'];
  static const _pageTips = <_PageTip>[
    _PageTip(
      title: 'Mẹo tủ lạnh',
      description:
          'Thêm thực phẩm, theo dõi hạn dùng và mở một món để sửa hoặc ghi nhận đã dùng.',
    ),
    _PageTip(
      title: 'Mẹo quét hóa đơn',
      description:
          'Chụp hoặc chọn hóa đơn, rà lại từng dòng rồi mới xác nhận nhập vào tủ.',
    ),
    _PageTip(
      title: 'Mẹo gợi ý món ăn',
      description:
          'Tìm món theo nguyên liệu đang có; mở công thức để xem phần còn thiếu.',
    ),
    _PageTip(
      title: 'Mẹo đi chợ',
      description:
          'Thêm món cần mua. Đánh dấu đã mua để chuyển món vào tủ lạnh.',
    ),
    _PageTip(
      title: 'Mẹo báo cáo',
      description:
          'Số liệu phản ánh các lần thêm, dùng và bỏ thực phẩm đã xác nhận.',
    ),
  ];
  int _index = 0;
  int _transitionDirection = 1;
  final Set<int> _visitedTabs = {0};
  bool _showPageTip = false;
  late final AnimationController _tabTransition;
  ModalRoute<dynamic>? _route;

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
    activeAppTabIndex.value = 0;
    tutorialPageRequest.addListener(_handleTutorialRequest);
    HouseholdService.instance.active.addListener(_handleActiveHouseholdChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleActiveHouseholdChanged();
      _showTipIfNeeded(0);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route == _route) return;
    if (_route != null) appRouteObserver.unsubscribe(this);
    _route = route;
    if (route != null) appRouteObserver.subscribe(this, route);
  }

  @override
  void didPushNext() => activeAppTabIndex.value = -1;

  @override
  void didPopNext() => activeAppTabIndex.value = _index;

  void _handleTutorialRequest() {
    final requested = tutorialPageRequest.value;
    if (requested == null) return;
    _selectTab(requested);
    tutorialPageRequest.value = null;
  }

  void _handleActiveHouseholdChanged() {
    if (!AppServices.configured) return;
    final householdId = HouseholdService.instance.active.value?.id;
    unawaited(
      HouseholdDataRepository.instance.watchHouseholdChanges(
        householdId: householdId,
        onSnapshot: (snapshot) {
          if (!mounted ||
              HouseholdService.instance.active.value?.id != householdId) {
            return;
          }
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
        },
      ),
    );
  }

  Future<void> _showTipIfNeeded(int index) async {
    final userId = AppServices.configured
        ? AppServices.client.auth.currentUser?.id ?? 'signed-out'
        : 'local';
    final preferenceKey = pageTutorialPreferenceKey(
      userId: userId,
      pageKey: _pageKeys[index],
    );
    final preferences = await SharedPreferences.getInstance();
    var seen = preferences.getBool(preferenceKey) ?? false;
    if (!seen && AppServices.configured) {
      try {
        seen = await HouseholdDataRepository.instance.isTutorialPageCompleted(
          _pageKeys[index],
        );
        if (seen) {
          await preferences.setBool(preferenceKey, true);
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
    final pageIndex = _index;
    final userId = AppServices.configured
        ? AppServices.client.auth.currentUser?.id ?? 'signed-out'
        : 'local';
    final preferenceKey = pageTutorialPreferenceKey(
      userId: userId,
      pageKey: _pageKeys[pageIndex],
    );
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(preferenceKey, true);
    if (AppServices.configured) {
      unawaited(
        HouseholdDataRepository.instance
            .markTutorialPageCompleted(_pageKeys[pageIndex])
            .catchError((_) {}),
      );
    }
    if (mounted) setState(() => _showPageTip = false);
  }

  Future<void> _advancePageTip() async {
    final next = _index + 1;
    await _dismissPageTip();
    if (mounted && next < _pages.length) _selectTab(next);
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    HouseholdService.instance.active.removeListener(
      _handleActiveHouseholdChanged,
    );
    if (AppServices.configured) {
      unawaited(
        HouseholdDataRepository.instance.watchHouseholdChanges(
          householdId: null,
          onSnapshot: (_) {},
        ),
      );
    }
    if (activeAppTabIndex.value == _index) activeAppTabIndex.value = -1;
    tutorialPageRequest.removeListener(_handleTutorialRequest);
    _tabTransition.dispose();
    super.dispose();
  }

  void _selectTab(int value) {
    if (value == _index) return;
    setState(() {
      _transitionDirection = value > _index ? 1 : -1;
      _index = value;
      _visitedTabs.add(value);
      _showPageTip = false;
    });
    activeAppTabIndex.value = value;
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
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final compactNavigationLabels = textScale >= 1.3;
    return Stack(
      fit: StackFit.expand,
      children: [
        Scaffold(
          body: SafeArea(
            top: true,
            bottom: false,
            minimum: const EdgeInsets.only(top: 24),
            child: Column(
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
                if (!AppServices.configured)
                  Material(
                    color: const Color(0xFFEAF5FF),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 7, 14, 7),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            size: 17,
                            color: Color(0xFF366A91),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Demo ngoại tuyến · dữ liệu mẫu chỉ lưu trên thiết bị, chưa đồng bộ gia đình.',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF345B78),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
                                  TickerMode(
                                    enabled: i == _index,
                                    child: _visitedTabs.contains(i)
                                        ? _pages[i]
                                        : const SizedBox.shrink(),
                                  ),
                              ],
                            ),
                          ),
                          builder: (context, child) {
                            final progress = Curves.easeOutCubic.transform(
                              _tabTransition.value,
                            );
                            return Transform.translate(
                              offset: Offset(
                                _transitionDirection * 10 * (1 - progress),
                                0,
                              ),
                              child: child,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: useRail
              ? null
              : NavigationBar(
                  height: compactNavigationLabels ? 80 : 68,
                  selectedIndex: _index,
                  backgroundColor: Colors.white,
                  indicatorColor: const Color(0xFFE7F8F1),
                  labelBehavior: compactNavigationLabels
                      ? NavigationDestinationLabelBehavior.onlyShowSelected
                      : NavigationDestinationLabelBehavior.alwaysShow,
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
        ),
        if (_showPageTip)
          Positioned.fill(
            child: AnchoredTutorialCoachmark(
              targetKey: tutorialTargetKeys[_index],
              title: _pageTips[_index].title,
              description: _pageTips[_index].description,
              step: _index + 1,
              totalSteps: _pages.length,
              onNext: _advancePageTip,
              onSkip: _dismissPageTip,
            ),
          ),
      ],
    );
  }
}
