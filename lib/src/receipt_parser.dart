import 'receipt_models.dart';

class ReceiptParser {
  static final _money = RegExp(
    r'(?<!\d)(\d{1,3}(?:[.,\s]\d{3})+|\d{4,9})(?:\s*(?:đ|vnd))?',
    caseSensitive: false,
  );
  static final _date = RegExp(r'\b(\d{1,2})[\/-](\d{1,2})[\/-](\d{2,4})\b');
  static final _quantity = RegExp(
    r'(\d+(?:[.,]\d+)?)\s*(kg|g|gram|ml|l|chai|lon|hộp|hop|gói|goi|bó|bo|quả|qua|cây|cay|miếng|mieng)',
    caseSensitive: false,
  );

  static const _ignored = <String>[
    'tong cong',
    'thanh tien',
    'tien mat',
    'tien thua',
    'tien khach dua',
    'khach tra',
    'chiet khau',
    'giam gia',
    'vat',
    'hoa don',
    'ma hd',
    'thu ngan',
    'cam on',
    'hotline',
    'website',
    'mst',
    'ma so thue',
    'subtotal',
    'total',
    'cash',
    'change',
    'so luong',
    'don gia',
    'dvt',
  ];

  ReceiptScanResult parse(String rawText, {List<String>? orderedLines}) {
    final lines = (orderedLines ?? rawText.split(RegExp(r'[\r\n]+')))
        .map((e) => e.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((e) => e.length > 1)
        .toList();
    final store = _store(lines);
    final purchasedAt = _purchaseDate(lines);
    final statedTotal = _statedTotal(lines);
    final items = <ReceiptLine>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final folded = _fold(line);
      if (_ignored.any(folded.contains) || _looksLikeMetadata(folded)) continue;

      final matches = _money.allMatches(line).toList();
      String name = line;
      int price = 0;
      if (matches.isNotEmpty) {
        final priceMatch = matches.last;
        price = _parseMoney(priceMatch.group(0)!);
        name = line.substring(0, priceMatch.start).trim();
      } else if (i + 1 < lines.length && _isMoneyOnly(lines[i + 1])) {
        price = _parseMoney(lines[++i]);
      } else {
        continue;
      }

      name = name.replaceAll(RegExp(r'^[\d\s.*xX-]+'), '').trim();
      if (name.length < 2 || price < 100) continue;
      final quantityMatch = _quantity.firstMatch(name);
      var quantity = 1.0;
      var unit = 'phần';
      if (quantityMatch != null) {
        quantity =
            double.tryParse(quantityMatch.group(1)!.replaceAll(',', '.')) ?? 1;
        unit = _normalizeUnit(quantityMatch.group(2)!);
        name = name.replaceFirst(quantityMatch.group(0)!, '').trim();
      }
      name = name.replaceAll(RegExp(r'[-:]+$'), '').trim();
      if (name.length < 2) continue;

      final normalized = _normalizeProduct(name);
      items.add(
        ReceiptLine(
          rawName: name,
          normalizedName: normalized,
          quantity: quantity,
          unit: unit,
          unitPriceVnd: quantity > 0 ? (price / quantity).round() : price,
          totalPriceVnd: price,
          estimatedExpiryDate: _estimateExpiry(
            normalized,
            purchasedAt ?? DateTime.now(),
          ),
          confidence: matches.isNotEmpty ? .82 : .62,
        ),
      );
    }

    return ReceiptScanResult(
      rawText: rawText,
      items: _deduplicate(items),
      storeName: store,
      purchasedAt: purchasedAt,
      totalVnd: statedTotal,
    );
  }

  String? _store(List<String> lines) {
    final head = _fold(lines.take(8).join(' '));
    const stores = {
      'winmart': 'WinMart',
      'vinmart': 'WinMart',
      'bach hoa xanh': 'Bách Hóa Xanh',
      'coopmart': 'Co.opmart',
      'co opmart': 'Co.opmart',
      'lotte mart': 'Lotte Mart',
      'mega market': 'MM Mega Market',
      'big c': 'GO!/Big C',
    };
    for (final entry in stores.entries) {
      if (head.contains(entry.key)) return entry.value;
    }
    return null;
  }

  DateTime? _purchaseDate(List<String> lines) {
    for (final line in lines.take(15)) {
      final match = _date.firstMatch(line);
      if (match == null) continue;
      var year = int.parse(match.group(3)!);
      if (year < 100) year += 2000;
      final date = DateTime.tryParse(
        '$year-${match.group(2)!.padLeft(2, '0')}-${match.group(1)!.padLeft(2, '0')}',
      );
      if (date != null) return date;
    }
    return null;
  }

  int? _statedTotal(List<String> lines) {
    for (final line in lines.reversed) {
      final folded = _fold(line);
      if (folded.contains('tong') ||
          folded.contains('thanh tien') ||
          folded.contains('total')) {
        final matches = _money.allMatches(line).toList();
        if (matches.isNotEmpty) return _parseMoney(matches.last.group(0)!);
      }
    }
    return null;
  }

  bool _looksLikeMetadata(String value) =>
      _date.hasMatch(value) ||
      value.contains('@') ||
      value.contains('http') ||
      RegExp(r'^[\d\s:/.-]+$').hasMatch(value);

  bool _isMoneyOnly(String value) => RegExp(
    r'^\s*\d{1,3}(?:[.,\s]\d{3})+(?:\s*(?:đ|vnd))?\s*$',
    caseSensitive: false,
  ).hasMatch(value);

  int _parseMoney(String value) =>
      int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  String _normalizeUnit(String unit) {
    final value = _fold(unit);
    return switch (value) {
      'g' || 'gram' => 'gram',
      'l' => 'lít',
      'hop' => 'hộp',
      'goi' => 'gói',
      'bo' => 'bó',
      'qua' => 'quả',
      'cay' => 'cây',
      'mieng' => 'miếng',
      _ => value,
    };
  }

  String _normalizeProduct(String value) {
    var result = value
        .replaceAll(RegExp(r'\b\d{5,}\b'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (result.isEmpty) return value;
    return result[0].toUpperCase() + result.substring(1).toLowerCase();
  }

  DateTime _estimateExpiry(String name, DateTime from) {
    final n = _fold(name);
    final days = n.contains('rau') || n.contains('hanh')
        ? 3
        : n.contains('thit') || n.contains('ca ') || n.startsWith('ca')
        ? 3
        : n.contains('dau hu')
        ? 4
        : n.contains('sua')
        ? 7
        : n.contains('trung')
        ? 14
        : n.contains('gao') || n.contains('nuoc mam') || n.contains('do hop')
        ? 180
        : 7;
    return from.add(Duration(days: days));
  }

  List<ReceiptLine> _deduplicate(List<ReceiptLine> input) {
    final seen = <String>{};
    return input
        .where((e) => seen.add('${_fold(e.normalizedName)}:${e.totalPriceVnd}'))
        .toList();
  }

  String _fold(String value) {
    const source =
        'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
    const target =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
    var result = value.toLowerCase();
    for (var i = 0; i < source.length; i++) {
      result = result.replaceAll(source[i], target[i]);
    }
    return result;
  }
}
