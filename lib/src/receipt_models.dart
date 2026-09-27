class ReceiptLine {
  ReceiptLine({
    required this.rawName,
    required this.normalizedName,
    this.quantity = 1,
    this.unit = 'phần',
    this.unitPriceVnd = 0,
    this.totalPriceVnd = 0,
    this.estimatedExpiryDate,
    this.confidence = .5,
    this.selected = true,
  });

  final String rawName;
  String normalizedName;
  double quantity;
  String unit;
  int unitPriceVnd;
  int totalPriceVnd;
  DateTime? estimatedExpiryDate;
  double confidence;
  bool selected;
}

class ReceiptScanResult {
  ReceiptScanResult({
    required this.rawText,
    required this.items,
    this.storeName,
    this.purchasedAt,
    this.totalVnd,
  });

  final String rawText;
  final List<ReceiptLine> items;
  final String? storeName;
  final DateTime? purchasedAt;
  final int? totalVnd;
}
