import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_services.dart';
import 'household_data_repository.dart';
import 'inventory_models.dart';

export 'inventory_models.dart'
    show FoodSummary, ShoppingSummary, InventoryItemRecord, InventoryEvent;

class ShoppingSnapshot {
  const ShoppingSnapshot(this.items, this.checked, this.links);
  final List<ShoppingSummary> items;
  final Set<int> checked;
  final Map<String, ShoppingInventoryLink> links;
}

/// The small local store used by the demo flow.
///
/// It intentionally keeps the prototype's compact tuple at the UI boundary,
/// but owns persistence so every screen reads the same inventory and a demo
/// survives an app restart on Android.
final demoInventorySeed = <FoodSummary>[
  FoodSummary.fromLegacy(
    name: 'Rau muống',
    detail: '2 bó · 15.000đ',
    status: 'Còn 2 ngày',
    imageIndex: 0,
  ),
  FoodSummary.fromLegacy(
    name: 'Cà chua',
    detail: '5 quả · 25.000đ',
    status: 'Tươi ngon',
    imageIndex: 1,
  ),
  FoodSummary.fromLegacy(
    name: 'Thịt heo ba chỉ',
    detail: '500 gram · 65.000đ',
    status: 'Còn 3 ngày',
    imageIndex: 2,
  ),
  FoodSummary.fromLegacy(
    name: 'Cá basa fillet',
    detail: '3 miếng · 45.000đ',
    status: 'Hết hạn',
    imageIndex: 3,
  ),
  FoodSummary.fromLegacy(
    name: 'Trứng gà',
    detail: '10 quả · 35.000đ',
    status: 'Tươi ngon',
    imageIndex: 4,
  ),
  FoodSummary.fromLegacy(
    name: 'Cải thảo',
    detail: '1 cây · 20.000đ',
    status: 'Tươi ngon',
    imageIndex: 5,
  ),
  FoodSummary.fromLegacy(
    name: 'Gạo ST25',
    detail: '5 kg · 175.000đ',
    status: 'Tươi ngon',
    imageIndex: 6,
  ),
  FoodSummary.fromLegacy(
    name: 'Nước mắm Nam Ngư',
    detail: '1 chai · 42.000đ',
    status: 'Tươi ngon',
    imageIndex: 7,
  ),
  FoodSummary.fromLegacy(
    name: 'Sữa tươi Vinamilk',
    detail: '2 hộp · 32.000đ',
    status: 'Tươi ngon',
    imageIndex: 8,
  ),
  FoodSummary.fromLegacy(
    name: 'Hành lá',
    detail: '1 bó · 3.000đ',
    status: 'Tươi ngon',
    imageIndex: 9,
  ),
];

final inventoryFoods = <FoodSummary>[...demoInventorySeed];

final inventoryRevision = ValueNotifier<int>(0);
final customFoodImagePaths = <String, String>{};
final inventoryEvents = <InventoryEvent>[];
final shoppingInventoryLinks = <String, ShoppingInventoryLink>{};
final shoppingItems = AppServices.configured
    ? <ShoppingSummary>[]
    : <ShoppingSummary>[
        (
          'Thịt gà ta',
          '1 kg · Mua con gà ta nguyên con, làm sẵn',
          'Cần mua gấp',
          'Mẹ',
          'Thịt cá',
        ),
        (
          'Dứa',
          '1 quả · Dứa chín vàng, để nấu canh chua',
          'Bình thường',
          'Mẹ',
          'Rau củ',
        ),
        (
          'Bánh phở',
          '2 gói · Bánh phở tươi loại dày',
          'Cần mua gấp',
          'Bố',
          'Đồ khô',
        ),
        ('Tỏi', '200 gram · Tỏi Lý Sơn', 'Bình thường', 'Bố', 'Rau củ'),
        (
          'Sữa chua Vinamilk',
          '1 lốc · Sữa chua có đường',
          'Có cũng được',
          'Con (Minh)',
          'Khác',
        ),
        (
          'Đậu phộng',
          '200 gram · Đậu phộng rang sẵn',
          'Có cũng được',
          'Mẹ',
          'Đồ khô',
        ),
        ('Dầu hào', '1 chai · Dầu hào Maggi', 'Bình thường', 'Bố', 'Đồ khô'),
        (
          'Cần tây',
          '2 cây · Cần tây tươi, lá xanh',
          'Bình thường',
          'Mẹ',
          'Rau củ',
        ),
        (
          'Cá hồi phi lê',
          '2 miếng · Cá hồi Na Uy, mua ở siêu thị',
          'Cần mua gấp',
          'Bố',
          'Thịt cá',
        ),
      ];
final shoppingChecked = AppServices.configured ? <int>{} : <int>{4, 6};
final shoppingRevision = ValueNotifier<int>(0);

Future<void> _inventoryWriteQueue = Future<void>.value();
Future<void> _shoppingWriteQueue = Future<void>.value();
Future<void>? _localRestoreOperation;

const _inventoryKey = 'vineat.demo.inventory.v1';
const _shoppingKey = 'vineat.demo.shopping.v1';
const _eventsKey = 'vineat.demo.events.v1';
const _householdCacheScopeKey = 'vineat.household_cache_scope.v1';

/// Shares a single in-flight cache restore between app startup and the
/// authenticated household gate without delaying the login screen.
Future<void> restoreLocalDemoData() async {
  final pending = _localRestoreOperation;
  if (pending != null) return pending;
  final operation = () async {
    final preferences = await SharedPreferences.getInstance();
    // Remote household snapshots are always fetched again under RLS. Never
    // hydrate another user's last household into a new account's import preview.
    if (preferences.containsKey(_householdCacheScopeKey)) return;
    await restoreInventory();
    final shopping = await restoreShopping();
    if (shopping != null) {
      shoppingItems
        ..clear()
        ..addAll(shopping.items);
      shoppingChecked
        ..clear()
        ..addAll(shopping.checked);
      shoppingRevision.value++;
    }
  }();
  _localRestoreOperation = operation;
  try {
    await operation;
  } finally {
    if (identical(_localRestoreOperation, operation)) {
      _localRestoreOperation = null;
    }
  }
}

Future<List<FoodSummary>> localDemoPreviewSnapshot() async {
  final preferences = await SharedPreferences.getInstance();
  if (preferences.containsKey(_householdCacheScopeKey)) {
    return List<FoodSummary>.of(demoInventorySeed);
  }
  return List<FoodSummary>.of(inventoryFoods);
}

Future<void> restoreInventory() async {
  final revisionAtStart = inventoryRevision.value;
  try {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_inventoryKey);
    if (encoded == null) return;
    final decoded = jsonDecode(encoded);
    if (decoded is! List) return;
    if (inventoryRevision.value != revisionAtStart) return;

    final restored = <FoodSummary>[];
    final restoredImagePaths = <String, String>{};
    for (final value in decoded) {
      if (value is! Map) continue;
      final name = value['name'];
      final detail = value['detail'];
      final status = value['status'];
      final image = value['image'];
      if (name is String &&
          detail is String &&
          status is String &&
          image is num) {
        final id = value['id'];
        final imageId = id is String && id.isNotEmpty ? id : null;
        final imagePath = value['imagePath'];
        if (imagePath is String && imagePath.isNotEmpty) {
          if (imageId != null) restoredImagePaths[imageId] = imagePath;
        }
        restored.add(
          FoodSummary.fromLegacy(
            id: imageId,
            name: name,
            detail: detail,
            status: status,
            imageIndex: image.toInt(),
            imagePath: imagePath is String ? imagePath : null,
          ),
        );
      }
    }
    inventoryFoods
      ..clear()
      ..addAll(restored);
    customFoodImagePaths
      ..clear()
      ..addAll(restoredImagePaths);
    final encodedEvents = preferences.getString(_eventsKey);
    if (encodedEvents != null) {
      final rawEvents = jsonDecode(encodedEvents);
      if (rawEvents is List) {
        inventoryEvents
          ..clear()
          ..addAll(rawEvents.whereType<Map>().map(InventoryEvent.fromJson));
      }
    }
    inventoryRevision.value++;
  } catch (_) {
    // A corrupt demo cache must never prevent the app from opening.
  }
}

Future<void> _persistInventory() {
  final revisionAtQueue = inventoryRevision.value;
  final cacheScope = _householdCacheScope();
  final encoded = jsonEncode(
    inventoryFoods
        .map(
          (food) => {
            ...food.toJson(),
            'detail': food.$2,
            'status': food.$3,
            'image': food.$4,
            'imagePath': customFoodImagePaths[food.id] ?? food.imagePath,
          },
        )
        .toList(),
  );
  final write = _inventoryWriteQueue.then((_) async {
    if (revisionAtQueue != inventoryRevision.value) return;
    try {
      final preferences = await SharedPreferences.getInstance();
      if (revisionAtQueue != inventoryRevision.value) return;
      await preferences.setString(_inventoryKey, encoded);
      if (cacheScope == null) {
        await preferences.remove(_householdCacheScopeKey);
      } else {
        await preferences.setString(_householdCacheScopeKey, cacheScope);
      }
    } catch (_) {
      // The in-memory state remains usable when storage is temporarily absent.
    }
  });
  _inventoryWriteQueue = write;
  return write;
}

void addFoodsToInventory(Iterable<FoodSummary> foods) {
  for (final food in foods) {
    inventoryFoods.add(food);
    _recordEvent('added', food);
    final id = food.id;
    _withRemoteSync(() async {
      await HouseholdDataRepository.instance.upsertInventory(
        food,
        id,
        localImagePath: customFoodImagePaths[food.id] ?? food.imagePath,
      );
      await HouseholdDataRepository.instance.logInventoryEvent(
        id: id,
        eventType: 'added',
        quantity: InventoryItemRecord.fromSummary(food).quantity,
        valueVnd: InventoryItemRecord.fromSummary(food).priceVnd,
        metadata: {'unit': InventoryItemRecord.fromSummary(food).unit},
      );
    });
  }
  inventoryRevision.value++;
  unawaited(_persistInventory());
}

void removeFoodFromInventory(FoodSummary food) {
  _removeFood(food, eventType: 'removed');
}

void _removeFood(FoodSummary food, {required String eventType}) {
  if (!inventoryFoods.contains(food)) return;
  final id = food.id;
  _recordEvent(eventType, food);
  inventoryFoods.remove(food);
  customFoodImagePaths.remove(food.id);
  _withRemoteSync(() async {
    if (eventType == 'consumed' || eventType == 'discarded') {
      await HouseholdDataRepository.instance.consumeInventory(
        id,
        InventoryItemRecord.fromSummary(food).quantity,
        discarded: eventType == 'discarded',
      );
    } else {
      await HouseholdDataRepository.instance.logInventoryEvent(
        id: id,
        eventType: 'updated',
        quantity: 0,
        valueVnd: 0,
        metadata: {'action': 'removed'},
      );
      await HouseholdDataRepository.instance.deleteInventory(id);
    }
  });
  inventoryRevision.value++;
  unawaited(_persistInventory());
}

void updateFoodInInventory(FoodSummary before, FoodSummary after) {
  final index = inventoryFoods.indexOf(before);
  if (index < 0) return;
  final updated = after.copyWith(id: before.id);
  inventoryFoods[index] = updated;
  _recordEvent('updated', after);
  _withRemoteSync(() async {
    await HouseholdDataRepository.instance.upsertInventory(
      updated,
      updated.id,
      localImagePath: customFoodImagePaths[updated.id] ?? updated.imagePath,
    );
    await HouseholdDataRepository.instance.logInventoryEvent(
      id: updated.id,
      eventType: 'updated',
      quantity: InventoryItemRecord.fromSummary(updated).quantity,
      valueVnd: InventoryItemRecord.fromSummary(updated).priceVnd,
      metadata: {'unit': updated.unit},
    );
  });
  inventoryRevision.value++;
  unawaited(_persistInventory());
}

void markFoodConsumed(FoodSummary food, {bool discarded = false}) {
  consumeFoodAmount(
    food,
    InventoryItemRecord.fromSummary(food).quantity,
    discarded: discarded,
  );
}

void recordRecipeCooked(String recipeName) {
  inventoryEvents.add(
    InventoryEvent(
      id: newLocalId(),
      type: 'cooked',
      name: recipeName,
      quantity: 1,
      unit: 'bữa',
      valueVnd: 0,
      occurredAt: DateTime.now(),
    ),
  );
  inventoryRevision.value++;
  unawaited(_persistEvents());
}

bool consumeFoodAmount(
  FoodSummary food,
  double amount, {
  bool discarded = false,
}) {
  final index = inventoryFoods.indexOf(food);
  if (index < 0 || amount <= 0) return false;
  final current = InventoryItemRecord.fromSummary(
    food,
    imagePath: customFoodImagePaths[food.id] ?? food.imagePath,
  );
  if (amount > current.quantity + 0.0001) return false;
  final consumedValue = current.quantity == 0
      ? 0
      : (current.priceVnd * amount / current.quantity).round();
  inventoryEvents.add(
    InventoryEvent(
      id: newLocalId(),
      type: discarded ? 'discarded' : 'consumed',
      name: food.$1,
      quantity: amount,
      unit: current.unit,
      valueVnd: consumedValue,
      occurredAt: DateTime.now(),
    ),
  );
  final remaining = current.quantity - amount;
  final id = food.id;
  if (remaining <= 0.0001) {
    inventoryFoods.removeAt(index);
    customFoodImagePaths.remove(food.id);
  } else {
    final remainingValue = (current.priceVnd - consumedValue).clamp(
      0,
      current.priceVnd,
    );
    inventoryFoods[index] = food.copyWith(
      quantity: remaining,
      priceVnd: remainingValue,
    );
  }
  inventoryRevision.value++;
  unawaited(_persistInventory());
  unawaited(_persistEvents());
  _withRemoteSync(
    () => HouseholdDataRepository.instance.consumeInventory(
      id,
      amount,
      discarded: discarded,
    ),
  );
  return true;
}

void replaceInventoryFromRemote({
  required List<InventoryItemRecord> records,
  required List<InventoryEvent> events,
}) {
  inventoryFoods
    ..clear()
    ..addAll(records.map(_summaryFromRecord));
  customFoodImagePaths
    ..clear()
    ..addEntries(
      records
          .where((record) => record.imagePath != null)
          .map((record) => MapEntry(record.id, record.imagePath!)),
    );
  inventoryEvents
    ..clear()
    ..addAll(events);
  inventoryRevision.value++;
  unawaited(_persistInventory());
  unawaited(_persistEvents());
}

void replaceShoppingFromRemote({
  required List<ShoppingSummary> items,
  required Set<int> checked,
}) {
  shoppingItems
    ..clear()
    ..addAll(items);
  shoppingChecked
    ..clear()
    ..addAll(checked.where((index) => index >= 0 && index < items.length));
  shoppingRevision.value++;
  unawaited(persistShopping(shoppingItems, shoppingChecked, syncRemote: false));
}

FoodSummary _summaryFromRecord(InventoryItemRecord record) {
  return FoodSummary.fromRecord(record);
}

void _withRemoteSync(Future<void> Function() operation) {
  if (!AppServices.configured ||
      HouseholdService.instance.active.value == null) {
    return;
  }
  final status = HouseholdDataRepository.instance.syncStatus;
  unawaited(() async {
    status.value = 'Đang đồng bộ dữ liệu gia đình…';
    try {
      await operation();
      status.value = null;
    } catch (_) {
      status.value =
          'Chưa đồng bộ được. Dữ liệu trên thiết bị vẫn được giữ lại; hãy kiểm tra mạng và thử lại.';
    }
  }());
}

String? _householdCacheScope() {
  if (!AppServices.configured) return null;
  final userId = AppServices.client.auth.currentUser?.id;
  if (userId == null) return null;
  final householdId = HouseholdService.instance.active.value?.id ?? 'none';
  return '$userId:$householdId';
}

void _recordEvent(String type, FoodSummary food) {
  final item = InventoryItemRecord.fromSummary(
    food,
    imagePath: customFoodImagePaths[food.id] ?? food.imagePath,
  );
  inventoryEvents.add(
    InventoryEvent(
      id: newLocalId(),
      type: type,
      name: item.name,
      quantity: item.quantity,
      unit: item.unit,
      valueVnd: item.priceVnd,
      occurredAt: DateTime.now(),
      metadata: {'source': type == 'added' ? 'manual_or_scan' : 'inventory'},
    ),
  );
  unawaited(_persistEvents());
}

Future<void> _persistEvents() async {
  try {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _eventsKey,
      jsonEncode(inventoryEvents.map((event) => event.toJson()).toList()),
    );
  } catch (_) {
    // A local report remains useful even when device storage is unavailable.
  }
}

void setShoppingPurchased(ShoppingSummary item, bool purchased) {
  final key = shoppingIdentity(item);
  final existingLink = shoppingInventoryLinks[key];
  if (purchased) {
    if (existingLink != null) return;
    final existingFood = inventoryFoods.where(
      (food) => food.$1.trim().toLowerCase() == item.$1.trim().toLowerCase(),
    );
    if (existingFood.isNotEmpty) {
      shoppingInventoryLinks[key] = ShoppingInventoryLink(
        food: existingFood.first,
        createdByPurchase: false,
      );
    } else {
      final quantity = item.$2.split('·').first.trim();
      final food = FoodSummary.fromLegacy(
        name: item.$1,
        detail: '$quantity · 0đ',
        status: 'Tươi ngon',
        imageIndex: item.$5.hashCode.abs() % 20,
      );
      inventoryFoods.add(food);
      shoppingInventoryLinks[key] = ShoppingInventoryLink(
        food: food,
        createdByPurchase: true,
      );
      _recordEvent('added', food);
      inventoryRevision.value++;
      unawaited(_persistInventory());
    }
  } else if (existingLink != null) {
    // Undoing a checklist tap does not mean the food was never bought; retain
    // stock already added to the fridge and only clear the visual relation.
    shoppingInventoryLinks.remove(key);
  }
}

int addMissingShoppingItems(String recipeName, Iterable<String> missingNames) {
  var added = 0;
  final existing = shoppingItems
      .map((item) => item.$1.trim().toLowerCase())
      .toSet();
  for (final name in missingNames) {
    final cleanName = name.trim();
    if (cleanName.isEmpty || !existing.add(cleanName.toLowerCase())) continue;
    shoppingItems.add((
      cleanName,
      '1 phần · Thiếu cho món $recipeName',
      'Bình thường',
      'Bạn',
      _shoppingCategoryFor(cleanName),
    ));
    added++;
  }
  if (added > 0) {
    shoppingRevision.value++;
    unawaited(persistShopping(shoppingItems, shoppingChecked));
  }
  return added;
}

String _shoppingCategoryFor(String name) {
  final lower = name.toLowerCase();
  if (lower.contains('thịt') || lower.contains('cá') || lower.contains('tôm')) {
    return 'Thịt cá';
  }
  if (lower.contains('mì') || lower.contains('bánh') || lower.contains('gạo')) {
    return 'Đồ khô';
  }
  return 'Rau củ';
}

Future<void> resetDemoInventory() async {
  customFoodImagePaths.clear();
  inventoryEvents.clear();
  inventoryFoods
    ..clear()
    ..addAll(demoInventorySeed);
  inventoryRevision.value++;
  final revisionAtQueue = inventoryRevision.value;
  final remove = _inventoryWriteQueue.then((_) async {
    if (revisionAtQueue != inventoryRevision.value) return;
    try {
      final preferences = await SharedPreferences.getInstance();
      if (revisionAtQueue != inventoryRevision.value) return;
      await preferences.remove(_inventoryKey);
      await preferences.remove(_eventsKey);
    } catch (_) {
      // Resetting the in-memory demo is still useful without a platform store.
    }
  });
  _inventoryWriteQueue = remove;
  try {
    await remove;
  } catch (_) {
    // The queued operation already protects the in-memory reset.
  }
}

Future<void> resetDemoShopping() async {
  shoppingItems
    ..clear()
    ..addAll(const [
      (
        'Thịt gà ta',
        '1 kg · Mua con gà ta nguyên con, làm sẵn',
        'Cần mua gấp',
        'Mẹ',
        'Thịt cá',
      ),
      (
        'Dứa',
        '1 quả · Dứa chín vàng, để nấu canh chua',
        'Bình thường',
        'Mẹ',
        'Rau củ',
      ),
      (
        'Bánh phở',
        '2 gói · Bánh phở tươi loại dày',
        'Cần mua gấp',
        'Bố',
        'Đồ khô',
      ),
      ('Tỏi', '200 gram · Tỏi Lý Sơn', 'Bình thường', 'Bố', 'Rau củ'),
      (
        'Sữa chua Vinamilk',
        '1 lốc · Sữa chua có đường',
        'Có cũng được',
        'Con (Minh)',
        'Khác',
      ),
      (
        'Đậu phộng',
        '200 gram · Đậu phộng rang sẵn',
        'Có cũng được',
        'Mẹ',
        'Đồ khô',
      ),
      ('Dầu hào', '1 chai · Dầu hào Maggi', 'Bình thường', 'Bố', 'Đồ khô'),
      (
        'Cần tây',
        '2 cây · Cần tây tươi, lá xanh',
        'Bình thường',
        'Mẹ',
        'Rau củ',
      ),
      (
        'Cá hồi phi lê',
        '2 miếng · Cá hồi Na Uy, mua ở siêu thị',
        'Cần mua gấp',
        'Bố',
        'Thịt cá',
      ),
    ]);
  shoppingChecked
    ..clear()
    ..addAll(const {4, 6});
  shoppingInventoryLinks.clear();
  shoppingRevision.value++;
  final remove = _shoppingWriteQueue.then((_) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_shoppingKey);
    } catch (_) {
      // Test/demo state is still reset in memory.
    }
  });
  _shoppingWriteQueue = remove;
  await remove;
}

Future<ShoppingSnapshot?> restoreShopping() async {
  try {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_shoppingKey);
    if (encoded == null) return null;
    final decoded = jsonDecode(encoded);
    if (decoded is! Map) return null;
    final items = <ShoppingSummary>[];
    final rawItems = decoded['items'];
    if (rawItems is List) {
      for (final value in rawItems) {
        if (value is! Map) continue;
        final fields = [
          value['name'],
          value['detail'],
          value['priority'],
          value['by'],
          value['category'],
        ];
        if (fields.every((field) => field is String)) {
          items.add((
            fields[0] as String,
            fields[1] as String,
            fields[2] as String,
            fields[3] as String,
            fields[4] as String,
          ));
        }
      }
    }
    final checked = <int>{};
    final rawChecked = decoded['checked'];
    if (rawChecked is List) {
      checked.addAll(rawChecked.whereType<num>().map((value) => value.toInt()));
    }
    final links = <String, ShoppingInventoryLink>{};
    final rawLinks = decoded['links'];
    if (rawLinks is List) {
      for (final value in rawLinks.whereType<Map>()) {
        final key = value['key'];
        if (key is String && key.isNotEmpty) {
          links[key] = ShoppingInventoryLink.fromJson(value);
        }
      }
    }
    shoppingInventoryLinks
      ..clear()
      ..addAll(links);
    return ShoppingSnapshot(items, checked, links);
  } catch (_) {
    return null;
  }
}

Future<void> persistShopping(
  List<ShoppingSummary> items,
  Set<int> checked, {
  bool syncRemote = true,
}) {
  final encoded = jsonEncode({
    'items': items
        .map(
          (item) => {
            'name': item.$1,
            'detail': item.$2,
            'priority': item.$3,
            'by': item.$4,
            'category': item.$5,
          },
        )
        .toList(),
    'checked': checked.toList(),
    'links': shoppingInventoryLinks.entries
        .map((entry) => entry.value.toJson(entry.key))
        .toList(),
  });
  final write = _shoppingWriteQueue.then((_) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_shoppingKey, encoded);
    } catch (_) {
      // Shopping remains available in memory if persistence is unavailable.
    }
  });
  _shoppingWriteQueue = write;
  if (syncRemote &&
      AppServices.configured &&
      HouseholdService.instance.active.value != null) {
    unawaited(() async {
      try {
        HouseholdDataRepository.instance.syncStatus.value =
            'Đang đồng bộ danh sách đi chợ…';
        await HouseholdDataRepository.instance.saveShopping(items, checked);
        HouseholdDataRepository.instance.syncStatus.value = null;
      } catch (_) {
        HouseholdDataRepository.instance.syncStatus.value =
            'Danh sách đi chợ chưa đồng bộ. Các thay đổi vẫn còn trên thiết bị; hãy thử lại khi có mạng.';
      }
    }());
  }
  return write;
}
