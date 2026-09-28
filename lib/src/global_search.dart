import 'package:flutter/material.dart';

import 'food_detail.dart';
import 'food_image.dart';
import 'inventory_store.dart';
import 'recipe_detail.dart';

const _green = Color(0xFF079669);
const _ink = Color(0xFF253043);
const _muted = Color(0xFF98A2B3);
const _assets = 'design_reference/home/page_files/';

class _SearchSelection {
  const _SearchSelection({this.food, this.recipe});
  final FoodDetailData? food;
  final RecipeDetailData? recipe;
}

Future<void> showGlobalSearch(BuildContext context) async {
  final result = await showDialog<_SearchSelection>(
    context: context,
    barrierColor: Colors.black45,
    builder: (_) => const _GlobalSearchDialog(),
  );
  if (result == null || !context.mounted) return;
  if (result.food != null) {
    final detailResult = await Navigator.push<Object?>(
      context,
      MaterialPageRoute(builder: (_) => FoodDetailScreen(food: result.food!)),
    );
    FoodSummary? original;
    for (final food in inventoryFoods) {
      if (food.id == result.food!.id) {
        original = food;
        break;
      }
    }
    if (original != null) {
      if (detailResult is FoodDetailData) {
        updateFoodInInventory(
          original,
          FoodSummary.fromLegacy(
            id: original.id,
            name: detailResult.name,
            detail: '${detailResult.quantity} · ${detailResult.price}',
            status: detailResult.status,
            imageIndex: detailResult.image,
            imagePath: original.imagePath,
            note: detailResult.note,
          ),
        );
      } else if (detailResult == FoodRemovalResult.deleted) {
        removeFoodFromInventory(original);
      } else if (detailResult == FoodRemovalResult.consumed) {
        markFoodConsumed(original);
      } else if (detailResult == FoodRemovalResult.discarded) {
        markFoodConsumed(original, discarded: true);
      }
    }
  } else if (result.recipe != null) {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecipeDetailScreen(recipe: result.recipe!),
      ),
    );
  }
}

class _GlobalSearchDialog extends StatefulWidget {
  const _GlobalSearchDialog();
  @override
  State<_GlobalSearchDialog> createState() => _GlobalSearchDialogState();
}

class _GlobalSearchDialogState extends State<_GlobalSearchDialog> {
  int tab = 0;
  String query = '';

  List<FoodDetailData> get foods => inventoryFoods
      .map(
        (food) => FoodDetailData.fromSummary(
          name: food.$1,
          detail: food.$2,
          status: food.$3,
          image: food.$4,
          id: food.id,
          imagePath: food.imagePath,
        ),
      )
      .toList();

  final recipes = <RecipeDetailData>[
    RecipeDetailData.fromSummary(
      name: 'Mì cay trứng lòng đào',
      time: '15 phút',
      level: 'Dễ',
      match: '90% có sẵn',
      image: 10,
      ingredientsText: 'Mì · Trứng gà · Hành lá · Nước mắm',
    ),
    RecipeDetailData.fromSummary(
      name: 'Canh rau muống nấu tôm',
      time: '15 phút',
      level: 'Dễ',
      match: '100% có sẵn',
      image: 11,
      ingredientsText: 'Rau muống · Tôm sú · Hành lá',
    ),
    RecipeDetailData.fromSummary(
      name: 'Bò xào cải thảo',
      time: '20 phút',
      level: 'Dễ',
      match: '80% có sẵn',
      image: 12,
      ingredientsText: 'Thịt bò Mỹ · Cải thảo · Dưa leo',
    ),
    RecipeDetailData.fromSummary(
      name: 'Bánh mì ốp la trứng gà',
      time: '10 phút',
      level: 'Dễ',
      match: '75% có sẵn',
      image: 13,
      ingredientsText: 'Trứng gà · Bánh mì · Hành lá',
    ),
    RecipeDetailData.fromSummary(
      name: 'Cá basa kho tiêu',
      time: '25 phút',
      level: 'Vừa',
      match: '90% có sẵn',
      image: 14,
      ingredientsText: 'Cá basa fillet · Nước mắm · Hành lá',
    ),
    RecipeDetailData.fromSummary(
      name: 'Salad cá thu dầu mè',
      time: '5 phút',
      level: 'Dễ',
      match: '90% có sẵn',
      image: 15,
      ingredientsText: 'Cá thu · Dưa leo · Hành lá',
    ),
    RecipeDetailData.fromSummary(
      name: 'Đậu hũ sốt cà chua',
      time: '20 phút',
      level: 'Dễ',
      match: '100% có sẵn',
      image: 4,
      ingredientsText: 'Đậu hũ · Cà chua · Hành lá',
    ),
    RecipeDetailData.fromSummary(
      name: 'Phở bò tái',
      time: '45 phút',
      level: 'Khó',
      match: '60% có sẵn',
      image: 2,
      ingredientsText: 'Thịt bò Mỹ · Bánh phở · Hành lá',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final key = query.trim().toLowerCase();
    final foundFoods = foods
        .where(
          (e) =>
              e.name.toLowerCase().contains(key) ||
              e.category.toLowerCase().contains(key),
        )
        .toList();
    final foundRecipes = recipes
        .where(
          (e) =>
              e.name.toLowerCase().contains(key) ||
              e.ingredients.any((i) => i.name.toLowerCase().contains(key)),
        )
        .toList();
    final length = tab == 0 ? foundFoods.length : foundRecipes.length;
    return Dialog(
      alignment: Alignment.bottomCenter,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 64),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 620),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 14, 6, 7),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 19, color: _muted),
                  const SizedBox(width: 9),
                  Expanded(
                    child: TextField(
                      autofocus: true,
                      onChanged: (value) => setState(() => query = value),
                      decoration: const InputDecoration.collapsed(
                        hintText: 'Tìm thực phẩm hoặc món ăn...',
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 19),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Row(
              children: [
                _Tab(
                  'Thực phẩm (${foundFoods.length})',
                  Icons.kitchen_outlined,
                  tab == 0,
                  () => setState(() => tab = 0),
                ),
                _Tab(
                  'Món ăn (${foundRecipes.length})',
                  Icons.restaurant_menu,
                  tab == 1,
                  () => setState(() => tab = 1),
                ),
              ],
            ),
            Expanded(
              child: length == 0
                  ? const Center(
                      child: Text(
                        'Không tìm thấy kết quả phù hợp',
                        style: TextStyle(color: _muted),
                      ),
                    )
                  : ListView.builder(
                      itemCount: length,
                      itemBuilder: (_, index) => tab == 0
                          ? _ResultTile(
                              image: foundFoods[index].image,
                              foodImagePath: foundFoods[index].imagePath,
                              foodName: foundFoods[index].name,
                              title: foundFoods[index].name,
                              subtitle:
                                  '${foundFoods[index].quantity} · ${foundFoods[index].price} · ${foundFoods[index].category}',
                              badge: foundFoods[index].status,
                              onTap: () => Navigator.pop(
                                context,
                                _SearchSelection(food: foundFoods[index]),
                              ),
                            )
                          : _ResultTile(
                              image: foundRecipes[index].image,
                              title: foundRecipes[index].name,
                              subtitle:
                                  '${foundRecipes[index].time} · ${foundRecipes[index].level} · ${foundRecipes[index].match}',
                              badge: foundRecipes[index].meal,
                              onTap: () => Navigator.pop(
                                context,
                                _SearchSelection(recipe: foundRecipes[index]),
                              ),
                            ),
                    ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              color: const Color(0xFFF8F9FA),
              child: const Text(
                'Chạm vào kết quả để xem chi tiết',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: _muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab(this.label, this.icon, this.active, this.onTap);
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              width: 2,
              color: active ? _green : Colors.transparent,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: active ? _green : _muted),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: active ? _green : _muted,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.image,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.onTap,
    this.foodName,
    this.foodImagePath,
  });
  final int image;
  final String title, subtitle, badge;
  final String? foodName;
  final String? foodImagePath;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: foodName == null
                ? Image.asset(
                    '$_assets${image == 0 ? 'search-image' : 'search-image($image)'}',
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                  )
                : FoodImage(
                    name: foodName!,
                    assetIndex: image,
                    imagePath: foodImagePath,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                  ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE9FBF4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(fontSize: 9, color: _green),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: _muted),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 18, color: _muted),
        ],
      ),
    ),
  );
}
