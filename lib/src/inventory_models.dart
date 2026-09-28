import 'dart:math';

typedef ShoppingSummary = (String, String, String, String, String);

String shoppingIdentity(ShoppingSummary item) =>
    '${item.$1.trim().toLowerCase()}|${item.$5.trim().toLowerCase()}';

/// Inventory data has a stable identity and typed quantities. `$1`-`$4` are
/// temporary presentation adapters for the existing compact widgets.
class FoodSummary {
  FoodSummary({
    String? id,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.priceVnd,
    required this.imageIndex,
    this.expiry,
    this.imagePath,
    this.note = '',
  }) : id = id ?? newLocalId();

  final String id;
  final String name;
  final double quantity;
  final String unit;
  final int priceVnd;
  final DateTime? expiry;
  final int imageIndex;
  final String? imagePath;
  final String note;

  String get $1 => name;
  String get $2 =>
      '${_formatQuantity(quantity)} $unit · ${_formatVnd(priceVnd)}';
  String get $3 => _freshnessLabel(expiry);
  int get $4 => imageIndex;

  factory FoodSummary.fromLegacy({
    String? id,
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
      name: name,
      quantity: amount.$1,
      unit: amount.$2,
      priceVnd: price,
      expiry: expiryDate ?? expiryFromStatus,
      imageIndex: imageIndex,
      imagePath: imagePath,
      note: note,
    );
  }

  factory FoodSummary.fromRecord(InventoryItemRecord record) => FoodSummary(
    id: record.id,
    name: record.name,
    quantity: record.quantity,
    unit: record.unit,
    priceVnd: record.priceVnd,
    expiry: record.expiry,
    imageIndex: record.imageIndex,
    imagePath: record.imagePath,
    note: record.note,
  );

  FoodSummary copyWith({
    String? id,
    String? name,
    double? quantity,
    String? unit,
    int? priceVnd,
    DateTime? expiry,
    int? imageIndex,
    String? imagePath,
    String? note,
  }) => FoodSummary(
    id: id ?? this.id,
    name: name ?? this.name,
    quantity: quantity ?? this.quantity,
    unit: unit ?? this.unit,
    priceVnd: priceVnd ?? this.priceVnd,
    expiry: expiry ?? this.expiry,
    imageIndex: imageIndex ?? this.imageIndex,
    imagePath: imagePath ?? this.imagePath,
    note: note ?? this.note,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'quantity': quantity,
    'unit': unit,
    'price_vnd': priceVnd,
    'expiry': expiry?.toIso8601String(),
    'image_index': imageIndex,
    'image_path': imagePath,
    'note': note,
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
      );
    }
    return FoodSummary.fromLegacy(
      id: value['id'] as String?,
      name: name,
      detail: value['detail'] as String? ?? '1 phần',
      status: value['status'] as String? ?? 'Tươi ngon',
      imageIndex: imageIndex,
      imagePath: value['imagePath'] as String?,
      note: value['note'] as String? ?? '',
    );
  }

  @override
  bool operator ==(Object other) => other is FoodSummary && other.id == id;

  @override
  int get hashCode => id.hashCode;
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
    required this.name,
    required this.quantity,
    required this.unit,
    required this.priceVnd,
    required this.expiry,
    required this.imageIndex,
    this.imagePath,
    this.note = '',
  });

  final String id;
  final String name;
  final double quantity;
  final String unit;
  final int priceVnd;
  final DateTime? expiry;
  final int imageIndex;
  final String? imagePath;
  final String note;

  factory InventoryItemRecord.fromSummary(
    FoodSummary summary, {
    String? id,
    String? imagePath,
  }) {
    return InventoryItemRecord(
      id: id ?? summary.id,
      name: summary.name,
      quantity: summary.quantity,
      unit: summary.unit,
      priceVnd: summary.priceVnd,
      expiry: summary.expiry,
      imageIndex: summary.imageIndex,
      imagePath: imagePath ?? summary.imagePath,
      note: summary.note,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'quantity': quantity,
    'unit': unit,
    'price_vnd': priceVnd,
    'expiry': expiry?.toIso8601String(),
    'image_index': imageIndex,
    'image_path': imagePath,
    'note': note,
  };
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
    'name': food.$1,
    'detail': food.$2,
    'status': food.$3,
    'image': food.$4,
    'created': createdByPurchase,
  };

  factory ShoppingInventoryLink.fromJson(Map value) => ShoppingInventoryLink(
    food: FoodSummary.fromLegacy(
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

(double, String) _parseAmount(String value) {
  final match = RegExp(r'^\s*(\d+(?:[.,]\d+)?)\s*(.*)$').firstMatch(value);
  if (match == null) return (1, value.trim().isEmpty ? 'phần' : value.trim());
  return (
    double.tryParse(match.group(1)!.replaceAll(',', '.')) ?? 1,
    match.group(2)!.trim().isEmpty ? 'phần' : match.group(2)!.trim(),
  );
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
