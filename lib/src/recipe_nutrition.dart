import 'nutrition_usda.dart';

const nutritionLabels = [
  'Năng lượng',
  'Chất đạm',
  'Tinh bột / carbohydrate',
  'Chất béo',
  'Chất xơ',
  'Đường tổng',
  'Béo bão hòa',
  'Natri',
  'Canxi',
  'Sắt',
  'Kali',
  'Vitamin C',
  'Vitamin A',
  'Vitamin D',
  'Vitamin B12',
  'Cholesterol',
];
const nutritionUnits = [
  'kcal',
  'g',
  'g',
  'g',
  'g',
  'g',
  'g',
  'mg',
  'mg',
  'mg',
  'mg',
  'mg',
  'µg RAE',
  'µg',
  'µg',
  'mg',
];

// Culinary reference portions per person, not a verified recipe or diet prescription.
// Count portions are explicit edible-weight assumptions, not inventory conversions.
const nutritionPortions = <String, ({int id, double grams, String? proxy})>{
  'Cá hồi': (id: 175167, grams: 100, proxy: null),
  'Dưa leo': (id: 168409, grams: 80, proxy: null),
  'Cà chua': (id: 170457, grams: 80, proxy: null),
  'Xà lách': (id: 169249, grams: 80, proxy: null),
  'Tỏi': (id: 169230, grams: 5, proxy: null),
  'Dầu ăn': (
    id: 172336,
    grams: 4.6,
    proxy: 'Dầu canola; giả định 5 ml ≈ 4,6 g mỗi người',
  ),
  'Trứng gà': (id: 171287, grams: 50, proxy: '1 trứng ≈ 50 g phần ăn được'),
  'Chuối': (id: 173944, grams: 118, proxy: '1 quả vừa ≈ 118 g phần ăn được'),
  'Đậu hũ': (
    id: 172476,
    grams: 100,
    proxy: 'Đậu hũ thường kết tủa canxi sulfat',
  ),
  'Rau muống': (id: 169301, grams: 80, proxy: null),
  'Cải thảo': (id: 169979, grams: 80, proxy: null),
  'Nấm đùi gà': (
    id: 168580,
    grams: 80,
    proxy: 'Tham chiếu nấm sò; không phải số liệu riêng cho nấm đùi gà',
  ),
  'Gạo lứt': (id: 169703, grams: 50, proxy: 'Gạo khô trước nấu'),
  'Yến mạch': (id: 173904, grams: 40, proxy: 'Yến mạch khô'),
  'Mì': (
    id: 169755,
    grams: 60,
    proxy: 'Mì trứng khô không bổ sung vi chất; không tính gói gia vị',
  ),
  'Sữa chua': (
    id: 171284,
    grams: 100,
    proxy: '1 hộp 100 g, sữa chua nguyên kem không đường',
  ),
  'Sữa đậu nành': (
    id: 175215,
    grams: 200,
    proxy: 'Không đường, tăng cường canxi/vitamin; giả định 200 ml ≈ 200 g',
  ),
  'Cá basa fillet': (
    id: 175165,
    grams: 100,
    proxy:
        'Tham chiếu cá da trơn channel catfish nuôi; không phải số liệu riêng cá basa',
  ),
  'Cá ngừ': (id: 173709, grams: 100, proxy: 'Cá ngừ hộp ngâm nước đã ráo'),
  'Cá thu': (id: 175119, grams: 100, proxy: 'Cá thu Đại Tây Dương'),
  'Tôm sú': (
    id: 175179,
    grams: 100,
    proxy: 'Tôm sống chung; không phải số liệu riêng tôm sú',
  ),
  'Ức gà': (id: 171077, grams: 100, proxy: 'Ức không da, không xương'),
  'Cà rốt': (id: 170393, grams: 80, proxy: null),
  'Bông cải xanh': (id: 170379, grams: 80, proxy: null),
  'Bí đỏ': (id: 168448, grams: 80, proxy: null),
  'Bánh mì': (
    id: 172675,
    grams: 60,
    proxy: '1 cái nhỏ ≈ 60 g, bánh mì kiểu Pháp',
  ),
  'Bánh phở': (
    id: 169742,
    grams: 60,
    proxy: 'Bánh phở khô; không dùng trọng lượng bánh tươi',
  ),
  'Cải xanh': (id: 169256, grams: 80, proxy: null),
  'Hành lá': (id: 170005, grams: 5, proxy: null),
  'Thịt bò': (id: 174055, grams: 100, proxy: 'Thịt thăn bò đã bỏ mỡ'),
  'Thịt bò Mỹ': (id: 174055, grams: 100, proxy: 'Thịt thăn bò đã bỏ mỡ'),
  'Nước mắm': (
    id: 174531,
    grams: 6,
    proxy: 'Giả định 5 ml ≈ 6 g; natri phụ thuộc nhãn hàng',
  ),
};

class RecipeNutrition {
  const RecipeNutrition(this.values, this.missing, this.assumptions);
  final List<double?> values;
  final List<String> missing, assumptions;
  bool get hasData => values[0] != null;
}

RecipeNutrition estimateRecipeNutrition(Iterable<String> ingredients) {
  final values = List<double?>.filled(nutritionLabels.length, 0);
  final missing = <String>[];
  final assumptions = <String>[];
  var count = 0;
  for (final name in ingredients.toSet()) {
    final portion = nutritionPortions[name];
    if (portion == null) {
      missing.add(name);
      continue;
    }
    count++;
    if (portion.proxy != null) assumptions.add('$name: ${portion.proxy}');
    final data = usdaNutrients[portion.id]!;
    for (var i = 0; i < values.length; i++) {
      values[i] = values[i] == null || data[i] == null
          ? null
          : values[i]! + data[i]! * portion.grams / 100;
    }
  }
  if (count == 0) values.fillRange(0, values.length, null);
  return RecipeNutrition(values, missing, assumptions);
}
