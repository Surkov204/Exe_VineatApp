import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vineat_app/main.dart' as app;

void setTestViewport(WidgetTester tester, Size size) {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(() {
    tester.view
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });
}

void main() {
  setUp(
    () => SharedPreferences.setMockInitialValues({
      'vineat_tutorial_completed_v1': true,
    }),
  );

  testWidgets('first-run guide walks through each app tab', (tester) async {
    SharedPreferences.setMockInitialValues({});
    setTestViewport(tester, const Size(360, 640));

    app.main();
    await tester.pumpAndSettle();
    expect(find.text('Bắt đầu với ViNeat'), findsOneWidget);

    for (var index = 1; index < 5; index++) {
      await tester.tap(find.text('Tiếp'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        index,
      );
    }
    expect(find.text('Báo cáo'), findsNWidgets(2));
    await tester.tap(find.text('Bắt đầu sử dụng'));
    await tester.pumpAndSettle();
    expect(find.text('Tủ lạnh của bạn'), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance()).getBool(
        'vineat_tutorial_completed_v1',
      ),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

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

    await tester.tap(find.text('Trang chủ'));
    await tester.pumpAndSettle();
    expect(find.text('Tủ lạnh của bạn'), findsOneWidget);
    expect(find.text('Giá trị trong tủ hiện tại'), findsNothing);
  });

  testWidgets('keeps tabs separated on a compact phone', (tester) async {
    setTestViewport(tester, const Size(360, 640));

    app.main();
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
    expect(find.text('Giá trị trong tủ hiện tại'), findsOneWidget);
    expect(find.text('Danh sách đi chợ'), findsNothing);

    await tester.tap(find.text('Trang chủ'));
    await tester.pumpAndSettle();
    expect(find.text('Tủ lạnh của bạn'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('supports add-to-shopping flow and 320dp layout', (tester) async {
    setTestViewport(tester, const Size(320, 568));

    app.main();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đi chợ'));
    await tester.pumpAndSettle();
    expect(find.text('Danh sách đi chợ'), findsOneWidget);

    await tester.tap(find.text('Thêm món'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Bắp cải');
    await tester.ensureVisible(find.text('Thêm vào danh sách'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thêm vào danh sách'));
    await tester.pumpAndSettle();
    expect(find.text('Bắp cải'), findsOneWidget);

    await tester.tap(find.text('Báo cáo'));
    await tester.pumpAndSettle();
    expect(find.text('Giá trị trong tủ hiện tại'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses a side rail on tablet widths and returns home', (
    tester,
  ) async {
    setTestViewport(tester, const Size(900, 800));

    app.main();
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.tap(find.text('Báo cáo'));
    await tester.pumpAndSettle();
    expect(find.text('Giá trị trong tủ hiện tại'), findsOneWidget);
    await tester.tap(find.text('Trang chủ'));
    await tester.pumpAndSettle();
    expect(find.text('Tủ lạnh của bạn'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('add food dialog offers image selection', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('Hình ảnh thực phẩm'), findsOneWidget);
    expect(find.text('Chọn ảnh'), findsOneWidget);
    expect(find.byIcon(Icons.photo_camera_outlined), findsOneWidget);
  });
}
