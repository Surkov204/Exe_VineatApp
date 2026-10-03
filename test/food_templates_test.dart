import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vineat_app/src/food_templates.dart';
import 'package:vineat_app/src/expiry_assistant.dart';
import 'package:vineat_app/src/receipt_models.dart';
import 'package:vineat_app/src/screens.dart';

void main() {
  test('accented, unaccented and combining Vietnamese names match', () {
    for (final name in ['Ức gà', 'uc ga', 'UC GA', 'U\u031B\u0301c ga\u0300']) {
      expect(suggestedExpiryDays(name, 'Tươi / sống'), 1);
    }
    expect(suggestedExpiryDays('thit bo', 'Tươi / sống'), 3);
    expect(suggestedExpiryDays('trung ga', 'Tươi / sống'), 21);
    expect(suggestedExpiryDays('sugar', 'Tươi / sống'), isNull);
  });
  testWidgets(
    'choosing suggestion follows realtime names but preserves manual dates',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final name = TextEditingController(text: 'uc ga');
      DateTime? expiry;
      late StateSetter refresh;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                refresh = setState;
                return ExpiryAssistant(
                  name: name,
                  baseDate: DateTime(2026, 9, 30),
                  expiry: expiry,
                  onChanged: (date) => setState(() => expiry = date),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tươi / sống'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('Dùng gợi ý tự động'));
      await tester.pump();
      expect(expiry, DateTime(2026, 10, 1));
      name.text = 'thit bo';
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      expect(expiry, DateTime(2026, 10, 3));
      name.text = 'khong biet';
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();
      expect(expiry, isNull);
      refresh(() => expiry = DateTime(2027, 1, 1));
      await tester.pump();
      name.text = 'trung ga';
      await tester.pump(const Duration(milliseconds: 200));
      expect(expiry, DateTime(2027, 1, 1));
      expect(name.text, 'trung ga');
      await tester.pumpWidget(const SizedBox.shrink());
      name.dispose();
    },
  );
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'personal templates persist and regenerate relative expiry without sharing mutable lines',
    () async {
      await FoodTemplateStore.save('Đi chợ riêng', [
        ReceiptLine(
          rawName: 'Trứng gà',
          normalizedName: 'Trứng gà',
          quantity: 6,
          unit: 'quả',
          totalPriceVnd: 24000,
          estimatedExpiryDate: DateTime.now().add(const Duration(days: 7)),
        ),
      ]);
      final saved = (await FoodTemplateStore.load()).single;
      expect(saved.name, 'Đi chợ riêng');
      final a = saved.buildLines();
      final b = saved.buildLines();
      a.first.quantity = 99;
      expect(b.first.quantity, 6);
      expect(b.first.totalPriceVnd, 24000);
      expect(
        b.first.estimatedExpiryDate!.difference(DateTime.now()).inDays,
        inInclusiveRange(6, 7),
      );
    },
  );
  test(
    'expiry preferences persist and unknown foods do not get invented dates',
    () async {
      await const ExpiryPreferences(enabled: true, automatic: true).save();
      expect((await ExpiryPreferences.load()).automatic, isTrue);
      expect(suggestedExpiryDays('Ức gà', 'Tươi / sống'), 1);
      expect(suggestedExpiryDays('Trứng gà', 'Tươi / sống'), 21);
      expect(suggestedExpiryDays('Thịt bò', 'Đã nấu chín'), 3);
      expect(suggestedExpiryDays('Sữa đóng hộp', 'Theo bao bì'), isNull);
      expect(suggestedExpiryDays('Món không biết', 'Tươi / sống'), isNull);
    },
  );
  testWidgets(
    'template sheet supports new personal template on compact phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await FoodTemplateStore.save('Mẫu riêng test', [
        ReceiptLine(rawName: 'Trứng gà', normalizedName: 'Trứng gà'),
      ]);
      await tester.pumpWidget(
        const MaterialApp(
          home: ScanScreen(initialMethod: AddFoodMethod.template),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tạo mẫu mới'), findsOneWidget);
      expect(find.text('Mẫu riêng test'), findsOneWidget);
      await tester.tap(find.text('Tạo mẫu mới'));
      await tester.pumpAndSettle();
      expect(find.text('Nhập thực phẩm thủ công'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Ngày hết hạn *'),
        180,
        scrollable: find
            .descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(Scrollable),
            )
            .last,
      );
      expect(find.text('Ngày hết hạn *'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
