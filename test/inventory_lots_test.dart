import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vineat_app/src/food_detail.dart';
import 'package:vineat_app/src/food_notification.dart';
import 'package:vineat_app/src/inventory_store.dart';
import 'package:vineat_app/src/screens.dart';
import 'package:vineat_app/src/food_form_widgets.dart';
import 'package:vineat_app/src/inventory_activity_screen.dart';

void main() {
  testWidgets('food sync notification fits a compact screen', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showFoodNotification(
                context,
                title: 'Đã thêm thực phẩm',
                message: 'Thịt heo · Đã đồng bộ với gia đình',
              ),
              child: const Text('Thêm'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Thêm'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.cloud_done_outlined), findsOneWidget);
    expect(find.text('Thịt heo · Đã đồng bộ với gia đình'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    inventoryFoods.clear();
    inventoryEvents.clear();
  });
  FoodSummary lot(String id, int price, DateTime expiry) => FoodSummary(
    id: id,
    name: 'Cà chua',
    quantity: 2,
    unit: 'kg',
    priceVnd: price,
    expiry: expiry,
    imageIndex: 0,
    audit: const InventoryAudit(addedBy: 'Hoa'),
  );
  test('same-name lots retain independent IDs, dates and audit on edit', () {
    final first = lot('lot-a', 20000, DateTime(2027, 1, 1));
    final second = lot('lot-b', 40000, DateTime(2027, 2, 1));
    addFoodsToInventory([first, second]);
    final detail = FoodDetailData.fromInventory(first);
    expect(detail.expiryValue, first.expiry);
    expect(detail.addedBy, 'Hoa');
    updateFoodInInventory(
      inventoryFoods.first,
      first.copyWith(expiry: DateTime(2027, 3, 1)),
    );
    expect(inventoryFoods, hasLength(2));
    expect(inventoryFoods.last.expiry, second.expiry);
    expect(inventoryFoods.first.audit.updatedBy, 'Bạn');
    final restored = FoodSummary.fromJson(inventoryFoods.first.toJson());
    expect(restored.id, first.id);
    expect(restored.audit.addedBy, 'Hoa');
    expect(restored.expiry, DateTime(2027, 3, 1));
  });
  testWidgets('metric cards filter expiry and sort lot value', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    inventoryFoods.addAll([
      lot('cheap', 20000, DateTime.now().add(const Duration(days: 2))),
      lot('valuable', 40000, DateTime.now().add(const Duration(days: 40))),
    ]);
    await tester.pumpWidget(const MaterialApp(home: InventoryScreen()));
    await tester.tap(find.text('Tổng giá trị'));
    await tester.pumpAndSettle();
    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey('inventory-date-valuable')))
          .dy,
      lessThan(
        tester
            .getTopLeft(find.byKey(const ValueKey('inventory-date-cheap')))
            .dy,
      ),
    );
    await tester.tap(find.text('Sắp hết hạn'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('inventory-date-valuable')), findsNothing);
    expect(find.byKey(const ValueKey('inventory-date-cheap')), findsOneWidget);
    expect(find.text('Còn lại'), findsOneWidget);
    await tester.tap(find.text('Số món'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('inventory-date-valuable')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('edit form opens date picker and retains selected expiry', (
    tester,
  ) async {
    final food = lot('dated', 20000, DateTime(2027, 1, 1));
    FoodDetailData? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              saved = await Navigator.of(context).push<FoodDetailData>(
                MaterialPageRoute(
                  builder: (_) => FoodDetailScreen(
                    food: FoodDetailData.fromInventory(food),
                  ),
                ),
              );
            },
            child: const Text('Mở món'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Mở món'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chỉnh sửa').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FoodChoiceField));
    await tester.pumpAndSettle();
    expect(find.text('Chọn Đơn vị'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('hộp'),
      160,
      scrollable: find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('hộp'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('edit-expiry-date')));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    Navigator.of(
      tester.element(find.byType(DatePickerDialog)),
    ).pop(DateTime(2027, 4, 10));
    await tester.pumpAndSettle();
    expect(find.text('10/04/2027'), findsOneWidget);
    await tester.tap(find.text('Lưu'));
    await tester.pumpAndSettle();
    expect(saved?.expiryValue, DateTime(2027, 4, 10));
    expect(saved?.id, 'dated');
    expect(saved?.quantity, '2 hộp');
    expect(tester.takeException(), isNull);
  });
  test(
    'person labels never expose email and partial use records its actor',
    () {
      expect(foodPersonName('user@gmail.com'), 'Chưa ghi nhận');
      final food = lot('used', 20000, DateTime(2027, 1, 1));
      inventoryFoods.add(food);
      consumeFoodAmount(food, 1);
      expect(inventoryEvents.last.metadata['remaining_quantity'], 1);
      expect(inventoryEvents.last.metadata['actor_name'], 'Bạn');
      expect(inventoryFoods.single.quantity, 1);
      consumeFoodAmount(inventoryFoods.single, 1);
      expect(inventoryEvents.last.metadata['remaining_quantity'], 0);
    },
  );
  testWidgets('activity page and filters fit compact phone', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    inventoryEvents.add(
      InventoryEvent(
        id: 'event',
        type: 'consumed',
        name: 'Cà chua',
        quantity: 2,
        unit: 'kg',
        valueVnd: 20000,
        occurredAt: DateTime.now(),
        metadata: const {'actor_name': 'Hoa', 'remaining_quantity': 0},
      ),
    );
    await tester.pumpWidget(const MaterialApp(home: InventoryActivityScreen()));
    await tester.scrollUntilVisible(find.text('Đã dùng'), 180);
    await tester.tap(find.text('Đã dùng'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Người thao tác: Hoa'), 180);
    expect(find.text('Người thao tác: Hoa'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
