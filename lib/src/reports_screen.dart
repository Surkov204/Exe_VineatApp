import 'package:flutter/material.dart';
import 'app_tutorial.dart';
import 'inventory_store.dart';
import 'inventory_activity_screen.dart';
import 'screens.dart' show BrandHeader;

const _green = Color(0xFF079669);
const _ink = Color(0xFF253043);
const _muted = Color(0xFF667085);
String _vnd(int value) =>
    '${value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')}đ';
String _quantity(double value) =>
    value.toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});
  void _history(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const InventoryActivityScreen()));

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: inventoryRevision,
    builder: (context, _, child) {
      final now = DateTime.now();
      final events =
          inventoryEvents
              .where(
                (e) =>
                    e.occurredAt.year == now.year &&
                    e.occurredAt.month == now.month,
              )
              .toList()
            ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
      final consumed = events.where((e) => e.type == 'consumed').toList();
      final discarded = events.where((e) => e.type == 'discarded').toList();
      final usedValue = consumed.fold<int>(0, (sum, e) => sum + e.valueVnd);
      final wasteValue = discarded.fold<int>(0, (sum, e) => sum + e.valueVnd);
      final cooked = events.where((e) => e.type == 'cooked').length;
      final totalValue = inventoryFoods.fold<int>(
        0,
        (sum, f) => sum + f.priceVnd,
      );
      final expired = inventoryFoods
          .where((f) => f.status == 'Hết hạn')
          .toList();
      final near = inventoryFoods.where((f) {
        if (f.expiry == null) return false;
        final days = DateTime(
          f.expiry!.year,
          f.expiry!.month,
          f.expiry!.day,
        ).difference(DateTime(now.year, now.month, now.day)).inDays;
        return days >= 0 && days <= 3;
      }).length;
      final expiredValue = expired.fold<int>(0, (sum, f) => sum + f.priceVnd);
      return Column(
        children: [
          const BrandHeader(title: 'Báo cáo gia đình'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Tổng quan',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F6EF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Tháng ${now.month}/${now.year}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _green,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  key: tutorialTargetKeys[4],
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF079669), Color(0xFF087F63)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x18079669),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.kitchen_outlined,
                            color: Colors.white,
                            size: 22,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Giá trị thực phẩm đang theo dõi',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _vnd(totalValue),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${inventoryFoods.length} món trong tủ lạnh',
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _StockChip('$near sắp hết hạn', Icons.timer_outlined),
                          _StockChip(
                            '${expired.length} đã hết hạn',
                            Icons.event_busy_outlined,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Thống kê tháng này',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  key: tutorialSectionKeys[4][0],
                  builder: (context, constraints) {
                    final single =
                        constraints.maxWidth < 300 ||
                        MediaQuery.textScalerOf(context).scale(1) > 1.3;
                    final metrics = [
                      _MetricCard(
                        label: 'Đã sử dụng tháng này',
                        value: _vnd(usedValue),
                        detail: '${consumed.length} lần xuất nguyên liệu',
                        icon: Icons.restaurant_outlined,
                        tint: const Color(0xFFE7F8F0),
                        foreground: _green,
                      ),
                      _MetricCard(
                        label: 'Đã bỏ tháng này',
                        value: _vnd(wasteValue),
                        detail: '${discarded.length} lần ghi nhận',
                        icon: Icons.delete_outline,
                        tint: const Color(0xFFFFF0F1),
                        foreground: const Color(0xFFC1374B),
                      ),
                      _MetricCard(
                        label: 'Giá trị đã hết hạn',
                        value: _vnd(expiredValue),
                        detail: '${expired.length} món hiện có trong tủ',
                        icon: Icons.event_busy_outlined,
                        tint: const Color(0xFFFFF6DF),
                        foreground: const Color(0xFF996100),
                      ),
                      _MetricCard(
                        label: 'Bữa đã nấu tháng này',
                        value: '$cooked',
                        detail: 'Lần xác nhận nấu món',
                        icon: Icons.soup_kitchen_outlined,
                        tint: const Color(0xFFF0ECFF),
                        foreground: const Color(0xFF6850AC),
                      ),
                    ];
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: metrics
                          .map(
                            (metric) => SizedBox(
                              width: single
                                  ? constraints.maxWidth
                                  : (constraints.maxWidth - 12) / 2,
                              child: metric,
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: 20),
                Container(
                  key: tutorialSectionKeys[4][1],
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFE7ECE9)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Hoạt động tháng này',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: _ink,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => _history(context),
                            child: const Text('Xem tất cả'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (events.isEmpty)
                        const _EmptyHistory()
                      else
                        ...events.take(8).map((e) {
                          final waste = e.type == 'discarded';
                          final cook = e.type == 'cooked';
                          final label = switch (e.type) {
                            'consumed' => 'Đã sử dụng ${e.name}',
                            'discarded' => 'Đã bỏ ${e.name}',
                            'cooked' => 'Đã nấu ${e.name}',
                            'added' => 'Đã thêm ${e.name}',
                            'updated' => 'Đã cập nhật ${e.name}',
                            'purchase_reversed' =>
                              'Đã bỏ đánh dấu mua ${e.name}',
                            _ => 'Đã xóa ${e.name}',
                          };
                          final actor = e.metadata['actor_name']?.toString();
                          final person =
                              actor == null ||
                                  actor.isEmpty ||
                                  actor.contains('@')
                              ? 'Thành viên'
                              : actor;
                          return Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Color(0xFFF0F3F1)),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: waste
                                        ? const Color(0xFFFFF0F1)
                                        : const Color(0xFFE7F8F0),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    waste
                                        ? Icons.delete_outline
                                        : cook
                                        ? Icons.soup_kitchen_outlined
                                        : Icons.check,
                                    size: 22,
                                    color: waste
                                        ? const Color(0xFFC1374B)
                                        : _green,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        label,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          height: 1.4,
                                          fontWeight: FontWeight.w700,
                                          color: _ink,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        '$person · ${e.occurredAt.day}/${e.occurredAt.month} · ${e.occurredAt.hour.toString().padLeft(2, '0')}:${e.occurredAt.minute.toString().padLeft(2, '0')}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          height: 1.4,
                                          color: _muted,
                                        ),
                                      ),
                                      if (!cook &&
                                          e.quantity > 0 &&
                                          e.unit.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 5,
                                          ),
                                          child: Text(
                                            '${_quantity(e.quantity)} ${e.unit}${e.valueVnd > 0 ? ' · ${_vnd(e.valueVnd)}' : ''}',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: _green,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.history_outlined),
                  label: const Text('Theo dõi thực phẩm và người thao tác'),
                  onPressed: () => _history(context),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Chỉ tính các thao tác đã xác nhận. Giá trị hết hạn là tồn hiện tại, không phải số tiền đã bỏ.',
                  style: TextStyle(fontSize: 13, height: 1.5, color: _muted),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      );
    },
  );
}

class _StockChip extends StatelessWidget {
  const _StockChip(this.label, this.icon);
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0x25FFFFFF),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: Colors.white),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, color: Colors.white),
          ),
        ),
      ],
    ),
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    required this.tint,
    required this.foreground,
  });
  final String label, value, detail;
  final IconData icon;
  final Color tint, foreground;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: tint,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 23, color: foreground),
        const SizedBox(height: 14),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: foreground,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            height: 1.4,
            color: _ink,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          detail,
          style: const TextStyle(fontSize: 13, height: 1.4, color: _muted),
        ),
      ],
    ),
  );
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 20),
    child: Column(
      children: [
        Icon(Icons.insights_outlined, size: 38, color: _green),
        SizedBox(height: 10),
        Text(
          'Chưa có hoạt động được ghi nhận',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Hoạt động sẽ xuất hiện khi bạn xác nhận nhập, xuất hoặc nấu món.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, height: 1.5, color: _muted),
        ),
      ],
    ),
  );
}
