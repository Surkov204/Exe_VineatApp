import 'package:flutter/material.dart';
import 'diet_preferences.dart';
import 'inventory_store.dart';
import 'menu_ingredients.dart';
import 'recipe_detail.dart';
import 'screens.dart' show recipeCatalog;

int cleanupDays(FoodSummary food, DateTime now) =>
    DateUtils.dateOnly(food.expiry!).difference(DateUtils.dateOnly(now)).inDays;

List<FoodSummary> cleanupFoods(Iterable<FoodSummary> foods, DateTime now) =>
    foods
        .where(
          (f) =>
              f.quantity > 0 &&
              f.expiry != null &&
              cleanupDays(f, now) >= 0 &&
              cleanupDays(f, now) <= 3,
        )
        .toList()
      ..sort((a, b) => a.expiry!.compareTo(b.expiry!));

List<RecipeCatalogItem> cleanupRecipes(List<FoodSummary> foods, DietKind diet) {
  int matches(RecipeCatalogItem r) => r.ingredients
      .where((i) => foods.any((f) => ingredientKey(f.name) == ingredientKey(i)))
      .length;
  return [...recipeCatalog, ...menuSupportingRecipes]
      .where(
        (r) =>
            (diet == DietKind.normal || r.diets.contains(diet)) &&
            matches(r) > 0,
      )
      .toList()
    ..sort((a, b) => matches(b).compareTo(matches(a)));
}

class FridgeCleanupScreen extends StatelessWidget {
  const FridgeCleanupScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF6FAF8),
    appBar: AppBar(
      title: const Text('Dọn tủ lạnh'),
      backgroundColor: Colors.white,
    ),
    body: ValueListenableBuilder<int>(
      valueListenable: inventoryRevision,
      builder: (context, _, child) => ValueListenableBuilder<DietKind>(
        valueListenable: preferredDiet,
        builder: (context, diet, child) {
          final now = DateTime.now();
          final urgent = cleanupFoods(inventoryFoods, now);
          final recipes = cleanupRecipes(urgent, diet);
          final expired = inventoryFoods
              .where(
                (f) =>
                    f.quantity > 0 &&
                    f.expiry != null &&
                    cleanupDays(f, now) < 0,
              )
              .length;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                '${urgent.length} món cần ưu tiên',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Hạn dùng trong 3 ngày tới · Kiểm tra tình trạng thực phẩm trước khi nấu.',
                style: TextStyle(fontSize: 15, color: Color(0xFF667085)),
              ),
              if (expired > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    '$expired món đã hết hạn không được dùng để gợi ý nấu.',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(height: 16),
              if (urgent.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Tủ lạnh chưa có món gần hết hạn.'),
                  ),
                ),
              for (final f in urgent)
                Card(
                  color: Colors.white,
                  elevation: 0,
                  child: ListTile(
                    leading: const Icon(
                      Icons.timer_outlined,
                      color: Colors.orange,
                    ),
                    title: Text(
                      f.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                    subtitle: Text(
                      '${f.detail.split('·').first.trim()} · HSD ${f.expiry!.day}/${f.expiry!.month}/${f.expiry!.year}',
                    ),
                    trailing: Text(
                      cleanupDays(f, now) == 0
                          ? 'Hôm nay'
                          : '${cleanupDays(f, now)} ngày',
                      style: const TextStyle(
                        color: Color(0xFF9C5700),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              const Text(
                'Nấu gì để dùng kịp?',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Theo chế độ: ${diet.label}. Gợi ý theo tên nguyên liệu, chưa bảo đảm đủ lượng.',
                style: const TextStyle(color: Color(0xFF667085)),
              ),
              if (urgent.isNotEmpty && recipes.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Chưa có công thức phù hợp với nguyên liệu và chế độ ăn này.',
                  ),
                ),
              for (final r in recipes.take(8))
                Card(
                  color: Colors.white,
                  elevation: 0,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            RecipeDetailScreen(recipe: r.toDetailData()),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${r.timeLabel} · ${r.difficultyLabel}',
                            style: const TextStyle(color: Color(0xFF667085)),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final i in r.ingredients.where(
                                (i) => urgent.any(
                                  (f) =>
                                      ingredientKey(f.name) == ingredientKey(i),
                                ),
                              ))
                                Chip(
                                  label: Text('Dùng kịp: $i'),
                                  backgroundColor: const Color(0xFFE1F7ED),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Nguyên liệu: ${r.ingredients.join(', ')}',
                            style: const TextStyle(fontSize: 15, height: 1.4),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Xem cách nấu →',
                            style: TextStyle(
                              color: Color(0xFF079669),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}
