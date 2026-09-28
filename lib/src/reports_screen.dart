import 'package:flutter/material.dart';

import 'app_tutorial.dart';
import 'inventory_store.dart';
import 'screens.dart' show BrandHeader;

const _green = Color(0xFF079669);
const _ink = Color(0xFF253043);
const _muted = Color(0xFF98A2B3);

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  int _price(FoodSummary food) {
    final parts = food.$2.split('·');
    final raw = parts.length > 1 ? parts.last : parts.first;
    return int.tryParse(raw.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }

  String _vnd(int value) =>
      '${value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')}đ';

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: inventoryRevision,
    builder: (context, _, _) {
      final now = DateTime.now();
      final monthEvents = inventoryEvents.where(
        (event) =>
            event.occurredAt.year == now.year &&
            event.occurredAt.month == now.month,
      );
      final totalValue = inventoryFoods.fold<int>(
        0,
        (sum, food) => sum + _price(food),
      );
      final expiredValue = inventoryFoods
          .where((food) => food.$3 == 'Hết hạn')
          .fold<int>(0, (sum, food) => sum + _price(food));
      final consumed = monthEvents
          .where((event) => event.type == 'consumed')
          .toList();
      final discarded = monthEvents
          .where((event) => event.type == 'discarded')
          .toList();
      final cooked = monthEvents
          .where((event) => event.type == 'cooked')
          .length;
      final consumedValue = consumed.fold<int>(
        0,
        (sum, event) => sum + event.valueVnd,
      );
      final wastedValue = discarded.fold<int>(
        0,
        (sum, event) => sum + event.valueVnd,
      );
      final hasHistory = monthEvents.isNotEmpty;
      return Column(
        children: [
          const BrandHeader(title: 'Báo cáo gia đình'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                KeyedSubtree(
                  key: tutorialTargetKeys[4],
                  child: _SummaryCard(
                    title: 'Giá trị thực phẩm đang theo dõi',
                    value: _vnd(totalValue),
                    footnote: '${inventoryFoods.length} món trong tủ lạnh',
                    icon: Icons.inventory_2_outlined,
                  ),
                ),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) => GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: constraints.maxWidth < 400 ? 1.15 : 1.55,
                    children: [
                      _MetricCard(
                        label: 'Đã sử dụng tháng này',
                        value: _vnd(consumedValue),
                        detail: '${consumed.length} lần ghi nhận',
                        icon: Icons.restaurant_outlined,
                        tint: const Color(0xFFE8FBF4),
                        foreground: _green,
                      ),
                      _MetricCard(
                        label: 'Đã bỏ tháng này',
                        value: _vnd(wastedValue),
                        detail: '${discarded.length} lần ghi nhận',
                        icon: Icons.delete_outline,
                        tint: const Color(0xFFFFF1F0),
                        foreground: Colors.redAccent,
                      ),
                      _MetricCard(
                        label: 'Giá trị đã hết hạn',
                        value: _vnd(expiredValue),
                        detail: 'Trong số thực phẩm hiện có',
                        icon: Icons.event_busy_outlined,
                        tint: const Color(0xFFFFF8E5),
                        foreground: Colors.orange,
                      ),
                      _MetricCard(
                        label: 'Bữa đã nấu tháng này',
                        value: '$cooked',
                        detail: 'Dựa trên thao tác đã xác nhận',
                        icon: Icons.soup_kitchen_outlined,
                        tint: const Color(0xFFF2EEFF),
                        foreground: Colors.deepPurple,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Hoạt động tháng này',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (!hasHistory)
                          const _EmptyHistory()
                        else
                          ...monthEvents.toList().reversed.take(12).map((
                            event,
                          ) {
                            final isWaste = event.type == 'discarded';
                            final isCook = event.type == 'cooked';
                            final label = switch (event.type) {
                              'consumed' => 'Đã sử dụng ${event.name}',
                              'discarded' => 'Đã bỏ ${event.name}',
                              'cooked' => 'Đã nấu ${event.name}',
                              'added' => 'Đã thêm ${event.name}',
                              'updated' => 'Đã cập nhật ${event.name}',
                              'purchase_reversed' =>
                                'Đã bỏ đánh dấu mua ${event.name}',
                              _ => 'Đã xóa ${event.name}',
                            };
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 17,
                                    backgroundColor: isWaste
                                        ? const Color(0xFFFFF1F0)
                                        : const Color(0xFFE8FBF4),
                                    child: Icon(
                                      isWaste
                                          ? Icons.delete_outline
                                          : isCook
                                          ? Icons.soup_kitchen_outlined
                                          : Icons.check,
                                      size: 17,
                                      color: isWaste
                                          ? Colors.redAccent
                                          : _green,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: _ink,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${event.occurredAt.hour.toString().padLeft(2, '0')}:${event.occurredAt.minute.toString().padLeft(2, '0')}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: _muted,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F7F9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: _muted),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Báo cáo chỉ tính những hoạt động bạn đã xác nhận. Món mẫu không được tính vào lịch sử sử dụng hoặc lãng phí.',
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.45,
                            color: _muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      );
    },
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.footnote,
    required this.icon,
  });
  final String title;
  final String value;
  final String footnote;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _green,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        const SizedBox(width: 2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                footnote,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ),
        Icon(icon, color: Colors.white.withValues(alpha: .8), size: 34),
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
  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color tint;
  final Color foreground;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: tint,
            child: Icon(icon, size: 17, color: foreground),
          ),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: _ink,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9, color: _muted),
          ),
        ],
      ),
    ),
  );
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
    decoration: BoxDecoration(
      color: const Color(0xFFF8F9FA),
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Column(
      children: [
        Icon(Icons.insights_outlined, size: 34, color: _muted),
        SizedBox(height: 8),
        Text(
          'Chưa có hoạt động được ghi nhận',
          style: TextStyle(fontWeight: FontWeight.w700, color: _ink),
        ),
        SizedBox(height: 4),
        Text(
          'Khi bạn dùng món hoặc xác nhận đã bỏ, báo cáo sẽ cập nhật tại đây.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: _muted),
        ),
      ],
    ),
  );
}
