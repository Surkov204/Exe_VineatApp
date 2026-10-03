import 'package:flutter/material.dart';
import 'app_services.dart';
import 'app_tutorial.dart';
import 'food_notification.dart';
import 'inventory_store.dart';
import 'inventory_usage.dart';
import 'inventory_models.dart' show newLocalId;
import 'meal_plan.dart';
import 'recipe_detail.dart';
import 'screens.dart' show BrandHeader;

Future<bool?> showInventoryUsageSheet(
  BuildContext context, {
  PlannedDish? dish,
  int people = 1,
}) {
  final stock = List<FoodSummary>.of(inventoryFoods);
  final plan = dish == null
      ? const UsagePlan([], [])
      : planDishUsage(dish, people, stock);
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    showDragHandle: true,
    builder: (_) =>
        _UsageSheet(stock: stock, plan: plan, dish: dish, people: people),
  );
}

class UsageScreen extends StatefulWidget {
  const UsageScreen({super.key, required this.catalog});
  final List<RecipeCatalogItem> catalog;
  @override
  State<UsageScreen> createState() => _UsageScreenState();
}

class _UsageScreenState extends State<UsageScreen> {
  List<PlannedDish> menu = [];
  DateTime day = menuDay(DateTime.now());
  int people = 1, generation = 0;
  bool loading = false;
  String? error;
  @override
  void initState() {
    super.initState();
    HouseholdService.instance.active.addListener(_load);
    activeAppTabIndex.addListener(_tabChanged);
    _load();
  }

  @override
  void dispose() {
    generation++;
    HouseholdService.instance.active.removeListener(_load);
    activeAppTabIndex.removeListener(_tabChanged);
    super.dispose();
  }

  void _tabChanged() {
    if (activeAppTabIndex.value == 5) _load();
  }

  Future<void> _load() async {
    final request = ++generation;
    setState(() {
      loading = true;
      menu = [];
      error = null;
    });
    try {
      final store = WeekMenuStore(menuWeek(day));
      final rows = await store.load().timeout(const Duration(seconds: 15));
      final count = await store
          .plannedPeople(day)
          .timeout(const Duration(seconds: 15));
      if (mounted && request == generation) {
        setState(() {
          menu = rows;
          people = count;
        });
      }
    } catch (_) {
      if (mounted && request == generation) {
        setState(
          () => error =
              'Chưa tải được thực đơn. Bạn vẫn có thể xuất thủ công hoặc chọn công thức.',
        );
      }
    } finally {
      if (mounted && request == generation) setState(() => loading = false);
    }
  }

  Future<void> _use({PlannedDish? dish}) async {
    final saved = await showInventoryUsageSheet(
      context,
      dish: dish,
      people: people,
    );
    if (saved == true && mounted) {
      showFoodNotification(
        context,
        title: 'Đã ghi nhận sử dụng',
        message: 'Tồn kho và lịch sử gia đình đã cập nhật.',
      );
    }
  }

  Future<void> _recipe() async {
    final recipe = await showModalBottomSheet<RecipeCatalogItem>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (c) => SizedBox(
        height: MediaQuery.sizeOf(c).height * .65,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Chọn món đã nấu',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            ...widget.catalog.map(
              (r) => ListTile(
                title: Text(r.name),
                subtitle: Text(r.ingredients.join(', ')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pop(c, r),
              ),
            ),
          ],
        ),
      ),
    );
    if (recipe != null && mounted) {
      await _use(
        dish: PlannedDish(
          date: menuDay(DateTime.now()),
          slot: 'dinner',
          name: recipe.name,
          ingredients: recipe.ingredients,
          recipeKey: recipe.id,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: inventoryRevision,
    builder: (c, _, child) {
      final history =
          inventoryEvents.where((e) => e.type == 'consumed').toList()
            ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
      final dishes = menu.where((d) => d.date == day).toList();
      return Column(
        children: [
          const BrandHeader(title: 'Xuất nguyên liệu', search: true),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  key: tutorialTargetKeys[5],
                  children: [
                    IconButton.filledTonal(
                      tooltip: 'Theo món ăn',
                      onPressed: _recipe,
                      icon: const Icon(Icons.restaurant_outlined),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: 'Trừ thủ công',
                      onPressed: () => _use(),
                      icon: const Icon(Icons.edit_note),
                    ),
                    const SizedBox(width: 8),
                    const Tooltip(
                      message: 'AI · Sắp có',
                      child: IconButton.filledTonal(
                        onPressed: null,
                        icon: Icon(Icons.auto_awesome_outlined),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Tải lại thực đơn',
                      onPressed: loading ? null : _load,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Column(
                  key: tutorialSectionKeys[5][0],
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Dùng theo thực đơn',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            final selected = await showDatePicker(
                              context: context,
                              initialDate: day,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (selected != null && mounted) {
                              day = menuDay(selected);
                              await _load();
                            }
                          },
                          icon: const Icon(Icons.calendar_month_outlined),
                          label: Text('${day.day}/${day.month}'),
                        ),
                      ],
                    ),
                    if (loading) const LinearProgressIndicator(),
                    if (error != null)
                      Text(
                        error!,
                        style: const TextStyle(color: Colors.deepOrange),
                      ),
                    if (!loading && dishes.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Ngày này chưa có món trong thực đơn. Chọn “Theo món ăn” hoặc “Trừ thủ công” ở trên.',
                        ),
                      ),
                    ...dishes.map(
                      (d) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(
                            d.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${mealSlots[d.slot]} · ${d.ingredients.join(', ')}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _use(dish: d),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Column(
                  key: tutorialSectionKeys[5][1],
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Lịch sử sử dụng gần đây',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (history.isEmpty)
                      const Text('Chưa có lần sử dụng nào được ghi nhận.'),
                    ...history
                        .take(15)
                        .map(
                          (e) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: const Icon(
                                Icons.outbox_outlined,
                                color: Color(0xFF079669),
                              ),
                              title: Text(
                                '${e.name} · −${usageAmount(e.quantity)} ${e.unit}',
                              ),
                              subtitle: Text(
                                '${e.metadata['actor_name'] ?? 'Thành viên'} · ${e.occurredAt.day}/${e.occurredAt.month} ${e.occurredAt.hour.toString().padLeft(2, '0')}:${e.occurredAt.minute.toString().padLeft(2, '0')}${e.metadata['recipe_name'] == null ? '' : '\n${e.metadata['recipe_name']}'}',
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

class _UsageSheet extends StatefulWidget {
  const _UsageSheet({
    required this.stock,
    required this.plan,
    required this.dish,
    required this.people,
  });
  final List<FoodSummary> stock;
  final UsagePlan plan;
  final PlannedDish? dish;
  final int people;
  @override
  State<_UsageSheet> createState() => _UsageSheetState();
}

class _UsageSheetState extends State<_UsageSheet> {
  final form = GlobalKey<FormState>();
  final amounts = <String, TextEditingController>{};
  final selected = <String>{};
  final operation = newLocalId();
  bool busy = false, attempted = false;
  bool showOtherIngredients = false;
  String query = '';
  String? error;
  late final stock = widget.stock
      .where(
        (f) =>
            f.quantity > 0 &&
            (f.expiry == null ||
                !menuDay(f.expiry!).isBefore(menuDay(DateTime.now()))),
      )
      .toList();
  @override
  void initState() {
    super.initState();
    for (final food in stock) {
      final use = widget.plan.uses
          .where((u) => u.food.id == food.id)
          .firstOrNull;
      amounts[food.id] = TextEditingController(
        text: use == null || use.quantity <= 0 ? '' : usageAmount(use.quantity),
      );
      if (use != null) selected.add(food.id);
    }
  }

  List<FoodSummary> get recipeStock =>
      stock.where((f) => widget.plan.recipeLotIds.contains(f.id)).toList();
  List<FoodSummary> get otherStock =>
      stock.where((f) => !widget.plan.recipeLotIds.contains(f.id)).toList();
  List<FoodSummary> get visibleOtherStock => otherStock
      .where(
        (f) =>
            showOtherIngredients || query.isNotEmpty || selected.contains(f.id),
      )
      .toList();
  List<FoodSummary> get orderedStock =>
      widget.dish == null ? stock : [...recipeStock, ...visibleOtherStock];

  @override
  void dispose() {
    for (final c in amounts.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (selected.isEmpty) return;
    // Validate controllers too: off-screen rows may not have mounted FormFields.
    for (final food in stock.where((f) => selected.contains(f.id))) {
      final amount = double.tryParse(
        amounts[food.id]!.text.replaceAll(',', '.'),
      );
      if (amount == null ||
          !amount.isFinite ||
          amount < .001 ||
          amount > food.quantity ||
          (amount * 1000 - (amount * 1000).round()).abs() > .00001) {
        setState(
          () => error =
              '${food.name}: nhập lượng từ 0.001 đến ${usageAmount(food.quantity)} ${food.unit}, tối đa 3 số thập phân.',
        );
        form.currentState!.validate();
        return;
      }
    }
    if (!form.currentState!.validate()) return;
    final uses = stock
        .where((f) => selected.contains(f.id))
        .map(
          (f) => InventoryUsage(
            food: f,
            quantity: double.parse(amounts[f.id]!.text.replaceAll(',', '.')),
          ),
        )
        .toList();
    setState(() {
      busy = true;
      attempted = true;
      error = null;
    });
    try {
      await confirmInventoryUsage(
        uses,
        operationId: operation,
        dishName: widget.dish?.name,
        people: widget.people,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Chưa nhận được xác nhận. Kiểm tra mạng/tồn kho và thử lại với cùng yêu cầu; hệ thống không trừ trùng khi gửi lại.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .82,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.dish?.name ?? 'Xuất thủ công',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Text(
                'Bỏ tick món không dùng hoặc sửa lượng. Bấm xác nhận xuất sẽ trừ đúng các nguyên liệu đã tick.',
                style: TextStyle(fontSize: 12, color: Colors.blueGrey),
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Tìm nguyên liệu trong tủ…',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => query = usageIngredientKey(v)),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Form(
                  key: form,
                  child: ListView(
                    children: [
                      if (widget.dish != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            'Nguyên liệu của món · ${widget.people} người',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                              color: Color(0xFF253043),
                            ),
                          ),
                        ),
                      if (widget.dish != null)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Định lượng theo món là gợi ý. Hãy sửa theo lượng thực tế đã dùng.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      if (widget.plan.missing.isNotEmpty)
                        Card(
                          color: const Color(0xFFFFF5DF),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              'Không trừ phần thiếu:\n${widget.plan.missing.join('\n')}',
                            ),
                          ),
                        ),
                      if (stock.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: Text(
                            'Chưa có thực phẩm còn hạn trong tủ. Nhập thực phẩm trước khi xuất.',
                          ),
                        ),
                      for (final food in orderedStock) ...[
                        if (widget.dish != null &&
                            food.id == visibleOtherStock.firstOrNull?.id)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'Nguyên liệu dùng thêm',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                                color: Color(0xFF253043),
                              ),
                            ),
                          ),
                        Offstage(
                          offstage: !usageIngredientKey(
                            food.name,
                          ).contains(query),
                          child: Card(
                            color: selected.contains(food.id)
                                ? const Color(0xFFF0FAF6)
                                : Colors.white,
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CheckboxListTile(
                                    key: ValueKey('usage-lot-${food.id}'),
                                    contentPadding: EdgeInsets.zero,
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    value: selected.contains(food.id),
                                    onChanged: attempted
                                        ? null
                                        : (v) => setState(() {
                                            if (v == true) {
                                              selected.add(food.id);
                                            } else {
                                              selected.remove(food.id);
                                            }
                                          }),
                                    title: Text(
                                      food.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'Còn ${usageAmount(food.quantity)} ${food.unit}${food.expiry == null ? '' : ' · HSD ${food.expiry!.day}/${food.expiry!.month}/${food.expiry!.year}'}',
                                    ),
                                  ),
                                  if (selected.contains(food.id))
                                    if (widget.plan.notes.containsKey(food.id))
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 10,
                                        ),
                                        child: Text(
                                          widget.plan.notes[food.id]!,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.blueGrey,
                                          ),
                                        ),
                                      ),
                                  if (selected.contains(food.id))
                                    TextFormField(
                                      key: ValueKey('usage-amount-${food.id}'),
                                      controller: amounts[food.id],
                                      enabled: !attempted,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      decoration: InputDecoration(
                                        labelText: 'Đã dùng (${food.unit})',
                                        border: const OutlineInputBorder(),
                                      ),
                                      onChanged: (_) => setState(() {}),
                                      validator: (v) {
                                        final n = double.tryParse(
                                          v?.replaceAll(',', '.') ?? '',
                                        );
                                        if (n == null ||
                                            !n.isFinite ||
                                            n < .001 ||
                                            n > food.quantity ||
                                            (n * 1000 - (n * 1000).round())
                                                    .abs() >
                                                .00001) {
                                          return 'Lượng từ 0.001 đến ${usageAmount(food.quantity)}, tối đa 3 số thập phân';
                                        }
                                        return null;
                                      },
                                    ),
                                  if (selected.contains(food.id))
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        'Sau khi xuất: ${usageAmount((food.quantity - (double.tryParse(amounts[food.id]!.text.replaceAll(',', '.')) ?? 0)).clamp(0, food.quantity))} ${food.unit}',
                                        style: const TextStyle(
                                          color: Color(0xFF079669),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (widget.dish != null && otherStock.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: OutlinedButton.icon(
                            onPressed: attempted
                                ? null
                                : () => setState(
                                    () => showOtherIngredients =
                                        !showOtherIngredients,
                                  ),
                            icon: Icon(
                              showOtherIngredients
                                  ? Icons.expand_less
                                  : Icons.add,
                            ),
                            label: Text(
                              showOtherIngredients
                                  ? 'Thu gọn nguyên liệu khác'
                                  : 'Dùng thêm nguyên liệu khác (${otherStock.length})',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    error!,
                    style: const TextStyle(
                      color: Colors.deepOrange,
                      fontSize: 12,
                    ),
                  ),
                ),
              FilledButton.icon(
                onPressed: busy || selected.isEmpty ? null : _save,
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.outbox_outlined),
                label: Text(
                  attempted
                      ? 'Thử lại xác nhận'
                      : 'Xác nhận xuất (${selected.length})',
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    ),
  );
}
