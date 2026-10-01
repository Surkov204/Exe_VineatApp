import 'dart:math';

class ShoppingSummary {
  ShoppingSummary({
    String? id,
    this.householdId,
    this.menuPlanId,
    this.neededDate,
    this.menuDay,
    required this.name,
    required this.quantity,
    required this.unit,
    this.note = '',
    this.priority = 'Bình thường',
    this.createdBy = 'Bạn',
    this.category = 'Khác',
  }) : id = id ?? newLocalId();

  final String id;
  final String? householdId;
  final String? menuPlanId;
  final DateTime? neededDate;
  final DateTime? menuDay;
  final String name;
  final double quantity;
  final String unit;
  final String note;
  final String priority;
  final String createdBy;
  final String category;

  String get detail =>
      '${_formatQuantity(quantity)} $unit${note.isEmpty ? '' : ' · $note'}';

  ShoppingSummary copyWith({
    String? id,
    String? householdId,
    String? menuPlanId,
    DateTime? neededDate,
    DateTime? menuDay,
    String? name,
    double? quantity,
    String? unit,
    String? note,
    String? priority,
    String? createdBy,
    String? category,
  }) => ShoppingSummary(
    id: id ?? this.id,
    householdId: householdId ?? this.householdId,
    menuPlanId: menuPlanId ?? this.menuPlanId,
    neededDate: neededDate ?? this.neededDate,
    menuDay: menuDay ?? this.menuDay,
    name: name ?? this.name,
    quantity: quantity ?? this.quantity,
    unit: unit ?? this.unit,
    note: note ?? this.note,
    priority: priority ?? this.priority,
    createdBy: createdBy ?? this.createdBy,
    category: category ?? this.category,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'household_id': householdId,
    'menu_plan_id': menuPlanId,
    'needed_date': neededDate?.toIso8601String(),
    'menu_day': menuDay?.toIso8601String(),
    'name': name,
    'quantity': quantity,
    'unit': unit,
    'note': note,
    'priority': priority,
    'created_by': createdBy,
    'category': category,
  };

  factory ShoppingSummary.fromJson(Map value) {
    final legacyDetail = value['detail'] as String? ?? '';
    final legacyParts = legacyDetail
        .split('·')
        .map((part) => part.trim())
        .toList();
    final legacyAmount = _parseAmount(legacyParts.firstOrNull ?? '1 phần');
    final legacyNote = legacyParts.skip(1).join(' · ');
    final quantity = value['quantity'] is num
        ? (value['quantity'] as num).toDouble()
        : legacyAmount.quantity;
    return ShoppingSummary(
      id: value['id'] as String?,
      householdId: value['household_id'] as String?,
      menuPlanId: value['menu_plan_id'] as String?,
      neededDate: DateTime.tryParse(value['needed_date'] as String? ?? ''),
      menuDay: DateTime.tryParse(value['menu_day'] as String? ?? ''),
      name: value['name'] as String? ?? 'Thực phẩm',
      quantity: quantity,
      unit: value['unit'] as String? ?? legacyAmount.unit,
      note: value['note'] as String? ?? legacyNote,
      priority: value['priority'] as String? ?? 'Bình thường',
      createdBy:
          value['created_by'] as String? ?? value['by'] as String? ?? 'Bạn',
      category: value['category'] as String? ?? 'Khác',
    );
  }
}

String shoppingIdentity(ShoppingSummary item) =>
    '${item.name.trim().toLowerCase()}|${item.category.trim().toLowerCase()}${item.menuPlanId == null ? '' : '|menu:${item.menuPlanId}:${item.menuDay?.toIso8601String() ?? ''}'}';

/// Inventory data has a stable identity and typed quantities. The display
/// labels are named getters so UI code never depends on tuple positions.
class InventoryAudit {
  const InventoryAudit({
    this.purchaseDate,
    this.addedBy = '',
    this.updatedBy = '',
    this.updatedAt,
  });
  final DateTime? purchaseDate, updatedAt;
  final String addedBy, updatedBy;
  Map<String, Object?> toJson() => {
    'purchase_date': purchaseDate?.toIso8601String(),
    'added_by': addedBy,
    'updated_by': updatedBy,
    'updated_at': updatedAt?.toIso8601String(),
  };
  factory InventoryAudit.fromJson(Map value) => InventoryAudit(
    purchaseDate: DateTime.tryParse(value['purchase_date'] as String? ?? ''),
    addedBy: value['added_by'] as String? ?? '',
    updatedBy: value['updated_by'] as String? ?? '',
    updatedAt: DateTime.tryParse(value['updated_at'] as String? ?? ''),
  );
}

class FoodSummary {
  FoodSummary({
    String? id,
    this.householdId,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.priceVnd,
    required this.imageIndex,
    this.expiry,
    this.imagePath,
    this.note = '',
    this.audit = const InventoryAudit(),
  }) : id = id ?? newLocalId();

  final String id;
  final String? householdId;
  final String name;
  final double quantity;
  final String unit;
  final int priceVnd;
  final DateTime? expiry;
  final int imageIndex;
  final String? imagePath;
  final String note;
  final InventoryAudit audit;

  String get detail =>
      '${_formatQuantity(quantity)} $unit · ${_formatVnd(priceVnd)}';
  String get status => _freshnessLabel(expiry);

  factory FoodSummary.fromLegacy({
    String? id,
    String? householdId,
    required String name,
    required String detail,
    required String status,
    required int imageIndex,
    DateTime? expiryDate,
    String? imagePath,
    String note = '',
  }) {
    final parts = detail.split('·').map((part) => part.trim()).toList();
    final amount = _parseAmount(parts.firstOrNull ?? '1 phần');
    final price = parts.length > 1
        ? int.tryParse(parts.last.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0
        : 0;
    final days = int.tryParse(
      RegExp(r'\d+').firstMatch(status)?.group(0) ?? '',
    );
    final expiryFromStatus = status == 'Hết hạn'
        ? DateTime.now().subtract(const Duration(days: 1))
        : status.contains('Còn')
        ? DateTime.now().add(Duration(days: days ?? 2))
        : DateTime.now().add(const Duration(days: 14));
    return FoodSummary(
      id: id,
      householdId: householdId,
      name: name,
      quantity: amount.quantity,
      unit: amount.unit,
      priceVnd: price,
      expiry: expiryDate ?? expiryFromStatus,
      imageIndex: imageIndex,
      imagePath: imagePath,
      note: note,
    );
  }

  factory FoodSummary.fromRecord(InventoryItemRecord record) => FoodSummary(
    id: record.id,
    householdId: record.householdId,
    name: record.name,
    quantity: record.quantity,
    unit: record.unit,
    priceVnd: record.priceVnd,
    expiry: record.expiry,
    imageIndex: record.imageIndex,
    imagePath: record.imagePath,
    note: record.note,
    audit: record.audit,
  );

  FoodSummary copyWith({
    String? id,
    String? householdId,
    String? name,
    double? quantity,
    String? unit,
    int? priceVnd,
    DateTime? expiry,
    int? imageIndex,
    String? imagePath,
    String? note,
    InventoryAudit? audit,
  }) => FoodSummary(
    id: id ?? this.id,
    householdId: householdId ?? this.householdId,
    name: name ?? this.name,
    quantity: quantity ?? this.quantity,
    unit: unit ?? this.unit,
    priceVnd: priceVnd ?? this.priceVnd,
    expiry: expiry ?? this.expiry,
    imageIndex: imageIndex ?? this.imageIndex,
    imagePath: imagePath ?? this.imagePath,
    note: note ?? this.note,
    audit: audit ?? this.audit,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'household_id': householdId,
    'name': name,
    'quantity': quantity,
    'unit': unit,
    'price_vnd': priceVnd,
    'expiry': expiry?.toIso8601String(),
    'image_index': imageIndex,
    'image_path': imagePath,
    'note': note,
    'audit': audit.toJson(),
  };

  factory FoodSummary.fromJson(Map value) {
    final name = value['name'] as String? ?? 'Thực phẩm';
    final imageIndex =
        (value['image_index'] as num?)?.toInt() ??
        (value['image'] as num?)?.toInt() ??
        0;
    if (value['quantity'] is num) {
      return FoodSummary(
        id: value['id'] as String?,
        householdId: value['household_id'] as String?,
        name: name,
        quantity: (value['quantity'] as num).toDouble(),
        unit: value['unit'] as String? ?? 'phần',
        priceVnd: (value['price_vnd'] as num?)?.toInt() ?? 0,
        expiry: DateTime.tryParse(
          value['expiry'] as String? ?? value['expiry_date'] as String? ?? '',
        ),
        imageIndex: imageIndex,
        imagePath:
            value['image_path'] as String? ?? value['imagePath'] as String?,
        note: value['note'] as String? ?? '',
        audit: InventoryAudit.fromJson(
          value['audit'] is Map ? value['audit'] as Map : {},
        ),
      );
    }
    return FoodSummary.fromLegacy(
      id: value['id'] as String?,
      householdId: value['household_id'] as String?,
      name: name,
      detail: value['detail'] as String? ?? '1 phần',
      status: value['status'] as String? ?? 'Tươi ngon',
      imageIndex: imageIndex,
      imagePath:
          value['image_path'] as String? ?? value['imagePath'] as String?,
      note: value['note'] as String? ?? '',
    );
  }

  @override
  bool operator ==(Object other) => other is FoodSummary && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class InventoryUsage {
  const InventoryUsage({required this.food, required this.quantity});

  final FoodSummary food;
  final double quantity;
}

String _freshnessLabel(DateTime? expiry) {
  if (expiry == null) return 'Tươi ngon';
  final today = DateTime.now();
  final days = DateTime(
    expiry.year,
    expiry.month,
    expiry.day,
  ).difference(DateTime(today.year, today.month, today.day)).inDays;
  if (days < 0) return 'Hết hạn';
  if (days <= 3) return 'Còn ${days == 0 ? 1 : days} ngày';
  return 'Tươi ngon';
}

String _formatQuantity(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value
          .toString()
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');

String _formatVnd(int value) =>
    '${value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')}đ';

class InventoryItemRecord {
  const InventoryItemRecord({
    required this.id,
    this.householdId,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.priceVnd,
    required this.expiry,
    required this.imageIndex,
    this.imagePath,
    this.note = '',
    this.audit = const InventoryAudit(),
  });

  final String id;
  final String? householdId;
  final String name;
  final double quantity;
  final String unit;
  final int priceVnd;
  final DateTime? expiry;
  final int imageIndex;
  final String? imagePath;
  final String note;
  final InventoryAudit audit;

  factory InventoryItemRecord.fromSummary(
    FoodSummary summary, {
    String? id,
    String? householdId,
    String? imagePath,
  }) {
    return InventoryItemRecord(
      id: id ?? summary.id,
      householdId: householdId ?? summary.householdId,
      name: summary.name,
      quantity: summary.quantity,
      unit: summary.unit,
      priceVnd: summary.priceVnd,
      expiry: summary.expiry,
      imageIndex: summary.imageIndex,
      imagePath: imagePath ?? summary.imagePath,
      note: summary.note,
      audit: summary.audit,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'household_id': householdId,
    'name': name,
    'quantity': quantity,
    'unit': unit,
    'price_vnd': priceVnd,
    'expiry': expiry?.toIso8601String(),
    'image_index': imageIndex,
    'image_path': imagePath,
    'note': note,
    'audit': audit.toJson(),
  };

  factory InventoryItemRecord.fromJson(Map value) => InventoryItemRecord(
    id: value['id'] as String? ?? newLocalId(),
    householdId: value['household_id'] as String?,
    name: value['name'] as String? ?? 'Thực phẩm',
    quantity: (value['quantity'] as num?)?.toDouble() ?? 1,
    unit: value['unit'] as String? ?? 'phần',
    priceVnd: (value['price_vnd'] as num?)?.toInt() ?? 0,
    expiry: DateTime.tryParse(
      value['expiry'] as String? ?? value['expiry_date'] as String? ?? '',
    ),
    imageIndex:
        (value['image_index'] as num?)?.toInt() ??
        (value['image'] as num?)?.toInt() ??
        0,
    imagePath: value['image_path'] as String? ?? value['imagePath'] as String?,
    note: value['note'] as String? ?? '',
    audit: InventoryAudit.fromJson(
      value['audit'] is Map ? value['audit'] as Map : {},
    ),
  );
}

class InventoryEvent {
  const InventoryEvent({
    required this.id,
    required this.type,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.valueVnd,
    required this.occurredAt,
    this.metadata = const {},
  });

  final String id;
  final String type;
  final String name;
  final double quantity;
  final String unit;
  final int valueVnd;
  final DateTime occurredAt;
  final Map<String, Object?> metadata;

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type,
    'name': name,
    'quantity': quantity,
    'unit': unit,
    'value_vnd': valueVnd,
    'occurred_at': occurredAt.toIso8601String(),
    'metadata': metadata,
  };

  factory InventoryEvent.fromJson(Map value) => InventoryEvent(
    id: value['id'] as String? ?? newLocalId(),
    type: value['type'] as String? ?? 'updated',
    name: value['name'] as String? ?? 'Thực phẩm',
    quantity: (value['quantity'] as num?)?.toDouble() ?? 0,
    unit: value['unit'] as String? ?? 'phần',
    valueVnd: (value['value_vnd'] as num?)?.toInt() ?? 0,
    occurredAt:
        DateTime.tryParse(value['occurred_at'] as String? ?? '') ??
        DateTime.now(),
    metadata: value['metadata'] is Map
        ? Map<String, Object?>.from(value['metadata'] as Map)
        : const {},
  );
}

class ShoppingInventoryLink {
  const ShoppingInventoryLink({
    required this.food,
    required this.createdByPurchase,
  });
  final FoodSummary food;
  final bool createdByPurchase;

  Map<String, Object?> toJson(String key) => {
    'key': key,
    ...food.toJson(),
    'name': food.name,
    'detail': food.detail,
    'status': food.status,
    'image': food.imageIndex,
    'created': createdByPurchase,
  };

  factory ShoppingInventoryLink.fromJson(Map value) => ShoppingInventoryLink(
    food: value['quantity'] is num
        ? FoodSummary.fromJson(value)
        : FoodSummary.fromLegacy(
            id: value['id'] as String?,
            householdId: value['household_id'] as String?,
            name: value['name'] as String? ?? '',
            detail: value['detail'] as String? ?? '',
            status: value['status'] as String? ?? 'Tươi ngon',
            imageIndex: (value['image'] as num?)?.toInt() ?? 0,
          ),
    createdByPurchase: value['created'] as bool? ?? false,
  );
}

String newLocalId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((value) => value.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class _ParsedAmount {
  const _ParsedAmount({required this.quantity, required this.unit});

  final double quantity;
  final String unit;
}

_ParsedAmount _parseAmount(String value) {
  final match = RegExp(r'^\s*(\d+(?:[.,]\d+)?)\s*(.*)$').firstMatch(value);
  if (match == null) {
    return _ParsedAmount(
      quantity: 1,
      unit: value.trim().isEmpty ? 'phần' : value.trim(),
    );
  }
  return _ParsedAmount(
    quantity: double.tryParse(match.group(1)!.replaceAll(',', '.')) ?? 1,
    unit: match.group(2)!.trim().isEmpty ? 'phần' : match.group(2)!.trim(),
  );
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
