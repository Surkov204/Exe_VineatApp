import 'app_services.dart';
import 'household_data_repository.dart';
import 'inventory_store.dart';
import 'meal_plan.dart';
import 'menu_ingredients.dart';
import 'expiry_assistant.dart' show normalizeExpiryFoodName;

class UsagePlan {
  const UsagePlan(
    this.uses,
    this.missing, {
    this.notes = const {},
    this.recipeLotIds = const {},
  });
  final List<InventoryUsage> uses;
  final List<String> missing;
  final Map<String, String> notes;
  final Set<String> recipeLotIds;
}

String usageIngredientKey(String name) =>
    normalizeExpiryFoodName(ingredientKey(name));

// Editable culinary suggestions in count units, NOT gram-to-piece conversions.
double? _countSuggestion(String name, String unit) {
  final key = usageIngredientKey(name);
  final normalizedUnit = normalizeExpiryFoodName(unit);
  if (normalizedUnit == 'qua' &&
      ['ca chua', 'dua leo', 'chuoi', 'trung ga'].contains(key)) {
    return 1;
  }
  if (normalizedUnit == 'cu' && ['ca rot', 'khoai tay'].contains(key)) {
    return .5;
  }
  if (normalizedUnit == 'bo' &&
      ['rau muong', 'hanh la', 'cai xanh'].contains(key)) {
    return .25;
  }
  if (normalizedUnit == 'cai' && ['bong cai xanh', 'cai thao'].contains(key)) {
    return .25;
  }
  if (normalizedUnit == 'mieng' && key == 'dau hu') return 1;
  return null;
}

String usageAmount(double n) =>
    n.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');

/// Read-only FEFO allocation. Previewing a dish never changes inventory.
UsagePlan planDishUsage(
  PlannedDish dish,
  int people,
  List<FoodSummary> stock, {
  DateTime? today,
}) {
  final day = menuDay(today ?? DateTime.now());
  final lots =
      stock
          .where(
            (f) =>
                f.quantity > 0 &&
                (f.expiry == null || !menuDay(f.expiry!).isBefore(day)),
          )
          .toList()
        ..sort(
          (a, b) => (a.expiry ?? DateTime(9999)).compareTo(
            b.expiry ?? DateTime(9999),
          ),
        );
  final quantities = <String, double>{};
  final notes = <String, String>{};
  final recipeIds = <String>{};
  final missing = <String>[];
  final names = dish.amounts.isEmpty
      ? dish.ingredients
      : dish.amounts.map((i) => i.name).toList();
  for (var index = 0; index < names.length; index++) {
    final name = names[index];
    final custom = dish.amounts.isEmpty ? null : dish.amounts[index];
    final portion = custom == null
        ? ingredientPortion(name)
        : (quantity: custom.forPeople(1), unit: custom.unit);
    final matching = lots
        .where((f) => usageIngredientKey(f.name) == usageIngredientKey(name))
        .toList();
    recipeIds.addAll(matching.map((f) => f.id));
    if (matching.isEmpty) {
      missing.add('$name: chưa có nguyên liệu còn hạn trong tủ');
      continue;
    }
    final base = portion == null ? null : unitBase(portion.unit);
    var compatible = matching
        .where((f) => unitBase(f.unit).base == base?.base)
        .toList();
    double? requiredQuantity = portion == null
        ? null
        : portion.quantity * people * base!.factor;
    var factorUnit = base?.base;
    var estimated = false;
    if (compatible.isEmpty) {
      final first = matching.first;
      final count = custom == null ? _countSuggestion(name, first.unit) : null;
      if (count == null) {
        quantities.putIfAbsent(first.id, () => 0);
        notes[first.id] =
            'Chưa có định lượng phù hợp với ${first.unit}. Nhập lượng thực tế; không tự quy đổi từ gram sang đơn vị đếm.';
        continue;
      }
      requiredQuantity = count * people;
      factorUnit = unitBase(first.unit).base;
      compatible = matching
          .where((f) => unitBase(f.unit).base == factorUnit)
          .toList();
      estimated = true;
    }
    var remaining = requiredQuantity!;
    for (final lot in compatible) {
      final conversion = unitBase(lot.unit);
      final available =
          (lot.quantity - (quantities[lot.id] ?? 0)) * conversion.factor;
      final used = remaining < available ? remaining : available;
      if (used <= 0) continue;
      quantities[lot.id] = (quantities[lot.id] ?? 0) + used / conversion.factor;
      if (estimated) {
        notes[lot.id] =
            'Gợi ý theo ${lot.unit}, không phải quy đổi từ gram. Hãy chỉnh theo lượng thực tế đã dùng.';
      }
      remaining -= used;
    }
    if (remaining > .0001) {
      missing.add('$name: thiếu ${usageAmount(remaining)} $factorUnit');
    }
  }
  return UsagePlan(
    [
      for (final lot in lots)
        if (quantities.containsKey(lot.id))
          InventoryUsage(food: lot, quantity: quantities[lot.id]!),
    ],
    missing,
    notes: notes,
    recipeLotIds: recipeIds,
  );
}

/// Server-first, atomic and idempotent. A retry uses the SAME operation id.
Future<void> confirmInventoryUsage(
  List<InventoryUsage> uses, {
  required String operationId,
  String? dishName,
  int people = 1,
}) async {
  if (uses.isEmpty) throw StateError('Chưa chọn nguyên liệu');
  final ids = <String>{};
  for (final use in uses) {
    final current = inventoryFoods
        .where((f) => f.id == use.food.id)
        .firstOrNull;
    if (!ids.add(use.food.id) ||
        !use.quantity.isFinite ||
        use.quantity <= 0 ||
        (!AppServices.configured &&
            (current == null ||
                current.unit != use.food.unit ||
                use.quantity > current.quantity + .0001))) {
      throw StateError('Tồn kho đã thay đổi. Kiểm tra lại lượng sử dụng.');
    }
  }
  if (AppServices.configured) {
    await HouseholdDataRepository.instance.confirmUsage(
      operationId,
      uses,
      dishName: dishName,
      people: people,
    );
    // The mutation is committed already. A failed refresh must not trigger a new deduction.
    try {
      final snapshot = await HouseholdDataRepository.instance
          .loadActiveHousehold();
      replaceInventoryFromRemote(
        records: snapshot.inventory,
        events: snapshot.events,
      );
      HouseholdDataRepository.instance.syncStatus.value = null;
    } catch (_) {
      HouseholdDataRepository.instance.syncStatus.value =
          'Đã ghi nhận xuất. Đang chờ tải lại tồn kho từ máy chủ.';
    }
    return;
  }
  for (final use in uses) {
    final current = inventoryFoods.firstWhere((f) => f.id == use.food.id);
    consumeFoodAmount(current, use.quantity);
  }
  if (dishName != null) recordRecipeCooked(dishName);
}
