import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vineat_app/src/inventory_store.dart';
import 'package:vineat_app/src/inventory_usage.dart';
import 'package:vineat_app/src/meal_plan.dart';
import 'package:vineat_app/src/menu_ingredients.dart';
import 'package:vineat_app/src/menu_shopping_sheet.dart';
import 'package:vineat_app/src/usage_screen.dart';

FoodSummary tofu(String id, double quantity, DateTime expiry) => FoodSummary(
  id: id,
  name: 'Đậu hũ',
  quantity: quantity,
  unit: 'kg',
  priceVnd: 20000,
  imageIndex: 0,
  expiry: expiry,
);

void main() {
  test(
    'count-unit ingredients auto-select without false weight conversion',
    () {
      final day = menuDay(DateTime.now());
      final stock = [
        FoodSummary(
          id: 'tomato',
          name: 'Ca chua',
          quantity: 4,
          unit: 'quả',
          priceVnd: 20000,
          imageIndex: 0,
          expiry: day,
        ),
      ];
      final plan = planDishUsage(
        PlannedDish(
          date: day,
          slot: 'breakfast',
          name: 'Trứng cà chua',
          ingredients: const ['Cà chua'],
        ),
        2,
        stock,
      );
      expect(plan.uses.single.quantity, 2);
      expect(plan.recipeLotIds, {'tomato'});
      expect(plan.notes['tomato'], contains('không phải quy đổi'));
      expect(plan.missing, isEmpty);
      expect(stock.single.quantity, 4);
    },
  );
  test('unknown or explicitly incompatible units require actual quantity', () {
    final day = menuDay(DateTime.now());
    final stock = [
      FoodSummary(
        id: 'tomato',
        name: 'Cà chua',
        quantity: 4,
        unit: 'quả',
        priceVnd: 0,
        imageIndex: 0,
        expiry: day,
      ),
    ];
    final plan = planDishUsage(
      PlannedDish(
        date: day,
        slot: 'lunch',
        name: 'Tự nhập',
        amounts: const [
          DishIngredient(name: 'Cà chua', quantity: 300, unit: 'gram'),
        ],
      ),
      1,
      stock,
    );
    expect(plan.uses.single.quantity, 0);
    expect(plan.notes['tomato'], contains('Nhập lượng thực tế'));
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    inventoryFoods.clear();
    inventoryEvents.clear();
  });
  test('export reuses saved menu people by day and week', () async {
    final day = menuDay(DateTime.now());
    final store = WeekMenuStore(menuWeek(day));
    await store.savePeople(4);
    await store.savePeople(2, day: day);
    expect(await WeekMenuStore(store.week).plannedPeople(day), 2);
    expect(
      await WeekMenuStore(store.week).plannedPeople(
        day.weekday == 7
            ? day.subtract(const Duration(days: 1))
            : day.add(const Duration(days: 1)),
      ),
      4,
    );
    expect(
      await WeekMenuStore(
        store.week.add(const Duration(days: 7)),
      ).plannedPeople(day.add(const Duration(days: 7))),
      1,
    );
  });
  testWidgets('export has compact actions without a people stepper', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: UsageScreen(catalog: [])),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Theo món ăn'), findsOneWidget);
    expect(find.byTooltip('Trừ thủ công'), findsOneWidget);
    expect(find.byTooltip('AI · Sắp có'), findsOneWidget);
    expect(find.byTooltip('Tải lại thực đơn'), findsOneWidget);
    expect(find.text('Số người đã ăn'), findsNothing);
    expect(find.text('Bạn đã sử dụng theo cách nào?'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  test('shopping includes covered ingredients without changing any stock', () {
    final day = menuDay(DateTime.now());
    final stock = [tofu('one', 1, day.add(const Duration(days: 3)))];
    final before = stock.single.toJson();
    final dish = PlannedDish(
      date: day,
      slot: 'lunch',
      name: 'Đậu hấp',
      ingredients: const ['Đậu hũ'],
    );
    final result = buildMenuPurchases([dish], 2, stock, includeCovered: true);
    expect(result.lines.single.requiredQuantity, 200);
    expect(result.lines.single.stockAvailable, 1000);
    expect(result.lines.single.buyQuantity, 0);
    expect(stock.single.toJson(), before);
    expect(inventoryEvents, isEmpty);
  });
  test(
    'dish usage allocates lots FEFO and never takes expired or missing stock',
    () {
      final day = menuDay(DateTime.now());
      final stock = [
        tofu('later', .5, day.add(const Duration(days: 3))),
        tofu('first', .05, day),
        tofu('expired', 1, day.subtract(const Duration(days: 1))),
      ];
      final dish = PlannedDish(
        date: day,
        slot: 'dinner',
        name: 'Món tự nhập',
        amounts: const [
          DishIngredient(name: 'Đậu hũ', quantity: 300, unit: 'gram'),
          DishIngredient(name: 'Bí đỏ', quantity: 100, unit: 'gram'),
        ],
      );
      final plan = planDishUsage(dish, 1, stock);
      expect(plan.uses.map((u) => u.food.id), ['first', 'later']);
      expect(plan.uses.first.quantity, .05);
      expect(plan.uses.last.quantity, .25);
      expect(plan.missing.single, contains('Bí đỏ'));
      expect(stock.first.quantity, .5);
    },
  );
  test(
    'invalid batch is rejected without partial deduction; explicit use reduces gradually',
    () async {
      final day = menuDay(DateTime.now());
      final a = tofu('a', 1, day), b = tofu('b', .1, day);
      inventoryFoods.addAll([a, b]);
      await expectLater(
        confirmInventoryUsage([
          InventoryUsage(food: a, quantity: .2),
          InventoryUsage(food: b, quantity: .2),
        ], operationId: 'bad'),
        throwsStateError,
      );
      expect(inventoryFoods.first.quantity, 1);
      expect(inventoryEvents, isEmpty);
      await confirmInventoryUsage([
        InventoryUsage(food: a, quantity: .2),
      ], operationId: 'good');
      expect(inventoryFoods.first.quantity, .8);
      expect(inventoryFoods.first.priceVnd, 16000);
      expect(inventoryEvents.single.type, 'consumed');
    },
  );
  testWidgets(
    'covered shopping preview shows three quantities and creates no purchase',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final day = menuDay(DateTime.now());
      final food = tofu('one', 1, day);
      MenuShoppingSelection? chosen;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (c) => TextButton(
                onPressed: () async {
                  chosen = await showMenuShoppingSheet(
                    c,
                    dishes: [
                      PlannedDish(
                        date: day,
                        slot: 'lunch',
                        name: 'Hấp',
                        ingredients: const ['Đậu hũ'],
                      ),
                    ],
                    stock: [food],
                    people: 1,
                    weekly: false,
                    day: day,
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
      expect(find.text('Cần dùng'), findsOneWidget);
      expect(find.text('Có sẵn'), findsOneWidget);
      expect(find.text('Cần mua'), findsOneWidget);
      expect(find.text('1000'), findsOneWidget);
      await tester.tap(find.text('Chốt & mở Đi chợ (0)'));
      await tester.pumpAndSettle();
      expect(chosen!.lines, isEmpty);
      expect(food.quantity, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('manual export requires confirmation and shows remaining stock', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final day = menuDay(DateTime.now());
    inventoryFoods.add(tofu('one', 1, day));
    bool? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (c) => TextButton(
              onPressed: () async {
                saved = await showInventoryUsageSheet(c);
              },
              child: const Text('Mở'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Mở'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '0.2');
    await tester.pumpAndSettle();
    expect(find.text('Sau khi xuất: 0.8 kg'), findsOneWidget);
    expect(inventoryFoods.single.quantity, 1);
    await tester.tap(find.text('Xác nhận xuất (1)'));
    await tester.pumpAndSettle();
    expect(saved, true);
    expect(inventoryFoods.single.quantity, .8);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'dish usage preselects correct quantities and cancel changes nothing',
    (tester) async {
      final day = menuDay(DateTime.now());
      inventoryFoods.add(tofu('one', 1, day));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (c) => TextButton(
                onPressed: () => showInventoryUsageSheet(
                  c,
                  dish: PlannedDish(
                    date: day,
                    slot: 'dinner',
                    name: 'Đậu hấp',
                    ingredients: const ['Đậu hũ'],
                  ),
                  people: 2,
                ),
                child: const Text('Mở'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Mở'));
      await tester.pumpAndSettle();
      expect(tester.widget<Checkbox>(find.byType(Checkbox).first).value, true);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        '0.2',
      );
      Navigator.of(tester.element(find.text('Đậu hấp'))).pop();
      await tester.pumpAndSettle();
      expect(inventoryFoods.single.quantity, 1);
      expect(inventoryEvents, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'dish groups, unchecking, quantity edits and extra ingredients affect only selected stock',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final day = menuDay(DateTime.now());
      inventoryFoods.addAll([
        FoodSummary(
          id: 'carrot',
          name: 'Cà rốt',
          quantity: 3,
          unit: 'củ',
          priceVnd: 10000,
          imageIndex: 0,
          expiry: day,
        ),
        FoodSummary(
          id: 'tomato',
          name: 'Cà chua',
          quantity: 4,
          unit: 'quả',
          priceVnd: 10000,
          imageIndex: 0,
          expiry: day,
        ),
        FoodSummary(
          id: 'egg',
          name: 'Trứng gà',
          quantity: 6,
          unit: 'quả',
          priceVnd: 10000,
          imageIndex: 0,
          expiry: day,
        ),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (c) => TextButton(
                onPressed: () => showInventoryUsageSheet(
                  c,
                  dish: PlannedDish(
                    date: day,
                    slot: 'breakfast',
                    name: 'Trứng xào cà chua',
                    ingredients: const ['Trứng gà', 'Cà chua'],
                  ),
                ),
                child: const Text('Mở'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Mở'));
      await tester.pumpAndSettle();
      expect(find.text('Nguyên liệu của món · 1 người'), findsOneWidget);
      expect(find.byKey(const ValueKey('usage-lot-carrot')), findsNothing);
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('usage-lot-tomato')),
            )
            .value,
        true,
      );
      await tester.enterText(
        find.byKey(const ValueKey('usage-amount-tomato')),
        '2',
      );
      final listScrollable = find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('usage-lot-egg')),
        100,
        scrollable: listScrollable,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('usage-lot-egg')));
      await tester.pumpAndSettle();
      final more = find.text('Dùng thêm nguyên liệu khác (1)');
      await tester.scrollUntilVisible(more, 100, scrollable: listScrollable);
      await tester.pumpAndSettle();
      await tester.tap(more);
      await tester.pumpAndSettle();
      expect(find.text('Nguyên liệu dùng thêm'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('usage-lot-carrot')),
        100,
        scrollable: listScrollable,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('usage-lot-carrot')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('usage-amount-carrot')),
        '0.5',
      );
      expect(inventoryFoods.first.quantity, 3);
      await tester.tap(find.text('Xác nhận xuất (2)'));
      await tester.pumpAndSettle();
      expect(inventoryFoods.firstWhere((f) => f.id == 'carrot').quantity, 2.5);
      expect(inventoryFoods.firstWhere((f) => f.id == 'tomato').quantity, 2);
      expect(inventoryFoods.firstWhere((f) => f.id == 'egg').quantity, 6);
      expect(tester.takeException(), isNull);
    },
  );
}
