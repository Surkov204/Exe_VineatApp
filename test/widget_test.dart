import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vineat_app/main.dart' as app;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('renders the five-screen ViNeat shell', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    expect(find.text('Tủ lạnh của bạn'), findsOneWidget);
    expect(find.text('Trang chủ'), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);
    expect(find.text('Món ăn'), findsOneWidget);
    expect(find.text('Đi chợ'), findsOneWidget);
    expect(find.text('Báo cáo'), findsOneWidget);

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
    expect(find.text('Giá trị trong tủ hiện tại'), findsOneWidget);
  });
}
