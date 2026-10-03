import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_services.dart';
import 'diet_preferences.dart';
import 'recipe_detail.dart';
import 'menu_ingredients.dart';
import 'household_data_repository.dart';
import 'inventory_store.dart';

DateTime menuDay(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime menuWeek(DateTime d) =>
    menuDay(d).subtract(Duration(days: d.weekday - 1));
String menuDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
const mealSlots = {
  'breakfast': 'Bữa sáng',
  'lunch': 'Bữa trưa',
  'dinner': 'Bữa tối',
};
List<PlannedDish> menuShoppingDishes(
  List<PlannedDish> items,
  DateTime day,
  bool weekly,
) => items
    .where(
      (dish) => weekly
          ? menuWeek(dish.date) == menuWeek(day)
          : dish.date == menuDay(day),
    )
    .toList();

class DishIngredient {
  const DishIngredient({
    required this.name,
    required this.quantity,
    required this.unit,
    this.servings = 1,
    this.inventoryId,
  });
  final String name, unit;
  final double quantity;
  final int servings;
  final String? inventoryId;
  Map<String, dynamic> toJson() => {
    'name': name,
    'quantity': quantity,
    'unit': unit,
    'servings': servings,
    'inventory_id': inventoryId,
  };
  factory DishIngredient.fromJson(Map v) => DishIngredient(
    name: v['name'] as String,
    quantity: (v['quantity'] as num).toDouble(),
    unit: v['unit'] as String,
    servings: (v['servings'] as num?)?.toInt() ?? 1,
    inventoryId: v['inventory_id'] as String?,
  );
  double forPeople(int people) =>
      quantity * people / (servings > 0 ? servings : 1);
}

class PlannedDish {
  const PlannedDish({
    required this.date,
    required this.slot,
    required this.name,
    this.recipeKey,
    this.ingredients = const [],
    this.amounts = const [],
  });
  final DateTime date;
  final String slot;
  final String name;
  final String? recipeKey;
  final List<String> ingredients;
  final List<DishIngredient> amounts;
  Map<String, dynamic> toJson() => {
    'date': menuDate(date),
    'slot': slot,
    'name': name,
    'recipe_key': recipeKey,
    'ingredients': amounts.isEmpty
        ? ingredients
        : amounts.map((i) => i.toJson()).toList(),
  };
  factory PlannedDish.fromJson(Map<String, dynamic> v) => PlannedDish(
    date: DateTime.parse(v['date'] as String),
    slot: v['slot'] as String,
    name: v['name'] as String,
    recipeKey: v['recipe_key'] as String?,
    ingredients: (v['ingredients'] as List? ?? [])
        .map((i) => i is Map ? i['name'] as String : i as String)
        .toList(),
    amounts: (v['ingredients'] as List? ?? [])
        .whereType<Map>()
        .map(DishIngredient.fromJson)
        .toList(),
  );
}

List<PlannedDish> suggestMenu(
  List<RecipeCatalogItem> catalog,
  DietKind diet,
  DateTime start,
  int days,
) {
  final combined = {
    for (final r in [...catalog, ...menuSupportingRecipes]) r.id: r,
  };
  final suitable = combined.values
      .where((r) => diet == DietKind.normal || r.diets.contains(diet))
      .toList();
  if (suitable.isEmpty) return [];
  final used = <String, int>{};
  final result = <PlannedDish>[];
  for (var day = 0; day < days; day++) {
    for (final slot in mealSlots.keys) {
      for (final role
          in slot == 'breakfast'
              ? [MenuRole.light]
              : [MenuRole.main, MenuRole.vegetable, MenuRole.soup]) {
        final pool = suitable.where((r) => menuRole(r) == role).toList();
        if (pool.isEmpty) continue;
        pool.sort((a, b) {
          final reuse = (used[a.id] ?? 0).compareTo(used[b.id] ?? 0);
          if (reuse != 0) return reuse;
          final readyA = a
              .toDetailData()
              .ingredients
              .where((i) => i.available)
              .length;
          final readyB = b
              .toDetailData()
              .ingredients
              .where((i) => i.available)
              .length;
          return readyB.compareTo(readyA);
        });
        final recipe = pool.first;
        used[recipe.id] = (used[recipe.id] ?? 0) + 1;
        result.add(
          PlannedDish(
            date: menuDay(start.add(Duration(days: day))),
            slot: slot,
            name: recipe.name,
            recipeKey: recipe.id,
            ingredients: recipe.ingredients,
          ),
        );
      }
    }
  }
  return result;
}

class WeekMenuStore {
  WeekMenuStore(this.week)
    : householdId = AppServices.configured
          ? HouseholdService.instance.active.value?.id
          : null;
  final DateTime week;
  final String? householdId;
  int revision = 0;
  String get key =>
      'vineat.week_menu.${householdId ?? 'local'}.${menuDate(week)}';
  void checkScope() {
    if (AppServices.configured &&
        (householdId == null ||
            HouseholdService.instance.active.value?.id != householdId)) {
      throw StateError('Gia đình đã thay đổi. Mở lại thực đơn.');
    }
  }

  Future<int> memberCount() async {
    if (!AppServices.configured) return 1;
    checkScope();
    final members = await AppServices.client
        .from('household_members')
        .select('user_id')
        .eq('household_id', householdId!);
    checkScope();
    if (members.isEmpty) throw StateError('Chưa tải được thành viên');
    return members.length;
  }

  Future<int> plannedPeople(DateTime day) async {
    checkScope();
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt('$key.people.${menuDate(day)}');
    checkScope();
    return count != null && count >= 1 && count <= 30 ? count : memberCount();
  }

  Future<void> savePeople(int people, {DateTime? day}) async {
    checkScope();
    final prefs = await SharedPreferences.getInstance();
    checkScope();
    for (final date
        in day == null
            ? List.generate(7, (i) => week.add(Duration(days: i)))
            : [menuDay(day)]) {
      await prefs.setInt('$key.people.${menuDate(date)}', people.clamp(1, 30));
    }
  }

  Future<void> confirmPurchases(
    List<MenuPurchase> lines, {
    DateTime? day,
  }) async {
    checkScope();
    if (AppServices.configured) {
      await AppServices.client.rpc(
        'confirm_menu_shopping',
        params: {
          'p_household': householdId,
          'p_week': menuDate(week),
          'p_revision': revision,
          'p_day': day == null ? null : menuDate(day),
          'p_items': lines
              .map(
                (l) => {
                  'name': l.name,
                  'quantity': l.buyQuantity,
                  'unit': l.unit,
                  'needed_date': menuDate(l.neededDate),
                  'menu_day': menuDate(l.neededDate),
                  'note': l.note,
                },
              )
              .toList(),
        },
      );
      checkScope();
      final rows = await HouseholdDataRepository.instance.loadShoppingItems();
      replaceShoppingFromRemote(
        items: rows.map((r) => r.item).toList(),
        checked: rows.where((r) => r.checked).map((r) => r.id).toSet(),
      );
    } else {
      shoppingItems.removeWhere(
        (s) =>
            s.menuPlanId == key &&
            (day == null || s.menuDay == menuDay(day)) &&
            !shoppingChecked.contains(s.id),
      );
      shoppingItems.addAll(
        lines.map(
          (l) => ShoppingSummary(
            name: l.name,
            quantity: l.buyQuantity,
            unit: l.unit,
            note: l.note,
            neededDate: l.neededDate,
            menuDay: l.neededDate,
            menuPlanId: key,
            priority:
                l.neededDate.difference(menuDay(DateTime.now())).inDays <= 1
                ? 'Cần mua gấp'
                : 'Bình thường',
          ),
        ),
      );
      shoppingRevision.value++;
      await persistShopping(shoppingItems, shoppingChecked, syncRemote: false);
    }
  }

  Future<List<PlannedDish>> load() async {
    checkScope();
    if (!AppServices.configured) {
      final prefs = await SharedPreferences.getInstance();
      return (jsonDecode(prefs.getString(key) ?? '[]') as List)
          .map((v) => PlannedDish.fromJson(Map<String, dynamic>.from(v)))
          .toList();
    }
    final row = await AppServices.client
        .from('meal_plans')
        .select(
          'revision,meal_plan_entries(planned_date,meal_slot,dish_name,recipe_key,ingredients)',
        )
        .eq('household_id', householdId!)
        .eq('week_start', menuDate(week))
        .maybeSingle();
    checkScope();
    revision = (row?['revision'] as num?)?.toInt() ?? 0;
    return ((row?['meal_plan_entries'] as List?) ?? [])
        .where((v) => v['dish_name'] != null)
        .map(
          (v) => PlannedDish.fromJson({
            'date': v['planned_date'],
            'slot': v['meal_slot'],
            'name': v['dish_name'],
            'recipe_key': v['recipe_key'],
            'ingredients': v['ingredients'],
          }),
        )
        .toList();
  }

  Future<void> save(List<PlannedDish> items) async {
    checkScope();
    final rows = items.map((e) => e.toJson()).toList();
    if (!AppServices.configured) {
      await (await SharedPreferences.getInstance()).setString(
        key,
        jsonEncode(rows),
      );
      return;
    }
    final next = await AppServices.client.rpc(
      'save_week_menu',
      params: {
        'p_household': householdId,
        'p_week': menuDate(week),
        'p_revision': revision,
        'p_items': rows,
      },
    );
    checkScope();
    revision = (next as num).toInt();
  }
}
