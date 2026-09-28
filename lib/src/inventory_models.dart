import 'dart:math';

typedef FoodSummary = (String, String, String, int);
typedef ShoppingSummary = (String, String, String, String, String);

String shoppingIdentity(ShoppingSummary item) =>
    '${item.$1.trim().toLowerCase()}|${item.$5.trim().toLowerCase()}';

/// Typed form used by persistence/reporting. UI records remain compatible with
/// the prototype during this staged migration.
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
    final detail = summary.$2.split('·').map((part) => part.trim()).toList();
    final amount = _parseAmount(detail.firstOrNull ?? '1 phần');
    final parsedPrice = detail.length > 1
        ? int.tryParse(detail.last.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0
        : 0;
    final days = int.tryParse(
      RegExp(r'\d+').firstMatch(summary.$3)?.group(0) ?? '',
    );
    final expiry = summary.$3 == 'Hết hạn'
        ? DateTime.now().subtract(const Duration(days: 1))
        : summary.$3.contains('Còn')
        ? DateTime.now().add(Duration(days: days ?? 2))
        : DateTime.now().add(const Duration(days: 14));
    return InventoryItemRecord(
      id: id ?? newLocalId(),
      name: summary.$1,
      quantity: amount.$1,
      unit: amount.$2,
      priceVnd: parsedPrice,
      expiry: expiry,
      imageIndex: summary.$4,
      imagePath: imagePath,
      note: '',
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
    food: (
      value['name'] as String? ?? '',
      value['detail'] as String? ?? '',
      value['status'] as String? ?? 'Tươi ngon',
      (value['image'] as num?)?.toInt() ?? 0,
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
