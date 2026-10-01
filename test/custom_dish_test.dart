import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vineat_app/src/custom_dish_editor.dart';
import 'package:vineat_app/src/meal_plan.dart';
import 'package:vineat_app/src/menu_ingredients.dart';
import 'package:vineat_app/src/inventory_store.dart';

void main() {
  testWidgets(
    'select fridge ingredient keeps stock identity and chosen amount',
    (tester) async {
      PlannedDish? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (c) => TextButton(
                onPressed: () async {
                  result = await showCustomDishEditor(
                    c,
                    day: DateTime(2030),
                    slot: 'dinner',
                    people: 1,
                    stock: [
                      FoodSummary(
                        id: 'tofu',
                        name: 'Đậu hũ',
                        quantity: 500,
                        unit: 'gram',
                        priceVnd: 20000,
                        imageIndex: 0,
                        expiry: DateTime(2030, 1, 5),
                      ),
                    ],
                  );
                },
                child: const Text('Mở'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Mở'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'Đậu hũ hấp');
      await tester.tap(find.text('Chọn trong tủ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đậu hũ'));
      await tester.pumpAndSettle();
      final fields = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextFormField),
      );
      await tester.enterText(fields.at(1), '200');
      await tester.tap(find.text('Lưu nguyên liệu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thêm món tự nhập'));
      await tester.pumpAndSettle();
      expect(result!.amounts.single.inventoryId, 'tofu');
      expect(result!.amounts.single.quantity, 200);
      expect(tester.takeException(), isNull);
    },
  );
  test('custom amounts persist, scale and subtract compatible stock', () {
    final day = DateTime(2030, 1, 1);
    final dish = PlannedDish(
      date: day,
      slot: 'lunch',
      name: 'Món mới',
      ingredients: const ['Nguyên liệu mới'],
      amounts: const [
        DishIngredient(
          name: 'Nguyên liệu mới',
          quantity: .5,
          unit: 'kg',
          servings: 2,
          inventoryId: 'lot',
        ),
      ],
    );
    final restored = PlannedDish.fromJson(dish.toJson());
    expect(restored.amounts.single.inventoryId, 'lot');
    expect(restored.amounts.single.servings, 2);
    final result = buildMenuPurchases(
      [restored],
      3,
      [
        FoodSummary(
          id: 'lot',
          name: 'Nguyên liệu mới',
          quantity: 200,
          unit: 'gram',
          priceVnd: 10000,
          imageIndex: 0,
          expiry: day,
        ),
      ],
      today: day,
    );
    expect(result.unmeasured, isEmpty);
    expect(result.lines.single.buyQuantity, 550);
    expect(result.lines.single.unit, 'gram');
    final legacy = PlannedDish.fromJson(
      PlannedDish(
        date: day,
        slot: 'lunch',
        name: 'Cũ',
        ingredients: const ['Đậu hũ'],
      ).toJson(),
    );
    expect(legacy.ingredients, ['Đậu hũ']);
    expect(legacy.amounts, isEmpty);
  });
  test(
    'duplicate custom names retain each amount and expired stock is excluded',
    () {
      final day = DateTime(2030, 1, 1);
      final dish = PlannedDish(
        date: day,
        slot: 'lunch',
        name: 'Món',
        amounts: const [
          DishIngredient(name: 'Bí đỏ', quantity: 100, unit: 'gram'),
          DishIngredient(name: 'Bí đỏ', quantity: 200, unit: 'gram'),
        ],
      );
      final result = buildMenuPurchases(
        [dish],
        1,
        [
          FoodSummary(
            name: 'Bí đỏ',
            quantity: 1,
            unit: 'kg',
            priceVnd: 0,
            imageIndex: 0,
            expiry: day.subtract(const Duration(days: 1)),
          ),
        ],
        today: day,
      );
      expect(result.lines.single.buyQuantity, 300);
    },
  );
  testWidgets('compact editor accepts manual ingredient with amount', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    PlannedDish? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (c) => TextButton(
              onPressed: () async {
                result = await showCustomDishEditor(
                  c,
                  day: DateTime(2030),
                  slot: 'lunch',
                  people: 2,
                  stock: [],
                );
              },
              child: const Text('Mở'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Mở'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Canh bí');
    await tester.tap(find.text('Nhập để đi chợ'));
    await tester.pumpAndSettle();
    final fields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(fields.at(0), 'Bí đỏ');
    await tester.enterText(fields.at(1), '300');
    await tester.tap(find.text('Lưu nguyên liệu'));
    await tester.pumpAndSettle();
    expect(find.text('Bí đỏ'), findsOneWidget);
    await tester.tap(find.text('Thêm món tự nhập'));
    await tester.pumpAndSettle();
    expect(result!.name, 'Canh bí');
    expect(result!.amounts.single.quantity, 300);
    expect(result!.amounts.single.servings, 2);
    expect(tester.takeException(), isNull);
  });
}
