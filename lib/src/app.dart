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
import 'usage_screen.dart';
import 'menu_ingredients.dart';

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
  static const _pageKeys = [
    'home',
    'scan',
    'recipes',
    'shopping',
    'reports',
    'usage',
  ];
  static const _navigationPages = [0, 1, 5, 2, 3, 4];
  static const _pageTips = <List<_PageTip>>[
    [
      _PageTip(
        title: 'Tủ lạnh gia đình',
        description:
            'Chạm hình tủ lạnh hoặc Tổng số món để mở trang đầy đủ thực phẩm. Trang chủ hiển thị tối đa 10 món; Xem tất cả mở danh sách có tìm kiếm.',
      ),
      _PageTip(
        title: 'Các chỉ số',
        description:
            'Ba trạng thái bên dưới cho biết món còn tươi, sắp hết hạn và đã hết hạn. Chạm ô hạn dùng để xem món cần ưu tiên.',
      ),
      _PageTip(
        title: 'Cảnh báo hạn dùng',
        description:
            'Vuốt hàng cảnh báo sang trái hoặc phải để xem đầy đủ món cần ưu tiên. Chạm món trong danh sách bên dưới để sửa, dùng hoặc bỏ.',
      ),
      _PageTip(
        title: 'Thêm thực phẩm',
        description:
            'Nút Thêm món cho chọn Scan, AI, Template hoặc Thủ công. Rà soát thông tin trước khi thêm thực phẩm vào tủ lạnh gia đình.',
      ),
    ],
    [
      _PageTip(
        title: 'Chọn cách nhập hóa đơn',
        description:
            'Chụp hoặc chọn ảnh hóa đơn. Bạn cũng có thể thử mẫu hoặc nhập thủ công.',
      ),
      _PageTip(
        title: 'Xem lại trước khi lưu',
        description:
            'Sau khi quét, kiểm tra tên, số lượng và giá của từng dòng. Chỉ xác nhận những món đúng.',
      ),
      _PageTip(
        title: 'Thực phẩm được đồng bộ',
        description:
            'Các món đã xác nhận sẽ xuất hiện trong tủ lạnh chung của gia đình.',
      ),
    ],
    [
      _PageTip(
        title: 'Tìm công thức',
        description:
            'Nhập tên món hoặc nguyên liệu. Gợi ý sẽ ưu tiên thực phẩm đang có trong tủ.',
      ),
      _PageTip(
        title: 'Chế độ ăn cá nhân',
        description:
            'Món phù hợp với chế độ ăn trong Hồ sơ được lọc riêng cho bạn; tủ lạnh vẫn dùng chung với gia đình.',
      ),
      _PageTip(
        title: 'Bộ lọc và cách nấu',
        description:
            'Chọn bữa hoặc mùa, rồi mở thẻ món để xem nguyên liệu và từng bước thực hiện.',
      ),
    ],
    [
      _PageTip(
        title: 'Thêm món cần mua',
        description:
            'Thêm thực phẩm vào danh sách đi chợ dùng chung với gia đình.',
      ),
      _PageTip(
        title: 'Lọc danh sách',
        description:
            'Chọn nhóm rau củ, thịt cá hoặc đồ khô để tìm món nhanh hơn.',
      ),
      _PageTip(
        title: 'Đánh dấu đã mua',
        description:
            'Chạm ô chọn của từng món khi mua xong để cập nhật danh sách và chuyển vào tủ.',
      ),
    ],
    [
      _PageTip(
        title: 'Giá trị tủ lạnh',
        description:
            'Tổng giá trị được tính từ những giá bạn đã nhập; giá chưa biết không được tự đoán.',
      ),
      _PageTip(
        title: 'Hoạt động tháng này',
        description:
            'Các ô bên dưới ghi số lần sử dụng, bỏ thực phẩm và bữa đã nấu trong tháng hiện tại.',
      ),
      _PageTip(
        title: 'Đọc chi tiết báo cáo',
        description:
            'Cuộn xuống để xem lịch sử. Báo cáo chỉ thay đổi theo thao tác đã xác nhận.',
      ),
    ],
    [
      _PageTip(
        title: 'Xuất nguyên liệu',
        description:
            'Theo món ăn sẽ gợi ý lượng đã dùng; Thủ công cho chọn từng lô. AI chưa hỗ trợ. Chỉ xác nhận sử dụng mới trừ tồn.',
      ),
      _PageTip(
        title: 'Dùng theo thực đơn',
        description:
            'Chọn ngày, số người đã ăn và món đã nấu. Kiểm tra hoặc sửa lượng thực tế trước khi xuất.',
      ),
      _PageTip(
        title: 'Lịch sử sử dụng',
        description:
            'Mỗi lần xuất có tên người sử dụng, thời gian, nguyên liệu và món ăn để gia đình đối chiếu.',
      ),
    ],
  ];
  int _index = 0;
  int _transitionDirection = 1;
  final Set<int> _visitedTabs = {0};
  bool _showPageTip = false;
  int _tipStep = 0;
  bool _replayingTutorial = false;
  late final AnimationController _tabTransition;
  ModalRoute<dynamic>? _route;

  static const _pages = [
    FridgeScreen(),
    ScanScreen(),
    RecipesScreen(),
    ShoppingScreen(),
    ReportsScreen(),
    UsageScreen(catalog: [...recipeCatalog, ...menuSupportingRecipes]),
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
    replayAppTutorialRequest.addListener(_replayTutorial);
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

  void _replayTutorial() {
    setState(() {
      _replayingTutorial = true;
      _tipStep = 0;
      _showPageTip = true;
    });
    if (_index != 0) _selectTab(0);
    _focusTipTarget();
  }

  GlobalKey _tipTarget(int page, int step) {
    if (page == 0) {
      return step == 3 ? tutorialTargetKeys[0] : tutorialSectionKeys[0][step];
    }
    return step == 0
        ? tutorialTargetKeys[page]
        : tutorialSectionKeys[page][step - 1];
  }

  void _focusTipTarget() {
    final page = _index;
    final step = _tipStep;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_showPageTip || _index != page || _tipStep != step) {
        return;
      }
      final target = _tipTarget(page, step).currentContext;
      if (target != null) {
        // The scrim is a sibling of the scroll view. An animated scroll would
        // leave its cut-out at the old coordinates while the content moves.
        Scrollable.ensureVisible(
          target,
          duration: Duration.zero,
          alignment: .24,
        );
      }
      // The first frame can precede the target's layout (or a scroll jump).
      // Recompute the cut-out once the target has its final screen position.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _showPageTip && _index == page && _tipStep == step) {
          setState(() {});
        }
      });
    });
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
    if (!seen && !_replayingTutorial && AppServices.configured) {
      try {
        seen = await HouseholdDataRepository.instance.isTutorialPageCompleted(
          '${_pageKeys[index]}_v4',
        );
        if (seen) {
          await preferences.setBool(preferenceKey, true);
        }
      } catch (_) {
        // Keep first-use help available even when the network is offline.
      }
    }
    if (mounted && _index == index && (!seen || _replayingTutorial)) {
      setState(() {
        _tipStep = 0;
        _showPageTip = true;
      });
      _focusTipTarget();
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
            .markTutorialPageCompleted('${_pageKeys[pageIndex]}_v4')
            .catchError((_) {}),
      );
    }
    if (mounted) setState(() => _showPageTip = false);
  }

  Future<void> _advancePageTip() async {
    if (_tipStep + 1 < _pageTips[_index].length) {
      setState(() => _tipStep++);
      _focusTipTarget();
      return;
    }
    final next = _navigationPages.indexOf(_index) + 1;
    await _dismissPageTip();
    if (!mounted) return;
    if (next < _pages.length) {
      _selectTab(_navigationPages[next]);
    } else {
      _replayingTutorial = false;
      _selectTab(0);
    }
  }

  Future<void> _skipTutorial() async {
    if (mounted) {
      setState(() {
        _showPageTip = false;
        _replayingTutorial = false;
      });
    }
    final preferences = await SharedPreferences.getInstance();
    final userId = AppServices.configured
        ? AppServices.client.auth.currentUser?.id ?? 'signed-out'
        : 'local';
    for (final page in _pageKeys) {
      await preferences.setBool(
        pageTutorialPreferenceKey(userId: userId, pageKey: page),
        true,
      );
      if (AppServices.configured) {
        unawaited(
          HouseholdDataRepository.instance
              .markTutorialPageCompleted('${page}_v4')
              .catchError((_) {}),
        );
      }
    }
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
    replayAppTutorialRequest.removeListener(_replayTutorial);
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
      _tipStep = 0;
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
                                if (!status.startsWith('Đang'))
                                  TextButton(
                                    onPressed: () async {
                                      try {
                                        await retryPendingInventoryAdds();
                                      } catch (_) {
                                        HouseholdDataRepository
                                                .instance
                                                .syncStatus
                                                .value =
                                            'Chưa tải lại được dữ liệu. Vui lòng thử lại.';
                                      }
                                    },
                                    child: const Text('Thử lại'),
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
                Expanded(
                  child: Row(
                    key: const ValueKey('app-body-row'),
                    children: [
                      if (useRail)
                        NavigationRail(
                          selectedIndex: _navigationPages.indexOf(_index),
                          onDestinationSelected: (value) =>
                              _selectTab(_navigationPages[value]),
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
                              label: Text('Nhập'),
                            ),
                            NavigationRailDestination(
                              icon: Icon(Icons.outbox_outlined),
                              label: Text('Xuất'),
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
          floatingActionButton: _index == 0
              ? FloatingActionButton.extended(
                  key: tutorialTargetKeys[0],
                  heroTag: 'vineat-home-add-food',
                  onPressed: () => homeAddFoodRequest.value++,
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm món'),
                  tooltip: 'Thêm thực phẩm vào tủ lạnh',
                )
              : null,
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          bottomNavigationBar: useRail
              ? null
              : NavigationBar(
                  height: compactNavigationLabels ? 80 : 68,
                  selectedIndex: _navigationPages.indexOf(_index),
                  backgroundColor: Colors.white,
                  indicatorColor: const Color(0xFFE7F8F1),
                  labelBehavior: compactNavigationLabels
                      ? NavigationDestinationLabelBehavior.onlyShowSelected
                      : NavigationDestinationLabelBehavior.alwaysShow,
                  onDestinationSelected: (value) =>
                      _selectTab(_navigationPages[value]),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home),
                      label: 'Trang chủ',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.document_scanner_outlined),
                      label: 'Nhập',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.outbox_outlined),
                      label: 'Xuất',
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
              targetKey: _tipTarget(_index, _tipStep),
              title: _pageTips[_index][_tipStep].title,
              description: _pageTips[_index][_tipStep].description,
              step:
                  _navigationPages
                      .take(_navigationPages.indexOf(_index))
                      .fold<int>(
                        0,
                        (sum, page) => sum + _pageTips[page].length,
                      ) +
                  _tipStep +
                  1,
              totalSteps: _pageTips.fold<int>(
                0,
                (sum, steps) => sum + steps.length,
              ),
              onNext: _advancePageTip,
              onSkip: _skipTutorial,
            ),
          ),
      ],
    );
  }
}
