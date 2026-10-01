import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vineat_app/src/diet_preferences.dart';
import 'package:vineat_app/src/fridge_cleanup_screen.dart';
import 'package:vineat_app/src/inventory_store.dart';
import 'package:vineat_app/src/profile_screen.dart';

FoodSummary food(String name, int days, {double quantity = 1}) => FoodSummary(
  name: name,
  quantity: quantity,
  unit: 'kg',
  priceVnd: 10000,
  imageIndex: 0,
  expiry: DateTime.now().add(Duration(days: days)),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    inventoryFoods.clear();
    preferredDiet.value = DietKind.normal;
  });
  test(
    'cleanup excludes expired, empty and distant stock and filters diet',
    () {
      final urgent = cleanupFoods([
        food('Cà chua', 0),
        food('Cá hồi', 2),
        food('Đậu hũ', 3),
        food('Tỏi', -1),
        food('Trứng gà', 4),
        food('Rau', 1, quantity: 0),
      ], DateTime.now());
      expect(urgent.map((f) => f.name), ['Cà chua', 'Cá hồi', 'Đậu hũ']);
      final vegan = cleanupRecipes(urgent, DietKind.vegan);
      expect(vegan, isNotEmpty);
      expect(vegan.every((r) => r.diets.contains(DietKind.vegan)), isTrue);
    },
  );
  for (final scale in [1.0, 1.5]) {
    testWidgets('compact profile and cleanup fit 360px at $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const ProfileScreen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(DietSelectorField), findsOneWidget);
      expect(find.text('Thành tựu mới'), findsNothing);
      expect(find.text('Dọn tủ lạnh thứ 6'), findsNothing);
      await tester.scrollUntilVisible(find.text('Về ViNeat'), 300);
      expect(find.text('1.0.0'), findsOneWidget);
      expect(find.text('Đặt lại tủ lạnh mẫu'), findsNothing);
      expect(find.textContaining('đồng bộ an toàn qua Supabase'), findsNothing);
      expect(
        find.textContaining('Dữ liệu tủ lạnh hiện được lưu'),
        findsNothing,
      );
      await tester.scrollUntilVisible(find.text('Chỉnh sửa hồ sơ'), -300);
      await tester.tap(find.text('Chỉnh sửa hồ sơ'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '');
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();
      expect(find.text('Vui lòng nhập tên hiển thị.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      inventoryFoods.add(food('Cà chua', 0));
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const FridgeCleanupScreen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 món cần ưu tiên'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -360));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(inventoryFoods.single.quantity, 1);
    });
  }
}
