import 'package:flutter/material.dart';

import 'diet_preferences.dart';
import 'global_search.dart';
import 'inventory_store.dart';
import 'profile_screen.dart';
import 'usage_screen.dart';
import 'meal_plan.dart';
import 'menu_shopping_sheet.dart';
import 'food_notification.dart';
import 'recipe_nutrition.dart';
import 'cooking_guide.dart';

const _green = Color(0xFF079669);
const _ink = Color(0xFF253043);
const _muted = Color(0xFF667085);
const _assetRoot = 'design_reference/home/page_files/';
const _recipePhotos = <String, String>{
  'mì cay trứng lòng đào': 'spicy-noodles-egg',
  'canh rau muống nấu tôm': 'water-spinach-shrimp-soup',
  'bò xào cải thảo': 'beef-cabbage-stir-fry',
  'bánh mì ốp la trứng gà': 'banh-mi-egg',
  'cá basa kho tiêu': 'caramel-braised-basa',
  'salad cá thu dầu mè': 'mackerel-sesame-salad',
  'đậu hũ sốt cà chua': 'tofu-tomato-sauce',
  'phở bò tái': 'pho-bo-tai',
};

bool hasBundledRecipePhoto(String name) =>
    _recipePhotos.keys.any((known) => name.toLowerCase().contains(known));

class RecipeVisual extends StatelessWidget {
  const RecipeVisual({
    super.key,
    required this.name,
    required this.imageIndex,
    this.height,
    this.width,
  });

  final String name;
  final int imageIndex;
  final double? height;
  final double? width;

  @override
  Widget build(BuildContext context) => hasBundledRecipePhoto(name)
      ? Image.asset(
          recipeImageAssetFor(name, imageIndex),
          height: height,
          width: width,
          fit: BoxFit.cover,
          cacheWidth: 1200,
        )
      : Container(
          height: height,
          width: width,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFE5F8EC), Color(0xFFBADFC9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Icon(
            Icons.restaurant_menu,
            size: 60,
            color: Color(0xFF1C8E64),
          ),
        );
}

String recipeImageAssetFor(String name, int fallbackIndex) {
  final normalized = name.toLowerCase();
  for (final entry in _recipePhotos.entries) {
    if (normalized.contains(entry.key)) {
      return 'assets/recipes/${entry.value}.webp';
    }
  }
  return '$_assetRoot${fallbackIndex == 0 ? 'search-image' : 'search-image($fallbackIndex)'}';
}

class RecipeIngredient {
  const RecipeIngredient(
    this.name,
    this.amount,
    this.available, {
    this.inventoryFood,
  });
  final String name;
  final String amount;
  final bool available;
  final FoodSummary? inventoryFood;
}

class RecipeStep {
  const RecipeStep(this.text, this.minutes, {this.tip});
  final String text;
  final int minutes;
  final String? tip;
}

enum RecipeDifficulty { easy, medium, hard }

extension RecipeDifficultyLabel on RecipeDifficulty {
  String get label => switch (this) {
    RecipeDifficulty.easy => 'Dễ',
    RecipeDifficulty.medium => 'Vừa',
    RecipeDifficulty.hard => 'Khó',
  };
}

enum RecipeCategory { summer, breakfast, dinner }

class RecipeCatalogItem {
  const RecipeCatalogItem({
    required this.id,
    required this.name,
    required this.durationMinutes,
    required this.difficulty,
    required this.imageIndex,
    required this.ingredients,
    this.categories = const {},
    this.diets = const {},
    this.vegetableCentric = false,
  });

  final String id;
  final String name;
  final int durationMinutes;
  final RecipeDifficulty difficulty;
  final int imageIndex;
  final List<String> ingredients;
  final Set<RecipeCategory> categories;

  /// Explicit recipe tags avoid guessing dietary safety from a dish name.
  final Set<DietKind> diets;
  final bool vegetableCentric;

  String get timeLabel => '$durationMinutes phút';
  String get difficultyLabel => difficulty.label;

  RecipeDetailData toDetailData() => RecipeDetailData.fromSummary(
    name: name,
    time: timeLabel,
    level: difficultyLabel,
    image: imageIndex,
    ingredientsText: ingredients.join(' · '),
  );
}

class RecipeDetailData {
  const RecipeDetailData({
    required this.name,
    required this.meal,
    required this.time,
    required this.level,
    required this.match,
    required this.image,
    required this.servings,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.description,
    required this.ingredients,
    required this.steps,
    required this.tags,
    this.nutrition,
    this.seasonings = const [],
  });

  final String name, meal, time, level, match, description;
  final int image, servings;
  final int? calories, protein, carbs, fat;
  final List<RecipeIngredient> ingredients;
  final List<RecipeStep> steps;
  final List<String> tags;
  final RecipeNutrition? nutrition;
  final List<String> seasonings;

  factory RecipeDetailData.fromSummary({
    required String name,
    required String time,
    required String level,
    required int image,
    required String ingredientsText,
  }) {
    final cleanName = _fix(name);
    final names = _fix(
      ingredientsText,
    ).split(RegExp(r'\s*[·Â]+\s*')).where((e) => e.trim().isNotEmpty).toList();
    final isBreakfast =
        cleanName.contains('Bánh mì') || cleanName.contains('Mì cay');
    final isBeef = cleanName.contains('Bò') || cleanName.contains('bò');
    final isSoup = cleanName.contains('Canh');
    final isFish = cleanName.contains('Cá basa');
    final isSalad = cleanName.contains('Salad');
    final isTofu = cleanName.contains('Đậu hũ');
    final isPho = cleanName.contains('Phở');
    final plainPreparation =
        cleanName.toLowerCase().contains('yến mạch') ||
        cleanName.toLowerCase().contains('hấp');
    final servings = isPho
        ? 4
        : isBeef
        ? 3
        : 2;
    FoodSummary? findFood(String ingredient) {
      final normalized = ingredient.trim().toLowerCase();
      for (final food in inventoryFoods) {
        final stockName = food.name.trim().toLowerCase();
        if (stockName == normalized ||
            stockName.contains(normalized) ||
            normalized.contains(stockName)) {
          return food;
        }
      }
      return null;
    }

    final ingredientNames = <String>{
      ...names,
      if (!plainPreparation) ...[
        if (!isSalad &&
            !isSoup &&
            !isPho &&
            !isBreakfast &&
            !cleanName.contains('Cơm gạo lứt'))
          'Tỏi',
        if (!isSoup && !isPho && !cleanName.contains('Mì cay')) 'Dầu ăn',
        if (isTofu) 'Muối, tiêu' else 'Gia vị',
      ],
    }.toList();
    final nutrition = estimateRecipeNutrition(ingredientNames);
    final ingredientList = <RecipeIngredient>[
      for (var i = 0; i < ingredientNames.length; i++)
        RecipeIngredient(
          ingredientNames[i],
          nutritionPortions[ingredientNames[i]] == null
              ? 'Tùy khẩu vị'
              : '${(nutritionPortions[ingredientNames[i]]!.grams * servings).toStringAsFixed(1).replaceFirst(RegExp(r'\.?0+$'), '')} g',
          findFood(ingredientNames[i]) != null,
          inventoryFood: findFood(ingredientNames[i]),
        ),
    ];
    final availableCount = ingredientList
        .where((ingredient) => ingredient.available)
        .length;
    final actualMatch = ingredientList.isEmpty
        ? 0
        : (availableCount * 100 / ingredientList.length).round();
    final guide = cookingGuide(cleanName, servings, ingredientNames);
    return RecipeDetailData(
      name: cleanName,
      meal: isBreakfast
          ? 'Bữa sáng'
          : isSoup || isFish
          ? 'Bữa trưa'
          : 'Bữa tối',
      time: _fix(time),
      level: _fix(level),
      match: '$actualMatch% có sẵn',
      image: image,
      servings: servings,
      calories: nutrition.values[0]?.round(),
      protein: nutrition.values[1]?.round(),
      carbs: nutrition.values[2]?.round(),
      fat: nutrition.values[3]?.round(),
      nutrition: nutrition,
      description: _descriptionFor(cleanName),
      ingredients: ingredientList,
      steps: guide.steps
          .map((step) => RecipeStep(step.text, step.minutes))
          .toList(),
      seasonings: guide.seasonings,
      tags: [
        isBreakfast ? 'bữa sáng' : 'bữa tối',
        isBeef ? 'thịt bò' : 'cơm nhà',
        'nhanh gọn',
      ],
    );
  }

  static String _descriptionFor(String name) {
    if (name.contains('Bánh mì')) {
      return 'Bánh mì giòn rụm kẹp trứng ốp la lòng đào, thêm chút nước tương và hành lá — bữa sáng nhanh mà đủ chất.';
    }
    if (name.contains('Bò')) {
      return 'Thịt bò mềm xào cùng cải thảo giòn ngọt, thơm chút gừng tỏi phi — đậm đà mà vẫn thanh nhẹ.';
    }
    if (name.contains('Canh')) {
      return 'Món canh thanh mát, vị ngọt tự nhiên từ rau và tôm, rất hợp cho bữa cơm gia đình.';
    }
    if (name.contains('Cá basa')) {
      return 'Cá basa mềm béo kho tiêu đậm vị, thơm nức và rất đưa cơm.';
    }
    return '$name được gợi ý từ nguyên liệu sẵn có trong tủ lạnh, dễ làm và phù hợp cho bữa ăn gia đình.';
  }

  static String _fix(String text) => text
      .replaceAll('BÃ¡nh mÃ¬', 'Bánh mì')
      .replaceAll('trá»©ng', 'trứng')
      .replaceAll('gÃ ', 'gà')
      .replaceAll('BÃ²', 'Bò')
      .replaceAll('bÃ²', 'bò')
      .replaceAll('cáº£i tháº£o', 'cải thảo')
      .replaceAll('Canh rau muá»‘ng náº¥u tÃ´m', 'Canh rau muống nấu tôm')
      .replaceAll('CÃ¡ basa kho tiÃªu', 'Cá basa kho tiêu')
      .replaceAll('Salad cÃ¡ thu dáº§u mÃ¨', 'Salad cá thu dầu mè')
      .replaceAll('Äáº­u hÅ© sá»‘t cÃ  chua', 'Đậu hũ sốt cà chua')
      .replaceAll('Phá»Ÿ bÃ² tÃ¡i', 'Phở bò tái')
      .replaceAll('Dá»…', 'Dễ')
      .replaceAll('Vá»«a', 'Vừa')
      .replaceAll('KhÃ³', 'Khó')
      .replaceAll('phÃºt', 'phút')
      .replaceAll('cÃ³ sáºµn', 'có sẵn')
      .replaceAll('Thá»‹t', 'Thịt')
      .replaceAll('Trá»©ng', 'Trứng')
      .replaceAll('HÃ nh lÃ¡', 'Hành lá')
      .replaceAll('NÆ°á»›c máº¯m', 'Nước mắm')
      .replaceAll('Rau muá»‘ng', 'Rau muống')
      .replaceAll('TÃ´m sÃº', 'Tôm sú')
      .replaceAll('CÃ¡', 'Cá')
      .replaceAll('DÆ°a leo', 'Dưa leo')
      .replaceAll('Äáº­u hÅ©', 'Đậu hũ')
      .replaceAll('CÃ  chua', 'Cà chua');
}

class RecipeDetailScreen extends StatelessWidget {
  const RecipeDetailScreen({super.key, required this.recipe});
  final RecipeDetailData recipe;

  Future<void> _recordCooked(BuildContext context) async {
    final saved = await showInventoryUsageSheet(
      context,
      dish: PlannedDish(
        date: menuDay(DateTime.now()),
        slot: 'dinner',
        name: recipe.name,
        ingredients: recipe.ingredients.map((i) => i.name).toList(),
      ),
      people: recipe.servings,
    );
    if (saved == true && context.mounted) {
      showFoodNotification(
        context,
        title: 'Đã ghi nhận món đã nấu',
        message: 'Lượng nguyên liệu đã dùng được cập nhật trong tủ.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFFAFAFB),
    appBar: AppBar(
      toolbarHeight: MediaQuery.textScalerOf(context).scale(1) > 1.3 ? 96 : 64,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            recipe.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          Text(
            '${recipe.meal} · ${recipe.level}',
            style: const TextStyle(fontSize: 14, color: _muted),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, size: 21),
          onPressed: () => showGlobalSearch(context),
        ),
        IconButton.filledTonal(
          icon: const Icon(Icons.person_outline, size: 20),
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFFD9FAEA),
            foregroundColor: _green,
          ),
        ),
        const SizedBox(width: 8),
      ],
    ),
    body: ListView(
      children: [
        _Hero(recipe: recipe),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              _Stats(recipe: recipe),
              const SizedBox(height: 14),
              _Ingredients(recipe: recipe),
              const SizedBox(height: 14),
              _Nutrition(recipe: recipe),
              const SizedBox(height: 14),
              _Steps(recipe: recipe),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: recipe.tags
                      .map(
                        (e) => Chip(
                          label: Text(
                            '#$e',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF667085),
                            ),
                          ),
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFFEEF0F3)),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        'Đã nấu món này chưa?',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                      const Text(
                        'Chọn lượng đã dùng để cập nhật tủ lạnh chính xác.',
                        style: TextStyle(fontSize: 14, color: _muted),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Tính năng chia sẻ sẽ được bổ sung sau.',
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                              icon: const Icon(Icons.share_outlined, size: 17),
                              label: const Text('Chia sẻ'),
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => _recordCooked(context),
                              icon: const Icon(Icons.done_all, size: 17),
                              label: const Text('Đã nấu xong'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Hero extends StatelessWidget {
  const _Hero({required this.recipe});
  final RecipeDetailData recipe;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.textScalerOf(context).scale(1) > 1.3 ? 300 : 240,
    child: Stack(
      fit: StackFit.expand,
      children: [
        RecipeVisual(name: recipe.name, imageIndex: recipe.image),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Color(0xDD111827)],
            ),
          ),
        ),
        Positioned(
          left: 14,
          right: 14,
          bottom: 14,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                children: [
                  _Badge(recipe.meal, Icons.wb_sunny_outlined),
                  _Badge(recipe.time, Icons.schedule),
                  _Badge('${recipe.servings} người', Icons.person_outline),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                recipe.name,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                recipe.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.4,
                  color: Color(0xFFE5E7EB),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, this.icon);
  final String text;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: _ink),
        const SizedBox(width: 3),
        Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
      ],
    ),
  );
}

class _Stats extends StatelessWidget {
  const _Stats({required this.recipe});
  final RecipeDetailData recipe;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Wrap(
      spacing: 10,
      runSpacing: 10,
      children:
          [
                _Stat(
                  Icons.schedule,
                  'Thời gian nấu',
                  recipe.time,
                  const Color(0xFFD5F8E9),
                  _green,
                ),
                _Stat(
                  Icons.restaurant_menu,
                  'Độ khó',
                  recipe.level,
                  const Color(0xFFFFF2C9),
                  Colors.orange,
                ),
                _Stat(
                  Icons.local_fire_department_outlined,
                  'Ước tính / suất',
                  recipe.calories == null
                      ? 'Chưa có số liệu'
                      : '≈ ${recipe.calories} kcal',
                  const Color(0xFFFFE9D7),
                  Colors.deepOrange,
                ),
                _Stat(
                  Icons.people_outline,
                  'Khẩu phần',
                  '${recipe.servings} người',
                  const Color(0xFFFFE1F0),
                  Colors.pink,
                ),
              ]
              .map(
                (stat) => SizedBox(
                  width: (constraints.maxWidth - 10) / 2,
                  child: stat,
                ),
              )
              .toList(),
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat(this.icon, this.label, this.value, this.bg, this.color);
  final IconData icon;
  final String label, value;
  final Color bg, color;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: bg,
            foregroundColor: color,
            child: Icon(icon, size: 19),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: _muted),
          ),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, color: _ink),
          ),
        ],
      ),
    ),
  );
}

class _Ingredients extends StatelessWidget {
  const _Ingredients({required this.recipe});
  final RecipeDetailData recipe;
  @override
  Widget build(BuildContext context) {
    final count = recipe.ingredients.where((e) => e.available).length;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Title(
            Icons.shopping_basket_outlined,
            'Nguyên liệu',
            '$count/${recipe.ingredients.length} món có sẵn trong tủ',
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Khối lượng tham khảo cho cả món, phần ăn được trước nấu. Có thể điều chỉnh khi xuất nguyên liệu.',
              style: TextStyle(fontSize: 15, height: 1.5, color: _muted),
            ),
          ),
          const SizedBox(height: 10),
          ...recipe.ingredients.map(
            (e) => Container(
              margin: const EdgeInsets.only(bottom: 7),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
              decoration: BoxDecoration(
                color: e.available
                    ? const Color(0xFFE9FBF4)
                    : const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: e.available
                      ? const Color(0xFFC9F3E2)
                      : const Color(0xFFF0F1F3),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: e.available
                        ? const Color(0xFF18BF8A)
                        : const Color(0xFFD8DDE4),
                    child: Icon(
                      e.available ? Icons.check : Icons.add,
                      size: 13,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      e.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: e.available ? _ink : _muted,
                      ),
                    ),
                  ),
                  Text(
                    e.amount,
                    style: const TextStyle(fontSize: 14, color: _muted),
                  ),
                ],
              ),
            ),
          ),
          ...[
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final day = menuDay(DateTime.now());
                  final selection = await showMenuShoppingSheet(
                    context,
                    dishes: [
                      PlannedDish(
                        date: day,
                        slot: 'dinner',
                        name: recipe.name,
                        ingredients: recipe.ingredients
                            .map((i) => i.name)
                            .toList(),
                      ),
                    ],
                    stock: inventoryFoods,
                    people: recipe.servings,
                    weekly: false,
                    day: day,
                  );
                  if (selection == null || !context.mounted) return;
                  shoppingItems.addAll(
                    selection.lines.map(
                      (line) => ShoppingSummary(
                        name: line.name,
                        quantity: line.buyQuantity,
                        unit: line.unit,
                        note: line.note,
                        neededDate: line.neededDate,
                      ),
                    ),
                  );
                  shoppingRevision.value++;
                  await persistShopping(shoppingItems, shoppingChecked);
                  if (context.mounted) {
                    showFoodNotification(
                      context,
                      title: 'Đã lên danh sách đi chợ',
                      message:
                          '${selection.lines.length} nguyên liệu cần mua · tồn kho không thay đổi.',
                    );
                  }
                },
                icon: const Icon(Icons.add_shopping_cart_outlined),
                label: const Text('Xem lượng cần dùng & đi chợ'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Nutrition extends StatelessWidget {
  const _Nutrition({required this.recipe});
  final RecipeDetailData recipe;
  @override
  Widget build(BuildContext context) => _Panel(
    child: Column(
      children: [
        _Title(Icons.favorite_border, 'Dinh dưỡng (mỗi suất)', ''),
        const SizedBox(height: 12),
        if (recipe.nutrition == null || !recipe.nutrition!.hasData)
          const Text(
            'Chưa đủ dữ liệu nguyên liệu để tính dinh dưỡng. Không thay dữ liệu thiếu bằng số 0.',
            style: TextStyle(color: _muted, height: 1.4),
          )
        else ...[
          const Text(
            'Ước tính mỗi người · khối lượng nguyên liệu trước nấu',
            style: TextStyle(fontSize: 15, height: 1.5, color: _muted),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) => Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List.generate(5, (i) {
                final value = recipe.nutrition!.values[i];
                final wide = MediaQuery.textScalerOf(context).scale(1) > 1.3;
                return SizedBox(
                  width: wide
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 10) / 2,
                  child: _Nutrient(
                    value == null
                        ? 'Chưa có dữ liệu'
                        : '≈ ${value.toStringAsFixed(i == 0 ? 0 : 1)} ${nutritionUnits[i]}',
                    nutritionLabels[i],
                    i < 4 ? const Color(0xFFE9F8F1) : const Color(0xFFF5F7FA),
                    _ink,
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 14),
          if (recipe.nutrition!.missing.isNotEmpty)
            Text(
              'Chưa tính: ${recipe.nutrition!.missing.join(', ')}. Natri, đường và năng lượng thực tế có thể cao hơn sau khi nêm.',
              style: const TextStyle(
                fontSize: 15,
                height: 1.5,
                color: Color(0xFF9A5B00),
              ),
            ),
        ],
      ],
    ),
  );
}

class _Nutrient extends StatelessWidget {
  const _Nutrient(this.value, this.label, this.bg, this.color);
  final String value, label;
  final Color bg, color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(9),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: _muted),
        ),
      ],
    ),
  );
}

class _Steps extends StatelessWidget {
  const _Steps({required this.recipe});
  final RecipeDetailData recipe;
  @override
  Widget build(BuildContext context) => _Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Title(
          Icons.format_list_numbered,
          'Các bước thực hiện',
          '${recipe.steps.length} bước · ~${recipe.time}',
        ),
        const SizedBox(height: 14),
        ...recipe.steps.asMap().entries.map((entry) {
          final last = entry.key == recipe.steps.length - 1;
          final step = entry.value;
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 36,
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: _green,
                        child: Text(
                          '${entry.key + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (!last)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: const Color(0xFFBDEEDC),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step.text,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.55,
                            color: Color(0xFF4B5565),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '⏱ ${step.minutes} phút',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _green,
                          ),
                        ),
                        if (step.tip != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFAE9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFFFE8A8),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.lightbulb_outline,
                                  size: 15,
                                  color: Colors.orange,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    step.tip!,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFFD97706),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(14), child: child),
  );
}

class _Title extends StatelessWidget {
  const _Title(this.icon, this.title, this.subtitle);
  final IconData icon;
  final String title, subtitle;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      CircleAvatar(
        radius: 17,
        backgroundColor: const Color(0xFFDDF8EC),
        foregroundColor: _green,
        child: Icon(icon, size: 17),
      ),
      const SizedBox(width: 9),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
            if (subtitle.isNotEmpty)
              Text(
                subtitle,
                style: const TextStyle(fontSize: 14, color: _muted),
              ),
          ],
        ),
      ),
    ],
  );
}
