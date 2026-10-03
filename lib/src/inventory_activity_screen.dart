import 'package:flutter/material.dart';
import 'food_form_widgets.dart';
import 'inventory_store.dart';

class InventoryActivityScreen extends StatefulWidget {
  const InventoryActivityScreen({super.key});
  @override
  State<InventoryActivityScreen> createState() =>
      _InventoryActivityScreenState();
}

class _InventoryActivityScreenState extends State<InventoryActivityScreen> {
  String filter = 'Tất cả';
  String date(DateTime d) =>
      '${d.day}/${d.month}/${d.year} · ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  String label(InventoryEvent e) => switch (e.type) {
    'added' => 'Đã thêm / mua',
    'consumed' =>
      e.metadata['remaining_quantity'] == 0 ? 'Đã dùng hết' : 'Đã sử dụng',
    'discarded' => 'Đã bỏ',
    'updated' => 'Đã chỉnh sửa',
    'removed' => 'Đã xóa',
    _ => 'Đã nấu',
  };
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF7FAF9),
    appBar: AppBar(
      title: const Text('Theo dõi thực phẩm'),
      backgroundColor: Colors.white,
    ),
    body: ValueListenableBuilder<int>(
      valueListenable: inventoryRevision,
      builder: (context, _, _) {
        final events = inventoryEvents.where((e) => e.type != 'cooked').toList()
          ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
        final purchased = events.where((e) => e.type == 'added');
        final finished = events.where(
          (e) => e.type == 'consumed' && e.metadata['remaining_quantity'] == 0,
        );
        final visible = events
            .where(
              (e) =>
                  filter == 'Tất cả' ||
                  (filter == 'Đã dùng' && e.type == 'consumed') ||
                  (filter == 'Đã mua' && e.type == 'added') ||
                  (filter == 'Đã bỏ' && e.type == 'discarded'),
            )
            .toList();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Vòng đời thực phẩm',
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Theo dõi từng lô và người thao tác cuối trong gia đình.',
              style: TextStyle(color: Colors.blueGrey),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, c) => Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final entry in <String, int>{
                    'Đã thêm / mua': purchased.length,
                    'Đã dùng hết': finished.length,
                    'Còn trong tủ': inventoryFoods.length,
                    'Gần hết hạn': inventoryFoods
                        .where((f) => f.status.contains('Còn'))
                        .length,
                    'Đã hết hạn': inventoryFoods
                        .where((f) => f.status == 'Hết hạn')
                        .length,
                    'Lần bỏ thực phẩm': events
                        .where((e) => e.type == 'discarded')
                        .length,
                  }.entries)
                    SizedBox(
                      width: (c.maxWidth - 10) / 2,
                      child: Card(
                        margin: EdgeInsets.zero,
                        color: const Color(0xFFE8F7F0),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Text(
                                '${entry.value}',
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF079669),
                                ),
                              ),
                              Text(entry.key, textAlign: TextAlign.center),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Số đã mua/dùng tính theo lô trong lịch sử đã tải (tối đa 250 hoạt động), không cộng kg với số hộp. Lịch sử cũ thiếu lượng còn lại chưa được tính là đã dùng hết.',
              style: TextStyle(fontSize: 12, color: Colors.blueGrey),
            ),
            const SizedBox(height: 20),
            const Text(
              'Nhật ký thao tác',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            Wrap(
              spacing: 8,
              children: ['Tất cả', 'Đã mua', 'Đã dùng', 'Đã bỏ']
                  .map(
                    (s) => ChoiceChip(
                      label: Text(s),
                      selected: filter == s,
                      onSelected: (_) => setState(() => filter = s),
                    ),
                  )
                  .toList(),
            ),
            if (visible.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Chưa có hoạt động phù hợp.',
                  textAlign: TextAlign.center,
                ),
              ),
            for (final e in visible)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${label(e)} · ${e.quantity} ${e.unit}',
                        style: const TextStyle(
                          color: Color(0xFF079669),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Người thao tác: ${foodPersonName(e.metadata['actor_name'] as String?)}',
                      ),
                      Text(
                        date(e.occurredAt.toLocal()),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blueGrey,
                        ),
                      ),
                      if (e.metadata['remaining_quantity'] != null)
                        Text(
                          'Sau thao tác còn: ${e.metadata['remaining_quantity']} ${e.unit}',
                          style: const TextStyle(fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}
