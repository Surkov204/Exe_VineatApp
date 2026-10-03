import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'diet_preferences.dart';
import 'food_notification.dart';
import 'inventory_store.dart';
import 'meal_plan.dart';
import 'recipe_detail.dart';
import 'menu_shopping_sheet.dart';
import 'custom_dish_editor.dart';

class MealPlanScreen extends StatefulWidget {
  const MealPlanScreen({super.key, required this.catalog, this.onOpenShopping});
  final List<RecipeCatalogItem> catalog;
  final void Function(DateTime? day, DateTime week)? onOpenShopping;
  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends State<MealPlanScreen> {
  DateTime selected = menuDay(DateTime.now());
  late WeekMenuStore store;
  List<PlannedDish> items = [];
  bool weekly = false, busy = true, loaded = false;
  String? error;
  int people = 1;
  @override
  void initState() {
    super.initState();
    store = WeekMenuStore(menuWeek(selected));
    _load();
  }

  Future<void> _load() async {
    setState(() {
      busy = true;
      error = null;
      loaded = false;
    });
    try {
      final rows = await store.load();
      final count = await store.plannedPeople(selected);
      if (mounted) {
        setState(() {
          items = rows;
          people = count;
          loaded = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Chưa tải được thực đơn. Kiểm tra kết nối rồi tải lại.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _save(List<PlannedDish> next) async {
    setState(() => busy = true);
    try {
      await store.save(next);
      await store.savePeople(people, day: weekly ? null : selected);
      if (mounted) setState(() => items = next);
    } catch (e) {
      if (mounted) {
        showFoodNotification(
          context,
          success: false,
          title: 'Chưa lưu thực đơn',
          message: e is PostgrestException && e.code == '40001'
              ? 'Người khác đã sửa thực đơn. Bấm tải lại trước khi chỉnh tiếp.'
              : 'Thực đơn cũ vẫn được giữ. Kiểm tra kết nối rồi thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _generate() async {
    final dates = weekly
        ? List.generate(7, (i) => store.week.add(Duration(days: i)))
        : [selected];
    final replace = items.any((e) => dates.contains(e.date));
    if (replace) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Tạo lại thực đơn?'),
          content: Text(
            'Các món trong ${weekly ? 'tuần này' : 'ngày đang chọn'} sẽ được thay bằng gợi ý mới.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Giữ lại'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Tạo lại'),
            ),
          ],
        ),
      );
      if (yes != true || !mounted) return;
    }
    final suggested = suggestMenu(
      widget.catalog,
      preferredDiet.value,
      weekly ? store.week : selected,
      weekly ? 7 : 1,
    );
    if (suggested.isEmpty) {
      if (mounted) {
        showFoodNotification(
          context,
          success: false,
          title: 'Chưa có công thức phù hợp',
          message: 'Bạn có thể thêm món thủ công vào từng bữa.',
        );
      }
      return;
    }
    await _save([...items.where((e) => !dates.contains(e.date)), ...suggested]);
  }

  Future<void> _add(DateTime day, String slot) async {
    final suitable = widget.catalog
        .where(
          (r) =>
              preferredDiet.value == DietKind.normal ||
              r.diets.contains(preferredDiet.value),
        )
        .toList();
    final dish = await showModalBottomSheet<PlannedDish>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          16 + MediaQuery.viewInsetsOf(c).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(c).height * .65,
          child: ListView(
            children: [
              Text(
                'Thêm món · ${mealSlots[slot]}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.edit_note),
                label: const Text('Món tự nhập · chọn nguyên liệu'),
                onPressed: () async {
                  final custom = await showCustomDishEditor(
                    c,
                    day: day,
                    slot: slot,
                    people: people,
                    stock: inventoryFoods,
                  );
                  if (custom != null && c.mounted) Navigator.pop(c, custom);
                },
              ),
              Text('Công thức phù hợp: ${preferredDiet.value.label}'),
              ...suitable.map(
                (r) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.restaurant_outlined,
                    color: Color(0xFF079669),
                  ),
                  title: Text(r.name),
                  subtitle: Text(r.timeLabel),
                  trailing: const Icon(Icons.add_circle_outline),
                  onTap: () => Navigator.pop(
                    c,
                    PlannedDish(
                      date: day,
                      slot: slot,
                      name: r.name,
                      recipeKey: r.id,
                      ingredients: r.ingredients,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (dish != null && mounted) await _save([...items, dish]);
  }

  List<PlannedDish> get visible =>
      items.where((e) => weekly || e.date == selected).toList();
  Future<void> _shopping() async {
    final scopeDay = weekly ? null : selected;
    final selection = await showMenuShoppingSheet(
      context,
      dishes: menuShoppingDishes(items, selected, weekly),
      stock: inventoryFoods,
      people: people,
      weekly: weekly,
      day: selected,
    );
    if (selection == null || !mounted) return;
    setState(() {
      busy = true;
      people = selection.people;
    });
    try {
      await store.confirmPurchases(selection.lines, day: scopeDay);
      await store.savePeople(people, day: scopeDay);
      if (!mounted) return;
      showFoodNotification(
        context,
        title: 'Đã chốt danh sách đi chợ',
        message:
            '${selection.lines.length} nguyên liệu · ${scopeDay == null ? 'cả tuần' : 'ngày ${scopeDay.day}/${scopeDay.month}'}',
      );
      widget.onOpenShopping?.call(scopeDay, store.week);
    } catch (_) {
      if (mounted) {
        showFoodNotification(
          context,
          success: false,
          title: 'Chưa chốt được thực đơn',
          message:
              'Kiểm tra kết nối; nếu gia đình vừa sửa menu, tải lại rồi chốt.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _dayCard(DateTime day) => Card(
    color: Colors.white,
    margin: const EdgeInsets.only(bottom: 14),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${day.weekday == 7 ? 'Chủ nhật' : 'Thứ ${day.weekday + 1}'} · ${day.day}/${day.month}',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 8),
          for (final slot in mealSlots.entries) ...[
            Row(
              children: [
                Icon(
                  slot.key == 'breakfast'
                      ? Icons.wb_sunny_outlined
                      : slot.key == 'lunch'
                      ? Icons.light_mode_outlined
                      : Icons.nights_stay_outlined,
                  size: 20,
                  color: const Color(0xFF079669),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    slot.value,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Thêm món ${slot.value.toLowerCase()}',
                  onPressed: busy || !loaded ? null : () => _add(day, slot.key),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            if (!items.any((e) => e.date == day && e.slot == slot.key))
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Chưa có món · bấm + để thêm',
                  style: TextStyle(color: Colors.blueGrey, fontSize: 12),
                ),
              ),
            ...items
                .where((e) => e.date == day && e.slot == slot.key)
                .map(
                  (dish) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FAF6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Material(
                      color: const Color(0xFFF0FAF6),
                      borderRadius: BorderRadius.circular(12),
                      child: ListTile(
                        title: Text(
                          dish.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          dish.recipeKey == null
                              ? 'Món tự nhập · $people người\n${dish.amounts.isEmpty ? dish.ingredients.join(', ') : dish.amounts.map((i) => '${i.name}: ${i.forPeople(people).toStringAsFixed(2).replaceFirst(RegExp(r"\.?0+$"), "")} ${i.unit}').join('\n')}'
                              : 'Công thức có sẵn',
                        ),
                        onTap: () {
                          final matches = widget.catalog.where(
                            (r) => r.id == dish.recipeKey,
                          );
                          if (matches.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RecipeDetailScreen(
                                  recipe: matches.first.toDetailData(),
                                ),
                              ),
                            );
                          }
                        },
                        trailing: IconButton(
                          tooltip: 'Xóa ${dish.name} khỏi thực đơn',
                          onPressed: busy
                              ? null
                              : () => _save(
                                  items
                                      .where((e) => !identical(e, dish))
                                      .toList(),
                                ),
                          icon: const Icon(Icons.close, size: 20),
                        ),
                      ),
                    ),
                  ),
                ),
            if (slot.key != 'dinner') const Divider(),
          ],
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF5F9F7),
    appBar: AppBar(
      title: const Text('Thực đơn gia đình'),
      actions: [
        IconButton(
          tooltip: 'Tải lại thực đơn',
          onPressed: busy ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ValueListenableBuilder<DietKind>(
          valueListenable: preferredDiet,
          builder: (c, diet, _) => Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F7ED),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Lên kế hoạch, đi chợ gọn hơn',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text('Gợi ý theo bạn: ${diet.label}'),
                const SizedBox(height: 6),
                const Text(
                  'Sáng ăn nhẹ · Trưa/tối: món chính, món rau/chay và món canh.',
                  style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Số người ăn',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              onPressed: busy || people <= 1
                  ? null
                  : () => setState(() => people--),
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text('$people người'),
            IconButton(
              onPressed: busy || people >= 30
                  ? null
                  : () => setState(() => people++),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
              value: false,
              label: Text('Theo ngày'),
              icon: Icon(Icons.today),
            ),
            ButtonSegment(
              value: true,
              label: Text('Theo tuần'),
              icon: Icon(Icons.date_range),
            ),
          ],
          selected: {weekly},
          onSelectionChanged: (v) => setState(() => weekly = v.first),
        ),
        Row(
          children: [
            IconButton(
              tooltip: 'Tuần trước',
              onPressed: busy
                  ? null
                  : () {
                      selected = selected.subtract(const Duration(days: 7));
                      store = WeekMenuStore(menuWeek(selected));
                      _load();
                    },
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Center(
                child: Text(
                  '${store.week.day}/${store.week.month} – ${store.week.add(const Duration(days: 6)).day}/${store.week.add(const Duration(days: 6)).month}/${store.week.year}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Tuần sau',
              onPressed: busy
                  ? null
                  : () {
                      selected = selected.add(const Duration(days: 7));
                      store = WeekMenuStore(menuWeek(selected));
                      _load();
                    },
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        if (!weekly)
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: List.generate(7, (i) {
                final day = store.week.add(Duration(days: i));
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(
                      '${day.weekday == 7 ? 'CN' : 'T${day.weekday + 1}'} ${day.day}',
                    ),
                    selected: day == selected,
                    onSelected: busy
                        ? null
                        : (_) => setState(() => selected = day),
                  ),
                );
              }),
            ),
          ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: busy || !loaded ? null : _generate,
              icon: const Icon(Icons.auto_awesome),
              label: Text('Gợi ý ${weekly ? '7 ngày' : '3 bữa'}'),
            ),
            OutlinedButton.icon(
              onPressed: busy || !loaded || visible.isEmpty ? null : _shopping,
              icon: const Icon(Icons.shopping_basket_outlined),
              label: const Text('Chốt & đi chợ'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (busy) const LinearProgressIndicator(),
        if (error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              error!,
              style: const TextStyle(color: Colors.deepOrange),
            ),
          ),
        if (loaded)
          ...List.generate(
            weekly ? 7 : 1,
            (i) =>
                _dayCard(weekly ? store.week.add(Duration(days: i)) : selected),
          ),
      ],
    ),
  );
}
