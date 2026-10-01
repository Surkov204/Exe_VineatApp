import 'package:flutter/material.dart';
import 'inventory_store.dart';
import 'meal_plan.dart';
import 'menu_ingredients.dart';

class MenuShoppingSelection {
  const MenuShoppingSelection(this.lines, this.people);
  final List<MenuPurchase> lines;
  final int people;
}

Future<MenuShoppingSelection?> showMenuShoppingSheet(
  BuildContext context, {
  required List<PlannedDish> dishes,
  required List<FoodSummary> stock,
  required int people,
  required bool weekly,
  required DateTime day,
}) => showModalBottomSheet<MenuShoppingSelection>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.white,
  showDragHandle: true,
  builder: (_) => _MenuShoppingSheet(
    dishes: dishes,
    stock: stock,
    people: people,
    weekly: weekly,
    day: day,
  ),
);

class _MenuShoppingSheet extends StatefulWidget {
  const _MenuShoppingSheet({
    required this.dishes,
    required this.stock,
    required this.people,
    required this.weekly,
    required this.day,
  });
  final List<PlannedDish> dishes;
  final List<FoodSummary> stock;
  final int people;
  final bool weekly;
  final DateTime day;
  @override
  State<_MenuShoppingSheet> createState() => _MenuShoppingSheetState();
}

class _MenuShoppingSheetState extends State<_MenuShoppingSheet> {
  late int people;
  late MenuPurchaseResult purchase;
  bool editQuantity = false;
  final form = GlobalKey<FormState>();
  @override
  void initState() {
    super.initState();
    people = widget.people;
    _calculate();
  }

  void _calculate() {
    purchase = buildMenuPurchases(
      widget.dishes,
      people,
      widget.stock,
      groupByDay: true,
      includeCovered: true,
    );
  }

  String amount(double n) =>
      n == n.roundToDouble() ? n.toInt().toString() : n.toStringAsFixed(2);
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .80,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.weekly
                  ? 'Đi chợ cả tuần'
                  : 'Đi chợ ngày ${widget.day.day}/${widget.day.month}',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Chỉ lập danh sách, không trừ tồn. Tồn chỉ giảm khi xác nhận ở trang Xuất.',
              style: TextStyle(fontSize: 12, color: Colors.blueGrey),
            ),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('Theo người'),
                  icon: Icon(Icons.people_outline),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('Sửa lượng'),
                  icon: Icon(Icons.edit_outlined),
                ),
              ],
              selected: {editQuantity},
              onSelectionChanged: (v) => setState(() {
                editQuantity = v.first;
                if (!editQuantity) _calculate();
              }),
            ),
            if (!editQuantity)
              Row(
                children: [
                  const Expanded(child: Text('Số người ăn')),
                  IconButton(
                    tooltip: 'Giảm số người',
                    onPressed: people <= 1
                        ? null
                        : () => setState(() {
                            people--;
                            _calculate();
                          }),
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  Text(
                    '$people người',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  IconButton(
                    tooltip: 'Tăng số người',
                    onPressed: people >= 30
                        ? null
                        : () => setState(() {
                            people++;
                            _calculate();
                          }),
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
            if (editQuantity)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Sửa trực tiếp lượng cần mua. Đổi số người sẽ tính lại.',
                  style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                ),
              ),
            Expanded(
              child: Form(
                key: form,
                child: ListView(
                  children: [
                    if (purchase.lines.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('Không có lượng cần mua thêm đã xác định.'),
                      ),
                    for (var index = 0; index < purchase.lines.length; index++)
                      _line(purchase.lines[index], index),
                    if (purchase.unmeasured.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          'Chưa có định lượng: ${purchase.unmeasured.join(', ')}. Bổ sung riêng ở Đi chợ.',
                          style: const TextStyle(
                            color: Colors.deepOrange,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () {
                if (form.currentState!.validate()) {
                  Navigator.pop(
                    context,
                    MenuShoppingSelection(
                      purchase.lines.where((l) => l.buyQuantity > 0).toList(),
                      people,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.shopping_basket_outlined),
              label: Text(
                'Chốt & mở Đi chợ (${purchase.lines.where((l) => l.buyQuantity > 0).length})',
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    ),
  );
  Widget _line(MenuPurchase line, int index) => Card(
    elevation: 0,
    color: const Color(0xFFF4F9F6),
    margin: const EdgeInsets.only(bottom: 8),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  line.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '${amount(line.buyQuantity)} ${line.unit}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF079669),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Dùng ${line.neededDate.day}/${line.neededDate.month} · ${line.unit}',
            style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _quantity('Cần dùng', line.requiredQuantity),
              _quantity('Có sẵn', line.stockAvailable),
              _quantity('Cần mua', line.buyQuantity),
            ],
          ),
          if (widget.weekly)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Dự kiến dùng ${amount(line.stockUsed)} ${line.unit} từ tủ cho ngày này; không tính trùng với ngày trước và không trừ tồn.',
                style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
              ),
            ),
          if (editQuantity)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: TextFormField(
                key: ValueKey('$people-$index'),
                initialValue: amount(line.buyQuantity),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Lượng mua (${line.unit})',
                  isDense: true,
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  final n = double.tryParse(v?.replaceAll(',', '.') ?? '');
                  return n != null && n.isFinite && n >= 0
                      ? null
                      : 'Nhập lượng từ 0 trở lên';
                },
                onChanged: (v) {
                  final n = double.tryParse(v.replaceAll(',', '.'));
                  if (n != null && n.isFinite && n >= 0) {
                    setState(() => line.buyQuantity = n);
                  }
                },
              ),
            ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            dense: true,
            title: const Text(
              'Món & bữa sử dụng',
              style: TextStyle(fontSize: 12),
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  line.note.replaceAll('; ', '\n'),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  Widget _quantity(String label, double value) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
        ),
        Text(
          amount(value),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}
