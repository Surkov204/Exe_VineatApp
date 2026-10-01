import 'diet_preferences.dart';
import 'recipe_detail.dart';
import 'inventory_store.dart';
import 'meal_plan.dart';

enum MenuRole { light, main, vegetable, soup, standalone }

const menuRecipeRoles = <String, MenuRole>{
  'egg-banh-mi': MenuRole.light,
  'egg-tomato-stir-fry': MenuRole.light,
  'oat-banana-bowl': MenuRole.light,
  'banana-oat-soy-bowl': MenuRole.light,
  'light-steamed-tofu': MenuRole.light,
  'spicy-egg-noodles': MenuRole.standalone,
  'pho-bo-tai': MenuRole.standalone,
  'rice-chicken-cucumber': MenuRole.standalone,
  'water-spinach-shrimp-soup': MenuRole.soup,
  'shrimp-vegetable-soup': MenuRole.soup,
  'pumpkin-tofu-soup': MenuRole.soup,
  'green-tofu-soup': MenuRole.soup,
  'mixed-vegetable-stir-fry': MenuRole.vegetable,
  'steamed-broccoli-carrot': MenuRole.vegetable,
};
MenuRole menuRole(RecipeCatalogItem r) =>
    menuRecipeRoles[r.id] ??
    (r.categories.contains(RecipeCategory.breakfast) && r.durationMinutes <= 15
        ? MenuRole.light
        : MenuRole.main);
const _allDiets = {
  DietKind.vegetarian,
  DietKind.vegan,
  DietKind.pescatarian,
  DietKind.meatNoFish,
  DietKind.vegetableForward,
  DietKind.lowCalorie,
  DietKind.highProtein,
  DietKind.noEgg,
  DietKind.lowerCarb,
};
const menuSupportingRecipes = [
  RecipeCatalogItem(
    id: 'light-steamed-tofu',
    name: 'Đậu hũ hấp rau củ',
    durationMinutes: 10,
    difficulty: RecipeDifficulty.easy,
    imageIndex: 4,
    ingredients: ['Đậu hũ', 'Cà rốt'],
    diets: _allDiets,
    categories: {RecipeCategory.breakfast},
  ),
  RecipeCatalogItem(
    id: 'steamed-broccoli-carrot',
    name: 'Bông cải và cà rốt hấp',
    durationMinutes: 15,
    difficulty: RecipeDifficulty.easy,
    imageIndex: 4,
    ingredients: ['Bông cải xanh', 'Cà rốt'],
    diets: _allDiets,
    vegetableCentric: true,
  ),
  RecipeCatalogItem(
    id: 'green-tofu-soup',
    name: 'Canh cải xanh đậu hũ',
    durationMinutes: 15,
    difficulty: RecipeDifficulty.easy,
    imageIndex: 4,
    ingredients: ['Cải xanh', 'Đậu hũ'],
    diets: _allDiets,
    vegetableCentric: true,
  ),
];

// Culinary starting quantities, not validated nutritional prescriptions.
({double quantity, String unit})? ingredientPortion(String name) {
  if (name == 'Trứng gà' || name == 'Chuối') return (quantity: 1, unit: 'quả');
  if (name == 'Sữa đậu nành') return (quantity: 200, unit: 'ml');
  if (name == 'Sữa chua') return (quantity: 1, unit: 'hộp');
  if (name == 'Bánh mì') return (quantity: 1, unit: 'cái');
  if (name == 'Yến mạch') return (quantity: 40, unit: 'gram');
  if (name == 'Mì') return (quantity: 60, unit: 'gram');
  if (name == 'Dầu ăn') return (quantity: 5, unit: 'ml');
  if (name == 'Gạo lứt') return (quantity: 50, unit: 'gram');
  if (name == 'Nước mắm') return (quantity: 5, unit: 'ml');
  if (name == 'Hành lá' || name == 'Tỏi') return (quantity: 5, unit: 'gram');
  if ([
    'Thịt bò Mỹ',
    'Thịt bò',
    'Ức gà',
    'Cá basa fillet',
    'Cá thu',
    'Cá hồi',
    'Cá ngừ',
    'Tôm sú',
    'Đậu hũ',
  ].contains(name)) {
    return (quantity: 100, unit: 'gram');
  }
  if ([
    'Rau muống',
    'Cải thảo',
    'Dưa leo',
    'Cà chua',
    'Xà lách',
    'Bông cải xanh',
    'Cà rốt',
    'Nấm đùi gà',
    'Bí đỏ',
    'Cải xanh',
  ].contains(name)) {
    return (quantity: 80, unit: 'gram');
  }
  return null;
}

String ingredientKey(String s) =>
    s.trim().toLowerCase() == 'thịt bò mỹ' ? 'thịt bò' : s.trim().toLowerCase();
({double factor, String base}) unitBase(String unit) =>
    switch (unit.trim().toLowerCase()) {
      'kg' || 'kilogram' => (factor: 1000, base: 'gram'),
      'g' || 'gram' => (factor: 1, base: 'gram'),
      'l' || 'lít' => (factor: 1000, base: 'ml'),
      'ml' => (factor: 1, base: 'ml'),
      final value => (factor: 1, base: value),
    };

class MenuPurchase {
  MenuPurchase(this.name, this.unit, this.neededDate);
  final String name, unit;
  DateTime neededDate;
  double requiredQuantity = 0, stockUsed = 0, buyQuantity = 0;
  // Planning coverage only. No inventory is mutated or reserved here.
  double stockAvailable = 0;
  final notes = <String>[];
  String get note => notes.join('; ');
}

class MenuPurchaseResult {
  const MenuPurchaseResult(this.lines, this.unmeasured);
  final List<MenuPurchase> lines;
  final Set<String> unmeasured;
}

MenuPurchaseResult buildMenuPurchases(
  List<PlannedDish> dishes,
  int people,
  List<FoodSummary> stock, {
  DateTime? today,
  bool groupByDay = false,
  bool includeCovered = false,
}) {
  final base = menuDay(today ?? DateTime.now());
  final sorted = dishes.where((d) => !d.date.isBefore(base)).toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  final remaining = {
    for (final f in stock) f.id: f.quantity * unitBase(f.unit).factor,
  };
  final lots = List<FoodSummary>.of(stock)
    ..sort(
      (a, b) =>
          (a.expiry ?? DateTime(9999)).compareTo(b.expiry ?? DateTime(9999)),
    );
  final lines = <String, MenuPurchase>{};
  final unknown = <String>{};
  for (final dish in sorted) {
    if (dish.ingredients.isEmpty && dish.amounts.isEmpty) {
      unknown.add(dish.name);
    }
    final names = dish.amounts.isEmpty
        ? dish.ingredients
        : dish.amounts.map((i) => i.name).toList();
    for (var index = 0; index < names.length; index++) {
      final name = names[index];
      final custom = dish.amounts.isEmpty ? null : dish.amounts[index];
      final conversion = custom == null ? null : unitBase(custom.unit);
      final portion = custom == null
          ? ingredientPortion(name)
          : (
              quantity: custom.forPeople(1) * conversion!.factor,
              unit: conversion.base,
            );
      if (portion == null) {
        unknown.add(name);
        continue;
      }
      final identity =
          '${ingredientKey(name)}|${portion.unit}${groupByDay ? '|${menuDate(dish.date)}' : ''}';
      final line = lines.putIfAbsent(
        identity,
        () => MenuPurchase(name, portion.unit, dish.date),
      );
      final demand = portion.quantity * people;
      line.requiredQuantity += demand;
      line.notes.add(
        '${dish.date.weekday == 7 ? 'CN' : 'T${dish.date.weekday + 1}'} ${dish.date.day}/${dish.date.month} · ${mealSlots[dish.slot]} · ${dish.name} ($people người)',
      );
      var missing = demand;
      for (final lot in lots) {
        if (ingredientKey(lot.name) != ingredientKey(name) ||
            unitBase(lot.unit).base != portion.unit ||
            (lot.expiry != null && menuDay(lot.expiry!).isBefore(dish.date))) {
          continue;
        }
        final available = remaining[lot.id] ?? 0;
        final used = available < missing ? available : missing;
        if (used <= 0) continue;
        remaining[lot.id] = available - used;
        missing -= used;
        line.stockUsed += used;
        // Keep counting compatible stock for the preview even if demand is met.
      }
      if (missing > 0) {
        if (line.buyQuantity == 0) line.neededDate = dish.date;
        line.buyQuantity += missing;
      }
    }
  }
  for (final line in lines.values) {
    line.stockAvailable = lots
        .where(
          (lot) =>
              ingredientKey(lot.name) == ingredientKey(line.name) &&
              unitBase(lot.unit).base == line.unit &&
              (lot.expiry == null ||
                  !menuDay(lot.expiry!).isBefore(line.neededDate)),
        )
        .fold<double>(
          0,
          (sum, lot) => sum + lot.quantity * unitBase(lot.unit).factor,
        );
  }
  return MenuPurchaseResult(
    lines.values.where((l) => includeCovered || l.buyQuantity > 0).toList()
      ..sort((a, b) => a.neededDate.compareTo(b.neededDate)),
    unknown,
  );
}
