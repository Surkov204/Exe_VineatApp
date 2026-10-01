import 'package:flutter_test/flutter_test.dart';
import 'package:vineat_app/src/cooking_guide.dart';
import 'package:vineat_app/src/recipe_detail.dart';

void main() {
  test(
    'seasonings scale with recipe servings and name the measuring spoon',
    () {
      final two = cookingGuide('Salad cá hồi dưa leo', 2, ['Cá hồi']);
      final four = cookingGuide('Salad cá hồi dưa leo', 4, ['Cá hồi']);
      expect(two.seasonings.first, '2 muỗng cà phê dầu ăn');
      expect(four.seasonings.first, '4 muỗng cà phê dầu ăn');
      expect(two.seasonings.join(' '), contains('1/4 muỗng cà phê muối'));
      expect(
        two.steps.map((s) => s.text).join(' '),
        contains('tâm cá đạt 63°C'),
      );
    },
  );
  test(
    'plain breakfast omits oil and salt; fish soup has water and measured salt',
    () {
      final oats = cookingGuide('Yến mạch chuối sữa chua', 2, [
        'Yến mạch',
        'Chuối',
      ]);
      expect(oats.steps.map((s) => s.text).join(' '), contains('240 ml nước'));
      expect(oats.seasonings.first, 'Không cần muối, đường hay dầu ăn');
      final soup = cookingGuide('Canh rau muống nấu tôm', 2, ['Tôm sú']);
      expect(soup.seasonings, contains('600 ml nước'));
      expect(soup.seasonings, contains('1/4 muỗng cà phê muối'));
    },
  );
  test('all instructions follow preparation, measured cooking and serving', () {
    for (final name in [
      'Trứng xào cà chua',
      'Cá basa kho tiêu',
      'Phở bò tái',
      'Bánh mì ốp la trứng gà',
      'Mì cay trứng lòng đào',
      'Đậu hũ xào nấm',
      'Bông cải và cà rốt hấp',
    ]) {
      final guide = cookingGuide(name, 2, ['Đậu hũ']);
      expect(guide.steps.length, greaterThanOrEqualTo(3), reason: name);
      expect(
        guide.seasonings.join(' '),
        contains('muỗng cà phê'),
        reason: name,
      );
      expect(guide.steps.every((s) => s.minutes > 0), isTrue);
    }
    final detail = RecipeDetailData.fromSummary(
      name: 'Salad cá hồi dưa leo',
      time: '20 phút',
      level: 'Dễ',
      image: 0,
      ingredientsText: 'Cá hồi · Dưa leo · Cà chua · Xà lách',
    );
    expect(detail.seasonings, isNotEmpty);
    expect(detail.ingredients.map((i) => i.name), isNot(contains('Tỏi')));
  });
}
