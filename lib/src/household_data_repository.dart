import 'dart:async';
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
  String _shoppingIdsKeyFor(String scope) =>
      'vineat.remote.shopping_ids.v1.${scope.replaceFirst(':', '.')}';

  final syncStatus = ValueNotifier<String?>(null);
  final _remoteImagePathsById = <String, String>{};
  final _shoppingInventoryLinks = <String, String>{};
  final _shoppingFingerprints = <String, String>{};
  Map<String, String> _shoppingIds = {};
  String? _loadedScope;
  RealtimeChannel? _realtimeChannel;
  String? _realtimeHouseholdId;
  ValueChanged<HouseholdDataSnapshot>? _onRealtimeSnapshot;
  Timer? _realtimeRefreshTimer;
  int _realtimeGeneration = 0;
  bool _refreshingRealtimeSnapshot = false;
  bool _refreshAgain = false;

  String? get _householdId => HouseholdService.instance.active.value?.id;
  String get _currentScope =>
      '${AppServices.client.auth.currentUser?.id ?? 'user'}:${_householdId ?? 'none'}';

  void _assertScope(String expectedScope) {
    if (_currentScope != expectedScope) {
      throw StateError('Gia đình/tài khoản đã đổi trong lúc đồng bộ.');
    }
  }

  Future<void> _ensureScope([String? expectedScope]) async {
    final scope = expectedScope ?? _currentScope;
    _assertScope(scope);
    if (_loadedScope == scope) return;
    _loadedScope = scope;
    _remoteImagePathsById.clear();
    _shoppingInventoryLinks.clear();
    _shoppingFingerprints.clear();
    _shoppingIds = {};
    await _loadShoppingIds(scope);
    _assertScope(scope);
  }

  Future<HouseholdDataSnapshot> loadActiveHousehold() async {
    final scope = _currentScope;
    await _ensureScope(scope);
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
          'id,household_id,name,quantity,unit,price_vnd,expiry_date,image_index,image_path,note',
        )
        .eq('household_id', householdId)
        .order('expiry_date');
    final allInventory = <InventoryItemRecord>[];
    for (final row in rows) {
      final id = row['id'] as String;
      final imagePath = row['image_path'] as String?;
      String? viewPath;
      if (imagePath != null && imagePath.isNotEmpty) {
        _remoteImagePathsById[id] = imagePath;
        try {
          viewPath = await client.storage
              .from('household-food')
              .createSignedUrl(imagePath, 3600);
        } catch (_) {
          viewPath = null;
        }
      }
      allInventory.add(
        _recordFromRow(row, householdId: householdId, imagePath: viewPath),
      );
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
    _assertScope(scope);
    return HouseholdDataSnapshot(
      inventory: inventory,
      shopping: shopping,
      events: events,
    );
  }

  /// Keeps the active household snapshot fresh across devices. The server-side
  /// filter and RLS ensure the channel only wakes this client's own household.
  Future<void> watchHouseholdChanges({
    required String? householdId,
    required ValueChanged<HouseholdDataSnapshot> onSnapshot,
  }) async {
    if (!AppServices.configured) return;
    if (_realtimeHouseholdId == householdId && _realtimeChannel != null) {
      _onRealtimeSnapshot = onSnapshot;
      return;
    }

    final generation = ++_realtimeGeneration;
    _realtimeRefreshTimer?.cancel();
    _refreshAgain = false;
    _onRealtimeSnapshot = onSnapshot;
    final previous = _realtimeChannel;
    _realtimeChannel = null;
    _realtimeHouseholdId = householdId;
    if (previous != null) {
      try {
        await AppServices.client.removeChannel(previous);
      } catch (_) {
        // A failed unsubscribe must not prevent the new household from loading.
      }
    }
    if (generation != _realtimeGeneration || householdId == null) return;

    final channel = AppServices.client.channel('vineat-household-$householdId');
    void onChange(PostgresChangePayload _) =>
        _scheduleRealtimeRefresh(generation);
    for (final table in const [
      'inventory_items',
      'shopping_items',
      'inventory_events',
      'recipe_cook_events',
    ]) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'household_id',
          value: householdId,
        ),
        callback: onChange,
      );
    }
    _realtimeChannel = channel;
    channel.subscribe();
  }

  /// Serializes household mutations with realtime teardown. The old channel is
  /// invalidated and its unsubscribe is awaited before the caller can fetch a
  /// new snapshot. If the mutation fails, the active household listener returns.
  Future<void> runWithHouseholdRealtimePaused(
    Future<void> Function() action,
  ) async {
    await _pauseHouseholdRealtime();
    try {
      await action();
    } catch (_) {
      await _resumeActiveHouseholdRealtime();
      rethrow;
    }
    await _resumeActiveHouseholdRealtime();
  }

  Future<void> _pauseHouseholdRealtime() async {
    ++_realtimeGeneration;
    _realtimeRefreshTimer?.cancel();
    _realtimeRefreshTimer = null;
    _refreshAgain = false;
    final previous = _realtimeChannel;
    _realtimeChannel = null;
    _realtimeHouseholdId = null;
    if (previous == null || !AppServices.configured) return;
    try {
      await AppServices.client.removeChannel(previous);
    } catch (_) {
      // The generation guard above prevents a late old-channel event from
      // updating the current household even if the server unsubscribe fails.
    }
  }

  Future<void> _resumeActiveHouseholdRealtime() async {
    final householdId = _householdId;
    final onSnapshot = _onRealtimeSnapshot;
    if (!AppServices.configured || householdId == null || onSnapshot == null) {
      return;
    }
    await watchHouseholdChanges(
      householdId: householdId,
      onSnapshot: onSnapshot,
    );
  }

  void _scheduleRealtimeRefresh(int generation) {
    if (generation != _realtimeGeneration) return;
    _realtimeRefreshTimer?.cancel();
    _realtimeRefreshTimer = Timer(const Duration(milliseconds: 450), () {
      unawaited(_refreshRealtimeSnapshot(generation));
    });
  }

  Future<void> _refreshRealtimeSnapshot(int generation) async {
    if (_refreshingRealtimeSnapshot) {
      _refreshAgain = true;
      return;
    }
    _refreshingRealtimeSnapshot = true;
    const syncingMessage = 'Đang cập nhật dữ liệu gia đình…';
    try {
      do {
        _refreshAgain = false;
        final householdId = _realtimeHouseholdId;
        if (generation != _realtimeGeneration || householdId == null) return;
        syncStatus.value = syncingMessage;
        try {
          final snapshot = await loadActiveHousehold();
          if (generation == _realtimeGeneration &&
              HouseholdService.instance.active.value?.id == householdId) {
            _onRealtimeSnapshot?.call(snapshot);
          }
        } catch (_) {
          if (generation == _realtimeGeneration) {
            syncStatus.value =
                'Có thay đổi mới nhưng chưa tải được dữ liệu. Kiểm tra kết nối.';
          }
        } finally {
          if (syncStatus.value == syncingMessage) syncStatus.value = null;
        }
      } while (_refreshAgain && generation == _realtimeGeneration);
    } finally {
      _refreshingRealtimeSnapshot = false;
    }
  }

  Future<bool> hasImportedDemoInventory(String householdId) async {
    final scope = _currentScope;
    if (_householdId != householdId) {
      throw StateError('Gia đình đang chọn đã thay đổi.');
    }
    final rows = await AppServices.client
        .from('demo_imports')
        .select('id')
        .eq('household_id', householdId)
        .eq('import_key', 'local-demo-v1')
        .limit(1);
    _assertScope(scope);
    return rows.isNotEmpty;
  }

  Future<int> importDemoInventory({
    required String householdId,
    required List<InventoryItemRecord> items,
  }) async {
    final scope = _currentScope;
    if (_householdId != householdId) {
      throw StateError('Gia đình đang chọn đã thay đổi.');
    }
    await _ensureScope(scope);
    final payload = items
        .map(
          (item) => {
            'name': item.name,
            'quantity': item.quantity,
            'unit': item.unit,
            'price_vnd': item.priceVnd,
            'expiry_date': item.expiry?.toIso8601String().split('T').first,
            'image_index': item.imageIndex,
          },
        )
        .toList();
    final imported = await AppServices.client.rpc(
      'import_demo_inventory',
      params: {
        'p_household_id': householdId,
        'p_import_key': 'local-demo-v1',
        'p_items': payload,
      },
    );
    _assertScope(scope);
    return imported is num ? imported.toInt() : 0;
  }

  Future<bool> isTutorialPageCompleted(String pageKey) async {
    final userId = AppServices.client.auth.currentUser?.id;
    if (userId == null) return false;
    final rows = await AppServices.client
        .from('tutorial_progress')
        .select('page_key')
        .eq('user_id', userId)
        .eq('page_key', pageKey)
        .limit(1);
    return rows.isNotEmpty;
  }

  Future<void> markTutorialPageCompleted(String pageKey) async {
    final userId = AppServices.client.auth.currentUser?.id;
    if (userId == null) return;
    await AppServices.client.from('tutorial_progress').upsert({
      'user_id': userId,
      'page_key': pageKey,
      'completed_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id,page_key');
  }

  Future<List<RemoteShoppingItem>> loadShoppingItems() async {
    final scope = _currentScope;
    await _ensureScope(scope);
    final householdId = _householdId;
    if (householdId == null) return const [];
    final shoppingRows = await AppServices.client
        .from('shopping_items')
        .select(
          'id,household_id,name,quantity,unit,category,priority,note,checked_at,inventory_item_id',
        )
        .eq('household_id', householdId)
        .order('created_at');
    _assertScope(scope);
    final shopping = <RemoteShoppingItem>[];
    for (final row in shoppingRows) {
      final item = _shoppingFromRow(row);
      final id = row['id'] as String;
      _shoppingIds[shoppingIdentity(item)] = id;
      _shoppingFingerprints[id] = _shoppingFingerprint(
        item,
        checked: row['checked_at'] != null,
      );
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
    await _saveShoppingIds(scope);
    _assertScope(scope);
    return shopping;
  }

  InventoryItemRecord _recordFromRow(
    Map<String, dynamic> row, {
    required String householdId,
    String? imagePath,
  }) {
    final rowHouseholdId = row['household_id'] as String?;
    if (rowHouseholdId != householdId) {
      throw StateError('Inventory row belongs to another household.');
    }
    final quantity = (row['quantity'] as num?)?.toDouble() ?? 1;
    final expiryText = row['expiry_date'] as String?;
    return InventoryItemRecord(
      id: row['id'] as String,
      householdId: rowHouseholdId,
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
    final priority = switch (row['priority']) {
      'urgent' => 'Cần mua gấp',
      'optional' => 'Có cũng được',
      _ => 'Bình thường',
    };
    return ShoppingSummary(
      id: row['id'] as String?,
      householdId: row['household_id'] as String? ?? _householdId,
      name: row['name'] as String? ?? 'Thực phẩm',
      quantity: (row['quantity'] as num?)?.toDouble() ?? 1,
      unit: row['unit'] as String? ?? 'phần',
      note: row['note'] as String? ?? '',
      priority: priority,
      createdBy: 'Gia đình',
      category: _categoryLabel(row['category'] as String? ?? 'other'),
    );
  }

  Future<void> upsertInventory(
    FoodSummary food,
    String id, {
    String? localImagePath,
  }) async {
    final scope = _currentScope;
    await _ensureScope(scope);
    final householdId = _householdId;
    if (householdId == null) return;
    if (food.id != id) throw StateError('Inventory identity mismatch.');
    final record = InventoryItemRecord.fromSummary(
      food,
      id: id,
      householdId: householdId,
      imagePath: localImagePath,
    );
    final remoteImagePath = await _resolveImagePath(
      householdId,
      record,
      localImagePath,
      scope,
    );
    _assertScope(scope);
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
    _assertScope(scope);
  }

  Future<String?> _resolveImagePath(
    String householdId,
    InventoryItemRecord record,
    String? localImagePath,
    String scope,
  ) async {
    _assertScope(scope);
    if (localImagePath == null || localImagePath.isEmpty) {
      return _remoteImagePathsById[record.id];
    }
    final uri = Uri.tryParse(localImagePath);
    if (uri?.hasScheme == true) return _remoteImagePathsById[record.id];
    final file = File(localImagePath);
    if (!await file.exists()) return _remoteImagePathsById[record.id];
    _assertScope(scope);
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
    _assertScope(scope);
    _remoteImagePathsById[record.id] = path;
    return path;
  }

  Future<void> deleteInventory(String id) async {
    final scope = _currentScope;
    await _ensureScope(scope);
    final householdId = _householdId;
    if (householdId == null) return;
    await AppServices.client
        .from('inventory_items')
        .delete()
        .eq('id', id)
        .eq('household_id', householdId);
    _assertScope(scope);
  }

  Future<void> consumeInventory(
    String id,
    double quantity, {
    required bool discarded,
  }) async {
    final scope = _currentScope;
    await _ensureScope(scope);
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
    _assertScope(scope);
  }

  Future<void> logInventoryEvent({
    required String id,
    required String eventType,
    required double quantity,
    required int valueVnd,
    Map<String, Object?> metadata = const {},
  }) async {
    final scope = _currentScope;
    await _ensureScope(scope);
    final householdId = _householdId;
    if (householdId == null) return;
    await AppServices.client.rpc(
      'record_inventory_event',
      params: {
        'p_household_id': householdId,
        'p_inventory_item_id': id,
        'p_event_type': eventType,
        'p_quantity': quantity,
        'p_value_vnd': valueVnd,
        'p_metadata': metadata,
      },
    );
    _assertScope(scope);
  }

  Future<void> saveShopping(
    List<ShoppingSummary> items,
    Set<String> checked,
  ) async {
    final scope = _currentScope;
    await _ensureScope(scope);
    final householdId = _householdId;
    if (householdId == null) return;
    await _loadShoppingIds(scope);
    for (final entry in items.asMap().entries) {
      _assertScope(scope);
      final item = entry.value;
      if (item.householdId != null && item.householdId != householdId) {
        throw StateError('Shopping item belongs to another household.');
      }
      final identity = shoppingIdentity(item);
      final id = _shoppingIds.putIfAbsent(identity, () => item.id);
      final existingInventoryId = _shoppingInventoryLinks[id];
      final fingerprint = _shoppingFingerprint(
        item,
        checked: checked.contains(item.id),
      );
      if (_shoppingFingerprints[id] == fingerprint) {
        if (checked.contains(item.id) && existingInventoryId == null) {
          final result = await AppServices.client.rpc(
            'complete_shopping_item',
            params: {'p_shopping_item_id': id},
          );
          _assertScope(scope);
          if (result is! String || result.isEmpty) {
            throw StateError('Máy chủ chưa xác nhận món đã mua.');
          }
          _shoppingInventoryLinks[id] = result;
        }
        continue;
      }
      final row = <String, Object?>{
        'id': id,
        'household_id': householdId,
        'name': item.name,
        'quantity': item.quantity,
        'unit': item.unit,
        'category': _categoryCode(item.category),
        'priority': _priorityCode(item.priority),
        'note': item.note.isEmpty ? null : item.note,
        'checked_at': checked.contains(item.id)
            ? DateTime.now().toUtc().toIso8601String()
            : null,
        'inventory_item_id': existingInventoryId,
        'created_by': AppServices.client.auth.currentUser?.id,
      };
      await AppServices.client.from('shopping_items').upsert(row);
      _assertScope(scope);
      if (checked.contains(item.id)) {
        final result = await AppServices.client.rpc(
          'complete_shopping_item',
          params: {'p_shopping_item_id': id},
        );
        _assertScope(scope);
        if (checked.contains(item.id) &&
            (result is! String || result.isEmpty)) {
          throw StateError('Máy chủ chưa xác nhận món đã mua.');
        }
        if (result is String && result.isNotEmpty) {
          _shoppingInventoryLinks[id] = result;
        }
      }
      _shoppingFingerprints[id] = fingerprint;
    }
    await _saveShoppingIds(scope);
    _assertScope(scope);
  }

  Future<void> deleteShoppingItem(ShoppingSummary item) async {
    final scope = _currentScope;
    await _ensureScope(scope);
    final householdId = _householdId;
    if (householdId == null) return;
    if (item.householdId != null && item.householdId != householdId) {
      throw StateError('Shopping item belongs to another household.');
    }
    final id = item.id;
    await AppServices.client
        .from('shopping_items')
        .delete()
        .eq('id', id)
        .eq('household_id', householdId);
    _assertScope(scope);
    _shoppingIds.remove(shoppingIdentity(item));
    _shoppingFingerprints.remove(id);
    _shoppingInventoryLinks.remove(id);
    await _saveShoppingIds(scope);
  }

  Future<void> recordRecipeCooked(
    String recipeName,
    List<InventoryUsage> uses,
  ) async {
    final scope = _currentScope;
    await _ensureScope(scope);
    final householdId = _householdId;
    if (householdId == null) return;
    final items = uses
        .map(
          (use) => {
            'inventory_item_id': _ensureFoodId(use.food),
            'quantity': use.quantity,
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
    _assertScope(scope);
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
    final scope = _currentScope;
    await _ensureScope(scope);
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
        _assertScope(scope);
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
    _assertScope(scope);
    if (result is! String || result.isEmpty) {
      throw StateError('Máy chủ không xác nhận đã lưu hóa đơn.');
    }
    return result;
  }

  String _ensureFoodId(FoodSummary food) => food.id;
  String ensureFoodId(FoodSummary food) => _ensureFoodId(food);

  Future<void> _loadShoppingIds([String? scope]) async {
    final key = _shoppingIdsKeyFor(scope ?? _currentScope);
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(key);
      if (raw == null) {
        _shoppingIds = {};
        return;
      }
      final decoded = Map<String, dynamic>.from((jsonDecode(raw) as Map));
      final loaded = decoded.map(
        (key, value) => MapEntry(key, value as String),
      );
      if (scope == null || _currentScope == scope) _shoppingIds = loaded;
    } catch (_) {
      if (scope == null || _currentScope == scope) _shoppingIds = {};
    }
  }

  Future<void> _saveShoppingIds([String? scope]) async {
    final key = _shoppingIdsKeyFor(scope ?? _currentScope);
    final ids = Map<String, String>.of(_shoppingIds);
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(key, jsonEncode(ids));
    } catch (_) {
      // Remote rows themselves remain authoritative if local ID cache is absent.
    }
  }
}

String _shoppingFingerprint(ShoppingSummary item, {required bool checked}) =>
    jsonEncode([
      item.name,
      item.quantity,
      item.unit,
      item.note,
      item.priority,
      item.createdBy,
      item.category,
      checked,
    ]);

String _eventType(String type) => switch (type) {
  'consumed' => 'consumed',
  'discarded' => 'discarded',
  'added' => 'added',
  'restored' => 'restored',
  _ => 'updated',
};

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
