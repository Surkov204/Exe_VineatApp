import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef FoodSummary = (String, String, String, int);
typedef ShoppingSummary = (String, String, String, String, String);

class ShoppingSnapshot {
  const ShoppingSnapshot(this.items, this.checked);
  final List<ShoppingSummary> items;
  final Set<int> checked;
}

/// The small local store used by the demo flow.
///
/// It intentionally keeps the prototype's compact tuple at the UI boundary,
/// but owns persistence so every screen reads the same inventory and a demo
/// survives an app restart on Android.
final inventoryFoods = <FoodSummary>[
  ('Rau muống', '2 bó · 15.000đ', 'Còn 2 ngày', 0),
  ('Cà chua', '5 quả · 25.000đ', 'Tươi ngon', 1),
  ('Thịt heo ba chỉ', '500 gram · 65.000đ', 'Còn 3 ngày', 2),
  ('Cá basa fillet', '3 miếng · 45.000đ', 'Hết hạn', 3),
  ('Trứng gà', '10 quả · 35.000đ', 'Tươi ngon', 4),
  ('Cải thảo', '1 cây · 20.000đ', 'Tươi ngon', 5),
  ('Gạo ST25', '5 kg · 175.000đ', 'Tươi ngon', 6),
  ('Nước mắm Nam Ngư', '1 chai · 42.000đ', 'Tươi ngon', 7),
  ('Sữa tươi Vinamilk', '2 hộp · 32.000đ', 'Tươi ngon', 8),
  ('Hành lá', '1 bó · 3.000đ', 'Tươi ngon', 9),
];

final inventoryRevision = ValueNotifier<int>(0);

Future<void> _inventoryWriteQueue = Future<void>.value();
Future<void> _shoppingWriteQueue = Future<void>.value();

const _inventoryKey = 'vineat.demo.inventory.v1';
const _shoppingKey = 'vineat.demo.shopping.v1';

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
        restored.add((name, detail, status, image.toInt()));
      }
    }
    inventoryFoods
      ..clear()
      ..addAll(restored);
    inventoryRevision.value++;
  } catch (_) {
    // A corrupt demo cache must never prevent the app from opening.
  }
}

Future<void> _persistInventory() {
  final revisionAtQueue = inventoryRevision.value;
  final encoded = jsonEncode(
    inventoryFoods
        .map(
          (food) => {
            'name': food.$1,
            'detail': food.$2,
            'status': food.$3,
            'image': food.$4,
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
    } catch (_) {
      // The in-memory state remains usable when storage is temporarily absent.
    }
  });
  _inventoryWriteQueue = write;
  return write;
}

void addFoodsToInventory(Iterable<FoodSummary> foods) {
  inventoryFoods.addAll(foods);
  inventoryRevision.value++;
  unawaited(_persistInventory());
}

void removeFoodFromInventory(FoodSummary food) {
  inventoryFoods.remove(food);
  inventoryRevision.value++;
  unawaited(_persistInventory());
}

void updateFoodInInventory(FoodSummary before, FoodSummary after) {
  final index = inventoryFoods.indexOf(before);
  if (index < 0) return;
  inventoryFoods[index] = after;
  inventoryRevision.value++;
  unawaited(_persistInventory());
}

Future<void> resetDemoInventory() async {
  inventoryFoods
    ..clear()
    ..addAll(const [
      ('Rau muống', '2 bó · 15.000đ', 'Còn 2 ngày', 0),
      ('Cà chua', '5 quả · 25.000đ', 'Tươi ngon', 1),
      ('Thịt heo ba chỉ', '500 gram · 65.000đ', 'Còn 3 ngày', 2),
      ('Cá basa fillet', '3 miếng · 45.000đ', 'Hết hạn', 3),
      ('Trứng gà', '10 quả · 35.000đ', 'Tươi ngon', 4),
      ('Cải thảo', '1 cây · 20.000đ', 'Tươi ngon', 5),
      ('Gạo ST25', '5 kg · 175.000đ', 'Tươi ngon', 6),
      ('Nước mắm Nam Ngư', '1 chai · 42.000đ', 'Tươi ngon', 7),
      ('Sữa tươi Vinamilk', '2 hộp · 32.000đ', 'Tươi ngon', 8),
      ('Hành lá', '1 bó · 3.000đ', 'Tươi ngon', 9),
    ]);
  inventoryRevision.value++;
  final revisionAtQueue = inventoryRevision.value;
  final remove = _inventoryWriteQueue.then((_) async {
    if (revisionAtQueue != inventoryRevision.value) return;
    try {
      final preferences = await SharedPreferences.getInstance();
      if (revisionAtQueue != inventoryRevision.value) return;
      await preferences.remove(_inventoryKey);
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
        final fields = [value['name'], value['detail'], value['priority'], value['by'], value['category']];
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
    return ShoppingSnapshot(items, checked);
  } catch (_) {
    return null;
  }
}

Future<void> persistShopping(
  List<ShoppingSummary> items,
  Set<int> checked,
) {
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
  return write;
}
