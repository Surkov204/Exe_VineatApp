import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vineat_app/src/app.dart' show VineatApp;
import 'package:vineat_app/src/food_detail.dart' show FoodDetailScreen;
import 'package:vineat_app/src/inventory_store.dart';
import 'package:vineat_app/src/profile_screen.dart' show ProfileScreen;
import 'package:vineat_app/src/screens.dart' show FridgeScreen;

void setTestViewport(WidgetTester tester, Size size) {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(() {
    tester.view
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'vineat_tutorial_completed_v1': true,
      'vineat_page_tutorial_home_v1': true,
      'vineat_page_tutorial_scan_v1': true,
      'vineat_page_tutorial_recipes_v1': true,
      'vineat_page_tutorial_shopping_v1': true,
      'vineat_page_tutorial_reports_v1': true,
    });
    // These helpers reset in-memory fixtures synchronously. Their queued
    // SharedPreferences cleanup must not hold the next widget test open.
    unawaited(resetDemoInventory());
    unawaited(resetDemoShopping());
  });

  testWidgets('first visit tips stay in layout and guide each app tab', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    setTestViewport(tester, const Size(360, 640));

    await tester.pumpWidget(const VineatApp());
    await tester.pumpAndSettle();
    expect(find.text('Bắt đầu với ViNeat'), findsNothing);
    expect(find.text('Mẹo tủ lạnh'), findsOneWidget);
    await tester.tap(find.text('Đã hiểu'));
    await tester.pumpAndSettle();

    const tabs = ['Scan', 'Món ăn', 'Đi chợ', 'Báo cáo'];
    const tips = [
      'Mẹo quét hóa đơn',
      'Mẹo gợi ý món ăn',
      'Mẹo đi chợ',
      'Mẹo báo cáo',
    ];
    for (var index = 0; index < tabs.length; index++) {
      await tester.tap(find.text(tabs[index]));
      await tester.pumpAndSettle();
      expect(find.text(tips[index]), findsOneWidget);
      await tester.tap(find.text('Đã hiểu'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        index + 1,
      );
    }
    expect(find.text('Báo cáo'), findsOneWidget);
    await tester.tap(find.text('Trang chủ'));
    await tester.pumpAndSettle();
    expect(find.text('Tủ lạnh của bạn'), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance()).getBool(
        'vineat_page_tutorial_home_v1',
      ),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders the five-screen ViNeat shell', (tester) async {
    await tester.pumpWidget(const VineatApp());
    await tester.pumpAndSettle();

    expect(find.text('Tủ lạnh của bạn'), findsOneWidget);
    expect(find.text('Trang chủ'), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);
    expect(find.text('Món ăn'), findsOneWidget);
    expect(find.text('Đi chợ'), findsOneWidget);
    expect(find.text('Báo cáo'), findsOneWidget);

    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();
    expect(find.text('Scan hóa đơn'), findsOneWidget);

    await tester.tap(find.text('Món ăn'));
    await tester.pumpAndSettle();
    expect(find.text('Gợi ý món ăn'), findsOneWidget);

    await tester.tap(find.text('Đi chợ'));
    await tester.pumpAndSettle();
    expect(find.text('Danh sách đi chợ'), findsOneWidget);

    await tester.tap(find.text('Báo cáo'));
    await tester.pumpAndSettle();
    expect(find.text('Giá trị thực phẩm đang theo dõi'), findsOneWidget);

    await tester.tap(find.text('Trang chủ'));
    await tester.pumpAndSettle();
    expect(find.text('Tủ lạnh của bạn'), findsOneWidget);
    expect(find.text('Giá trị thực phẩm đang theo dõi'), findsNothing);
  });

  testWidgets('keeps tabs separated on a compact phone', (tester) async {
    setTestViewport(tester, const Size(360, 640));

    await tester.pumpWidget(const VineatApp());
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(tester.getSize(find.byType(IndexedStack)).width, 360);

    await tester.tap(find.text('Món ăn'));
    await tester.pumpAndSettle();
    expect(find.text('Gợi ý món ăn'), findsOneWidget);
    expect(find.text('Tủ lạnh của bạn'), findsNothing);

    await tester.tap(find.text('Đi chợ'));
    await tester.pumpAndSettle();
    expect(find.text('Danh sách đi chợ'), findsOneWidget);
    expect(find.text('Gợi ý món ăn'), findsNothing);

    await tester.tap(find.text('Báo cáo'));
    await tester.pumpAndSettle();
    expect(find.text('Giá trị thực phẩm đang theo dõi'), findsOneWidget);
    expect(find.text('Danh sách đi chợ'), findsNothing);

    await tester.tap(find.text('Trang chủ'));
    await tester.pumpAndSettle();
    expect(find.text('Tủ lạnh của bạn'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fridge priority chip filters without covering home content', (
    tester,
  ) async {
    setTestViewport(tester, const Size(320, 568));

    await tester.pumpWidget(const VineatApp());
    await tester.pumpAndSettle();

    final priorityChip = find.ancestor(
      of: find.text('3 cần ưu tiên'),
      matching: find.byType(InkWell),
    );
    expect(priorityChip.hitTestable(), findsOneWidget);
    await tester.tap(priorityChip);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -420));
    await tester.pumpAndSettle();
    expect(find.text('Món cần ưu tiên'), findsOneWidget);
    expect(find.text('Cà chua'), findsNothing);
    expect(find.text('Cá basa fillet'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Bỏ lọc'));
    await tester.pumpAndSettle();
    expect(find.text('Cà chua'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile and family settings fit a compact phone', (
    tester,
  ) async {
    setTestViewport(tester, const Size(320, 568));

    await tester.pumpWidget(const VineatApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.person_outline).first);
    await tester.pumpAndSettle();

    expect(find.text('Cài đặt'), findsOneWidget);
    expect(find.text('Hồ sơ cá nhân'), findsOneWidget);
    final profileList = find.descendant(
      of: find.byType(ProfileScreen),
      matching: find.byType(ListView),
    );
    expect(profileList, findsOneWidget);
    await tester.drag(profileList, const Offset(0, -720));
    await tester.pumpAndSettle();
    expect(find.text('Gia đình'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('household cache is not reused as local demo import data', () async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      'vineat.household_cache_scope.v1',
      'previous-user:previous-household',
    );
    inventoryFoods.insert(0, (
      'Dữ liệu riêng của gia đình cũ',
      '1 phần · 10đ',
      'Tươi ngon',
      0,
    ));
    addTearDown(() => inventoryFoods.removeAt(0));

    final preview = await localDemoPreviewSnapshot();
    expect(preview.length, demoInventorySeed.length);
    expect(
      preview.any((food) => food.$1 == 'Dữ liệu riêng của gia đình cũ'),
      isFalse,
    );
  });

  testWidgets('supports add-to-shopping flow and 320dp layout', (tester) async {
    setTestViewport(tester, const Size(320, 568));

    await tester.pumpWidget(const VineatApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đi chợ'));
    await tester.pumpAndSettle();
    expect(find.text('Danh sách đi chợ'), findsOneWidget);

    await tester.tap(find.text('Thêm món'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Bắp cải');
    await tester.ensureVisible(find.text('Thêm vào danh sách'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thêm vào danh sách'));
    await tester.pumpAndSettle();
    expect(find.text('Bắp cải'), findsOneWidget);

    await tester.tap(find.text('Báo cáo'));
    await tester.pumpAndSettle();
    expect(find.text('Giá trị thực phẩm đang theo dõi'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('uses a side rail on tablet widths and returns home', (
    tester,
  ) async {
    setTestViewport(tester, const Size(900, 800));

    await tester.pumpWidget(const VineatApp());
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.tap(find.text('Báo cáo'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Giá trị thực phẩm đang theo dõi'), findsOneWidget);
    await tester.tap(find.text('Trang chủ'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Tủ lạnh của bạn'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('add food dialog offers image selection', (tester) async {
    await tester.pumpWidget(const VineatApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('Hình ảnh thực phẩm'), findsOneWidget);
    expect(find.text('Chọn ảnh'), findsOneWidget);
    expect(find.byIcon(Icons.photo_camera_outlined), findsOneWidget);
  });

  testWidgets('marking a shopping item bought adds it to the fridge', (
    tester,
  ) async {
    setTestViewport(tester, const Size(360, 640));
    await tester.pumpWidget(const VineatApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Đi chợ'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();

    expect(inventoryFoods.any((food) => food.$1 == 'Thịt gà ta'), isTrue);
    await tester.tap(find.text('Trang chủ'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('recipe missing ingredients can be added to shopping', (
    tester,
  ) async {
    setTestViewport(tester, const Size(393, 852));
    await tester.pumpWidget(const VineatApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Món ăn'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mì cay trứng lòng đào').first);
    await tester.pumpAndSettle();
    final addMissingIngredients = find.textContaining('món thiếu vào đi chợ');
    await tester.ensureVisible(addMissingIngredients);
    await tester.pumpAndSettle();
    await tester.tap(addMissingIngredients);
    await tester.pumpAndSettle();

    expect(shoppingItems.any((item) => item.$1 == 'Mì'), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('consuming food updates the report from recorded activity', (
    tester,
  ) async {
    setTestViewport(tester, const Size(393, 852));
    await tester.pumpWidget(const VineatApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trang chủ').last);
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
    expect(find.byType(FridgeScreen).hitTestable(), findsOneWidget);
    expect(find.text('Bắt đầu với ViNeat'), findsNothing);

    final fridgeList = find.descendant(
      of: find.byType(FridgeScreen),
      matching: find.byType(ListView),
    );
    await tester.drag(fridgeList.first, const Offset(0, -420));
    await tester.pumpAndSettle();

    final foodTile = find.ancestor(
      of: find.text('500 gram · 65.000đ'),
      matching: find.byType(InkWell),
    );
    await tester.ensureVisible(foodTile);
    await tester.tap(foodTile);
    await tester.pumpAndSettle();
    expect(find.text('Chi tiết thực phẩm'), findsOneWidget);
    final detailList = find.descendant(
      of: find.byType(FoodDetailScreen),
      matching: find.byType(ListView),
    );
    await tester.drag(detailList, const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đã sử dụng hết'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Báo cáo'));
    await tester.pumpAndSettle();
    expect(find.text('Đã sử dụng tháng này'), findsOneWidget);
    expect(find.text('Đã sử dụng Thịt heo ba chỉ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
