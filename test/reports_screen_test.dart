import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vineat_app/src/inventory_store.dart';
import 'package:vineat_app/src/reports_screen.dart';

void main() {
  setUp(() {
    inventoryFoods.clear();
    inventoryEvents.clear();
  });
  for (final scale in [1.0, 1.5]) {
    testWidgets('report cards and actor history fit small screen at $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final now = DateTime.now();
      inventoryFoods.add(
        FoodSummary(
          id: 'food',
          name: 'Cà chua',
          quantity: 2,
          unit: 'kg',
          priceVnd: 40000,
          imageIndex: 0,
          expiry: now.add(const Duration(days: 2)),
        ),
      );
      inventoryEvents.addAll([
        InventoryEvent(
          id: 'newer',
          type: 'consumed',
          name: 'Cà chua cho món canh rau gia đình',
          quantity: .5,
          unit: 'kg',
          valueVnd: 10000,
          occurredAt: now,
          metadata: const {'actor_name': 'Hoa'},
        ),
        InventoryEvent(
          id: 'older',
          type: 'discarded',
          name: 'Rau',
          quantity: 1,
          unit: 'bó',
          valueVnd: 5000,
          occurredAt: now.subtract(const Duration(minutes: 1)),
          metadata: const {'actor_name': 'hidden@example.com'},
        ),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const Scaffold(body: ReportsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('40.000đ'), findsOneWidget);
      expect(find.text('1 sắp hết hạn'), findsOneWidget);
      final scroll = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('Hoạt động tháng này'),
        250,
        scrollable: scroll,
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Hoa ·'), findsOneWidget);
      expect(find.textContaining('hidden@example.com'), findsNothing);
      expect(find.text('0.5 kg · 10.000đ'), findsOneWidget);
      expect(
        tester.getTopLeft(find.textContaining('Đã sử dụng Cà chua')).dy,
        lessThan(tester.getTopLeft(find.text('Đã bỏ Rau')).dy),
      );
      expect(tester.takeException(), isNull);
    });
  }
}
