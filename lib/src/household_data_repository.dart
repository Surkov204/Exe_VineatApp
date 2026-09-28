import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_services.dart';
import 'inventory_models.dart';
import 'receipt_models.dart';

class RemoteShoppingItem {
  const RemoteShoppingItem({
    required this.id,
    required this.item,
    required this.checked,
    this.inventoryItemId,
  });
  final String id;
  final ShoppingSummary item;
  final bool checked;
  final String? inventoryItemId;
}

class HouseholdDataSnapshot {
  const HouseholdDataSnapshot({
    required this.inventory,
    required this.shopping,
    required this.events,
  });
  final List<InventoryItemRecord> inventory;
  final List<RemoteShoppingItem> shopping;
  final List<InventoryEvent> events;
}

/// Supabase persistence boundary for household-owned demo workflows.
/// The UI uses optimistic local state; failures are surfaced in syncStatus.
class HouseholdDataRepository {
  HouseholdDataRepository._();
  static final HouseholdDataRepository instance = HouseholdDataRepository._();
  String get _shoppingIdsKey =>
      'vineat.remote.shopping_ids.v1.${AppServices.client.auth.currentUser?.id ?? 'user'}.${_householdId ?? 'none'}';

  final syncStatus = ValueNotifier<String?>(null);
  final _remoteImagePathsByName = <String, String>{};
  final _shoppingInventoryLinks = <String, String>{};
  Map<String, String> _shoppingIds = {};
  String? _loadedScope;

  String? get _householdId => HouseholdService.instance.active.value?.id;

  Future<void> _ensureScope() async {
    final scope =
        '${AppServices.client.auth.currentUser?.id ?? 'user'}:${_householdId ?? 'none'}';
    if (_loadedScope == scope) return;
    _loadedScope = scope;
    _remoteImagePathsByName.clear();
    _shoppingInventoryLinks.clear();
    _foodIdsByName.clear();
    _shoppingIds = {};
    await _loadShoppingIds();
  }

  Future<HouseholdDataSnapshot> loadActiveHousehold() async {
    await _ensureScope();
    final householdId = _householdId;
    if (householdId == null) {
      return const HouseholdDataSnapshot(
        inventory: [],
        shopping: [],
        events: [],
      );
    }
    final client = AppServices.client;
    final rows = await client
        .from('inventory_items')
        .select(
          'id,name,quantity,unit,price_vnd,expiry_date,image_index,image_path,note',
        )
        .eq('household_id', householdId)
        .order('expiry_date');
    final allInventory = <InventoryItemRecord>[];
    for (final row in rows) {
      final id = row['id'] as String;
      final name = row['name'] as String? ?? 'Thực phẩm';
      final imagePath = row['image_path'] as String?;
      String? viewPath;
      if (imagePath != null && imagePath.isNotEmpty) {
        _remoteImagePathsByName[name] = imagePath;
        try {
          viewPath = await client.storage
              .from('household-food')
              .createSignedUrl(imagePath, 3600);
        } catch (_) {
          viewPath = null;
        }
      }
      _foodIdsByName[name] = id;
      allInventory.add(_recordFromRow(row, imagePath: viewPath));
    }
    final inventory = allInventory.where((item) => item.quantity > 0).toList();

    final shopping = await loadShoppingItems();
    final eventRows = await client
        .from('inventory_events')
        .select(
          'id,event_type,quantity,value_vnd,metadata,occurred_at,inventory_item_id',
        )
        .eq('household_id', householdId)
        .order('occurred_at', ascending: false)
        .limit(250);
    final eventInventoryIds = eventRows
        .map((row) => row['inventory_item_id'])
        .whereType<String>()
        .toSet();
    final namesById = <String, String>{
      for (final item in allInventory)
        if (eventInventoryIds.contains(item.id)) item.id: item.name,
    };
    final events = eventRows
        .map(
          (row) => InventoryEvent(
            id: row['id'] as String,
            type: _eventType(row['event_type'] as String? ?? 'updated'),
            name:
                namesById[row['inventory_item_id']] ??
                (row['metadata'] is Map
                    ? ((row['metadata'] as Map)['name'] as String? ??
                          'Thực phẩm')
                    : 'Thực phẩm'),
            quantity: (row['quantity'] as num?)?.toDouble() ?? 0,
            unit: row['metadata'] is Map
                ? ((row['metadata'] as Map)['unit'] as String? ?? 'phần')
                : 'phần',
            valueVnd: (row['value_vnd'] as num?)?.toInt() ?? 0,
            occurredAt:
                DateTime.tryParse(
                  row['occurred_at'] as String? ?? '',
                )?.toLocal() ??
                DateTime.now(),
            metadata: row['metadata'] is Map
                ? Map<String, Object?>.from(row['metadata'] as Map)
                : const {},
          ),
        )
        .toList();
    final cookedRows = await client
        .from('recipe_cook_events')
        .select('id,recipe_name,servings,cooked_at')
        .eq('household_id', householdId)
        .order('cooked_at', ascending: false)
        .limit(100);
    events.addAll(
      cookedRows.map(
        (row) => InventoryEvent(
          id: row['id'] as String,
          type: 'cooked',
          name: row['recipe_name'] as String? ?? 'Món ăn',
          quantity: (row['servings'] as num?)?.toDouble() ?? 1,
          unit: 'suất',
          valueVnd: 0,
          occurredAt:
              DateTime.tryParse(row['cooked_at'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
        ),
      ),
    );
    events.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    if (_householdId != householdId) {
      throw StateError('The selected household changed during data loading.');
    }
    return HouseholdDataSnapshot(
      inventory: inventory,
      shopping: shopping,
      events: events,
    );
  }

  Future<List<RemoteShoppingItem>> loadShoppingItems() async {
    await _ensureScope();
    final householdId = _householdId;
    if (householdId == null) return const [];
    final shoppingRows = await AppServices.client
        .from('shopping_items')
        .select(
          'id,name,quantity,unit,category,priority,note,checked_at,inventory_item_id',
        )
        .eq('household_id', householdId)
        .order('created_at');
    await _loadShoppingIds();
    final shopping = <RemoteShoppingItem>[];
    for (final row in shoppingRows) {
      final item = _shoppingFromRow(row);
      final id = row['id'] as String;
      _shoppingIds[shoppingIdentity(item)] = id;
      final inventoryId = row['inventory_item_id'] as String?;
      if (inventoryId != null) _shoppingInventoryLinks[id] = inventoryId;
      shopping.add(
        RemoteShoppingItem(
          id: id,
          item: item,
          checked: row['checked_at'] != null,
          inventoryItemId: inventoryId,
        ),
      );
    }
    await _saveShoppingIds();
    return shopping;
  }

  InventoryItemRecord _recordFromRow(
    Map<String, dynamic> row, {
    String? imagePath,
  }) {
    final quantity = (row['quantity'] as num?)?.toDouble() ?? 1;
    final expiryText = row['expiry_date'] as String?;
    return InventoryItemRecord(
      id: row['id'] as String,
      name: row['name'] as String? ?? 'Thực phẩm',
      quantity: quantity,
      unit: row['unit'] as String? ?? 'phần',
      priceVnd: (row['price_vnd'] as num?)?.toInt() ?? 0,
      expiry: expiryText == null ? null : DateTime.tryParse(expiryText),
      imageIndex: (row['image_index'] as num?)?.toInt() ?? 0,
      imagePath: imagePath,
      note: row['note'] as String? ?? '',
    );
  }

  ShoppingSummary _shoppingFromRow(Map<String, dynamic> row) {
    final quantity = (row['quantity'] as num?)?.toDouble() ?? 1;
    final unit = row['unit'] as String? ?? 'phần';
    final note = row['note'] as String?;
    final detail =
        '${_formatQuantity(quantity)} $unit${note == null || note.isEmpty ? '' : ' · $note'}';
    final priority = switch (row['priority']) {
      'urgent' => 'Cần mua gấp',
      'optional' => 'Có cũng được',
      _ => 'Bình thường',
    };
    return (
      row['name'] as String? ?? 'Thực phẩm',
      detail,
      priority,
      'Gia đình',
      _categoryLabel(row['category'] as String? ?? 'other'),
    );
  }

  Future<void> upsertInventory(
    FoodSummary food,
    String id, {
    String? localImagePath,
  }) async {
    await _ensureScope();
    final householdId = _householdId;
    if (householdId == null) return;
    _foodIdsByName[food.$1] = id;
    final record = InventoryItemRecord.fromSummary(
      food,
      id: id,
      imagePath: localImagePath,
    );
    final remoteImagePath = await _resolveImagePath(
      householdId,
      record,
      localImagePath,
    );
    await AppServices.client.from('inventory_items').upsert({
      'id': id,
      'household_id': householdId,
      'name': record.name,
      'quantity': record.quantity,
      'unit': record.unit,
      'price_vnd': record.priceVnd,
      'purchase_date': DateTime.now().toIso8601String().substring(0, 10),
      'expiry_date': record.expiry?.toIso8601String().substring(0, 10),
      'image_index': record.imageIndex,
      'image_path': remoteImagePath,
      'note': record.note,
      'source': 'manual',
      'created_by': AppServices.client.auth.currentUser?.id,
    });
  }

  Future<String?> _resolveImagePath(
    String householdId,
    InventoryItemRecord record,
    String? localImagePath,
  ) async {
    if (localImagePath == null || localImagePath.isEmpty) {
      return _remoteImagePathsByName[record.name];
    }
    final uri = Uri.tryParse(localImagePath);
    if (uri?.hasScheme == true) return _remoteImagePathsByName[record.name];
    final file = File(localImagePath);
    if (!await file.exists()) return _remoteImagePathsByName[record.name];
    final extension = localImagePath.split('.').last.toLowerCase();
    final contentType = switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
    final path = '$householdId/inventory/${record.id}.$extension';
    await AppServices.client.storage
        .from('household-food')
        .upload(
          path,
          file,
          fileOptions: FileOptions(upsert: true, contentType: contentType),
        );
    _remoteImagePathsByName[record.name] = path;
    return path;
  }

  Future<void> deleteInventory(String id) async {
    await _ensureScope();
    final householdId = _householdId;
    if (householdId == null) return;
    await AppServices.client
        .from('inventory_items')
        .delete()
        .eq('id', id)
        .eq('household_id', householdId);
  }

  Future<void> consumeInventory(
    String id,
    double quantity, {
    required bool discarded,
  }) async {
    await _ensureScope();
    final householdId = _householdId;
    if (householdId == null) return;
    await AppServices.client.rpc(
      'consume_inventory_item',
      params: {
        'p_inventory_item_id': id,
        'p_quantity': quantity,
        'p_discarded': discarded,
      },
    );
  }

  Future<void> logInventoryEvent({
    required String id,
    required String eventType,
    required double quantity,
    required int valueVnd,
    required String name,
    Map<String, Object?> metadata = const {},
  }) async {
    await _ensureScope();
    final householdId = _householdId;
    if (householdId == null) return;
    await AppServices.client.from('inventory_events').insert({
      'household_id': householdId,
      'inventory_item_id': id,
      'event_type': eventType,
      'quantity': quantity,
      'value_vnd': valueVnd,
      'metadata': {'name': name, ...metadata},
      'actor_id': AppServices.client.auth.currentUser?.id,
    });
  }

  Future<Map<String, String>> saveShopping(
    List<ShoppingSummary> items,
    Set<int> checked,
  ) async {
    await _ensureScope();
    final householdId = _householdId;
    if (householdId == null) return const {};
    await _loadShoppingIds();
    final activeIds = <String>{};
    final purchasedInventoryIds = <String, String>{};
    for (final entry in items.asMap().entries) {
      final item = entry.value;
      final identity = shoppingIdentity(item);
      final id = _shoppingIds.putIfAbsent(identity, newLocalId);
      activeIds.add(id);
      final existingInventoryId = _shoppingInventoryLinks[id];
      final detail = item.$2.split('·').map((part) => part.trim()).toList();
      final amount = _parseQuantity(detail.first);
      final row = <String, Object?>{
        'id': id,
        'household_id': householdId,
        'name': item.$1,
        'quantity': amount.$1,
        'unit': amount.$2,
        'category': _categoryCode(item.$5),
        'priority': _priorityCode(item.$3),
        'note': detail.length > 1 ? detail.sublist(1).join(' · ') : null,
        'checked_at': checked.contains(entry.key)
            ? DateTime.now().toUtc().toIso8601String()
            : null,
        'inventory_item_id': existingInventoryId,
        'created_by': AppServices.client.auth.currentUser?.id,
      };
      await AppServices.client.from('shopping_items').upsert(row);
      if (checked.contains(entry.key)) {
        final result = await AppServices.client.rpc(
          'complete_shopping_item',
          params: {'p_shopping_item_id': id},
        );
        if (result is String && result.isNotEmpty) {
          _shoppingInventoryLinks[id] = result;
          _foodIdsByName[item.$1] = result;
          purchasedInventoryIds[item.$1] = result;
        }
      }
    }
    final remoteRows = await AppServices.client
        .from('shopping_items')
        .select('id')
        .eq('household_id', householdId);
    final staleIds = remoteRows
        .map((row) => row['id'] as String)
        .where((id) => !activeIds.contains(id))
        .toList();
    if (staleIds.isNotEmpty) {
      await AppServices.client
          .from('shopping_items')
          .delete()
          .eq('household_id', householdId)
          .inFilter('id', staleIds);
    }
    await _saveShoppingIds();
    return purchasedInventoryIds;
  }

  Future<void> recordRecipeCooked(
    String recipeName,
    List<(FoodSummary, double)> uses,
  ) async {
    await _ensureScope();
    final householdId = _householdId;
    if (householdId == null) return;
    await _loadShoppingIds();
    final items = uses
        .map(
          (use) => {
            'inventory_item_id': _ensureFoodId(use.$1),
            'quantity': use.$2,
          },
        )
        .toList();
    await AppServices.client.rpc(
      'record_recipe_cooked',
      params: {
        'p_household_id': householdId,
        'p_recipe_name': recipeName,
        'p_servings': 1,
        'p_items': items,
      },
    );
  }

  Future<String> importReceipt({
    required List<ReceiptLine> lines,
    required Set<int> selectedIndexes,
    required String? rawText,
    required String? storeName,
    required DateTime? purchasedAt,
    required int? totalVnd,
    required String? localImagePath,
  }) async {
    await _ensureScope();
    final householdId = _householdId;
    if (householdId == null) throw StateError('Chưa chọn gia đình.');
    var imagePath = '';
    if (localImagePath != null && localImagePath.isNotEmpty) {
      final uri = Uri.tryParse(localImagePath);
      final file = File(localImagePath);
      if (uri?.hasScheme != true && await file.exists()) {
        final extension = localImagePath.split('.').last.toLowerCase();
        final path = '$householdId/receipts/${newLocalId()}.$extension';
        await AppServices.client.storage
            .from('household-food')
            .upload(
              path,
              file,
              fileOptions: FileOptions(
                upsert: false,
                contentType: extension == 'png' ? 'image/png' : 'image/jpeg',
              ),
            );
        imagePath = path;
      }
    }
    final computedTotal =
        totalVnd ?? lines.fold<int>(0, (sum, line) => sum + line.totalPriceVnd);
    final result = await AppServices.client.rpc(
      'import_receipt',
      params: {
        'p_household_id': householdId,
        'p_store_name': storeName,
        'p_purchased_at': purchasedAt?.toUtc().toIso8601String(),
        'p_total_vnd': computedTotal,
        'p_image_path': imagePath,
        'p_raw_ocr_text': rawText,
        'p_items': [
          for (var index = 0; index < lines.length; index++)
            {
              'raw_name': lines[index].rawName,
              'normalized_name': lines[index].normalizedName,
              'quantity': lines[index].quantity,
              'unit': lines[index].unit,
              'unit_price_vnd': lines[index].unitPriceVnd,
              'total_price_vnd': lines[index].totalPriceVnd,
              'estimated_expiry_date': lines[index].estimatedExpiryDate
                  ?.toIso8601String()
                  .substring(0, 10),
              'confidence': lines[index].confidence,
              'selected_for_import': selectedIndexes.contains(index),
            },
        ],
      },
    );
    if (result is! String || result.isEmpty) {
      throw StateError('Máy chủ không xác nhận đã lưu hóa đơn.');
    }
    return result;
  }

  final _foodIdsByName = <String, String>{};
  String _ensureFoodId(FoodSummary food) =>
      _foodIdsByName.putIfAbsent(food.$1, newLocalId);
  String ensureFoodId(FoodSummary food) => _ensureFoodId(food);

  Future<void> _loadShoppingIds() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_shoppingIdsKey);
      if (raw == null) return;
      final decoded = Map<String, dynamic>.from((jsonDecode(raw) as Map));
      _shoppingIds = decoded.map(
        (key, value) => MapEntry(key, value as String),
      );
    } catch (_) {
      _shoppingIds = {};
    }
  }

  Future<void> _saveShoppingIds() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_shoppingIdsKey, jsonEncode(_shoppingIds));
    } catch (_) {
      // Remote rows themselves remain authoritative if local ID cache is absent.
    }
  }
}

String _eventType(String type) => switch (type) {
  'consumed' => 'consumed',
  'discarded' => 'discarded',
  'added' => 'added',
  'restored' => 'restored',
  _ => 'updated',
};

(double, String) _parseQuantity(String value) {
  final match = RegExp(r'^\s*(\d+(?:[.,]\d+)?)\s*(.*)$').firstMatch(value);
  if (match == null) return (1, 'phần');
  return (
    double.tryParse(match.group(1)!.replaceAll(',', '.')) ?? 1,
    match.group(2)!.trim().isEmpty ? 'phần' : match.group(2)!.trim(),
  );
}

String _formatQuantity(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value
          .toString()
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');

String _priorityCode(String priority) => switch (priority) {
  'Cần mua gấp' => 'urgent',
  'Có cũng được' => 'optional',
  _ => 'normal',
};

String _categoryCode(String category) => switch (category) {
  'Rau củ' => 'vegetables',
  'Thịt cá' => 'meat_fish',
  'Đồ khô' => 'dry_goods',
  _ => 'other',
};

String _categoryLabel(String category) => switch (category) {
  'vegetables' || 'vegetable' => 'Rau củ',
  'meat_fish' || 'meat' || 'fish' => 'Thịt cá',
  'dry_goods' || 'dry' => 'Đồ khô',
  _ => 'Khác',
};
