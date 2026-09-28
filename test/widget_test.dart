import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vineat_app/src/app.dart' show VineatApp;
import 'package:vineat_app/src/auth_screens.dart' show LoginScreen;
import 'package:vineat_app/src/app_tutorial.dart'
    show
        AnchoredTutorialCoachmark,
        pageTutorialPreferenceKey,
        tutorialTargetKeys;
import 'package:vineat_app/src/food_detail.dart' show FoodDetailScreen;
import 'package:vineat_app/src/fridge_showcase.dart' show SmartFridgeShowcase;
import 'package:vineat_app/src/inventory_store.dart';
import 'package:vineat_app/src/inventory_models.dart'
    show ShoppingInventoryLink;
import 'package:vineat_app/src/profile_screen.dart' show ProfileScreen;
import 'package:vineat_app/src/recipe_detail.dart' show recipeImageAssetFor;
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
  test('tutorial completion is isolated per signed-in account', () {
    final accountA = pageTutorialPreferenceKey(
      userId: 'user-a',
      pageKey: 'home',
    );
    final accountB = pageTutorialPreferenceKey(
      userId: 'user-b',
      pageKey: 'home',
    );
    expect(accountA, isNot(accountB));
    expect(
      pageTutorialPreferenceKey(userId: 'local', pageKey: 'home'),
      'vineat_page_tutorial_local_home_v3',
    );
  });

  test('recipe catalog entries use their matching bundled photo', () {
    const expected = {
      'Mì cay trứng lòng đào': 'spicy-noodles-egg',
      'Canh rau muống nấu tôm': 'water-spinach-shrimp-soup',
      'Bò xào cải thảo': 'beef-cabbage-stir-fry',
      'Bánh mì ốp la trứng gà': 'banh-mi-egg',
      'Cá basa kho tiêu': 'caramel-braised-basa',
      'Salad cá thu dầu mè': 'mackerel-sesame-salad',
      'Đậu hũ sốt cà chua': 'tofu-tomato-sauce',
      'Phở bò tái': 'pho-bo-tai',
    };
    for (final entry in expected.entries) {
      expect(
        recipeImageAssetFor(entry.key, 0),
        'assets/recipes/${entry.value}.webp',
      );
    }
  });

  test(
    'inventory models preserve household scope through local persistence',
    () {
      const record = InventoryItemRecord(
        id: 'food-1',
        householdId: 'household-a',
        name: 'Cà chua',
        quantity: 3,
        unit: 'quả',
        priceVnd: 12000,
        expiry: null,
        imageIndex: 1,
      );
      final restored = InventoryItemRecord.fromJson(record.toJson());
      final summary = FoodSummary.fromJson(
        FoodSummary.fromRecord(restored).toJson(),
      );

      expect(restored.householdId, 'household-a');
      expect(summary.householdId, 'household-a');
      expect(summary.copyWith(quantity: 2).householdId, 'household-a');
      final purchaseLink = ShoppingInventoryLink(
        food: summary,
        createdByPurchase: true,
      );
      final restoredLink = ShoppingInventoryLink.fromJson(
        purchaseLink.toJson('shopping-1'),
      );
      expect(restoredLink.food.id, summary.id);
      expect(restoredLink.food.householdId, 'household-a');
    },
  );

  test('shopping items use stable IDs and upgrade legacy detail records', () {
    final legacy = ShoppingSummary.fromJson({
      'name': 'Dứa',
      'detail': '2 quả · Chín vàng',
      'priority': 'Cần mua gấp',
      'by': 'Mẹ',
      'category': 'Rau củ',
    });
    final restored = ShoppingSummary.fromJson(legacy.toJson());

    expect(legacy.id, isNotEmpty);
    expect(restored.id, legacy.id);
    expect(restored.name, 'Dứa');
    expect(restored.quantity, 2);
    expect(restored.unit, 'quả');
    expect(restored.note, 'Chín vàng');
    expect(restored.priority, 'Cần mua gấp');
    expect(restored.createdBy, 'Mẹ');
  });

  test('legacy shopping checkbox index restores as a stable item ID', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      'vineat.demo.shopping.v1',
      jsonEncode({
        'items': [
          {
            'name': 'Dứa',
            'detail': '2 quả · Chín vàng',
            'priority': 'Cần mua gấp',
            'by': 'Mẹ',
            'category': 'Rau củ',
          },
        ],
        'checked': [0],
      }),
    );

    final snapshot = await restoreShopping();
    expect(snapshot, isNotNull);
    expect(snapshot!.checked, {snapshot.items.single.id});
  });

  test('inventory restore reads typed and legacy cached records', () async {
    SharedPreferences.setMockInitialValues({});
    await resetDemoInventory();
    final typedFood = FoodSummary(
      id: 'typed-food',
      householdId: 'household-a',
      name: 'Cà chua',
      quantity: 2.5,
      unit: 'kg',
      priceVnd: 18000,
      expiry: DateTime(2026, 10, 3),
      imageIndex: 2,
      imagePath: r'C:\demo\tomato.jpg',
      note: 'Để ngăn mát',
    );
    SharedPreferences.setMockInitialValues({
      'vineat.demo.inventory.v1': jsonEncode([
        typedFood.toJson(),
        {
          'id': 'legacy-food',
          'name': 'Dứa',
          'detail': '1 quả · 12.000đ',
          'status': 'Còn 4 ngày',
          'image': 5,
          'imagePath': r'C:\demo\pineapple.jpg',
        },
      ]),
    });

    await restoreInventory();

    expect(inventoryFoods, hasLength(2));
    expect(inventoryFoods.first.name, 'Cà chua');
    expect(inventoryFoods.first.quantity, 2.5);
    expect(inventoryFoods.first.householdId, 'household-a');
    expect(inventoryFoods.first.note, 'Để ngăn mát');
    expect(customFoodImagePaths['typed-food'], r'C:\demo\tomato.jpg');
    expect(inventoryFoods.last.name, 'Dứa');
    expect(inventoryFoods.last.imageIndex, 5);
    expect(customFoodImagePaths['legacy-food'], r'C:\demo\pineapple.jpg');
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'vineat_tutorial_completed_v1': true,
      'vineat_page_tutorial_local_home_v3': true,
      'vineat_page_tutorial_local_scan_v3': true,
      'vineat_page_tutorial_local_recipes_v3': true,
      'vineat_page_tutorial_local_shopping_v3': true,
      'vineat_page_tutorial_local_reports_v3': true,
    });
    // These helpers reset in-memory fixtures synchronously. Their queued
    // SharedPreferences cleanup must not hold the next widget test open.
    unawaited(resetDemoInventory());
    unawaited(resetDemoShopping());
  });

  testWidgets('first visit coachmarks target actions and guide each app tab', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    setTestViewport(tester, const Size(360, 640));

    await tester.pumpWidget(const VineatApp());
    await tester.pumpAndSettle();
    expect(find.text('Bắt đầu với ViNeat'), findsNothing);
    const tips = [
      'Mẹo tủ lạnh',
      'Mẹo quét hóa đơn',
      'Mẹo gợi ý món ăn',
      'Mẹo đi chợ',
      'Mẹo báo cáo',
    ];
    expect(find.text('1/5'), findsOneWidget);
    for (var index = 0; index < tips.length; index++) {
      expect(find.text(tips[index]), findsOneWidget);
      await tester.tap(find.text(index == tips.length - 1 ? 'Xong' : 'Tiếp'));
      await tester.pumpAndSettle();
      if (index < tips.length - 1) {
        expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex,
          index + 1,
        );
      }
    }
    expect(find.text('Báo cáo'), findsOneWidget);
    expect(find.text('Giá trị thực phẩm đang theo dõi'), findsOneWidget);
    await tester.tap(find.text('Trang chủ'));
    await tester.pumpAndSettle();
    expect(find.text('Tủ lạnh của bạn'), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance()).getBool(
        'vineat_page_tutorial_local_home_v3',
      ),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('first-use spotlight fits a compact 320dp phone', (tester) async {
    SharedPreferences.setMockInitialValues({});
    setTestViewport(tester, const Size(320, 568));

    await tester.pumpWidget(const VineatApp());
    await tester.pumpAndSettle();

    expect(find.byType(AnchoredTutorialCoachmark), findsOneWidget);
    expect(tutorialTargetKeys[0].currentContext, isNotNull);
    expect(find.text('Tiếp').hitTestable(), findsOneWidget);
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
    expect(find.textContaining('Demo ngoại tuyến'), findsOneWidget);

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

  testWidgets('sign-in keeps the form visible with its interactive preview', (
    tester,
  ) async {
    setTestViewport(tester, const Size(360, 640));
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pumpAndSettle();

    final preview = tester.widget<SmartFridgeShowcase>(
      find.byType(SmartFridgeShowcase),
    );
    expect(preview.active, isTrue);
    expect(find.text('Chào mừng bạn về nhà'), findsOneWidget);
    expect(find.text('Email của bạn'), findsOneWidget);
    expect(find.text('Tiếp tục với Google'), findsOneWidget);
    expect(tester.takeException(), isNull);
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

  testWidgets('five tabs fit a 393dp phone and return to the fridge', (
    tester,
  ) async {
    setTestViewport(tester, const Size(393, 852));
    await tester.pumpWidget(const VineatApp());
    await tester.pumpAndSettle();

    for (final tab in ['Scan', 'Món ăn', 'Đi chợ', 'Báo cáo']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'tab $tab at 393dp');
    }
    await tester.tap(find.text('Trang chủ').last);
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
    expect(inventoryFoods.map((food) => food.name), contains('Cà chua'));

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
    expect(find.text('Thực phẩm trong tủ'), findsOneWidget);
    final fridgeList = find.descendant(
      of: find.byType(FridgeScreen),
      matching: find.byType(ListView),
    );
    await tester.drag(fridgeList, const Offset(0, -300));
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
    inventoryFoods.insert(
      0,
      FoodSummary.fromLegacy(
        name: 'Dữ liệu riêng của gia đình cũ',
        detail: '1 phần · 10đ',
        status: 'Tươi ngon',
        imageIndex: 0,
      ),
    );
    addTearDown(() => inventoryFoods.removeAt(0));

    final preview = await localDemoPreviewSnapshot();
    expect(preview.length, demoInventorySeed.length);
    expect(
      preview.any((food) => food.name == 'Dữ liệu riêng của gia đình cũ'),
      isFalse,
    );
  });

  testWidgets('supports add-to-shopping flow and 320dp layout', (tester) async {
    setTestViewport(tester, const Size(320, 568));
    final originalCheckedIds = {shoppingItems[4].id, shoppingItems[6].id};
    final firstItemId = shoppingItems.first.id;

    await tester.pumpWidget(const VineatApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đi chợ'));
    await tester.pumpAndSettle();
    expect(find.text('Danh sách đi chợ'), findsOneWidget);

    await tester.tap(find.text('Thêm món'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Bắp cải');
    await tester.enterText(find.byType(TextField).at(1), '0');
    await tester.ensureVisible(find.text('Thêm vào danh sách'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thêm vào danh sách'));
    await tester.pumpAndSettle();
    expect(find.text('Nhập số lượng lớn hơn 0'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(1), '2.5');
    await tester.ensureVisible(find.text('Thêm vào danh sách'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thêm vào danh sách'));
    await tester.pumpAndSettle();
    expect(find.text('Bắp cải'), findsOneWidget);
    expect(
      shoppingItems.singleWhere((item) => item.name == 'Bắp cải').quantity,
      2.5,
    );

    await tester.tap(find.text('Thêm món'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Bắp cải');
    await tester.ensureVisible(find.text('Thêm vào danh sách'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thêm vào danh sách'));
    await tester.pumpAndSettle();
    expect(find.text('Bắp cải đã có trong danh sách'), findsOneWidget);
    expect(find.text('Bắp cải'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Bắp cải đã có trong danh sách'), findsNothing);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();
    expect(shoppingItems.any((item) => item.id == firstItemId), isFalse);
    expect(shoppingChecked, containsAll(originalCheckedIds));

    await tester.tap(find.text('Báo cáo'));
    await tester.pumpAndSettle();
    expect(find.text('Giá trị thực phẩm đang theo dõi'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('labels sample lists honestly and fits Scan on a small phone', (
    tester,
  ) async {
    setTestViewport(tester, const Size(320, 568));
    await tester.pumpWidget(const VineatApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();
    expect(find.text('Không phải hóa đơn thật'), findsOneWidget);
    expect(find.text('Quét gần đây'), findsNothing);
    expect(find.text('Winmart'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Dữ liệu mẫu').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đi chợ hàng tuần'));
    await tester.pumpAndSettle();

    expect(find.text('Dữ liệu mẫu · không phải OCR'), findsOneWidget);
    expect(find.text('Kết quả OCR · cần kiểm tra'), findsNothing);
    expect(
      find.text('Danh sách minh họa, không đại diện hóa đơn thật.'),
      findsOneWidget,
    );
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

    expect(inventoryFoods.any((food) => food.name == 'Thịt gà ta'), isTrue);
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

    expect(shoppingItems.any((item) => item.name == 'Mì'), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('consuming food updates the report from recorded activity', (
    tester,
  ) async {
    setTestViewport(tester, const Size(393, 852));
    await tester.pumpWidget(const VineatApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Báo cáo').last);
    await tester.pumpAndSettle();
    expect(find.text('Chưa có hoạt động được ghi nhận'), findsOneWidget);
    expect(find.text('Xu hướng (dữ liệu minh họa)'), findsNothing);
    expect(find.text('So sánh (dữ liệu minh họa)'), findsNothing);
    expect(find.text('Mục tiêu mẫu'), findsNothing);

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
    expect(find.text('Xu hướng (dữ liệu minh họa)'), findsNothing);
    expect(find.text('Mục tiêu mẫu'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
