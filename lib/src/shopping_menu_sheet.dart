import 'package:flutter/material.dart';
import 'inventory_store.dart';
import 'meal_plan.dart';
import 'menu_ingredients.dart';

String shoppingQuantity(double value) =>
    value.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');

class ShoppingMenuUse {
  const ShoppingMenuUse(this.schedule, this.dish, this.people);
  final String schedule, dish;
  final int people;
}

List<ShoppingMenuUse> shoppingMenuUses(String note) => note
    .split('; ')
    .map((entry) {
      final parts = entry.split(' · ');
      final match = RegExp(
        r'^(.*) \((\d+) người\)$',
      ).firstMatch(parts.length >= 3 ? parts.sublist(2).join(' · ') : '');
      return ShoppingMenuUse(
        parts.length >= 3 ? '${parts[0]} · ${parts[1]}' : '',
        match?.group(1) ?? entry,
        int.tryParse(match?.group(2) ?? '') ?? 1,
      );
    })
    .where((use) => use.dish.trim().isNotEmpty)
    .toList();

Future<void> showShoppingMenuSheet(
  BuildContext context,
  ShoppingSummary item,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  backgroundColor: Colors.white,
  builder: (_) => _ShoppingMenuSheet(item: item),
);

class _ShoppingMenuSheet extends StatefulWidget {
  const _ShoppingMenuSheet({required this.item});
  final ShoppingSummary item;
  @override
  State<_ShoppingMenuSheet> createState() => _ShoppingMenuSheetState();
}

class _ShoppingMenuSheetState extends State<_ShoppingMenuSheet> {
  List<PlannedDish> dishes = [];
  bool loading = true, failed = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final date = widget.item.menuDay ?? widget.item.neededDate;
      if (date != null) {
        final rows = await WeekMenuStore(
          menuWeek(date),
        ).load().timeout(const Duration(seconds: 12));
        if (mounted) dishes = rows;
      }
    } catch (_) {
      failed = true;
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final uses = shoppingMenuUses(item.note);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .8,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text(
            item.name,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Cần mua ${shoppingQuantity(item.quantity)} ${item.unit}',
            style: const TextStyle(
              fontSize: 18,
              color: Color(0xFF079669),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Mua để nấu món gì?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if (loading) const LinearProgressIndicator(),
          if (failed)
            const Text(
              'Chưa tải được nguyên liệu chi tiết. Thông tin đã chốt vẫn hiển thị bên dưới.',
            ),
          ...uses.map((use) {
            final matches = dishes.where((dish) {
              final schedule =
                  '${dish.date.weekday == 7 ? 'CN' : 'T${dish.date.weekday + 1}'} ${dish.date.day}/${dish.date.month} · ${mealSlots[dish.slot]}';
              return dish.name == use.dish && schedule == use.schedule;
            });
            final dish = matches.isEmpty ? null : matches.first;
            final ingredients = dish == null
                ? <String>[]
                : dish.amounts.isNotEmpty
                ? dish.amounts
                      .map(
                        (i) =>
                            '${i.name} · ${shoppingQuantity(i.forPeople(use.people))} ${i.unit}',
                      )
                      .toList()
                : dish.ingredients.map((name) {
                    final portion = ingredientPortion(name);
                    return portion == null
                        ? name
                        : '$name · ${shoppingQuantity(portion.quantity * use.people)} ${portion.unit}';
                  }).toList();
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5FAF8),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE0EDE7)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    use.dish,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (use.schedule.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '${use.schedule} · ${use.people} người',
                        style: const TextStyle(color: Color(0xFF667085)),
                      ),
                    ),
                  const SizedBox(height: 12),
                  const Text(
                    'Nguyên liệu cần dùng',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  if (ingredients.isEmpty)
                    Text(
                      loading
                          ? 'Đang tải nguyên liệu…'
                          : '${item.name} · từ danh sách đã chốt',
                    ),
                  ...ingredients.map(
                    (ingredient) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.check_circle_outline,
                            size: 18,
                            color: Color(0xFF079669),
                          ),
                          const SizedBox(width: 8),
                          Expanded(child: Text(ingredient)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const Text(
            'Nguyên liệu tham chiếu thực đơn hiện tại, định lượng có thể thay đổi nếu menu đã sửa. Lượng cần mua ở trên là phần còn thiếu đã chốt.',
            style: TextStyle(fontSize: 12, color: Color(0xFF667085)),
          ),
        ],
      ),
    );
  }
}
