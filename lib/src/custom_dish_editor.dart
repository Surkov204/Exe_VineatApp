import 'package:flutter/material.dart';
import 'inventory_store.dart';
import 'meal_plan.dart';

Future<PlannedDish?> showCustomDishEditor(
  BuildContext context, {
  required DateTime day,
  required String slot,
  required int people,
  required List<FoodSummary> stock,
}) => showModalBottomSheet<PlannedDish>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.white,
  showDragHandle: true,
  builder: (_) =>
      _CustomDishEditor(day: day, slot: slot, people: people, stock: stock),
);

class _CustomDishEditor extends StatefulWidget {
  const _CustomDishEditor({
    required this.day,
    required this.slot,
    required this.people,
    required this.stock,
  });
  final DateTime day;
  final String slot;
  final int people;
  final List<FoodSummary> stock;
  @override
  State<_CustomDishEditor> createState() => _CustomDishEditorState();
}

class _CustomDishEditorState extends State<_CustomDishEditor> {
  final name = TextEditingController();
  final form = GlobalKey<FormState>();
  final ingredients = <DishIngredient>[];
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> _stock() async {
    final available = widget.stock
        .where(
          (f) =>
              f.quantity > 0 &&
              (f.expiry == null || !menuDay(f.expiry!).isBefore(widget.day)),
        )
        .toList();
    final food = await showModalBottomSheet<FoodSummary>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (c) => SizedBox(
        height: MediaQuery.sizeOf(c).height * .6,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Chọn nguyên liệu trong tủ',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            if (available.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Không có thực phẩm còn hạn đến ngày nấu. Bạn có thể nhập nguyên liệu cần mua.',
                ),
              ),
            ...available.map(
              (f) => ListTile(
                title: Text(f.name),
                subtitle: Text(
                  'Còn ${f.quantity} ${f.unit}${f.expiry == null ? '' : ' · HSD ${f.expiry!.day}/${f.expiry!.month}'}',
                ),
                leading: const Icon(Icons.kitchen_outlined),
                trailing: const Icon(Icons.add_circle_outline),
                onTap: () => Navigator.pop(c, f),
              ),
            ),
          ],
        ),
      ),
    );
    if (food != null && mounted) await _ingredient(food: food);
  }

  Future<void> _ingredient({FoodSummary? food, int? index}) async {
    final old = index == null ? null : ingredients[index];
    final ingredientName = TextEditingController(
      text: old?.name ?? food?.name ?? '',
    );
    final quantity = TextEditingController(
      text:
          old?.quantity.toString() ??
          (food == null
              ? ''
              : (food.quantity < 1 ? food.quantity : 1).toString()),
    );
    final unit = TextEditingController(text: old?.unit ?? food?.unit ?? 'gram');
    final ingredientForm = GlobalKey<FormState>();
    final result = await showDialog<DishIngredient>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(index == null ? 'Thêm nguyên liệu' : 'Sửa nguyên liệu'),
        content: SingleChildScrollView(
          child: Form(
            key: ingredientForm,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Lượng cần dùng cho ${widget.people} người. Phần thiếu sẽ được đưa vào Đi chợ.',
                  style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: ingredientName,
                  readOnly: food != null,
                  maxLength: 100,
                  decoration: const InputDecoration(
                    labelText: 'Tên nguyên liệu',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Nhập tên nguyên liệu'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: quantity,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Khối lượng / số lượng cần dùng',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final n = double.tryParse(v?.replaceAll(',', '.') ?? '');
                    return n == null || !n.isFinite || n <= 0
                        ? 'Nhập lượng lớn hơn 0'
                        : null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: unit,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Đơn vị',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.expand_more),
                  ),
                  onTap: () async {
                    final chosen = await showModalBottomSheet<String>(
                      context: c,
                      showDragHandle: true,
                      backgroundColor: Colors.white,
                      builder: (picker) => ListView(
                        shrinkWrap: true,
                        children:
                            {
                                  ...[
                                    'gram',
                                    'kg',
                                    'ml',
                                    'lít',
                                    'quả',
                                    'cái',
                                    'hộp',
                                    'miếng',
                                    'bó',
                                  ],
                                  unit.text,
                                }
                                .map(
                                  (u) => ListTile(
                                    title: Text(
                                      u,
                                      style: TextStyle(
                                        fontWeight: unit.text == u
                                            ? FontWeight.w800
                                            : FontWeight.w400,
                                      ),
                                    ),
                                    trailing: unit.text == u
                                        ? const Icon(
                                            Icons.check,
                                            color: Color(0xFF079669),
                                          )
                                        : null,
                                    onTap: () => Navigator.pop(picker, u),
                                  ),
                                )
                                .toList(),
                      ),
                    );
                    if (chosen != null && c.mounted) unit.text = chosen;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              if (!ingredientForm.currentState!.validate()) return;
              Navigator.pop(
                c,
                DishIngredient(
                  name: ingredientName.text.trim(),
                  quantity: double.parse(quantity.text.replaceAll(',', '.')),
                  unit: unit.text,
                  servings: widget.people,
                  inventoryId: food?.id ?? old?.inventoryId,
                ),
              );
            },
            child: const Text('Lưu nguyên liệu'),
          ),
        ],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 350));
    ingredientName.dispose();
    quantity.dispose();
    unit.dispose();
    if (result == null || !mounted) return;
    setState(() {
      if (index == null) {
        ingredients.add(result);
      } else {
        ingredients[index] = result;
      }
    });
  }

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
        height: MediaQuery.sizeOf(context).height * .8,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Món tự nhập · ${mealSlots[widget.slot]}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Form(
                key: form,
                child: ListView(
                  children: [
                    TextFormField(
                      controller: name,
                      maxLength: 100,
                      decoration: const InputDecoration(
                        labelText: 'Tên món',
                        hintText: 'Ví dụ: Canh bí nấu đậu hũ',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Nhập tên món' : null,
                    ),
                    Text(
                      'Nguyên liệu cho ${widget.people} người',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _stock,
                          icon: const Icon(Icons.kitchen_outlined),
                          label: const Text('Chọn trong tủ'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _ingredient(),
                          icon: const Icon(Icons.add),
                          label: const Text('Nhập để đi chợ'),
                        ),
                      ],
                    ),
                    if (ingredients.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'Thêm nguyên liệu và lượng cần dùng để tính danh sách đi chợ.',
                          style: TextStyle(color: Colors.blueGrey),
                        ),
                      ),
                    for (var i = 0; i < ingredients.length; i++)
                      Card(
                        color: const Color(0xFFF1FAF6),
                        child: ListTile(
                          title: Text(ingredients[i].name),
                          subtitle: Text(
                            '${ingredients[i].quantity} ${ingredients[i].unit} · ${ingredients[i].inventoryId == null ? 'Tính phần cần mua' : 'Đã chọn trong tủ'}',
                          ),
                          onTap: () => _ingredient(index: i),
                          trailing: IconButton(
                            tooltip: 'Xóa nguyên liệu ${ingredients[i].name}',
                            onPressed: () =>
                                setState(() => ingredients.removeAt(i)),
                            icon: const Icon(Icons.close),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: ingredients.isEmpty
                  ? null
                  : () {
                      if (!form.currentState!.validate()) return;
                      Navigator.pop(
                        context,
                        PlannedDish(
                          date: widget.day,
                          slot: widget.slot,
                          name: name.text.trim(),
                          ingredients: ingredients.map((i) => i.name).toList(),
                          amounts: List.of(ingredients),
                        ),
                      );
                    },
              icon: const Icon(Icons.check),
              label: const Text('Thêm món tự nhập'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ),
  );
}
