import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vineat_app/src/diet_preferences.dart';
import 'package:vineat_app/src/meal_plan.dart';
import 'package:vineat_app/src/meal_plan_screen.dart';
import 'package:vineat_app/src/recipe_detail.dart';
import 'package:vineat_app/src/menu_ingredients.dart';
import 'package:vineat_app/src/menu_shopping_sheet.dart';
import 'package:vineat_app/src/inventory_store.dart';

const catalog = [
  RecipeCatalogItem(
    id: 'oats',
    name: 'Yến mạch trái cây',
    durationMinutes: 10,
    difficulty: RecipeDifficulty.easy,
    imageIndex: 0,
    ingredients: ['Yến mạch', 'Chuối'],
    categories: {RecipeCategory.breakfast},
    diets: {DietKind.vegan},
  ),
  RecipeCatalogItem(
    id: 'tofu',
    name: 'Đậu hũ rau củ',
    durationMinutes: 20,
    difficulty: RecipeDifficulty.easy,
    imageIndex: 0,
    ingredients: ['Đậu hũ', 'Cà chua'],
    diets: {DietKind.vegan},
  ),
  RecipeCatalogItem(
    id: 'beef',
    name: 'Bò xào',
    durationMinutes: 20,
    difficulty: RecipeDifficulty.easy,
    imageIndex: 0,
    ingredients: ['Thịt bò'],
  ),
];

void main() {
  test(
    'day scope excludes other dates; weekly quantities remain separated by day',
    () {
      final day = menuDay(DateTime.now());
      final dishes = [
        PlannedDish(
          date: day,
          slot: 'lunch',
          name: 'Đậu hũ hôm nay',
          ingredients: const ['Đậu hũ'],
        ),
        PlannedDish(
          date: day.add(const Duration(days: 1)),
          slot: 'dinner',
          name: 'Đậu hũ ngày mai',
          ingredients: const ['Đậu hũ'],
        ),
      ];
      expect(menuShoppingDishes(dishes, day, false), hasLength(1));
      final result = buildMenuPurchases(
        dishes,
        1,
        [],
        today: day,
        groupByDay: true,
      );
      expect(result.lines, hasLength(2));
      expect(result.lines.first.buyQuantity, 100);
      expect(result.lines.first.note, isNot(contains('ngày mai')));
    },
  );
  testWidgets(
    'compact shopping sheet recalculates people and accepts manual quantity',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final day = menuDay(DateTime.now());
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
                        name: 'Đậu hũ sốt',
                        ingredients: const ['Đậu hũ'],
                      ),
                    ],
                    stock: [],
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
      expect(find.text('Đi chợ ngày ${day.day}/${day.month}'), findsOneWidget);
      expect(find.text('100 gram'), findsOneWidget);
      await tester.tap(find.byTooltip('Tăng số người'));
      await tester.pumpAndSettle();
      expect(find.text('200 gram'), findsOneWidget);
      await tester.tap(find.text('Sửa lượng'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '350');
      await tester.tap(find.text('Chốt & mở Đi chợ (1)'));
      await tester.pumpAndSettle();
      expect(chosen!.lines.single.buyQuantity, 350);
      expect(chosen!.people, 2);
      expect(tester.takeException(), isNull);
    },
  );
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    preferredDiet.value = DietKind.vegan;
  });
  test('weekly menu has seven days and three slots with diet-safe recipes', () {
    final start = menuWeek(DateTime(2026, 9, 30));
    final result = suggestMenu(catalog, DietKind.vegan, start, 7);
    expect(result, hasLength(49));
    expect(result.any((d) => d.recipeKey == 'beef'), isFalse);
    for (var i = 0; i < 7; i++) {
      final day = start.add(Duration(days: i));
      expect(
        result.where((d) => d.date == day && d.slot == 'breakfast'),
        hasLength(1),
      );
      expect(
        result.where((d) => d.date == day && d.slot == 'lunch'),
        hasLength(3),
      );
      expect(
        result.where((d) => d.date == day && d.slot == 'dinner'),
        hasLength(3),
      );
      expect(
        result
            .where((d) => d.date == start.add(Duration(days: i)))
            .map((d) => d.slot)
            .toSet(),
        mealSlots.keys.toSet(),
      );
    }
    expect(result.first.recipeKey, 'oats');
    expect(PlannedDish.fromJson(result.first.toJson()).name, result.first.name);
  });
  test('local menus survive reload and isolate different weeks', () async {
    final start = menuWeek(DateTime(2026, 9, 30));
    final rows = suggestMenu(catalog, DietKind.vegan, start, 1);
    await WeekMenuStore(start).save(rows);
    expect(await WeekMenuStore(start).load(), hasLength(7));
    expect(
      await WeekMenuStore(start.add(const Duration(days: 7))).load(),
      isEmpty,
    );
    await WeekMenuStore(start).save([]);
    expect(await WeekMenuStore(start).load(), isEmpty);
  });
  test(
    'reconfirm menu preserves manual shopping and does not duplicate unpurchased menu items',
    () async {
      shoppingChecked.clear();
      shoppingItems.clear();
      final day = menuDay(DateTime.now());
      final store = WeekMenuStore(menuWeek(day));
      shoppingItems.add(
        ShoppingSummary(name: 'Món nhập tay', quantity: 1, unit: 'hộp'),
      );
      final line = MenuPurchase('Đậu hũ', 'gram', day)..buyQuantity = 250;
      line.notes.add('Bữa trưa · Đậu hũ (2 người)');
      await store.confirmPurchases([line]);
      await store.confirmPurchases([line]);
      expect(
        shoppingItems.where((s) => s.menuPlanId == store.key),
        hasLength(1),
      );
      expect(shoppingItems.any((s) => s.name == 'Món nhập tay'), isTrue);
      expect(shoppingItems.last.quantity, 250);
      expect(shoppingItems.last.neededDate, day);
      expect(shoppingItems.last.note, contains('Bữa trưa'));
    },
  );
  test(
    'menu quantities scale by people, subtract kg stock once and honor cooking-date expiry',
    () {
      final day = DateTime(2026, 9, 30);
      final dishes = [
        PlannedDish(
          date: day,
          slot: 'lunch',
          name: 'Đậu hũ sốt',
          ingredients: const ['Đậu hũ'],
        ),
        PlannedDish(
          date: day.add(const Duration(days: 1)),
          slot: 'dinner',
          name: 'Đậu hũ hấp',
          ingredients: const ['Đậu hũ'],
        ),
      ];
      final stock = [
        FoodSummary(
          id: 'tofu-stock',
          name: 'Đậu hũ',
          quantity: .25,
          unit: 'kg',
          priceVnd: 10000,
          expiry: day,
          imageIndex: 0,
        ),
      ];
      final result = buildMenuPurchases(dishes, 2, stock, today: day);
      expect(result.lines.single.requiredQuantity, 400);
      expect(result.lines.single.stockUsed, 200);
      expect(result.lines.single.buyQuantity, 200);
      expect(result.lines.single.neededDate, day.add(const Duration(days: 1)));
      expect(result.lines.single.note, contains('Bữa trưa'));
      expect(result.lines.single.note, contains('Bữa tối'));
      expect(
        buildMenuPurchases(dishes, 1, [], today: day).lines.single.buyQuantity,
        200,
      );
    },
  );
  testWidgets('planner creates three meals and deletes one on compact phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: MealPlanScreen(catalog: catalog)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gợi ý 3 bữa'));
    await tester.pumpAndSettle();
    expect(find.text('Yến mạch trái cây'), findsOneWidget);
    final remove = find.byTooltip('Xóa Yến mạch trái cây khỏi thực đơn');
    await tester.ensureVisible(remove);
    await tester.pumpAndSettle();
    await tester.tap(remove);
    await tester.pumpAndSettle();
    expect(find.text('Yến mạch trái cây'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
