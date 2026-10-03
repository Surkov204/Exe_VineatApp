import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vineat_app/src/inventory_store.dart';
import 'package:vineat_app/src/meal_plan.dart';
import 'package:vineat_app/src/screens.dart';
import 'package:vineat_app/src/shopping_menu_sheet.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    shoppingChecked.clear();
    shoppingItems.clear();
  });
  test(
    'menu notes separate schedule, dish and people without losing legacy text',
    () {
      final uses = shoppingMenuUses(
        'T5 1/10 · Bữa trưa · Salad cá hồi (2 người); CN 4/10 · Bữa tối · Canh rau (3 người)',
      );
      expect(uses.first.dish, 'Salad cá hồi');
      expect(uses.first.people, 2);
      expect(uses.last.schedule, 'CN 4/10 · Bữa tối');
      expect(
        shoppingMenuUses('Thiếu cho món Canh rau').single.dish,
        'Thiếu cho món Canh rau',
      );
      expect(shoppingQuantity(240), '240');
      expect(shoppingQuantity(.5), '0.5');
    },
  );
  testWidgets(
    'shopping cards show purchase amount and dish ingredients on small screen',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final day = DateTime(2026, 10, 1);
      await WeekMenuStore(menuWeek(day)).save([
        PlannedDish(
          date: day,
          slot: 'lunch',
          name: 'Salad cá hồi',
          ingredients: const ['Cà chua', 'Cá hồi'],
        ),
      ]);
      shoppingItems.add(
        ShoppingSummary(
          name: 'Cà chua',
          quantity: 240,
          unit: 'gram',
          menuPlanId: 'menu',
          neededDate: day,
          menuDay: day,
          note: 'T5 1/10 · Bữa trưa · Salad cá hồi (2 người)',
        ),
      );
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ShoppingScreen())),
      );
      await tester.pumpAndSettle();
      expect(find.text('240 gram'), findsOneWidget);
      await tester.ensureVisible(find.text('Nấu: Salad cá hồi'));
      await tester.tap(find.text('Nấu: Salad cá hồi'));
      await tester.pumpAndSettle();
      expect(find.text('Mua để nấu món gì?'), findsOneWidget);
      expect(find.text('Salad cá hồi'), findsOneWidget);
      expect(find.text('T5 1/10 · Bữa trưa · 2 người'), findsOneWidget);
      expect(find.textContaining('Cá hồi ·'), findsOneWidget);
      expect(shoppingChecked, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
