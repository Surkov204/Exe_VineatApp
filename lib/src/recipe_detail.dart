import 'package:flutter/material.dart';

import 'global_search.dart';
import 'profile_screen.dart';

const _green = Color(0xFF079669);
const _ink = Color(0xFF253043);
const _muted = Color(0xFF98A2B3);
const _assetRoot = 'design_reference/home/page_files/';

class RecipeIngredient {
  const RecipeIngredient(this.name, this.amount, this.available);
  final String name;
  final String amount;
  final bool available;
}

class RecipeStep {
  const RecipeStep(this.text, this.minutes, {this.tip});
  final String text;
  final int minutes;
  final String? tip;
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
  });

  final String name, meal, time, level, match, description;
  final int image, servings, calories, protein, carbs, fat;
  final List<RecipeIngredient> ingredients;
  final List<RecipeStep> steps;
  final List<String> tags;

  factory RecipeDetailData.fromSummary({
    required String name,
    required String time,
    required String level,
    required String match,
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
    final servings = isPho
        ? 4
        : isBeef
        ? 3
        : 2;
    final calories = isPho
        ? 450
        : isBeef
        ? 320
        : isSalad
        ? 240
        : isSoup
        ? 180
        : isFish
        ? 410
        : isTofu
        ? 280
        : 380;
    final ingredientList = <RecipeIngredient>[
      for (var i = 0; i < names.length; i++)
        RecipeIngredient(
          names[i],
          i == 0
              ? (isBeef ? '300g' : '2 phần')
              : i == 1
              ? '1 phần'
              : '1 nhánh',
          i < 2,
        ),
      const RecipeIngredient('Tỏi', '2 tép', false),
      const RecipeIngredient('Dầu ăn', '1 muỗng', false),
      const RecipeIngredient('Gia vị', 'vừa đủ', true),
    ];
    final action = isSoup
        ? 'nấu canh'
        : isSalad
        ? 'trộn salad'
        : isFish
        ? 'kho cá'
        : isTofu
        ? 'làm sốt'
        : isPho
        ? 'nấu nước dùng'
        : 'chế biến';
    return RecipeDetailData(
      name: cleanName,
      meal: isBreakfast
          ? 'Bữa sáng'
          : isSoup || isFish
          ? 'Bữa trưa'
          : 'Bữa tối',
      time: _fix(time),
      level: _fix(level),
      match: _fix(match),
      image: image,
      servings: servings,
      calories: calories,
      protein: isBeef
          ? 32
          : isFish
          ? 28
          : 16,
      carbs: isPho
          ? 48
          : isBreakfast
          ? 30
          : 12,
      fat: isBeef
          ? 18
          : isFish
          ? 22
          : 14,
      description: _descriptionFor(cleanName),
      ingredients: ingredientList,
      steps: [
        RecipeStep(
          'Sơ chế ${names.take(2).join(' và ')}. Rửa sạch, để ráo rồi cắt thành miếng vừa ăn.',
          5,
        ),
        RecipeStep(
          'Ướp nguyên liệu chính với gia vị, tỏi băm và một chút dầu ăn.',
          5,
          tip: 'Ướp đủ thời gian giúp món ăn thấm vị và thơm hơn.',
        ),
        RecipeStep(
          'Bắc bếp ở lửa vừa, cho nguyên liệu vào $action. Đảo nhẹ để chín đều.',
          8,
          tip: isBeef
              ? 'Dùng lửa lớn để thịt bò mềm, không ra nước.'
              : 'Nêm từng chút để dễ điều chỉnh khẩu vị.',
        ),
        RecipeStep(
          'Nêm nếm lại vừa ăn, tắt bếp và trình bày món ra đĩa. Dùng khi còn nóng.',
          2,
        ),
      ],
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

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFFAFAFB),
    appBar: AppBar(
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
            style: const TextStyle(fontSize: 11, color: _muted),
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
                              fontSize: 11,
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
                        'Chia sẻ thành quả với cả nhà nhé!',
                        style: TextStyle(fontSize: 11, color: _muted),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Đã tạo nội dung chia sẻ món ăn',
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
                              onPressed: () =>
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Đã đánh dấu nấu xong!'),
                                    ),
                                  ),
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
    height: 210,
    child: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          '$_assetRoot${recipe.image == 0 ? 'search-image' : 'search-image(${recipe.image})'}',
          fit: BoxFit.cover,
        ),
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
                  fontSize: 12,
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
            fontSize: 10,
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
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: 10,
    crossAxisSpacing: 10,
    childAspectRatio: 1.35,
    children: [
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
        'Calories',
        '${recipe.calories} kcal',
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
    ],
  );
}

class _Stat extends StatelessWidget {
  const _Stat(this.icon, this.label, this.value, this.bg, this.color);
  final IconData icon;
  final String label, value;
  final Color bg, color;
  @override
  Widget build(BuildContext context) => Card(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: bg,
          foregroundColor: color,
          child: Icon(icon, size: 19),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 11, color: _muted)),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w800, color: _ink),
        ),
      ],
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
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: e.available ? _ink : _muted,
                      ),
                    ),
                  ),
                  Text(
                    e.amount,
                    style: const TextStyle(fontSize: 10, color: _muted),
                  ),
                ],
              ),
            ),
          ),
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
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 9,
          crossAxisSpacing: 9,
          childAspectRatio: 1.8,
          children: [
            _Nutrient(
              '${recipe.calories}',
              'kcal',
              const Color(0xFFF8F9FA),
              _ink,
            ),
            _Nutrient(
              '${recipe.protein}g',
              'Protein',
              const Color(0xFFFFEAEE),
              Colors.pink,
            ),
            _Nutrient(
              '${recipe.carbs}g',
              'Carbs',
              const Color(0xFFFFF8E5),
              Colors.orange,
            ),
            _Nutrient(
              '${recipe.fat}g',
              'Fat',
              const Color(0xFFFFF1E8),
              Colors.deepOrange,
            ),
          ],
        ),
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
        Text(label, style: const TextStyle(fontSize: 10, color: _muted)),
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
                            fontSize: 12,
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
                            fontSize: 12,
                            height: 1.55,
                            color: Color(0xFF4B5565),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '⏱ ${step.minutes} phút',
                          style: const TextStyle(
                            fontSize: 10,
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
                                      fontSize: 10,
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
                style: const TextStyle(fontSize: 10, color: _muted),
              ),
          ],
        ),
      ),
    ],
  );
}
