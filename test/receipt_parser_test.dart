import 'package:flutter_test/flutter_test.dart';
import 'package:vineat_app/src/receipt_parser.dart';

void main() {
  final parser = ReceiptParser();

  test('parses Vietnamese receipt header, products and total', () {
    const text = '''
WINMART
Ngày: 26/09/2026
THỊT HEO BA CHỈ 500g 65.000đ
RAU MUỐNG 2 bó 15.000
TỔNG CỘNG 80.000đ
TIỀN MẶT 100.000đ
''';
    final result = parser.parse(text);

    expect(result.storeName, 'WinMart');
    expect(result.purchasedAt, DateTime(2026, 9, 26));
    expect(result.totalVnd, 80000);
    expect(result.items, hasLength(2));
    expect(result.items.first.normalizedName, 'Thịt heo ba chỉ');
    expect(result.items.first.quantity, 500);
    expect(result.items.first.unit, 'gram');
    expect(result.items.first.totalPriceVnd, 65000);
  });

  test('supports a price on the following OCR line', () {
    final result = parser.parse(
      'BÁCH HÓA XANH\nTRỨNG GÀ 10 quả\n35.000\nTỔNG CỘNG\n35.000',
    );

    expect(result.storeName, 'Bách Hóa Xanh');
    expect(result.items, hasLength(1));
    expect(result.items.single.normalizedName, 'Trứng gà');
    expect(result.items.single.quantity, 10);
    expect(result.items.single.totalPriceVnd, 35000);
  });

  test('does not turn payment metadata into products', () {
    final result = parser.parse(
      'HÓA ĐƠN\nMST 0123456789\nTỔNG CỘNG 120.000\nTIỀN KHÁCH ĐƯA 200.000\nTIỀN THỪA 80.000',
    );
    expect(result.items, isEmpty);
  });
}
