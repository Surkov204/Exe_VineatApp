import 'package:flutter/material.dart';

import 'food_image.dart';
import 'global_search.dart';

const _green = Color(0xFF079669);
const _ink = Color(0xFF253043);
const _muted = Color(0xFF98A2B3);

enum FoodRemovalResult { deleted, consumed, discarded }

class FoodDetailData {
  const FoodDetailData({
    required this.name,
    required this.category,
    required this.quantity,
    required this.price,
    required this.purchaseDate,
    required this.expiryDate,
    required this.status,
    required this.addedBy,
    required this.note,
    required this.image,
  });

  final String name, category, quantity, price, purchaseDate, expiryDate;
  final String status, addedBy, note;
  final int image;

  factory FoodDetailData.fromSummary({
    required String name,
    required String detail,
    required String status,
    required int image,
  }) {
    final parts = detail.split('·').map((e) => e.trim()).toList();
    final now = DateTime.now();
    final daysRemaining = int.tryParse(
      RegExp(r'\d+').firstMatch(status)?.group(0) ?? '',
    );
    final expiry = status == 'Hết hạn'
        ? now.subtract(const Duration(days: 1))
        : status.contains('Còn')
        ? now.add(Duration(days: daysRemaining ?? 2))
        : now.add(const Duration(days: 14));
    return FoodDetailData(
      name: name,
      category: _categoryFor(name),
      quantity: parts.isEmpty ? detail : parts.first,
      price: parts.length > 1 ? parts[1] : '—',
      purchaseDate: _formatDate(now.subtract(const Duration(days: 3))),
      expiryDate: _formatDate(expiry),
      status: status,
      addedBy: image.isEven ? 'Mẹ' : 'Bố',
      note: _noteFor(name),
      image: image,
    );
  }

  static String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';

  static String _categoryFor(String name) {
    if (name.contains('Thịt') ||
        name.contains('Cá') ||
        name.contains('Trứng')) {
      return 'Thịt cá';
    }
    if (name.contains('Nước mắm')) {
      return 'Gia vị';
    }
    if (name.contains('Gạo')) {
      return 'Đồ khô';
    }
    if (name.contains('Sữa')) {
      return 'Sữa và đồ uống';
    }
    return 'Rau củ';
  }

  static String _noteFor(String name) {
    if (name.contains('Rau')) {
      return 'Mua ở chợ sáng';
    }
    if (name.contains('Thịt') || name.contains('Cá')) {
      return 'Bảo quản trong ngăn mát';
    }
    return 'Kiểm tra hạn dùng trước khi sử dụng';
  }

  FoodDetailData copyWith({String? quantity, String? price, String? note}) {
    return FoodDetailData(
      name: name,
      category: category,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      purchaseDate: purchaseDate,
      expiryDate: expiryDate,
      status: status,
      addedBy: addedBy,
      note: note ?? this.note,
      image: image,
    );
  }
}

class FoodDetailScreen extends StatefulWidget {
  const FoodDetailScreen({super.key, required this.food});
  final FoodDetailData food;

  @override
  State<FoodDetailScreen> createState() => _FoodDetailScreenState();
}

class _FoodDetailScreenState extends State<FoodDetailScreen> {
  late FoodDetailData food = widget.food;

  bool get expired => food.status == 'Hết hạn';
  bool get warning => food.status.contains('Còn');

  Future<void> _edit() async {
    final result = await showDialog<FoodDetailData>(
      context: context,
      builder: (_) => _EditFoodDialog(food: food),
    );
    if (result != null && mounted) {
      Navigator.pop(context, result);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa thực phẩm?'),
        content: Text('Bạn có chắc muốn xóa ${food.name} khỏi tủ lạnh?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.pop(context, FoodRemovalResult.deleted);
    }
  }

  Future<void> _markUsed({required bool discarded}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          discarded ? 'Ghi nhận đã bỏ thực phẩm?' : 'Ghi nhận đã sử dụng?',
        ),
        content: Text(
          discarded
              ? 'Thông tin này sẽ được tính vào báo cáo lãng phí.'
              : 'ViNeat sẽ ghi nhận món này đã được sử dụng trong báo cáo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.pop(
        context,
        discarded ? FoodRemovalResult.discarded : FoodRemovalResult.consumed,
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFFAFAFB),
    appBar: AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back),
      ),
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chi tiết thực phẩm',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: _ink,
            ),
          ),
          Text(
            'Xem và chỉnh sửa thông tin',
            style: TextStyle(fontSize: 10, color: _muted),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () => showGlobalSearch(context),
          icon: const Icon(Icons.search),
        ),
        TextButton.icon(
          onPressed: _edit,
          icon: const Icon(Icons.edit_outlined, size: 17),
          label: const Text('Chỉnh sửa'),
        ),
        const SizedBox(width: 5),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              SizedBox(
                height: 225,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    FoodImage(
                      name: food.name,
                      assetIndex: food.image,
                      fit: BoxFit.cover,
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xB8000000)],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 18,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  food.name,
                                  style: const TextStyle(
                                    fontSize: 23,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  food.category,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFFE5E7EB),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _StatusBadge(
                            text: food.status,
                            expired: expired,
                            warning: warning,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.18,
                      children: [
                        _InfoTile(
                          Icons.balance_outlined,
                          'Số lượng',
                          food.quantity,
                        ),
                        _InfoTile(Icons.paid_outlined, 'Giá tiền', food.price),
                        _InfoTile(
                          Icons.inventory_2_outlined,
                          'Ngày mua',
                          food.purchaseDate,
                        ),
                        _InfoTile(
                          Icons.event_available_outlined,
                          'Hạn sử dụng',
                          food.expiryDate,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Thời gian sử dụng còn lại',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Color(0xFF667085)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            expired ? 'Đã hết hạn' : food.status,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: expired
                                  ? Colors.redAccent
                                  : warning
                                  ? Colors.orange
                                  : _green,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: expired
                          ? .05
                          : warning
                          ? .35
                          : .85,
                      minHeight: 10,
                      borderRadius: BorderRadius.circular(10),
                      color: expired
                          ? Colors.redAccent
                          : warning
                          ? Colors.orange
                          : _green,
                      backgroundColor: const Color(0xFFF0F2F5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Column(
              children: [
                _DetailRow('Hạn sử dụng', food.expiryDate),
                _DetailRow('Thêm bởi', food.addedBy),
                _DetailRow(
                  'Trạng thái',
                  food.status,
                  status: true,
                  expired: expired,
                  warning: warning,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Ghi chú',
                          style: TextStyle(color: Color(0xFF667085)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6F7F9),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Text(
                          food.note,
                          style: const TextStyle(color: _ink),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _edit,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Chỉnh sửa thực phẩm'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        const SizedBox(height: 10),
        FilledButton.tonalIcon(
          onPressed: () => _markUsed(discarded: false),
          icon: const Icon(Icons.restaurant),
          label: const Text('Đã sử dụng hết'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15),
            foregroundColor: _green,
          ),
        ),
        if (expired) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _markUsed(discarded: true),
            icon: const Icon(Icons.delete_sweep_outlined),
            label: const Text('Đã bỏ vì hết hạn'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
          ),
        ],
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _delete,
          icon: const Icon(Icons.delete_outline),
          label: const Text('Xóa thực phẩm'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            foregroundColor: Colors.redAccent,
            backgroundColor: const Color(0xFFFFF3F3),
            side: const BorderSide(color: Color(0xFFFFD3D3)),
          ),
        ),
        const SizedBox(height: 30),
      ],
    ),
  );
}

class _InfoTile extends StatelessWidget {
  const _InfoTile(this.icon, this.label, this.value);
  final IconData icon;
  final String label, value;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFFF8F9FA),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: _muted),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF667085)),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: _ink,
          ),
        ),
      ],
    ),
  );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.text,
    required this.expired,
    required this.warning,
  });
  final String text;
  final bool expired, warning;
  @override
  Widget build(BuildContext context) {
    final color = expired
        ? Colors.redAccent
        : warning
        ? Colors.orange
        : _green;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: expired
            ? const Color(0xFFFFECEE)
            : warning
            ? const Color(0xFFFFF5D6)
            : const Color(0xFFE4FAF1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(
    this.label,
    this.value, {
    this.status = false,
    this.expired = false,
    this.warning = false,
  });
  final String label, value;
  final bool status, expired, warning;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 15),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xFFF0F1F3))),
    ),
    child: Row(
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF667085))),
        const Spacer(),
        if (status)
          _StatusBadge(text: value, expired: expired, warning: warning)
        else
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700, color: _ink),
          ),
      ],
    ),
  );
}

class _EditFoodDialog extends StatefulWidget {
  const _EditFoodDialog({required this.food});
  final FoodDetailData food;
  @override
  State<_EditFoodDialog> createState() => _EditFoodDialogState();
}

class _EditFoodDialogState extends State<_EditFoodDialog> {
  late final quantity = TextEditingController(text: widget.food.quantity);
  late final price = TextEditingController(text: widget.food.price);
  late final note = TextEditingController(text: widget.food.note);
  @override
  void dispose() {
    quantity.dispose();
    price.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Chỉnh sửa ${widget.food.name}'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: quantity,
            decoration: const InputDecoration(labelText: 'Số lượng'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: price,
            decoration: const InputDecoration(labelText: 'Giá tiền'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: note,
            minLines: 2,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Ghi chú'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(
          context,
          widget.food.copyWith(
            quantity: quantity.text.trim(),
            price: price.text.trim(),
            note: note.text.trim(),
          ),
        ),
        child: const Text('Lưu'),
      ),
    ],
  );
}
