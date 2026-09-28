import 'package:flutter/material.dart';

import 'inventory_models.dart';

class RecipeCookDialog extends StatefulWidget {
  const RecipeCookDialog({super.key, required this.ingredients});
  final List<(String, FoodSummary)> ingredients;

  @override
  State<RecipeCookDialog> createState() => _RecipeCookDialogState();
}

class _RecipeCookDialogState extends State<RecipeCookDialog> {
  final _controllers = <String, TextEditingController>{};
  final _selected = <String, bool>{};
  String? _error;

  List<(String, FoodSummary)> get _stockIngredients {
    final seen = <String>{};
    return widget.ingredients.where((ingredient) {
      final food = ingredient.$2;
      return seen.add(food.$1.toLowerCase());
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    for (final ingredient in _stockIngredients) {
      final food = ingredient.$2;
      _controllers[food.$1] = TextEditingController(text: '1');
      _selected[food.$1] = false;
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _save() {
    final uses = <(FoodSummary, double)>[];
    for (final ingredient in _stockIngredients) {
      final food = ingredient.$2;
      if (_selected[food.$1] != true) continue;
      final amount = double.tryParse(
        _controllers[food.$1]!.text.trim().replaceAll(',', '.'),
      );
      final stock = InventoryItemRecord.fromSummary(food).quantity;
      if (amount == null || amount <= 0 || amount > stock) {
        setState(
          () => _error =
              'Nhập lượng đã dùng lớn hơn 0 và không vượt quá lượng đang có.',
        );
        return;
      }
      uses.add((food, amount));
    }
    Navigator.pop(context, uses);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Ghi nhận bữa đã nấu'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Chọn nguyên liệu đã dùng để trừ đúng số lượng khỏi tủ lạnh. Các món khác không bị thay đổi.',
              style: TextStyle(fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 12),
            if (_stockIngredients.isEmpty)
              const Text(
                'Không tìm thấy nguyên liệu khớp trong tủ lạnh; chỉ ghi nhận tên món đã nấu.',
              ),
            ..._stockIngredients.map((ingredient) {
              final food = ingredient.$2;
              final stock = InventoryItemRecord.fromSummary(food);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Checkbox(
                      value: _selected[food.$1],
                      onChanged: (value) =>
                          setState(() => _selected[food.$1] = value ?? false),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            food.$1,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            'Đang có ${stock.quantity} ${stock.unit}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF98A2B3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 76,
                      child: TextField(
                        controller: _controllers[food.$1],
                        enabled: _selected[food.$1] == true,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: stock.unit,
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton.icon(
        onPressed: _save,
        icon: const Icon(Icons.done),
        label: const Text('Xác nhận đã nấu'),
      ),
    ],
  );
}
