import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vineat_app/src/recipe_nutrition.dart';
import 'package:vineat_app/src/recipe_detail.dart';
import 'package:vineat_app/src/nutrition_usda.dart';

void main() {
  test('USDA calorie math uses 100 g edible reference and deduplicates', () {
    final result = estimateRecipeNutrition(['Cá hồi', 'Cá hồi', 'Dưa leo']);
    expect(
      result.values[0],
      closeTo(
        usdaNutrients[175167]![0]! + usdaNutrients[168409]![0]! * .8,
        .0001,
      ),
    );
    expect(result.values[1], greaterThan(20));
    expect(result.missing, isEmpty);
  });
  test('unknown food has no invented nutrients; assumptions stay explicit', () {
    expect(estimateRecipeNutrition(['Món lạ']).hasData, isFalse);
    final estimate = estimateRecipeNutrition(['Cá basa fillet', 'Gia vị']);
    expect(estimate.assumptions.single, contains('không phải số liệu riêng'));
    expect(estimate.missing, ['Gia vị']);
    expect(usdaDescriptions[175165], contains('catfish'));
  });
  test('oat breakfast does not implicitly include garlic or frying oil', () {
    final detail = RecipeDetailData.fromSummary(
      name: 'Yến mạch chuối sữa chua',
      time: '10 phút',
      level: 'Dễ',
      image: 0,
      ingredientsText: 'Yến mạch · Chuối · Sữa chua',
    );
    expect(detail.ingredients.map((i) => i.name), isNot(contains('Dầu ăn')));
    expect(detail.ingredients.map((i) => i.name), isNot(contains('Tỏi')));
    expect(detail.calories, greaterThan(250));
  });
  for (final scale in [1.0, 1.5]) {
    testWidgets('nutrition readable on 360dp with text scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final recipe = RecipeDetailData.fromSummary(
        name: 'Salad cá hồi dưa leo',
        time: '20 phút',
        level: 'Dễ',
        image: 0,
        ingredientsText: 'Cá hồi · Dưa leo · Cà chua · Xà lách',
      );
      await tester.pumpWidget(
        MaterialApp(
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(
              c,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: RecipeDetailScreen(recipe: recipe),
        ),
      );
      await tester.pumpAndSettle();
      final scroll = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('Dinh dưỡng (mỗi suất)'),
        250,
        scrollable: scroll,
      );
      await tester.pumpAndSettle();
      expect(find.text('Chất đạm'), findsOneWidget);
      expect(find.text('Chất xơ'), findsOneWidget);
      expect(find.text('Vitamin B12'), findsNothing);
      expect(find.text('Cholesterol'), findsNothing);
      expect(find.text('Nguồn dữ liệu & giả định'), findsNothing);
      expect(find.text('Chuẩn bị gia vị'), findsNothing);
      expect(find.textContaining('Dùng muỗng đong gạt ngang'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
