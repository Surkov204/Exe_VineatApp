import 'package:flutter/material.dart';

import 'app_services.dart';

enum DietKind {
  normal(
    'normal',
    'Không hạn chế',
    'Đa dạng rau, quả, ngũ cốc và nguồn đạm',
    Icons.restaurant_outlined,
  ),
  vegetarian(
    'vegetarian',
    'Ăn chay',
    'Không có thịt, cá và hải sản',
    Icons.spa_outlined,
  ),
  vegan(
    'vegan',
    'Thuần chay',
    'Không có nguyên liệu từ động vật',
    Icons.eco_outlined,
  ),
  pescatarian(
    'pescatarian',
    'Ăn cá không ăn thịt',
    'Dùng cá, hải sản, trứng, đậu và rau; không thịt',
    Icons.set_meal_outlined,
  ),
  meatNoFish(
    'no_seafood',
    'Ăn thịt không ăn cá',
    'Dùng thịt, trứng, đậu và rau; không cá/hải sản',
    Icons.restaurant_outlined,
  ),
  vegetableForward(
    'vegetable_forward',
    'Ưu tiên rau củ',
    'Gợi ý món có nhiều rau củ',
    Icons.grass_outlined,
  ),
  lowCalorie(
    'low_calorie',
    'Ăn nhẹ',
    'Ưu tiên món nhiều rau, ít chế biến; vẫn ăn đủ bữa',
    Icons.balance_outlined,
  ),
  highProtein(
    'high_protein',
    'Ăn tập gym',
    'Ưu tiên đạm đa dạng cùng rau và tinh bột phù hợp',
    Icons.fitness_center_outlined,
  ),
  noEgg(
    'no_egg',
    'Không dùng trứng',
    'Không gợi ý món có trứng trong công thức',
    Icons.egg_outlined,
  ),
  lowerCarb(
    'lower_carb',
    'Ưu tiên ít tinh bột',
    'Gợi ý món không lấy mì, bánh mì hoặc phở làm chính',
    Icons.rice_bowl_outlined,
  );

  const DietKind(this.id, this.label, this.description, this.icon);
  final String id;
  final String label;
  final String description;
  final IconData icon;

  static DietKind fromId(String? id) {
    // Preserve the closest safe behavior for diets saved by older app builds.
    if (id == 'no_red_meat') return normal;
    if (id == 'fish_forward') return pescatarian;
    for (final diet in values) {
      if (diet.id == id) return diet;
    }
    return normal;
  }

  String get guidance => switch (this) {
    normal =>
      'Kết hợp rau/quả, ngũ cốc (ưu tiên nguyên hạt) và nguồn đạm đa dạng trong ngày; hạn chế muối, đường thêm và chất béo bão hòa.',
    vegetarian =>
      'Kết hợp rau, ngũ cốc và đạm từ đậu/đậu hũ, hạt hoặc trứng. Chú ý đủ sắt, B12 và canxi trong toàn ngày.',
    vegan =>
      'Kết hợp đậu/đậu hũ, ngũ cốc, rau, quả và hạt. Cần nguồn vitamin B12 từ thực phẩm tăng cường hoặc bổ sung phù hợp.',
    pescatarian =>
      'Luân phiên cá, trứng, đậu và nhiều loại rau; thêm ngũ cốc và quả để thực đơn không chỉ dựa vào cá.',
    meatNoFish =>
      'Luân phiên thịt nạc, trứng và đậu; thêm rau, quả, ngũ cốc. Không lấy thịt làm thay thế cho mọi nhóm thực phẩm.',
    vegetableForward =>
      'Ưu tiên nhiều loại rau và quả nhưng vẫn kết hợp nguồn đạm, ngũ cốc và chất béo không bão hòa.',
    lowCalorie =>
      'Ưu tiên món có rau, đạm và khẩu phần vừa phải; không bỏ bữa hoặc cắt giảm năng lượng khi chưa biết nhu cầu cá nhân.',
    highProtein =>
      'Phối hợp tập luyện với đạm từ nhiều nguồn; vẫn cần rau, quả và carbohydrate phù hợp mức vận động.',
    noEgg =>
      'Thay đạm từ trứng bằng cá, thịt hoặc đậu; vẫn chú ý rau, quả và ngũ cốc trong ngày.',
    lowerCarb =>
      'Giảm thực phẩm tinh chế trước, không loại bỏ hoàn toàn carbohydrate; ưu tiên rau, đậu và ngũ cốc nguyên hạt theo nhu cầu.',
  };

  String get evidence => switch (this) {
    vegan || vegetarian => 'WHO 2026 · USDA MyPlate · NIH ODS (B12)',
    highProtein => 'WHO 2026 · ACSM (dinh dưỡng khi tập)',
    _ => 'WHO 2026 · USDA/HHS 2025–2030',
  };
}

/// Shared by registration, profile and recipes so a saved choice takes effect
/// immediately without rebuilding the tab shell.
final preferredDiet = ValueNotifier<DietKind>(DietKind.normal);
String? _preferredDietUserId;
int _dietRevision = 0;

void applyPreferredDiet(DietKind choice) {
  _dietRevision++;
  _preferredDietUserId = AppServices.configured
      ? AppServices.client.auth.currentUser?.id
      : null;
  preferredDiet.value = choice;
}

Future<void> refreshPreferredDiet() async {
  if (!AppServices.configured) return;
  final userId = AppServices.client.auth.currentUser?.id;
  if (userId == null) {
    applyPreferredDiet(DietKind.normal);
    return;
  }
  if (_preferredDietUserId != userId) {
    preferredDiet.value = DietKind.normal;
    _preferredDietUserId = userId;
    _dietRevision++;
  }
  final revisionAtStart = _dietRevision;
  try {
    final profile = await AppServices.client
        .from('profiles')
        .select('diet')
        .eq('id', userId)
        .maybeSingle();
    if (AppServices.client.auth.currentUser?.id == userId &&
        revisionAtStart == _dietRevision) {
      applyPreferredDiet(DietKind.fromId(profile?['diet'] as String?));
    }
  } catch (_) {
    // Keep the last visible choice when temporarily offline.
  }
}

class DietSelectorField extends StatelessWidget {
  const DietSelectorField({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final DietKind value;
  final ValueChanged<DietKind> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => InkWell(
    key: const ValueKey('diet-selector'),
    borderRadius: BorderRadius.circular(4),
    onTap: enabled ? () => _showChoices(context) : null,
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: 'Chế độ ăn',
        prefixIcon: const Icon(Icons.restaurant_outlined),
        suffixIcon: const Icon(Icons.keyboard_arrow_down),
        border: const OutlineInputBorder(),
        enabled: enabled,
      ),
      child: Text(
        value.label,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: enabled ? const Color(0xFF203044) : null,
        ),
      ),
    ),
  );

  Future<void> _showChoices(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final chosen = await showModalBottomSheet<DietKind>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.72,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Chọn chế độ ăn',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                itemCount: DietKind.values.length,
                itemBuilder: (context, index) {
                  final option = DietKind.values[index];
                  return ListTile(
                    key: ValueKey('diet-option-${option.id}'),
                    leading: Icon(option.icon),
                    title: Text(option.label),
                    subtitle: Text(option.description),
                    trailing: option == value
                        ? const Icon(
                            Icons.check_circle,
                            color: Color(0xFF079669),
                          )
                        : null,
                    onTap: () => Navigator.pop(sheetContext, option),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (chosen != null) onChanged(chosen);
  }
}
