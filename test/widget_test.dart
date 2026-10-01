import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:vineat_app/src/reports_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;
import 'package:vineat_app/src/app_services.dart'
    show
        AppServices,
        Household,
        HouseholdSelectionStore,
        HouseholdService,
        appOAuthRedirect,
        debugDemoAuthenticated,
        debugDemoEmail,
        debugDemoOtp,
        debugOtpDemoEnabled,
        profileOAuthRedirect,
        releaseOAuthRedirect;
import 'package:vineat_app/src/app.dart' show VineatApp;
import 'package:vineat_app/src/auth_screens.dart'
    show HouseholdPicker, LoginScreen;
import 'package:vineat_app/src/auth_error_messages.dart'
    show vietnameseAuthError;
import 'package:vineat_app/src/email_validation.dart' show validateLoginEmail;
import 'package:vineat_app/src/diet_preferences.dart'
    show DietKind, DietSelectorField, preferredDiet;
import 'package:vineat_app/src/app_tutorial.dart'
    show
        AnchoredTutorialCoachmark,
        pageTutorialPreferenceKey,
        tutorialSectionKeys,
        tutorialTargetKeys;
import 'package:vineat_app/src/food_detail.dart' show FoodDetailScreen;
import 'package:vineat_app/src/fridge_showcase.dart' show SmartFridgeShowcase;
import 'package:vineat_app/src/inventory_store.dart';
import 'package:vineat_app/src/inventory_models.dart'
    show ShoppingInventoryLink;
import 'package:vineat_app/src/profile_screen.dart' show ProfileScreen;
import 'package:vineat_app/src/recipe_detail.dart'
    show RecipeDetailData, recipeImageAssetFor;
import 'package:vineat_app/src/registration_screen.dart'
    show RegistrationScreen, profileNeedsRegistration;
import 'package:vineat_app/src/screens.dart'
    show FridgeScreen, RecipesScreen, InventoryScreen, ScanScreen;
import 'package:vineat_app/src/vineat_logo.dart' show VineatLogo;

void _noop() {}

void setTestViewport(WidgetTester tester, Size size) {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(() {
    tester.view
      ..resetPhysicalSize()
      ..resetDevicePixelRatio()
      ..resetPadding()
      ..resetViewPadding();
  });
}

void main() {
  test('only the ten requested adult diet modes are available', () {
    expect(DietKind.values.map((diet) => diet.label).toList(), [
      'Không hạn chế',
      'Ăn chay',
      'Thuần chay',
      'Ăn cá không ăn thịt',
      'Ăn thịt không ăn cá',
      'Ưu tiên rau củ',
      'Ăn nhẹ',
      'Ăn tập gym',
      'Không dùng trứng',
      'Ưu tiên ít tinh bột',
    ]);
    expect(DietKind.fromId('no_red_meat'), DietKind.normal);
    expect(DietKind.fromId('fish_forward'), DietKind.pescatarian);
    expect(DietKind.fromId('no_seafood'), DietKind.meatNoFish);
  });
  test('auth errors distinguish server email limits from fast tapping', () {
    const quota = AuthException(
      'Email rate limit exceeded',
      statusCode: '429',
      code: 'over_email_send_rate_limit',
    );
    final quotaMessage = vietnameseAuthError(quota, action: 'send');
    expect(quotaMessage, contains('giới hạn gửi mã'));
    expect(quotaMessage, isNot(contains('thao tác hơi nhanh')));

    const unauthorized = AuthException(
      'Email address not authorized',
      statusCode: '403',
      code: 'email_address_not_authorized',
    );
    expect(
      vietnameseAuthError(unauthorized, action: 'send'),
      contains('chưa được phép nhận mã'),
    );
    const perIp = AuthException(
      'Too many requests',
      statusCode: '429',
      code: 'over_request_rate_limit',
    );
    expect(vietnameseAuthError(perIp, action: 'send'), contains('kết nối này'));
  });

  test(
    'email validation accepts Vietnamese text and rejects malformed input',
    () {
      expect(validateLoginEmail('nguyễn.văn@vídụ.vn'), isNull);
      expect(validateLoginEmail('user.name+tag@example.com'), isNull);
      expect(validateLoginEmail('a@@example.com'), isNotNull);
      expect(validateLoginEmail('a..b@example.com'), isNotNull);
      expect(validateLoginEmail('a@example'), isNotNull);
      expect(validateLoginEmail('a@-example.com'), isNotNull);
      expect(
        validateLoginEmail('demo@vineat.test'),
        contains('không có hộp thư'),
      );
      expect(validateLoginEmail('demo@vineat.test', cloudAuth: false), isNull);
    },
  );

  test('debug preview uses a unique OAuth callback scheme', () {
    expect(
      appOAuthRedirect,
      'com.vineat.team.vineat_app.preview://login-callback',
    );
  });

  test(
    'profile build has its own callback and does not collide with release',
    () {
      expect(
        profileOAuthRedirect,
        'com.vineat.team.vineat_app.profile://login-callback',
      );
      expect({
        appOAuthRedirect,
        profileOAuthRedirect,
        releaseOAuthRedirect,
      }, hasLength(3));
    },
  );

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
      'vineat_page_tutorial_local_home_v4',
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

  test('recipe nutrition estimates use sourced ingredient portions', () {
    final detail = RecipeDetailData.fromSummary(
      name: 'Đậu hũ sốt cà chua',
      time: '20 phút',
      level: 'Dễ',
      image: 4,
      ingredientsText: 'Đậu hũ · Cà chua · Hành lá',
    );
    expect(detail.calories, greaterThan(0));
    expect(detail.protein, greaterThan(0));
    expect(detail.nutrition!.missing, contains('Muối, tiêu'));
    expect(detail.ingredients.first.amount, '200 g');
  });

  test('new test recipes use dish-specific cooking steps', () {
    final oat = RecipeDetailData.fromSummary(
      name: 'Yến mạch chuối sữa chua',
      time: '10 phút',
      level: 'Dễ',
      image: 13,
      ingredientsText: 'Yến mạch · Chuối · Sữa chua',
    );
    final salmon = RecipeDetailData.fromSummary(
      name: 'Salad cá hồi dưa leo',
      time: '20 phút',
      level: 'Dễ',
      image: 15,
      ingredientsText: 'Cá hồi · Dưa leo · Xà lách',
    );
    expect(
      oat.steps.map((step) => step.text).join(' '),
      isNot(contains('Ướp')),
    );
    expect(salmon.steps.map((step) => step.text).join(' '), contains('chín'));
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

  test('remote household snapshots do not reuse prior purchase links', () {
    final previousItem = ShoppingSummary(
      id: 'shopping-a',
      householdId: 'household-a',
      name: 'Cà rốt',
      quantity: 2,
      unit: 'củ',
      category: 'Rau củ',
    );
    final currentItem = ShoppingSummary(
      id: 'shopping-b',
      householdId: 'household-b',
      name: 'Cà rốt',
      quantity: 2,
      unit: 'củ',
      category: 'Rau củ',
    );
    shoppingInventoryLinks[shoppingIdentity(
      previousItem,
    )] = ShoppingInventoryLink(
      food: FoodSummary(
        id: 'food-a',
        householdId: 'household-a',
        name: 'Cà rốt',
        quantity: 2,
        unit: 'củ',
        priceVnd: 0,
        imageIndex: 0,
      ),
      createdByPurchase: true,
    );

    replaceInventoryFromRemote(records: const [], events: const []);
    replaceShoppingFromRemote(items: [currentItem], checked: const {});
    setShoppingPurchased(currentItem, true);

    expect(shoppingInventoryLinks, hasLength(1));
    expect(
      shoppingInventoryLinks[shoppingIdentity(currentItem)]!.food.householdId,
      'household-b',
    );
    expect(inventoryFoods, hasLength(1));
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
      'vineat_page_tutorial_local_home_v4': true,
      'vineat_page_tutorial_local_scan_v4': true,
      'vineat_page_tutorial_local_recipes_v4': true,
      'vineat_page_tutorial_local_shopping_v4': true,
      'vineat_page_tutorial_local_reports_v4': true,
      'vineat_page_tutorial_local_usage_v4': true,
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
      'Tủ lạnh gia đình',
      'Các chỉ số',
      'Cảnh báo hạn dùng',
      'Thêm thực phẩm',
      'Chọn cách nhập hóa đơn',
      'Xem lại trước khi lưu',
      'Thực phẩm được đồng bộ',
      'Xuất nguyên liệu',
      'Dùng theo thực đơn',
      'Lịch sử sử dụng',
      'Tìm công thức',
      'Chế độ ăn cá nhân',
      'Bộ lọc và cách nấu',
      'Thêm món cần mua',
      'Lọc danh sách',
      'Đánh dấu đã mua',
      'Giá trị tủ lạnh',
      'Hoạt động tháng này',
      'Đọc chi tiết báo cáo',
    ];
    expect(find.text('1/19'), findsOneWidget);
    for (var index = 0; index < tips.length; index++) {
      expect(find.text(tips[index]).last, findsOneWidget);
      final coachmark = tester.widget<AnchoredTutorialCoachmark>(
        find.byType(AnchoredTutorialCoachmark),
      );
      expect(
        coachmark.targetKey.currentContext,
        isNotNull,
        reason: 'missing spotlight target at step ${index + 1}',
      );
      final section = tester.getRect(find.byKey(coachmark.targetKey));
      expect(
        find.byKey(const ValueKey('tutorial-highlight-outline')),
        findsOneWidget,
        reason: 'missing spotlight outline at step ${index + 1}',
      );
      final outline = tester.getRect(
        find.byKey(const ValueKey('tutorial-highlight-outline')),
      );
      expect(
        outline.top,
        closeTo(section.top - 7, 1),
        reason: 'spotlight shifted at step ${index + 1}',
      );
      await tester.tap(find.text(index == tips.length - 1 ? 'Xong' : 'Tiếp'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Tủ lạnh của bạn'), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance()).getBool(
        'vineat_page_tutorial_local_home_v4',
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

  testWidgets('spotlight follows the exact section after scrolling', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    setTestViewport(tester, const Size(360, 640));
    await tester.pumpWidget(const VineatApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tiếp'));
    await tester.pumpAndSettle();
    final section = tester.getRect(find.byKey(tutorialSectionKeys[0][1]));
    final outline = tester.getRect(
      find.byKey(const ValueKey('tutorial-highlight-outline')),
    );
    expect(outline.top, closeTo(section.top - 7, 1));
    expect(outline.bottom, closeTo(section.bottom + 7, 1));
    expect(outline.left, closeTo(section.left - 7, 1));
    expect(outline.right, closeTo(section.right + 7, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('home can replay and skip the full guided tour', (tester) async {
    setTestViewport(tester, const Size(320, 568));
    await tester.pumpWidget(const VineatApp());
    await tester.pumpAndSettle();

    expect(find.byTooltip('Xem lại hướng dẫn'), findsOneWidget);
    await tester.tap(find.byTooltip('Xem lại hướng dẫn'));
    await tester.pumpAndSettle();
    expect(find.text('1/19'), findsOneWidget);
    await tester.tap(find.text('Bỏ qua'));
    await tester.pumpAndSettle();
    expect(find.byType(AnchoredTutorialCoachmark), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home date reflects the current device date', (tester) async {
    setTestViewport(tester, const Size(360, 640));
    await tester.pumpWidget(const VineatApp());
    await tester.pumpAndSettle();
    final now = DateTime.now();
    expect(
      find.textContaining('tháng ${now.month} năm ${now.year}'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('home stays below the Android status bar', (tester) async {
    setTestViewport(tester, const Size(360, 640));
    tester.view
      ..viewPadding = const FakeViewPadding(top: 24, bottom: 24)
      // Edge-to-edge Android can report viewPadding while padding is zero.
      ..padding = const FakeViewPadding();

    await tester.pumpWidget(const VineatApp());
    await tester.pumpAndSettle();

    final heading = find.text('Tủ lạnh của bạn');
    expect(tester.getTopLeft(heading).dy, greaterThanOrEqualTo(24));
    expect(find.textContaining('Demo ngoại tuyến'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders the five-screen ViNeat shell', (tester) async {
    setTestViewport(tester, const Size(393, 852));
    await tester.pumpWidget(const VineatApp());
    await tester.pumpAndSettle();

    expect(find.text('Tủ lạnh của bạn'), findsOneWidget);
    expect(find.text('Tổng số món'), findsOneWidget);
    expect(find.text('Còn tươi'), findsOneWidget);
    expect(find.text('Sắp hết hạn'), findsOneWidget);
    expect(find.text('Đã hết hạn'), findsOneWidget);
    expect(find.text('Trang chủ'), findsOneWidget);
    expect(find.text('Nhập'), findsOneWidget);
    expect(find.text('Món ăn'), findsOneWidget);
    expect(find.text('Đi chợ'), findsOneWidget);
    expect(find.text('Báo cáo'), findsOneWidget);
    expect(find.textContaining('Demo ngoại tuyến'), findsNothing);
    expect(
      tester.widget<VineatLogo>(find.byType(VineatLogo).first).symbolOnly,
      isTrue,
    );

    await tester.tap(find.text('Nhập'));
    await tester.pumpAndSettle();
    expect(find.text('Nhập thực phẩm'), findsOneWidget);

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
    final homeAdd = find.byKey(tutorialTargetKeys[0]);
    expect(homeAdd.hitTestable(), findsOneWidget);
    final addBounds = tester.getRect(homeAdd);
    expect(addBounds.right, greaterThan(tester.view.physicalSize.width - 100));
    expect(
      addBounds.bottom,
      greaterThan(tester.view.physicalSize.height - 180),
    );

    await tester.tap(find.text('Món ăn'));
    await tester.pumpAndSettle();
    expect(homeAdd.hitTestable(), findsNothing);
    await tester.tap(find.text('Trang chủ'));
    await tester.pumpAndSettle();
    expect(homeAdd.hitTestable(), findsOneWidget);
  });

  testWidgets('sign-in logo moves into place without fixed demo inventory', (
    tester,
  ) async {
    setTestViewport(tester, const Size(360, 640));
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    final initialLogoTop = tester.getTopLeft(find.byType(VineatLogo)).dy;
    final initialLogoWidth = tester.getSize(find.byType(VineatLogo)).width;
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      tester.getTopLeft(find.byType(VineatLogo)).dy,
      closeTo(initialLogoTop, 1),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 500));
    final spinningLogo = tester.widget<Transform>(
      find.byKey(const ValueKey('login-logo-motion')),
    );
    expect(spinningLogo.transform.entry(0, 0), lessThan(.9));
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.byType(VineatLogo)).dy,
      lessThan(initialLogoTop - 100),
    );
    expect(tester.getTopLeft(find.byType(VineatLogo)).dy, greaterThan(40));
    expect(
      tester.getSize(find.byType(VineatLogo)).width,
      lessThan(initialLogoWidth),
    );
    expect(find.byType(SmartFridgeShowcase), findsNothing);
    expect(find.textContaining('3 món đang có'), findsNothing);
    expect(find.textContaining('dữ liệu mẫu'), findsNothing);
    expect(find.text('Chào mừng bạn về nhà'), findsOneWidget);
    expect(find.text('Email của bạn'), findsOneWidget);
    expect(find.text('Tiếp tục với Google'), findsOneWidget);
    expect(
      tester.getCenter(find.byType(TextField).first).dy,
      inInclusiveRange(640 * .35, 640 * .75),
    );
    expect(
      tester.widget<VineatLogo>(find.byType(VineatLogo)).withBackground,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('login gives an immediate centered Vietnamese email error', (
    tester,
  ) async {
    setTestViewport(tester, const Size(360, 640));
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'sai@@vídụ.vn');
    await tester.tap(find.text('Tiếp tục bằng email'));
    await tester.pumpAndSettle();
    final error = find.text('Email cần đúng dạng ten@mien.com.');
    expect(error, findsOneWidget);
    expect(tester.widget<Text>(error).textAlign, TextAlign.center);
    await tester.enterText(find.byType(TextField).first, 'nguyễn@vídụ.vn');
    await tester.pumpAndSettle();
    expect(error, findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('only an unfinished profile needs registration', () {
    expect(profileNeedsRegistration(null), isTrue);
    expect(profileNeedsRegistration({'display_name': 'Bạn'}), isTrue);
    expect(profileNeedsRegistration({'display_name': 'Nguyễn Lan'}), isFalse);
    expect(
      profileNeedsRegistration({'display_name': 'Bạn'}, hasHousehold: true),
      isFalse,
    );
  });

  testWidgets('existing member chooses which family to open', (tester) async {
    setTestViewport(tester, const Size(360, 640));
    Household? chosen;
    const families = [
      Household(id: 'one', name: 'Nhà Lan', role: 'owner'),
      Household(id: 'two', name: 'Nhà Minh', role: 'member'),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: HouseholdPicker(
          households: families,
          onSelected: (family) => chosen = family,
          onSignOut: _noop,
        ),
      ),
    );
    expect(find.text('Chọn gia đình của bạn'), findsOneWidget);
    expect(find.text('Nhà Lan'), findsOneWidget);
    expect(find.text('Nhà Minh'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('choose-family-two')));
    expect(chosen?.id, 'two');
    expect(tester.takeException(), isNull);
  });

  test(
    'family choice survives restart but is scoped and cleared on sign-out',
    () async {
      SharedPreferences.setMockInitialValues({});
      const families = [
        Household(id: 'one', name: 'Nhà Lan', role: 'owner'),
        Household(id: 'two', name: 'Nhà Minh', role: 'member'),
      ];
      await HouseholdSelectionStore.save('user-a', 'two');
      expect(
        HouseholdSelectionStore.match(
          await HouseholdSelectionStore.read('user-a'),
          families,
        )?.id,
        'two',
      );
      expect(await HouseholdSelectionStore.read('user-b'), isNull);
      expect(HouseholdSelectionStore.match(null, families), isNull);
      expect(HouseholdSelectionStore.match('removed', families), isNull);

      HouseholdService.instance.active.value = families.last;
      await HouseholdService.instance.clearSelectionForUser('user-a');
      expect(await HouseholdSelectionStore.read('user-a'), isNull);
      expect(HouseholdService.instance.active.value, isNull);
    },
  );

  testWidgets('registration asks for a name and accepts a family code', (
    tester,
  ) async {
    setTestViewport(tester, const Size(360, 640));
    await tester.pumpWidget(
      const MaterialApp(
        home: RegistrationScreen(email: 'new@vineat.test', onCompleted: _noop),
      ),
    );
    expect(
      find.byKey(const ValueKey('registration-family-code')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('registration-family-name')),
      findsNothing,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('registration-create-family')),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, -180));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('registration-create-family')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('registration-family-name')),
      findsOneWidget,
    );
    final familyNameField = tester.widget<TextFormField>(
      find.byKey(const ValueKey('registration-family-name')),
    );
    expect(familyNameField.controller!.text, isEmpty);
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const ValueKey('registration-family-name')),
              matching: find.byType(TextField),
            ),
          )
          .decoration!
          .hintText,
      'Gia đình của tôi',
    );
    expect(
      find.byKey(const ValueKey('registration-family-code')),
      findsNothing,
    );
    await tester.scrollUntilVisible(
      find.text('Hoàn tất và tạo gia đình'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Hoàn tất và tạo gia đình'));
    await tester.pumpAndSettle();
    expect(find.text('Nhập họ và tên ít nhất 2 ký tự.'), findsOneWidget);

    await tester.drag(find.byType(ListView).first, const Offset(0, 900));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('registration-full-name')),
      'Nguyễn Lan',
    );
    await tester.enterText(
      find.byKey(const ValueKey('registration-role')),
      'Mẹ',
    );
    expect(
      tester
          .widget<TextField>(
            find.descendant(
              of: find.byKey(const ValueKey('registration-full-name')),
              matching: find.byType(TextField),
            ),
          )
          .hintLocales,
      contains(const Locale('vi', 'VN')),
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('registration-family-name')),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, -140));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('registration-family-name')),
      'Gia đình Nguyễn',
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('registration-family-name')),
          )
          .controller!
          .text,
      'Gia đình Nguyễn',
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('registration-join-family')),
    );
    await tester.tap(find.byKey(const ValueKey('registration-join-family')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('registration-family-code')),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey('registration-family-code')),
      'FAMILY123',
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Hoàn tất và tham gia gia đình'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Hoàn tất và tham gia gia đình'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('registration-family-name')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('diet choices open in a scrollable sheet on a small phone', (
    tester,
  ) async {
    setTestViewport(tester, const Size(320, 640));
    DietKind selected = DietKind.normal;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: DietSelectorField(
              value: selected,
              onChanged: (value) => selected = value,
            ),
          ),
        ),
      ),
    );
    final selectedDiet = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('diet-selector')),
        matching: find.text('Không hạn chế'),
      ),
    );
    expect(selectedDiet.style?.fontWeight, FontWeight.w700);
    await tester.tap(find.byKey(const ValueKey('diet-selector')));
    await tester.pumpAndSettle();
    expect(find.text('Chọn chế độ ăn'), findsOneWidget);
    expect(find.byType(ListView), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('diet-option-high_protein')),
      160,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const ValueKey('diet-option-high_protein')));
    await tester.pumpAndSettle();
    expect(selected, DietKind.highProtein);
    expect(tester.takeException(), isNull);
  });

  testWidgets('recipes immediately follow the chosen dietary preference', (
    tester,
  ) async {
    setTestViewport(tester, const Size(360, 640));
    preferredDiet.value = DietKind.vegan;
    addTearDown(() => preferredDiet.value = DietKind.normal);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: RecipesScreen())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Đậu hũ sốt cà chua'), findsOneWidget);
    expect(find.text('Bò xào cải thảo'), findsNothing);
    expect(find.textContaining('Thuần chay'), findsWidgets);
    expect(find.text('Nguyên tắc dinh dưỡng'), findsNothing);
    preferredDiet.value = DietKind.pescatarian;
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Canh rau muống nấu tôm'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Canh rau muống nấu tôm'), findsOneWidget);
    expect(find.text('Bò xào cải thảo'), findsNothing);
    preferredDiet.value = DietKind.meatNoFish;
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Bò xào cải thảo'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Bò xào cải thảo'), findsOneWidget);
    expect(find.text('Canh rau muống nấu tôm'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  if (debugOtpDemoEnabled) {
    test('private debug session is stored and cleared', () async {
      SharedPreferences.setMockInitialValues({});
      debugDemoAuthenticated.value = false;
      addTearDown(() {
        AppServices.initialized = false;
        debugDemoAuthenticated.value = false;
      });
      await AppServices.signInDebugDemo();
      expect(debugDemoAuthenticated.value, isTrue);
      debugDemoAuthenticated.value = false;
      AppServices.initialized = false;
      await AppServices.initialize();
      expect(debugDemoAuthenticated.value, isTrue);
      await AppServices.signOutDebugDemo();
      expect(debugDemoAuthenticated.value, isFalse);
      AppServices.initialized = false;
      await AppServices.initialize();
      expect(debugDemoAuthenticated.value, isFalse);
      expect(
        (await SharedPreferences.getInstance()).getBool(
          'vineat.debug_auth_session.v1',
        ),
        isNull,
      );
    });

    testWidgets('private debug sign-in rejects a wrong code and signs out', (
      tester,
    ) async {
      debugDemoAuthenticated.value = false;
      addTearDown(() => debugDemoAuthenticated.value = false);
      setTestViewport(tester, const Size(360, 640));
      await tester.pumpWidget(const VineatApp());
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.textContaining('DEMO NGOẠI TUYẾN'), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        isEmpty,
      );

      await tester.enterText(find.byType(TextField).first, debugDemoEmail);
      await tester.tap(find.text('Tiếp tục bằng email'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.text('Mã xác thực'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        isEmpty,
      );

      await tester.enterText(find.byType(TextField).first, '000000');
      await tester.tap(find.text('Xác nhận và đăng nhập'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(
        find.text('Email hoặc mã xác thực chưa chính xác.'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField).first, debugDemoOtp);
      await tester.tap(find.text('Xác nhận và đăng nhập'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Chưa đăng nhập được. Vui lòng thử lại.'), findsNothing);
      expect(debugDemoAuthenticated.value, isTrue);
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.text('Tủ lạnh của bạn'), findsOneWidget);
      expect(find.textContaining('Demo ngoại tuyến'), findsNothing);
      await tester.tap(find.byTooltip('Mở hồ sơ'));
      await tester.pumpAndSettle();
      expect(find.text('Đăng xuất'), findsOneWidget);
      await tester.tap(find.text('Đăng xuất'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('login stays usable with enlarged text and keyboard open', (
    tester,
  ) async {
    setTestViewport(tester, const Size(360, 640));
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Email của bạn'),
      180,
      scrollable: find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    final email = find.byType(TextField).first;
    await tester.enterText(email, 'demo@example.test');
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    final continueButton = find.text('Tiếp tục bằng email');
    await tester.scrollUntilVisible(
      continueButton,
      180,
      scrollable: find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();

    expect(continueButton.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile navigation remains usable at 150% system text', (
    tester,
  ) async {
    setTestViewport(tester, const Size(320, 568));
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(const VineatApp());
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).labelBehavior,
      NavigationDestinationLabelBehavior.onlyShowSelected,
    );
    expect(find.text('Trang chủ').last.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.shopping_basket_outlined).last);
    await tester.pumpAndSettle();
    expect(find.text('Danh sách đi chợ'), findsOneWidget);
    expect(find.text('Thêm món').hitTestable(), findsOneWidget);
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

    for (final tab in ['Nhập', 'Xuất', 'Món ăn', 'Đi chợ', 'Báo cáo']) {
      await tester.tap(find.text(tab).last);
      if (tab == 'Xuất') {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'tab $tab at 393dp');
    }
    await tester.tap(find.text('Trang chủ').last);
    await tester.pumpAndSettle();
    expect(find.text('Tủ lạnh của bạn'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all expiry alerts stay on one horizontally scrollable row', (
    tester,
  ) async {
    setTestViewport(tester, const Size(360, 640));
    inventoryFoods.addAll(
      List.generate(
        8,
        (index) => FoodSummary(
          name: 'Cảnh báo thử $index',
          quantity: 1,
          unit: 'phần',
          priceVnd: 1000,
          imageIndex: -1,
          expiry: DateTime.now().add(const Duration(days: 1)),
        ),
      ),
    );
    addTearDown(resetDemoInventory);
    inventoryRevision.value++;
    await tester.pumpWidget(const VineatApp());
    await tester.pumpAndSettle();
    final alerts = find.byKey(const ValueKey('expiry-alerts-scroll'));
    await tester.ensureVisible(alerts);
    await tester.pumpAndSettle();
    final first = find.descendant(
      of: alerts,
      matching: find.text('Cảnh báo thử 0'),
    );
    final last = find.descendant(
      of: alerts,
      matching: find.text('Cảnh báo thử 7'),
    );
    expect(last, findsOneWidget);
    expect(tester.getTopLeft(first).dy, tester.getTopLeft(last).dy);
    await tester.drag(alerts, const Offset(-2000, 0));
    await tester.pumpAndSettle();
    expect(last.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inventory header fits a small phone with enlarged text', (
    tester,
  ) async {
    setTestViewport(tester, const Size(320, 568));
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(const MaterialApp(home: InventoryScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Số món'), findsOneWidget);
    expect(find.text('Tổng giá trị'), findsOneWidget);
    expect(find.text('Sắp hết hạn'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('expiry warning opens the matching food detail', (tester) async {
    setTestViewport(tester, const Size(360, 640));
    await tester.pumpWidget(const VineatApp());
    await tester.pumpAndSettle();
    final food = inventoryFoods.firstWhere(
      (food) => food.status != 'Tươi ngon',
    );
    final alerts = find.byKey(const ValueKey('expiry-alerts-scroll'));
    await tester.ensureVisible(alerts);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: alerts, matching: find.text(food.name)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(FoodDetailScreen), findsOneWidget);
    expect(
      tester.widget<FoodDetailScreen>(find.byType(FoodDetailScreen)).food.id,
      food.id,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('tapping the fridge brings the inventory into view', (
    tester,
  ) async {
    setTestViewport(tester, const Size(360, 640));
    await tester.pumpWidget(const VineatApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-fridge-inventory')));
    await tester.pumpAndSettle();
    expect(find.text('Tất cả thực phẩm').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('fridge priority chip filters without covering home content', (
    tester,
  ) async {
    setTestViewport(tester, const Size(320, 568));

    await tester.pumpWidget(const VineatApp());
    await tester.pumpAndSettle();
    expect(inventoryFoods.map((food) => food.name), contains('Cà chua'));

    final priorityChip = find.ancestor(
      of: find.text('Sắp hết hạn'),
      matching: find.byType(InkWell),
    );
    await tester.ensureVisible(priorityChip);
    await tester.pumpAndSettle();
    expect(priorityChip.hitTestable(), findsOneWidget);
    await tester.tap(priorityChip);
    await tester.pumpAndSettle();
    final fridgeList = find
        .descendant(
          of: find.byType(FridgeScreen),
          matching: find.byType(CustomScrollView),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Món cần ưu tiên'),
      100,
      scrollable: find
          .descendant(of: fridgeList, matching: find.byType(Scrollable))
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Món cần ưu tiên'), findsOneWidget);
    expect(find.text('Cà chua'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Cá basa fillet'),
      100,
      scrollable: find
          .descendant(of: fridgeList, matching: find.byType(Scrollable))
          .first,
    );
    expect(find.text('Cá basa fillet'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text('Bỏ lọc'),
      -100,
      scrollable: find
          .descendant(of: fridgeList, matching: find.byType(Scrollable))
          .first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Bỏ lọc').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Bỏ lọc'));
    await tester.pumpAndSettle();
    expect(find.text('Thực phẩm trong tủ'), findsOneWidget);
    await tester.drag(fridgeList, const Offset(0, 520));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Cà chua'),
      180,
      scrollable: find
          .descendant(
            of: find.byType(FridgeScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Cà chua'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long inventory remains reachable above the fixed navigation', (
    tester,
  ) async {
    setTestViewport(tester, const Size(320, 568));
    final stressFoods = List.generate(
      100,
      (index) => FoodSummary(
        name: 'Thực phẩm dài ${index + 1}',
        quantity: 1,
        unit: 'phần',
        priceVnd: 1000,
        imageIndex: index % 8,
      ),
    );
    addTearDown(resetDemoInventory);

    // Seed the in-memory fixture in one batch so this layout-only test does
    // not enqueue persistence or household-sync operations for 100 items.
    inventoryFoods.addAll(stressFoods);
    inventoryRevision.value++;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const FridgeScreen(),
          bottomNavigationBar: NavigationBar(
            selectedIndex: 0,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home), label: 'Trang chủ'),
              NavigationDestination(
                icon: Icon(Icons.document_scanner),
                label: 'Nhập',
              ),
              NavigationDestination(
                icon: Icon(Icons.restaurant_menu),
                label: 'Món ăn',
              ),
              NavigationDestination(
                icon: Icon(Icons.shopping_basket),
                label: 'Đi chợ',
              ),
              NavigationDestination(
                icon: Icon(Icons.bar_chart),
                label: 'Báo cáo',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final lastFood = find.byWidgetPredicate(
      (widget) => widget is Text && widget.data == 'Thực phẩm dài 100',
    );
    final fridgeList = find
        .descendant(
          of: find.byType(FridgeScreen),
          matching: find.byType(CustomScrollView),
        )
        .first;
    expect(find.byType(FridgeScreen), findsOneWidget);
    expect(lastFood, findsNothing);
    await tester.scrollUntilVisible(
      find.text('Xem tất cả'),
      150,
      scrollable: find
          .descendant(of: fridgeList, matching: find.byType(Scrollable))
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xem tất cả'));
    await tester.pumpAndSettle();
    expect(find.text('Tất cả thực phẩm'), findsOneWidget);
    expect(find.text('Số món'), findsOneWidget);
    expect(find.text('Sắp hết hạn'), findsOneWidget);
    expect(find.text('Còn lại'), findsWidgets);
    expect(find.text('Giá tiền'), findsWidgets);
    final fullList = find.byType(CustomScrollView).last;
    await tester.scrollUntilVisible(
      lastFood,
      400,
      maxScrolls: 150,
      scrollable: find
          .descendant(of: fullList, matching: find.byType(Scrollable))
          .first,
    );
    await tester.pumpAndSettle();

    expect(lastFood.hitTestable(), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byType(TextField),
      -400,
      maxScrolls: 150,
      scrollable: find
          .descendant(of: fullList, matching: find.byType(Scrollable))
          .first,
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Thực phẩm dài 100');
    await tester.pumpAndSettle();
    expect(lastFood, findsOneWidget);
    expect(find.text('Thực phẩm dài 99'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Tổng giá trị tủ lạnh'),
      200,
      scrollable: find
          .descendant(of: fridgeList, matching: find.byType(Scrollable))
          .first,
    );
    expect(find.text('Thực phẩm dài 11'), findsNothing);
    expect(find.byType(NavigationBar).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
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
    await tester.scrollUntilVisible(
      find.text('Gia đình'),
      300,
      scrollable: find.descendant(
        of: find.byType(ProfileScreen),
        matching: find.byType(Scrollable),
      ),
    );
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

    await tester.tap(find.text('Nhập'));
    await tester.pumpAndSettle();
    expect(find.text('Không phải hóa đơn thật'), findsOneWidget);
    expect(find.text('Chưa chọn ảnh hóa đơn'), findsOneWidget);
    expect(find.text('Đặt hóa đơn trong khung'), findsNothing);
    expect(find.text('Quét gần đây'), findsNothing);
    expect(find.text('Winmart'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.dragFrom(const Offset(160, 270), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(find.text('Chọn ảnh'), findsOneWidget);
    expect(find.text('Chụp ảnh'), findsOneWidget);
    await tester.dragFrom(const Offset(160, 270), const Offset(0, 300));
    await tester.pumpAndSettle();

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

  testWidgets('add menu and template workflow fit a compact phone', (
    tester,
  ) async {
    setTestViewport(tester, const Size(320, 568));
    await tester.pumpWidget(const VineatApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(tutorialTargetKeys[0]));
    await tester.pumpAndSettle();
    for (final method in ['scan', 'ai', 'template', 'manual']) {
      expect(
        find.byKey(ValueKey('add-method-$method')).hitTestable(),
        findsOneWidget,
      );
    }
    await tester.tap(find.byKey(const ValueKey('add-method-template')));
    await tester.pumpAndSettle();
    expect(find.text('Chọn mẫu thực phẩm'), findsOneWidget);
    final before = inventoryFoods.length;
    await tester.tap(find.text('Bữa sáng nhanh'));
    await tester.pumpAndSettle();
    final confirm = find.text('Thêm vào tủ').last;
    final inputPage = find.byType(ScanScreen).last;
    await tester.scrollUntilVisible(
      confirm,
      200,
      scrollable: find
          .descendant(of: inputPage, matching: find.byType(Scrollable))
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(inventoryFoods.length, greaterThan(before));
    expect(find.text('Tủ lạnh của bạn'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('add food dialog offers image selection', (tester) async {
    await tester.pumpWidget(const VineatApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('add-method-scan')), findsOneWidget);
    expect(find.byKey(const ValueKey('add-method-ai')), findsOneWidget);
    expect(find.byKey(const ValueKey('add-method-template')), findsOneWidget);
    expect(find.byKey(const ValueKey('add-method-manual')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('add-method-manual')));
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
    await tester.enterText(
      find
          .descendant(
            of: find.byType(RecipesScreen),
            matching: find.byType(TextField),
          )
          .first,
      'Mì cay',
    );
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mì cay trứng lòng đào').first);
    await tester.pumpAndSettle();
    final addMissingIngredients = find.text('Xem lượng cần dùng & đi chợ');
    await tester.ensureVisible(addMissingIngredients);
    await tester.pumpAndSettle();
    await tester.tap(addMissingIngredients);
    await tester.pumpAndSettle();
    final beforeStock = inventoryFoods.map((f) => f.toJson()).toList();
    await tester.tap(find.textContaining('Chốt & mở Đi chợ'));
    await tester.pumpAndSettle();
    expect(inventoryFoods.map((f) => f.toJson()).toList(), beforeStock);

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
    await tester.scrollUntilVisible(
      find.text('Chưa có hoạt động được ghi nhận'),
      250,
      scrollable: find
          .descendant(
            of: find.byType(ReportsScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
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
      matching: find.byType(CustomScrollView),
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
