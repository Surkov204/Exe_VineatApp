import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'app_services.dart';
import 'app_tutorial.dart';
import 'diet_preferences.dart';
import 'food_detail.dart';
import 'food_form_widgets.dart';
import 'food_templates.dart';
import 'expiry_assistant.dart';
import 'food_notification.dart';
import 'inventory_activity_screen.dart';
import 'food_image.dart';
import 'fridge_showcase.dart';
import 'global_search.dart';
import 'household_data_repository.dart';
import 'inventory_store.dart';
import 'profile_screen.dart';
import 'receipt_models.dart';
import 'receipt_ocr_service.dart';
import 'recipe_detail.dart';
import 'meal_plan_screen.dart';
import 'menu_ingredients.dart';
import 'shopping_menu_sheet.dart';
import 'vineat_logo.dart';

export 'reports_screen.dart' show ReportsScreen;

const _green = Color(0xFF079669);
const _ink = Color(0xFF253043);
const _muted = Color(0xFF98A2B3);
const _assetRoot = 'design_reference/home/page_files/';

String _shortDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/${date.year}';

class BrandHeader extends StatelessWidget {
  const BrandHeader({
    super.key,
    this.title,
    this.subtitle,
    this.search = false,
    this.onTutorial,
  });
  final String? title;
  final String? subtitle;
  final bool search;
  final VoidCallback? onTutorial;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.paddingOf(context).top + 12,
        16,
        12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final showSearch = search && constraints.maxWidth >= 270;
              return Row(
                children: [
                  const VineatLogo(width: 34, symbolOnly: true),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: const Text(
                          'ViNeat',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: _ink,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (showSearch)
                    IconButton.filledTonal(
                      onPressed: () => showGlobalSearch(context),
                      icon: const Icon(Icons.search),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFF3F4F6),
                      ),
                    ),
                  if (showSearch) const SizedBox(width: 4),
                  if (onTutorial != null)
                    IconButton(
                      tooltip: 'Xem lại hướng dẫn',
                      onPressed: onTutorial,
                      icon: const Icon(Icons.help_outline_rounded),
                      color: _green,
                    ),
                  if (constraints.maxWidth >= 220)
                    IconButton.filledTonal(
                      tooltip: 'Mở hồ sơ',
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ProfileScreen(),
                        ),
                      ),
                      icon: const Icon(Icons.person_outline),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFD9FAEA),
                        foregroundColor: _green,
                      ),
                    ),
                ],
              );
            },
          ),
          if (title != null) ...[
            const SizedBox(height: 13),
            Text(
              title!,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: const TextStyle(fontSize: 12, color: _muted),
              ),
          ],
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(
    this.title, {
    super.key,
    this.trailing,
    this.onTrailingTap,
  });
  final String title;
  final String? trailing;
  final VoidCallback? onTrailingTap;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
      ),
      if (trailing != null)
        InkWell(
          onTap: onTrailingTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            child: Text(
              trailing!,
              style: const TextStyle(
                fontSize: 12,
                color: _green,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
    ],
  );
}

class FridgeScreen extends StatefulWidget {
  const FridgeScreen({super.key});

  @override
  State<FridgeScreen> createState() => _FridgeScreenState();
}

class _FridgeScreenState extends State<FridgeScreen>
    with WidgetsBindingObserver {
  bool _showOnlyAttention = false;
  bool _addingFood = false;
  final _inventorySectionKey = GlobalKey();
  int _handledAddRequest = 0;
  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  void _openInventory() {
    Navigator.of(context).push(_inventoryRoute(context));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _handledAddRequest = homeAddFoodRequest.value;
    homeAddFoodRequest.addListener(_handleHomeAddRequest);
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  void _handleHomeAddRequest() {
    final request = homeAddFoodRequest.value;
    if (request == _handledAddRequest || activeAppTabIndex.value != 0) return;
    _handledAddRequest = request;
    unawaited(_addFood());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    homeAddFoodRequest.removeListener(_handleHomeAddRequest);
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() => _now = DateTime.now());
    }
  }

  Future<void> _addFood() async {
    if (_addingFood) return;
    _addingFood = true;
    try {
      final method = await showModalBottomSheet<AddFoodMethod>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => const _AddFoodMethodSheet(),
      );
      if (!mounted || method == null) return;
      if (method != AddFoodMethod.manual) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              appBar: AppBar(
                title: Text(
                  method == AddFoodMethod.scan
                      ? 'Scan hóa đơn'
                      : method == AddFoodMethod.ai
                      ? 'AI đọc hóa đơn'
                      : 'Template thực phẩm',
                ),
              ),
              body: SafeArea(child: ScanScreen(initialMethod: method)),
            ),
          ),
        );
        return;
      }
      final food = await showDialog<FoodSummary>(
        context: context,
        barrierColor: Colors.black54,
        builder: (_) => const _AddFoodDialog(),
      );
      if (food == null || !mounted) return;
      final saved = await addFoodsToInventory([food]);
      if (!mounted) return;
      showFoodNotification(
        context,
        success: saved,
        title: saved ? 'Đã thêm thực phẩm' : 'Chưa lưu lên cloud',
        message: saved
            ? '${food.name} · ${AppServices.configured ? 'Đã đồng bộ với gia đình' : 'Đã lưu trên thiết bị'}'
            : '${food.name} đang chờ đồng bộ. Bấm Thử lại ở thông báo phía trên.',
      );
    } finally {
      _addingFood = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    const dayNames = [
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
      'Chủ Nhật',
    ];
    final now = _now;
    final today =
        '${dayNames[now.weekday - 1]}, ${now.day} tháng ${now.month} năm ${now.year} · ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    return ValueListenableBuilder<int>(
      valueListenable: inventoryRevision,
      builder: (_, _, _) {
        final expiredCount = inventoryFoods
            .where((food) => food.status == 'Hết hạn')
            .length;
        final warningCount = inventoryFoods
            .where((food) => food.status.contains('Còn'))
            .length;
        final freshCount = inventoryFoods.length - expiredCount - warningCount;
        int priceOf(FoodSummary food) => food.priceVnd;

        String vnd(int value) =>
            '${value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')}đ';
        final totalValue = inventoryFoods.fold<int>(
          0,
          (sum, food) => sum + priceOf(food),
        );
        final expiredValue = inventoryFoods
            .where((food) => food.status == 'Hết hạn')
            .fold<int>(0, (sum, food) => sum + priceOf(food));
        final wasteRatio = totalValue == 0 ? 0.0 : expiredValue / totalValue;
        final displayedFoods = _showOnlyAttention
            ? inventoryFoods
                  .where((food) => food.status != 'Tươi ngon')
                  .toList()
            : inventoryFoods;
        return Column(
          children: [
            BrandHeader(
              title: 'Tủ lạnh của bạn',
              subtitle: today,
              search: true,
              onTutorial: () => replayAppTutorialRequest.value++,
            ),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        ValueListenableBuilder<int>(
                          valueListenable: activeAppTabIndex,
                          builder: (context, activeTab, _) =>
                              SmartFridgeShowcase(
                                key: tutorialSectionKeys[0][0],
                                active: activeTab == 0,
                                inventoryCount: inventoryFoods.length,
                                expiringCount: warningCount,
                                freshCount: freshCount,
                                expiredCount: expiredCount,
                                statisticsKey: tutorialSectionKeys[0][1],
                                height:
                                    MediaQuery.textScalerOf(context).scale(1) >
                                        1.25
                                    ? 160
                                    : 140,
                                onInventoryTap: _openInventory,
                                onExpiringTap: () =>
                                    setState(() => _showOnlyAttention = true),
                              ),
                        ),
                        const SizedBox(height: 12),
                        Card(
                          key: tutorialSectionKeys[0][2],
                          child: Padding(
                            padding: const EdgeInsets.all(13),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.timer_outlined,
                                      color: Colors.redAccent,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    const Expanded(
                                      child: Text(
                                        'Cảnh báo hết hạn',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.redAccent,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        '${warningCount + expiredCount} cần ưu tiên',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: _muted,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    const Icon(
                                      Icons.swipe_left_alt_outlined,
                                      size: 17,
                                      color: _muted,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                SingleChildScrollView(
                                  key: const ValueKey('expiry-alerts-scroll'),
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: inventoryFoods
                                        .where(
                                          (food) => food.status != 'Tươi ngon',
                                        )
                                        .map(
                                          (food) => Padding(
                                            padding: const EdgeInsets.only(
                                              right: 7,
                                            ),
                                            child: _AlertChip(
                                              food.name,
                                              food.status == 'Hết hạn',
                                              onTap: () => _openInventoryFood(
                                                context,
                                                food,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          key: _inventorySectionKey,
                          children: [
                            Expanded(
                              child: SectionTitle(
                                _showOnlyAttention
                                    ? 'Món cần ưu tiên'
                                    : 'Thực phẩm trong tủ',
                                trailing: _showOnlyAttention
                                    ? null
                                    : 'Xem tất cả',
                                onTrailingTap: _openInventory,
                              ),
                            ),
                            if (_showOnlyAttention)
                              TextButton(
                                onPressed: () =>
                                    setState(() => _showOnlyAttention = false),
                                child: const Text('Bỏ lọc'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (displayedFoods.isEmpty)
                          const Card(
                            child: Padding(
                              padding: EdgeInsets.all(18),
                              child: Text('Hiện chưa có món nào cần ưu tiên.'),
                            ),
                          ),
                      ]),
                    ),
                  ),
                  if (displayedFoods.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final f = displayedFoods[index];
                          return _FoodTile(
                            summary: f,
                            name: f.name,
                            detail: f.detail,
                            status: f.status,
                            image: f.imageIndex,
                            onDeleted: () => removeFoodFromInventory(f),
                            onUpdated: (food) => updateFoodInInventory(
                              f,
                              FoodSummary.fromLegacy(
                                id: f.id,
                                name: food.name,
                                detail: '${food.quantity} · ${food.price}',
                                status: food.status,
                                imageIndex: food.image,
                                imagePath: f.imagePath,
                                note: food.note,
                                expiryDate: food.expiryValue ?? f.expiry,
                              ),
                            ),
                          );
                        }, childCount: displayedFoods.length.clamp(0, 10)),
                      ),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.all(14),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        const SizedBox(height: 14),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(15),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tổng giá trị tủ lạnh',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: _ink,
                                  ),
                                ),
                                SizedBox(height: 5),
                                Text(
                                  vnd(totalValue),
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: _ink,
                                  ),
                                ),
                                SizedBox(height: 9),
                                LinearProgressIndicator(
                                  value: wasteRatio,
                                  color: Colors.redAccent,
                                  backgroundColor: Color(0xFFF2F4F7),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  '${vnd(expiredValue)} thực phẩm đã hết hạn',
                                  style: TextStyle(fontSize: 11, color: _muted),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 90),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

enum AddFoodMethod { scan, ai, template, manual }

class _AddFoodMethodSheet extends StatelessWidget {
  const _AddFoodMethodSheet();
  @override
  Widget build(BuildContext context) => SafeArea(
    child: FractionallySizedBox(
      widthFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .8,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Thêm thực phẩm',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Bạn muốn thêm món bằng cách nào?',
                style: TextStyle(color: _muted, fontSize: 13),
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, bounds) {
                  final columns =
                      MediaQuery.textScalerOf(context).scale(1) > 1.3 ? 1 : 2;
                  final width =
                      (bounds.maxWidth - (columns - 1) * 12) / columns;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _method(
                        context,
                        width,
                        AddFoodMethod.scan,
                        Icons.document_scanner_outlined,
                        'Scan',
                        'Chụp hóa đơn bằng camera',
                        const Color(0xFFE4F7EE),
                        _green,
                      ),
                      _method(
                        context,
                        width,
                        AddFoodMethod.ai,
                        Icons.auto_awesome_outlined,
                        'AI',
                        'Đọc thực phẩm từ ảnh hóa đơn',
                        const Color(0xFFF1EBFF),
                        const Color(0xFF7953BA),
                      ),
                      _method(
                        context,
                        width,
                        AddFoodMethod.template,
                        Icons.dashboard_customize_outlined,
                        'Template',
                        'Chọn bộ thực phẩm có sẵn',
                        const Color(0xFFEDF3FF),
                        const Color(0xFF3459A5),
                      ),
                      _method(
                        context,
                        width,
                        AddFoodMethod.manual,
                        Icons.edit_note_rounded,
                        'Thủ công',
                        'Tự nhập tên, lượng và giá tiền',
                        const Color(0xFFFFF4D8),
                        const Color(0xFF9A5A00),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _method(
    BuildContext context,
    double width,
    AddFoodMethod method,
    IconData icon,
    String label,
    String description,
    Color background,
    Color color,
  ) => SizedBox(
    width: width,
    child: Material(
      color: background,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        key: ValueKey('add-method-${method.name}'),
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.pop(context, method),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 30, color: color),
              const SizedBox(height: 14),
              Text(
                label,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                description,
                style: const TextStyle(fontSize: 12, color: _ink),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _AddFoodDialog extends StatefulWidget {
  const _AddFoodDialog();

  @override
  State<_AddFoodDialog> createState() => _AddFoodDialogState();
}

class _AddFoodDialogState extends State<_AddFoodDialog> {
  final name = TextEditingController();
  final quantity = TextEditingController(text: '1');
  final price = TextEditingController();
  final note = TextEditingController();
  String category = 'Rau củ';
  String? unit;
  DateTime purchaseDate = DateTime.now();
  DateTime? expiryDate;
  bool submitted = false;
  bool savingImage = false;
  XFile? selectedImage;
  final imagePicker = ImagePicker();

  @override
  void dispose() {
    name.dispose();
    quantity.dispose();
    price.dispose();
    note.dispose();
    super.dispose();
  }

  String _date(DateTime? value) {
    if (value == null) return 'dd/mm/yyyy';
    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/${value.year}';
  }

  Future<void> _pickDate({required bool expiry}) async {
    final chosen = await showDatePicker(
      context: context,
      initialDate: expiry
          ? (expiryDate ?? DateTime.now().add(const Duration(days: 3)))
          : purchaseDate,
      firstDate: expiry ? purchaseDate : DateTime(2020),
      lastDate: DateTime(2035),
      helpText: expiry ? 'Chọn hạn sử dụng' : 'Chọn ngày mua',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
      builder: foodDatePickerTheme,
    );
    if (chosen == null) return;
    setState(() {
      if (expiry) {
        expiryDate = chosen;
      } else {
        purchaseDate = chosen;
        if (expiryDate != null && expiryDate!.isBefore(chosen)) {
          expiryDate = null;
        }
      }
    });
  }

  Future<void> _pickFoodImage(ImageSource source) async {
    try {
      final image = await imagePicker.pickImage(
        source: source,
        imageQuality: 82,
        maxWidth: 1400,
      );
      if (image != null && mounted) setState(() => selectedImage = image);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Không thể mở ảnh trên thiết bị này',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
  }

  Future<String?> _saveSelectedImage() async {
    final image = selectedImage;
    if (image == null) return null;
    try {
      final root = await getApplicationDocumentsDirectory();
      final folder = Directory(
        '${root.path}${Platform.pathSeparator}food_images',
      );
      await folder.create(recursive: true);
      final target =
          '${folder.path}${Platform.pathSeparator}'
          'food_${DateTime.now().microsecondsSinceEpoch}.jpg';
      return (await File(image.path).copy(target)).path;
    } catch (_) {
      return image.path;
    }
  }

  Future<void> _submit() async {
    setState(() => submitted = true);
    if (name.text.trim().isEmpty ||
        quantity.text.trim().isEmpty ||
        unit == null ||
        expiryDate == null) {
      return;
    }
    setState(() => savingImage = true);
    final imagePath = await _saveSelectedImage();
    if (!mounted) return;
    final rawPrice = price.text.replaceAll(RegExp(r'[^0-9]'), '');
    final displayPrice = rawPrice.isEmpty ? '0đ' : '${_money(rawPrice)}đ';
    final days = expiryDate!.difference(DateTime.now()).inDays;
    final status = days < 0
        ? 'Hết hạn'
        : days <= 3
        ? 'Còn ${days < 1 ? 1 : days} ngày'
        : 'Tươi ngon';
    final image = switch (category) {
      'Rau củ' => 5,
      'Thịt cá' => 2,
      'Đồ khô' => 6,
      'Đồ uống' => 8,
      _ => 0,
    };
    final foodName = name.text.trim();
    Navigator.pop<FoodSummary>(
      context,
      FoodSummary.fromLegacy(
        name: foodName,
        detail: '${quantity.text.trim()} $unit · $displayPrice',
        status: status,
        imageIndex: image,
        expiryDate: expiryDate,
        imagePath: imagePath,
        note: note.text.trim(),
      ).copyWith(audit: InventoryAudit(purchaseDate: purchaseDate)),
    );
  }

  String _money(String value) =>
      value.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');

  InputDecoration _decoration(
    String label, {
    String? hint,
    bool required = false,
  }) {
    return InputDecoration(
      label: Text.rich(
        TextSpan(
          text: label,
          children: required
              ? const [
                  TextSpan(
                    text: ' *',
                    style: TextStyle(color: Colors.red),
                  ),
                ]
              : const [],
        ),
      ),
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF7FAF9),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(11)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final missingExpiry = submitted && expiryDate == null;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 740),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 10, 14),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Thêm thực phẩm mới',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: _ink,
                      ),
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    TextField(
                      controller: name,
                      decoration:
                          _decoration(
                            'Tên thực phẩm',
                            hint: 'VD: Thịt heo ba chỉ, Rau muống...',
                            required: true,
                          ).copyWith(
                            errorText: submitted && name.text.trim().isEmpty
                                ? 'Vui lòng nhập tên thực phẩm'
                                : null,
                          ),
                    ),
                    ExpiryAssistant(
                      name: name,
                      baseDate: purchaseDate,
                      expiry: expiryDate,
                      onChanged: (date) => setState(() => expiryDate = date),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Hình ảnh thực phẩm',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: _ink,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: double.infinity,
                              height: 150,
                              child: selectedImage == null
                                  ? Image.asset(
                                      '$_assetRoot${switch (category) {
                                        'Rau củ' => 'search-image(5)',
                                        'Thịt cá' => 'search-image(2)',
                                        'Đồ khô' => 'search-image(6)',
                                        'Đồ uống' => 'search-image(8)',
                                        _ => 'search-image',
                                      }}',
                                      fit: BoxFit.cover,
                                    )
                                  : Image.file(
                                      File(selectedImage!.path),
                                      fit: BoxFit.cover,
                                    ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      _pickFoodImage(ImageSource.gallery),
                                  icon: const Icon(
                                    Icons.photo_library_outlined,
                                  ),
                                  label: const Text('Chọn ảnh'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              IconButton.filledTonal(
                                onPressed: () =>
                                    _pickFoodImage(ImageSource.camera),
                                tooltip: 'Chụp ảnh',
                                icon: const Icon(Icons.photo_camera_outlined),
                              ),
                              if (selectedImage != null) ...[
                                const SizedBox(width: 6),
                                IconButton(
                                  onPressed: () =>
                                      setState(() => selectedImage = null),
                                  tooltip: 'Dùng ảnh mặc định',
                                  icon: const Icon(Icons.refresh),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    FoodChoiceField(
                      label: 'Danh mục',
                      value: category,
                      options: const [
                        'Rau củ',
                        'Thịt cá',
                        'Đồ khô',
                        'Đồ uống',
                        'Khác',
                      ],
                      onChanged: (value) => setState(() => category = value),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: quantity,
                            keyboardType: TextInputType.number,
                            decoration: _decoration('Số lượng', required: true)
                                .copyWith(
                                  errorText:
                                      submitted && quantity.text.trim().isEmpty
                                      ? 'Bắt buộc'
                                      : null,
                                ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FoodChoiceField(
                            label: 'Đơn vị',
                            value: unit,
                            options: const [
                              'gram',
                              'kg',
                              'quả',
                              'bó',
                              'cây',
                              'hộp',
                              'chai',
                              'miếng',
                            ],
                            errorText: submitted && unit == null
                                ? 'Bắt buộc'
                                : null,
                            onChanged: (value) => setState(() => unit = value),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _DateField(
                            label: 'Ngày mua',
                            value: _date(purchaseDate),
                            onTap: () => _pickDate(expiry: false),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DateField(
                            label: 'Hạn sử dụng *',
                            value: _date(expiryDate),
                            error: missingExpiry,
                            onTap: () => _pickDate(expiry: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: price,
                      keyboardType: TextInputType.number,
                      decoration: _decoration(
                        'Giá tiền (VNĐ)',
                        hint: 'VD: 15000',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: note,
                      maxLines: 3,
                      decoration: _decoration(
                        'Ghi chú',
                        hint: 'VD: Mua ở chợ sáng, để ngăn mát...',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFEAECF0))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      child: const Text('Hủy'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: savingImage ? null : _submit,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      child: savingImage
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Thêm vào tủ'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    this.error = false,
  });

  final String label, value;
  final VoidCallback onTap;
  final bool error;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(11),
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        errorText: error ? 'Bắt buộc' : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(11)),
        suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
      ),
      child: Text(
        value,
        style: TextStyle(color: value == 'dd/mm/yyyy' ? _muted : _ink),
      ),
    ),
  );
}

class _AlertChip extends StatelessWidget {
  const _AlertChip(this.text, this.expired, {this.onTap});
  final String text;
  final bool expired;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: expired ? const Color(0xFFFFEEEE) : const Color(0xFFFFF8E5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: expired ? const Color(0xFFFFCDD2) : const Color(0xFFFFE4A3),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: expired ? Colors.redAccent : const Color(0xFFE59B0B),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openInventoryFood(BuildContext context, FoodSummary food) async {
  final result = await Navigator.of(context).push<Object?>(
    MaterialPageRoute(
      builder: (_) =>
          FoodDetailScreen(food: FoodDetailData.fromInventory(food)),
    ),
  );
  if (result is FoodDetailData) {
    updateFoodInInventory(
      food,
      FoodSummary.fromLegacy(
        id: food.id,
        name: result.name,
        detail: '${result.quantity} · ${result.price}',
        status: result.status,
        imageIndex: result.image,
        imagePath: food.imagePath,
        note: result.note,
        expiryDate: result.expiryValue ?? food.expiry,
      ),
    );
  }
  if (result == FoodRemovalResult.consumed ||
      result == FoodRemovalResult.discarded) {
    markFoodConsumed(food, discarded: result == FoodRemovalResult.discarded);
  }
  if (result is FoodRemovalResult) removeFoodFromInventory(food);
}

class _FoodTile extends StatelessWidget {
  const _FoodTile({
    required this.summary,
    required this.name,
    required this.detail,
    required this.status,
    required this.image,
    required this.onDeleted,
    required this.onUpdated,
    this.expandedDetails = false,
  });
  final FoodSummary summary;
  final String name, detail, status;
  final int image;
  final VoidCallback onDeleted;
  final ValueChanged<FoodDetailData> onUpdated;
  final bool expandedDetails;
  @override
  Widget build(BuildContext context) {
    final warning = status.contains('Còn');
    final expired = status == 'Hết hạn';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          final original = summary;
          final result = await Navigator.of(context).push<Object?>(
            MaterialPageRoute(
              builder: (_) =>
                  FoodDetailScreen(food: FoodDetailData.fromInventory(summary)),
            ),
          );
          if (result is FoodDetailData) onUpdated(result);
          if (result == FoodRemovalResult.deleted) onDeleted();
          if (result == FoodRemovalResult.consumed) {
            markFoodConsumed(original);
            onDeleted();
          }
          if (result == FoodRemovalResult.discarded) {
            markFoodConsumed(original, discarded: true);
            onDeleted();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: expandedDetails
              ? _InventoryLotCard(summary)
              : Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: FoodImage(
                        name: name,
                        assetIndex: image,
                        imagePath: summary.imagePath,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: _ink,
                            ),
                          ),
                          const SizedBox(height: 3),
                          if (expandedDetails) ...[
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 14,
                              runSpacing: 8,
                              children: [
                                _InventoryField(
                                  [
                                        'kg',
                                        'g',
                                        'gram',
                                      ].contains(summary.unit.toLowerCase())
                                      ? 'Khối lượng'
                                      : 'Số lượng',
                                  '${summary.quantity == summary.quantity.roundToDouble() ? summary.quantity.toInt() : summary.quantity} ${summary.unit}',
                                ),
                                _InventoryField(
                                  'Giá tiền',
                                  _inventoryMoney(summary.priceVnd),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              summary.expiry == null
                                  ? 'Chưa có hạn dùng'
                                  : 'Hạn dùng: ${_shortDate(summary.expiry!)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: _muted,
                              ),
                            ),
                          ] else
                            Text(
                              detail,
                              style: const TextStyle(
                                fontSize: 10,
                                color: _muted,
                              ),
                            ),
                          const SizedBox(height: 7),
                          if (!expandedDetails)
                            Text(
                              summary.expiry == null
                                  ? 'Chưa có hạn dùng'
                                  : 'HSD ${_shortDate(summary.expiry!)}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: _muted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: expired
                            ? const Color(0xFFFFEEEE)
                            : warning
                            ? const Color(0xFFFFF7DE)
                            : const Color(0xFFE8FBF1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: expired
                              ? Colors.redAccent
                              : warning
                              ? Colors.amber.shade800
                              : const Color(0xFF22B573),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

String _inventoryMoney(int value) =>
    '${value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')}đ';

Route<void> _inventoryRoute(BuildContext context) => PageRouteBuilder<void>(
  pageBuilder: (_, _, _) => const InventoryScreen(),
  transitionDuration: MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 280),
  reverseTransitionDuration: const Duration(milliseconds: 200),
  transitionsBuilder: (_, animation, _, child) => FadeTransition(
    opacity: animation,
    child: SlideTransition(
      position: Tween(
        begin: const Offset(0, .035),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
      child: child,
    ),
  ),
);

class _InventoryLotCard extends StatelessWidget {
  const _InventoryLotCard(this.food);
  final FoodSummary food;
  @override
  Widget build(BuildContext context) {
    final warning = food.status.contains('Còn');
    final color = food.status == 'Hết hạn'
        ? Colors.redAccent
        : warning
        ? const Color(0xFF9A5A00)
        : _green;
    return Padding(
      padding: const EdgeInsets.all(5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FoodImage(
                  name: food.name,
                  assetIndex: food.imageIndex,
                  imagePath: food.imagePath,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      food.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      food.audit.purchaseDate == null
                          ? 'Ngày mua: Chưa ghi nhận'
                          : 'Ngày mua: ${_shortDate(food.audit.purchaseDate!)}',
                      key: ValueKey('inventory-date-${food.id}'),
                      style: const TextStyle(fontSize: 11, color: _muted),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: _muted),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F8F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _InventoryField(
                    'Còn lại',
                    '${food.quantity == food.quantity.roundToDouble() ? food.quantity.toInt() : food.quantity} ${food.unit}',
                  ),
                ),
                Expanded(
                  child: _InventoryField(
                    'Giá tiền',
                    _inventoryMoney(food.priceVnd),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Text(
                food.expiry == null
                    ? 'Chưa có hạn dùng'
                    : 'Hạn dùng: ${_shortDate(food.expiry!)}',
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '• ${food.status}',
                style: TextStyle(fontSize: 12, color: color),
              ),
            ],
          ),
          if (food.audit.addedBy.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Thêm bởi: ${foodPersonName(food.audit.addedBy)}',
              style: const TextStyle(fontSize: 11, color: _muted),
            ),
          ],
          if (food.audit.updatedBy.isNotEmpty)
            Text(
              'Cập nhật cuối: ${foodPersonName(food.audit.updatedBy)}',
              style: const TextStyle(fontSize: 11, color: _muted),
            ),
        ],
      ),
    );
  }
}

class _InventoryField extends StatelessWidget {
  const _InventoryField(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 10, color: _muted)),
      Text(
        value,
        style: const TextStyle(
          fontSize: 13,
          color: _ink,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

/// The household inventory stays live while searching or editing an item.
class _InventoryMetric extends StatelessWidget {
  const _InventoryMetric(
    this.icon,
    this.label,
    this.value,
    this.background,
    this.color, {
    required this.onTap,
    required this.selected,
  });
  final VoidCallback onTap;
  final bool selected;
  final IconData icon;
  final String label, value;
  final Color background, color;
  @override
  Widget build(BuildContext context) => Material(
    color: background,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 19, color: color),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontSize: 11, color: color)),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});
  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  String _query = '';
  int _mode = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF7FAF9),
    appBar: AppBar(
      toolbarHeight: MediaQuery.textScalerOf(context).scale(1) > 1.25 ? 96 : 72,
      actions: [
        IconButton(
          tooltip: 'Theo dõi thực phẩm',
          icon: const Icon(Icons.history_outlined),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const InventoryActivityScreen()),
          ),
        ),
      ],
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tất cả thực phẩm',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: _ink,
            ),
          ),
          SizedBox(height: 3),
          Text(
            'Quản lý tủ lạnh gia đình',
            style: TextStyle(fontSize: 11, color: _muted),
          ),
        ],
      ),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
    body: SafeArea(
      child: ValueListenableBuilder<int>(
        valueListenable: inventoryRevision,
        builder: (context, _, _) {
          final foods = inventoryFoods
              .where(
                (f) =>
                    f.name.toLowerCase().contains(_query.toLowerCase().trim()),
              )
              .where((f) => _mode != 2 || f.status.contains('Còn'))
              .toList();
          foods.sort(
            (a, b) => _mode == 1
                ? b.priceVnd.compareTo(a.priceVnd)
                : _mode == 2
                ? a.expiry!.compareTo(b.expiry!)
                : a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
          final value = inventoryFoods.fold<int>(
            0,
            (sum, f) => sum + f.priceVnd,
          );
          final expiring = inventoryFoods
              .where((food) => food.status.contains('Còn'))
              .length;
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutBuilder(
                        builder: (context, bounds) {
                          final columns =
                              bounds.maxWidth < 310 ||
                                  MediaQuery.textScalerOf(context).scale(1) >
                                      1.25
                              ? 2
                              : 3;
                          final width =
                              (bounds.maxWidth - (columns - 1) * 8) / columns;
                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              SizedBox(
                                width: width,
                                child: _InventoryMetric(
                                  Icons.kitchen_outlined,
                                  'Số món',
                                  '${inventoryFoods.length} món',
                                  const Color(0xFFE4F7EE),
                                  _green,
                                  selected: _mode == 0,
                                  onTap: () => setState(() => _mode = 0),
                                ),
                              ),
                              SizedBox(
                                width: width,
                                child: _InventoryMetric(
                                  Icons.account_balance_wallet_outlined,
                                  'Tổng giá trị',
                                  _inventoryMoney(value),
                                  const Color(0xFFEDF3FF),
                                  const Color(0xFF3459A5),
                                  selected: _mode == 1,
                                  onTap: () => setState(() => _mode = 1),
                                ),
                              ),
                              SizedBox(
                                width: width,
                                child: _InventoryMetric(
                                  Icons.timer_outlined,
                                  'Sắp hết hạn',
                                  '$expiring món',
                                  const Color(0xFFFFF4D8),
                                  const Color(0xFF9A5A00),
                                  selected: _mode == 2,
                                  onTap: () => setState(() => _mode = 2),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        onChanged: (value) => setState(() => _query = value),
                        decoration: const InputDecoration(
                          hintText: 'Tìm thực phẩm…',
                          prefixIcon: Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${foods.length} thực phẩm · ${_mode == 1
                            ? 'Giá trị cao → thấp'
                            : _mode == 2
                            ? 'Hạn dùng gần nhất trước'
                            : 'Tất cả · Theo tên'}',
                        style: const TextStyle(color: _muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              if (foods.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Không tìm thấy thực phẩm phù hợp.'),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final f = foods[index];
                      return _FoodTile(
                        summary: f,
                        name: f.name,
                        detail: f.detail,
                        status: f.status,
                        image: f.imageIndex,
                        expandedDetails: true,
                        onDeleted: () => removeFoodFromInventory(f),
                        onUpdated: (food) => updateFoodInInventory(
                          f,
                          FoodSummary.fromLegacy(
                            id: f.id,
                            name: food.name,
                            detail: '${food.quantity} · ${food.price}',
                            status: food.status,
                            imageIndex: food.image,
                            imagePath: f.imagePath,
                            note: food.note,
                            expiryDate: food.expiryValue ?? f.expiry,
                          ),
                        ),
                      );
                    }, childCount: foods.length),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}

enum _ScanInputOrigin { recognizedReceipt, sampleTemplate, manualEntry }

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key, this.initialMethod});
  final AddFoodMethod? initialMethod;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin {
  int stage = 0;
  int scanStep = 0;
  XFile? receiptImage;
  ReceiptScanResult? scanResult;
  final imagePicker = ImagePicker();
  final ocrService = ReceiptOcrService();
  bool importing = false;
  String? scanError;
  _ScanInputOrigin inputOrigin = _ScanInputOrigin.recognizedReceipt;
  final selected = <int>{0, 1, 2, 3, 4, 5, 6, 7};
  final timers = <Timer>[];
  late final AnimationController rotation;

  final results = <ReceiptLine>[];

  Future<void> _chooseTemplate() async {
    final template = await showModalBottomSheet<List<ReceiptLine>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _FoodTemplateSheet(),
    );
    if (template == null || !mounted) return;
    setState(() {
      scanResult = null;
      inputOrigin = _ScanInputOrigin.sampleTemplate;
      results
        ..clear()
        ..addAll(template);
      selected
        ..clear()
        ..addAll(List.generate(results.length, (index) => index));
      stage = 2;
    });
  }

  Future<void> _manualEntry() async {
    final items = await showDialog<List<ReceiptLine>>(
      context: context,
      barrierColor: Colors.black45,
      builder: (_) => const _ManualFoodDialog(),
    );
    if (items == null || items.isEmpty || !mounted) return;
    setState(() {
      scanResult = null;
      inputOrigin = _ScanInputOrigin.manualEntry;
      results
        ..clear()
        ..addAll(items);
      selected
        ..clear()
        ..addAll(List.generate(results.length, (index) => index));
      stage = 2;
    });
  }

  Future<void> _saveTemplate() async {
    final lines = selected.map((i) => results[i]).toList();
    if (lines.isEmpty) return;
    await saveFoodTemplateDialog(context, lines);
  }

  Future<void> _pickReceipt(ImageSource source) async {
    try {
      final image = await imagePicker.pickImage(
        source: source,
        imageQuality: 95,
        maxWidth: 3000,
      );
      if (image == null) {
        if (!mounted) return;
        return;
      }
      if (!mounted) return;
      setState(() => receiptImage = image);
      await _startScan();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Không đọc được ảnh hóa đơn. Hãy thử ảnh rõ hơn.',
            textAlign: TextAlign.center,
          ),
        ),
      );
      setState(() {
        stage = 0;
        scanError = error.toString();
      });
    }
  }

  Future<void> _addSelectedToFridge() async {
    if (importing) return;
    setState(() => importing = true);
    final foods = selected.map((index) {
      final item = results[index];
      return FoodSummary(
        name: item.normalizedName,
        quantity: item.quantity,
        unit: item.unit,
        priceVnd: item.totalPriceVnd,
        imageIndex: inventoryFoods.length % 10,
        expiry: item.estimatedExpiryDate,
      );
    });
    try {
      if (AppServices.configured &&
          HouseholdService.instance.active.value != null &&
          scanResult != null) {
        HouseholdDataRepository.instance.syncStatus.value =
            'Đang lưu hóa đơn và thực phẩm…';
        await HouseholdDataRepository.instance.importReceipt(
          lines: results,
          selectedIndexes: selected,
          rawText: scanResult!.rawText,
          storeName: scanResult!.storeName,
          purchasedAt: scanResult!.purchasedAt,
          totalVnd: scanResult!.totalVnd,
          localImagePath: receiptImage?.path,
        );
        final snapshot = await HouseholdDataRepository.instance
            .loadActiveHousehold();
        replaceInventoryFromRemote(
          records: snapshot.inventory,
          events: snapshot.events,
        );
        HouseholdDataRepository.instance.syncStatus.value = null;
      } else {
        final saved = await addFoodsToInventory(foods);
        if (!saved) {
          if (mounted) {
            showFoodNotification(
              context,
              success: false,
              title: 'Có món chưa đồng bộ',
              message:
                  'Danh sách được giữ trên thiết bị. Bấm Thử lại để lưu lên cloud.',
            );
          }
          if (mounted) setState(() => importing = false);
          return;
        }
      }
    } catch (_) {
      HouseholdDataRepository.instance.syncStatus.value =
          'Hóa đơn chưa được lưu trên máy chủ. Thông tin đang giữ ở bước rà soát; thử lưu lại khi có mạng.';
      if (mounted) {
        setState(() => importing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Chưa lưu được hóa đơn. Hãy thử lại.',
              textAlign: TextAlign.center,
            ),
          ),
        );
      }
      return;
    }
    if (!mounted) return;
    showFoodNotification(
      context,
      title: 'Đã thêm ${selected.length} thực phẩm',
      message: AppServices.configured
          ? 'Đã đồng bộ vào tủ lạnh gia đình.'
          : 'Đã lưu vào tủ lạnh trên thiết bị.',
    );
    if (widget.initialMethod != null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      importing = false;
      stage = 0;
      receiptImage = null;
      scanResult = null;
    });
  }

  Future<void> _editResult(int index) async {
    final edited = await showDialog<ReceiptLine>(
      context: context,
      builder: (_) => _EditReceiptLineDialog(line: results[index]),
    );
    if (edited != null && mounted) setState(() => results[index] = edited);
  }

  @override
  void initState() {
    super.initState();
    rotation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    if (widget.initialMethod != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        switch (widget.initialMethod!) {
          case AddFoodMethod.scan:
            unawaited(_pickReceipt(ImageSource.camera));
          case AddFoodMethod.ai:
            unawaited(_pickReceipt(ImageSource.gallery));
          case AddFoodMethod.template:
            unawaited(_chooseTemplate());
          case AddFoodMethod.manual:
            break;
        }
      });
    }
  }

  @override
  void dispose() {
    _cancelScanTimers();
    rotation.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    _cancelScanTimers();
    setState(() {
      stage = 1;
      scanStep = 0;
      inputOrigin = _ScanInputOrigin.recognizedReceipt;
    });
    rotation.repeat();
    try {
      final image = receiptImage;
      if (image == null) throw StateError('Chưa có ảnh hóa đơn');
      if (mounted) setState(() => scanStep = 1);
      final scan = await ocrService.scan(image.path);
      if (!mounted) return;
      setState(() => scanStep = 2);
      if (scan.items.isEmpty) {
        throw const FormatException('Không tìm thấy dòng sản phẩm và giá tiền');
      }
      results
        ..clear()
        ..addAll(scan.items);
      selected
        ..clear()
        ..addAll(List.generate(results.length, (index) => index));
      rotation.stop();
      setState(() {
        scanResult = scan;
        stage = 2;
        scanError = null;
      });
    } catch (error) {
      rotation.stop();
      if (!mounted) return;
      setState(() {
        stage = 0;
        scanError = error.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'OCR chưa đọc được hóa đơn. Hãy chụp gần và rõ hơn.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
  }

  void _cancelScanTimers() {
    for (final timer in timers) {
      timer.cancel();
    }
    timers.clear();
  }

  void _reset() {
    _cancelScanTimers();
    rotation.reset();
    setState(() {
      stage = 0;
      scanStep = 0;
      receiptImage = null;
      scanResult = null;
      scanError = null;
      results.clear();
      selected.clear();
      inputOrigin = _ScanInputOrigin.recognizedReceipt;
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (widget.initialMethod == null)
        const BrandHeader(title: 'Nhập thực phẩm', search: true),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _InputMethodCard(
              key: widget.initialMethod == null ? tutorialTargetKeys[1] : null,
              onScan: () => _pickReceipt(ImageSource.gallery),
              onTemplate: _chooseTemplate,
              onManual: _manualEntry,
            ),
            const SizedBox(height: 14),
            if (stage == 0) ...[
              Container(
                key: widget.initialMethod == null
                    ? tutorialSectionKeys[1][0]
                    : null,
                height: 240,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F8F4),
                  border: Border.all(color: const Color(0xFFDCEBE4)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.receipt_long_outlined,
                            size: 31,
                            color: _green,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Chưa chọn ảnh hóa đơn',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'Chụp ảnh hoặc chọn ảnh rõ nét để nhận diện món.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: _muted),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                key: widget.initialMethod == null
                    ? tutorialSectionKeys[1][1]
                    : null,
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: () => _pickReceipt(ImageSource.gallery),
                        icon: const Icon(Icons.image_outlined),
                        label: const Text('Chọn ảnh'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: () => _pickReceipt(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Chụp ảnh'),
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (stage == 1)
              _ScanningCard(rotation: rotation, step: scanStep)
            else
              _ScanResults(
                items: results,
                selected: selected,
                inputOrigin: inputOrigin,
                onToggle: (index) => setState(
                  () => selected.contains(index)
                      ? selected.remove(index)
                      : selected.add(index),
                ),
                onToggleAll: () => setState(
                  () => selected.length == results.length
                      ? selected.clear()
                      : selected.addAll(
                          List.generate(results.length, (index) => index),
                        ),
                ),
                onReset: _reset,
                onConfirm: _addSelectedToFridge,
                onEdit: _editResult,
              ),
            if (scanError != null && stage == 0)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Lỗi OCR: $scanError',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                ),
              ),
            const SizedBox(height: 18),
            if (stage == 2)
              OutlinedButton.icon(
                onPressed: selected.isEmpty ? null : _saveTemplate,
                icon: const Icon(Icons.bookmark_add_outlined),
                label: const Text('Tạo mẫu từ danh sách đã chọn'),
              ),
            Card(
              color: const Color(0xFFF1F8FF),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.privacy_tip_outlined, color: _green),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rõ ràng về dữ liệu',
                            style: TextStyle(
                              color: _ink,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'OCR xử lý trên thiết bị. Hóa đơn chỉ được lưu sau khi bạn rà soát và xác nhận. Danh sách mẫu hoặc nhập thủ công chỉ thêm thực phẩm, không tạo lịch sử quét giả.',
                            style: TextStyle(
                              color: _muted,
                              fontSize: 11,
                              height: 1.45,
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
            Card(
              color: const Color(0xFFFFFBEB),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SectionTitle('💡 Mẹo chụp hóa đơn'),
                    SizedBox(height: 10),
                    Text(
                      '✓ Đặt hóa đơn trên mặt phẳng tối màu\n✓ Đảm bảo đủ ánh sáng, tránh bóng đổ\n✓ Chụp toàn bộ hóa đơn trong khung',
                      style: TextStyle(
                        height: 1.8,
                        color: Color(0xFF667085),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    ],
  );
}

class _InputMethodCard extends StatelessWidget {
  const _InputMethodCard({
    super.key,
    required this.onScan,
    required this.onTemplate,
    required this.onManual,
  });

  final VoidCallback onScan, onTemplate, onManual;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Chọn cách thêm thực phẩm'),
          const SizedBox(height: 11),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth < 420 ? 2 : 3;
              const gap = 8.0;
              final width =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  SizedBox(
                    width: width,
                    child: _InputMethod(
                      icon: Icons.receipt_long_outlined,
                      label: 'Quét hóa đơn',
                      note: 'Chụp hoặc tải ảnh',
                      active: true,
                      onTap: onScan,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _InputMethod(
                      icon: Icons.dashboard_customize_outlined,
                      label: 'Dữ liệu mẫu',
                      note: 'Không phải hóa đơn thật',
                      onTap: onTemplate,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _InputMethod(
                      icon: Icons.edit_note_outlined,
                      label: 'Nhập thủ công',
                      note: 'Tự nhập từng món',
                      onTap: onManual,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );
}

class _InputMethod extends StatelessWidget {
  const _InputMethod({
    required this.icon,
    required this.label,
    required this.note,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label, note;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(11),
    child: Container(
      height: 92,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFE9FBF4) : Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: active ? const Color(0xFF8BE1C3) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 23, color: _green),
          const SizedBox(height: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            note,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9, color: _muted),
          ),
        ],
      ),
    ),
  );
}

class _FoodTemplateItem {
  const _FoodTemplateItem({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.totalPriceVnd,
    required this.shelfLifeDays,
  });

  final String name;
  final double quantity;
  final String unit;
  final int totalPriceVnd;
  final int shelfLifeDays;

  ReceiptLine toReceiptLine({DateTime? referenceTime}) {
    final now = referenceTime ?? DateTime.now();
    return ReceiptLine(
      rawName: name,
      normalizedName: name,
      quantity: quantity,
      unit: unit,
      unitPriceVnd: quantity <= 0 ? 0 : (totalPriceVnd / quantity).round(),
      totalPriceVnd: totalPriceVnd,
      estimatedExpiryDate: now.add(Duration(days: shelfLifeDays)),
      confidence: 1,
    );
  }
}

class _FoodTemplate {
  const _FoodTemplate({
    required this.title,
    required this.description,
    required this.icon,
    required this.items,
  });

  final String title;
  final String description;
  final IconData icon;
  final List<_FoodTemplateItem> items;

  List<ReceiptLine> buildLines() =>
      items.map((item) => item.toReceiptLine()).toList();
}

class _FoodTemplateSheet extends StatelessWidget {
  const _FoodTemplateSheet();

  static final templates = <_FoodTemplate>[
    _FoodTemplate(
      title: 'Đi chợ hàng tuần',
      description: '8 món thiết yếu cho cả nhà',
      icon: Icons.shopping_basket_outlined,
      items: [
        _FoodTemplateItem(
          name: 'Thịt heo',
          quantity: 500,
          unit: 'gram',
          totalPriceVnd: 65000,
          shelfLifeDays: 7,
        ),
        _FoodTemplateItem(
          name: 'Trứng gà',
          quantity: 10,
          unit: 'quả',
          totalPriceVnd: 35000,
          shelfLifeDays: 21,
        ),
        _FoodTemplateItem(
          name: 'Rau muống',
          quantity: 2,
          unit: 'bó',
          totalPriceVnd: 15000,
          shelfLifeDays: 3,
        ),
        _FoodTemplateItem(
          name: 'Cà chua',
          quantity: 5,
          unit: 'quả',
          totalPriceVnd: 25000,
          shelfLifeDays: 7,
        ),
        _FoodTemplateItem(
          name: 'Cải thảo',
          quantity: 1,
          unit: 'cây',
          totalPriceVnd: 20000,
          shelfLifeDays: 7,
        ),
        _FoodTemplateItem(
          name: 'Sữa tươi',
          quantity: 2,
          unit: 'hộp',
          totalPriceVnd: 32000,
          shelfLifeDays: 10,
        ),
        _FoodTemplateItem(
          name: 'Đậu hũ',
          quantity: 4,
          unit: 'miếng',
          totalPriceVnd: 10000,
          shelfLifeDays: 3,
        ),
        _FoodTemplateItem(
          name: 'Hành lá',
          quantity: 2,
          unit: 'bó',
          totalPriceVnd: 15000,
          shelfLifeDays: 3,
        ),
      ],
    ),
    _FoodTemplate(
      title: 'Bữa sáng nhanh',
      description: '5 món cho bữa sáng trong tuần',
      icon: Icons.free_breakfast_outlined,
      items: [
        _FoodTemplateItem(
          name: 'Trứng gà',
          quantity: 10,
          unit: 'quả',
          totalPriceVnd: 35000,
          shelfLifeDays: 21,
        ),
        _FoodTemplateItem(
          name: 'Bánh mì',
          quantity: 5,
          unit: 'ổ',
          totalPriceVnd: 20000,
          shelfLifeDays: 3,
        ),
        _FoodTemplateItem(
          name: 'Sữa tươi',
          quantity: 5,
          unit: 'hộp',
          totalPriceVnd: 40000,
          shelfLifeDays: 10,
        ),
        _FoodTemplateItem(
          name: 'Chuối',
          quantity: 1,
          unit: 'nải',
          totalPriceVnd: 25000,
          shelfLifeDays: 5,
        ),
        _FoodTemplateItem(
          name: 'Yến mạch',
          quantity: 500,
          unit: 'gram',
          totalPriceVnd: 55000,
          shelfLifeDays: 180,
        ),
      ],
    ),
    _FoodTemplate(
      title: 'Lẩu cuối tuần',
      description: '6 nguyên liệu cho 4 người',
      icon: Icons.soup_kitchen_outlined,
      items: [
        _FoodTemplateItem(
          name: 'Thịt bò',
          quantity: 500,
          unit: 'gram',
          totalPriceVnd: 125000,
          shelfLifeDays: 3,
        ),
        _FoodTemplateItem(
          name: 'Tôm sú',
          quantity: 500,
          unit: 'gram',
          totalPriceVnd: 110000,
          shelfLifeDays: 2,
        ),
        _FoodTemplateItem(
          name: 'Nấm kim châm',
          quantity: 3,
          unit: 'gói',
          totalPriceVnd: 30000,
          shelfLifeDays: 5,
        ),
        _FoodTemplateItem(
          name: 'Rau cải',
          quantity: 2,
          unit: 'bó',
          totalPriceVnd: 24000,
          shelfLifeDays: 3,
        ),
        _FoodTemplateItem(
          name: 'Đậu hũ',
          quantity: 4,
          unit: 'miếng',
          totalPriceVnd: 10000,
          shelfLifeDays: 3,
        ),
        _FoodTemplateItem(
          name: 'Mì gói',
          quantity: 4,
          unit: 'gói',
          totalPriceVnd: 20000,
          shelfLifeDays: 180,
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final sheetHeight = MediaQuery.sizeOf(context).height * .72;
    return SafeArea(
      child: SizedBox(
        height: sheetHeight,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Chọn mẫu thực phẩm',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              const Text(
                'Bạn vẫn có thể chọn lại từng món trước khi thêm vào tủ.',
                style: TextStyle(fontSize: 12, color: _muted),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Tạo mẫu mới'),
                onPressed: () async {
                  final lines = await showDialog<List<ReceiptLine>>(
                    context: context,
                    builder: (_) => const _ManualFoodDialog(),
                  );
                  if (lines == null || lines.isEmpty || !context.mounted) {
                    return;
                  }
                  final saved = await saveFoodTemplateDialog(context, lines);
                  if (saved && context.mounted) Navigator.pop(context, lines);
                },
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    FutureBuilder<List<SavedFoodTemplate>>(
                      future: FoodTemplateStore.load(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const Text(
                            'Chưa tải được mẫu riêng. Kiểm tra kết nối rồi mở lại.',
                          );
                        }
                        if (!snapshot.hasData) {
                          return const LinearProgressIndicator();
                        }
                        return Column(
                          children: snapshot.data!
                              .map(
                                (t) => Card(
                                  child: ListTile(
                                    leading: const Icon(
                                      Icons.bookmark,
                                      color: _green,
                                    ),
                                    title: Text(t.name),
                                    subtitle: Text(
                                      '${t.items.length} món · Mẫu của bạn',
                                    ),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () =>
                                        Navigator.pop(context, t.buildLines()),
                                  ),
                                ),
                              )
                              .toList(),
                        );
                      },
                    ),
                    ...templates.map(
                      (template) => Card(
                        margin: const EdgeInsets.only(bottom: 9),
                        child: ListTile(
                          onTap: () =>
                              Navigator.pop(context, template.buildLines()),
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFE7FAF3),
                            foregroundColor: _green,
                            child: Icon(template.icon),
                          ),
                          title: Text(
                            template.title,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(template.description),
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManualFoodDialog extends StatefulWidget {
  const _ManualFoodDialog();

  @override
  State<_ManualFoodDialog> createState() => _ManualFoodDialogState();
}

class _ManualFoodDialogState extends State<_ManualFoodDialog> {
  final name = TextEditingController();
  final quantity = TextEditingController();
  final price = TextEditingController();
  final items = <ReceiptLine>[];
  String unit = 'gram';
  DateTime? expiryDate;
  String? error;

  Future<void> _pickExpiry() async {
    final date = await showDatePicker(
      context: context,
      initialDate: expiryDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Chọn ngày hết hạn',
      confirmText: 'Chọn',
      cancelText: 'Hủy',
      builder: foodDatePickerTheme,
    );
    if (date != null && mounted) setState(() => expiryDate = date);
  }

  @override
  void dispose() {
    name.dispose();
    quantity.dispose();
    price.dispose();
    super.dispose();
  }

  void _addItem() {
    final parsedQuantity = double.tryParse(
      quantity.text.trim().replaceAll(',', '.'),
    );
    final parsedPrice = int.tryParse(
      price.text.replaceAll(RegExp(r'[^0-9]'), ''),
    );
    if (name.text.trim().isEmpty ||
        parsedQuantity == null ||
        parsedQuantity <= 0 ||
        expiryDate == null) {
      setState(
        () => error = 'Nhập tên, số lượng lớn hơn 0 và chọn ngày hết hạn.',
      );
      return;
    }
    final totalPrice = parsedPrice ?? 0;
    setState(() {
      items.add(
        ReceiptLine(
          rawName: name.text.trim(),
          normalizedName: name.text.trim(),
          quantity: parsedQuantity,
          unit: unit,
          unitPriceVnd: (parsedPrice == null || parsedQuantity == 0)
              ? 0
              : (totalPrice / parsedQuantity).round(),
          totalPriceVnd: totalPrice,
          estimatedExpiryDate: expiryDate,
          confidence: 1,
        ),
      );
      name.clear();
      quantity.clear();
      price.clear();
      expiryDate = null;
      error = null;
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    title: const Text('Nhập thực phẩm thủ công'),
    content: SizedBox(
      width: 470,
      child: Theme(
        data: Theme.of(context).copyWith(
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFFF7FAF9),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(
                  labelText: 'Tên thực phẩm *',
                  prefixIcon: Icon(Icons.restaurant_outlined),
                ),
              ),
              const SizedBox(height: 10),
              ExpiryAssistant(
                name: name,
                baseDate: DateTime.now(),
                expiry: expiryDate,
                onChanged: (date) => setState(() => expiryDate = date),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: quantity,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Số lượng *',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FoodChoiceField(
                      label: 'Đơn vị',
                      value: unit,
                      options: const ['gram', 'kg', 'quả', 'bó', 'hộp', 'chai'],
                      onChanged: (value) => setState(() => unit = value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: price,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Giá (VNĐ)',
                        hintText: 'Ví dụ: 25000',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: _pickExpiry,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Ngày hết hạn *',
                          suffixIcon: Icon(Icons.event_outlined),
                        ),
                        child: Text(
                          expiryDate == null
                              ? 'Chọn ngày'
                              : _shortDate(expiryDate!),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (error != null)
                Text(
                  error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add),
                  label: const Text('Thêm vào danh sách'),
                ),
              ),
              if (items.isNotEmpty) ...[
                const Divider(height: 24),
                ...items.asMap().entries.map(
                  (entry) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      radius: 14,
                      child: Text('${entry.key + 1}'),
                    ),
                    title: Text(entry.value.normalizedName),
                    subtitle: Text(
                      '${entry.value.quantity} ${entry.value.unit} · '
                      'HSD: ${entry.value.estimatedExpiryDate == null ? 'Chưa có' : _shortDate(entry.value.estimatedExpiryDate!)}',
                    ),
                    trailing: IconButton(
                      onPressed: () =>
                          setState(() => items.removeAt(entry.key)),
                      icon: const Icon(Icons.close, size: 18),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: items.isEmpty ? null : () => Navigator.pop(context, items),
        child: Text('Xem trước (${items.length})'),
      ),
    ],
  );
}

class _ScanningCard extends StatelessWidget {
  const _ScanningCard({required this.rotation, required this.step});
  final Animation<double> rotation;
  final int step;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 38),
      child: Column(
        children: [
          SizedBox(
            width: 165,
            height: 165,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const SizedBox(
                  width: 165,
                  height: 165,
                  child: CircularProgressIndicator(
                    value: 1,
                    strokeWidth: 6,
                    color: Color(0xFF9BECCC),
                  ),
                ),
                RotationTransition(
                  turns: rotation,
                  child: const SizedBox(
                    width: 125,
                    height: 125,
                    child: CircularProgressIndicator(
                      strokeWidth: 6,
                      strokeCap: StrokeCap.round,
                      color: _green,
                      backgroundColor: Colors.transparent,
                    ),
                  ),
                ),
                const Icon(
                  Icons.receipt_long_outlined,
                  color: _green,
                  size: 34,
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          const Text(
            'Đang xử lý hóa đơn...',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: _ink,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Đang đọc ảnh và chuẩn bị dữ liệu\nđể bạn kiểm tra trước khi lưu',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Color(0xFF667085),
            ),
          ),
          const SizedBox(height: 22),
          _ScanProgress('Đang đọc văn bản...', step >= 0, step == 0),
          _ScanProgress('Nhận diện tên sản phẩm...', step >= 1, step == 1),
          _ScanProgress('Ước tính hạn sử dụng...', step >= 2, step == 2),
        ],
      ),
    ),
  );
}

class _ScanProgress extends StatelessWidget {
  const _ScanProgress(this.label, this.done, this.active);
  final String label;
  final bool done, active;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? const Color(0xFF22C58B) : const Color(0xFFE6E9EE),
          ),
          child: done
              ? Icon(
                  active ? Icons.more_horiz : Icons.check,
                  color: Colors.white,
                  size: 16,
                )
              : null,
        ),
        const SizedBox(width: 11),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: done ? const Color(0xFF667085) : _muted,
            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    ),
  );
}

class _ScanResults extends StatelessWidget {
  const _ScanResults({
    required this.items,
    required this.selected,
    required this.inputOrigin,
    required this.onToggle,
    required this.onToggleAll,
    required this.onReset,
    required this.onConfirm,
    required this.onEdit,
  });
  final List<ReceiptLine> items;
  final Set<int> selected;
  final _ScanInputOrigin inputOrigin;
  final ValueChanged<int> onToggle;
  final VoidCallback onToggleAll, onReset, onConfirm;
  final ValueChanged<int> onEdit;

  @override
  Widget build(BuildContext context) {
    final title = switch (inputOrigin) {
      _ScanInputOrigin.recognizedReceipt => 'Kết quả OCR · cần kiểm tra',
      _ScanInputOrigin.sampleTemplate => 'Dữ liệu mẫu · không phải OCR',
      _ScanInputOrigin.manualEntry => 'Thực phẩm nhập thủ công',
    };
    final description = switch (inputOrigin) {
      _ScanInputOrigin.recognizedReceipt =>
        'OCR có thể đọc sai; hãy rà soát trước khi lưu.',
      _ScanInputOrigin.sampleTemplate =>
        'Danh sách minh họa, không đại diện hóa đơn thật.',
      _ScanInputOrigin.manualEntry =>
        'Kiểm tra thông tin bạn vừa nhập trước khi lưu.',
    };
    final total = selected.fold<int>(
      0,
      (sum, index) => sum + items[index].totalPriceVnd,
    );
    final formattedTotal = total.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 390;
        final selectionCount = Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F3F5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            '${selected.length}/${items.length}',
            style: const TextStyle(fontSize: 11, color: _muted),
          ),
        );
        final titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: _ink,
              ),
            ),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: _muted),
            ),
          ],
        );
        final toggleAll = TextButton(
          onPressed: onToggleAll,
          child: Text(
            selected.length == items.length ? 'Bỏ chọn tất cả' : 'Chọn tất cả',
          ),
        );
        return Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: compact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: titleBlock),
                              const SizedBox(width: 8),
                              selectionCount,
                            ],
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: toggleAll,
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: titleBlock),
                          toggleAll,
                          selectionCount,
                        ],
                      ),
              ),
              const Divider(height: 1),
              ...items.asMap().entries.map((entry) {
                final checked = selected.contains(entry.key);
                return InkWell(
                  onTap: () => onToggle(entry.key),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 13,
                    ),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFF0F1F3)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: checked,
                          onChanged: (_) => onToggle(entry.key),
                          activeColor: _green,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                entry.value.normalizedName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: _ink,
                                ),
                              ),
                              Text(
                                '${entry.value.quantity == entry.value.quantity.roundToDouble() ? entry.value.quantity.toInt() : entry.value.quantity} ${entry.value.unit} · HSD ${entry.value.estimatedExpiryDate == null ? 'chưa rõ' : _shortDate(entry.value.estimatedExpiryDate!)} · ${(entry.value.confidence * 100).round()}%',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: _muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: compact ? 76 : 96,
                          child: Column(
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '${entry.value.totalPriceVnd.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')}đ',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF475467),
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Sửa thông tin mặt hàng',
                                onPressed: () => onEdit(entry.key),
                                icon: const Icon(Icons.edit_outlined, size: 18),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              Padding(
                padding: const EdgeInsets.all(14),
                child: compact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Tổng giá trị đã chọn',
                                style: TextStyle(fontSize: 10, color: _muted),
                              ),
                              Text(
                                '${formattedTotal.isEmpty ? '0' : formattedTotal}đ',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: _green,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: onReset,
                                  child: const Text('Quét lại'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: FilledButton.icon(
                                  onPressed: selected.isEmpty
                                      ? null
                                      : onConfirm,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Thêm vào tủ'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Tổng giá trị đã chọn',
                                  style: TextStyle(fontSize: 10, color: _muted),
                                ),
                                Text(
                                  '${formattedTotal.isEmpty ? '0' : formattedTotal}đ',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: _green,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton(
                            onPressed: onReset,
                            child: const Text('Quét lại'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: selected.isEmpty ? null : onConfirm,
                            icon: const Icon(Icons.add),
                            label: const Text('Thêm vào tủ'),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EditReceiptLineDialog extends StatefulWidget {
  const _EditReceiptLineDialog({required this.line});
  final ReceiptLine line;

  @override
  State<_EditReceiptLineDialog> createState() => _EditReceiptLineDialogState();
}

class _EditReceiptLineDialogState extends State<_EditReceiptLineDialog> {
  late final name = TextEditingController(text: widget.line.normalizedName);
  late final quantity = TextEditingController(
    text: widget.line.quantity.toString(),
  );
  late final unit = TextEditingController(text: widget.line.unit);
  late final price = TextEditingController(
    text: widget.line.totalPriceVnd.toString(),
  );
  late DateTime? expiry = widget.line.estimatedExpiryDate;

  @override
  void dispose() {
    name.dispose();
    quantity.dispose();
    unit.dispose();
    price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Sửa kết quả OCR'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: name,
            decoration: const InputDecoration(labelText: 'Tên sản phẩm'),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: quantity,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Số lượng'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: unit,
                  decoration: const InputDecoration(labelText: 'Đơn vị'),
                ),
              ),
            ],
          ),
          TextField(
            controller: price,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Thành tiền'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Hạn dùng'),
            subtitle: Text(
              expiry == null ? 'Chưa xác định' : _shortDate(expiry!),
            ),
            trailing: const Icon(Icons.calendar_month),
            onTap: () async {
              final value = await showDatePicker(
                context: context,
                initialDate:
                    expiry ?? DateTime.now().add(const Duration(days: 7)),
                firstDate: DateTime.now().subtract(const Duration(days: 30)),
                lastDate: DateTime.now().add(const Duration(days: 730)),
              );
              if (value != null) setState(() => expiry = value);
            },
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
        onPressed: () {
          final parsedQuantity = double.tryParse(
            quantity.text.replaceAll(',', '.'),
          );
          final parsedPrice = int.tryParse(
            price.text.replaceAll(RegExp(r'[^0-9]'), ''),
          );
          if (name.text.trim().isEmpty ||
              parsedQuantity == null ||
              parsedQuantity <= 0 ||
              parsedPrice == null) {
            return;
          }
          Navigator.pop(
            context,
            ReceiptLine(
              rawName: widget.line.rawName,
              normalizedName: name.text.trim(),
              quantity: parsedQuantity,
              unit: unit.text.trim().isEmpty ? 'phần' : unit.text.trim(),
              unitPriceVnd: (parsedPrice / parsedQuantity).round(),
              totalPriceVnd: parsedPrice,
              estimatedExpiryDate: expiry,
              confidence: 1,
              selected: widget.line.selected,
            ),
          );
        },
        child: const Text('Lưu'),
      ),
    ],
  );
}

const recipeCatalog = _RecipesScreenState.catalog;

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});
  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  int category = 0;
  String query = '';
  final recipes = recipeCatalog;
  static const catalog = [
    RecipeCatalogItem(
      id: 'spicy-egg-noodles',
      name: 'Mì cay trứng lòng đào',
      durationMinutes: 15,
      difficulty: RecipeDifficulty.easy,
      imageIndex: 10,
      ingredients: ['Mì', 'Trứng gà', 'Hành lá', 'Nước mắm'],
      categories: {RecipeCategory.breakfast},
      diets: {DietKind.pescatarian},
    ),
    RecipeCatalogItem(
      id: 'water-spinach-shrimp-soup',
      name: 'Canh rau muống nấu tôm',
      durationMinutes: 15,
      difficulty: RecipeDifficulty.easy,
      imageIndex: 11,
      ingredients: ['Rau muống', 'Tôm sú', 'Hành lá'],
      categories: {RecipeCategory.summer},
      vegetableCentric: true,
      diets: {
        DietKind.pescatarian,
        DietKind.vegetableForward,
        DietKind.lowCalorie,
        DietKind.highProtein,
        DietKind.noEgg,
        DietKind.lowerCarb,
      },
    ),
    RecipeCatalogItem(
      id: 'beef-napa-cabbage-stir-fry',
      name: 'Bò xào cải thảo',
      durationMinutes: 20,
      difficulty: RecipeDifficulty.easy,
      imageIndex: 12,
      ingredients: ['Thịt bò Mỹ', 'Cải thảo', 'Dưa leo'],
      categories: {RecipeCategory.dinner},
      vegetableCentric: true,
      diets: {
        DietKind.vegetableForward,
        DietKind.highProtein,
        DietKind.meatNoFish,
        DietKind.noEgg,
        DietKind.lowerCarb,
      },
    ),
    RecipeCatalogItem(
      id: 'egg-banh-mi',
      name: 'Bánh mì ốp la trứng gà',
      durationMinutes: 10,
      difficulty: RecipeDifficulty.easy,
      imageIndex: 13,
      ingredients: ['Trứng gà', 'Bánh mì', 'Hành lá'],
      categories: {RecipeCategory.breakfast},
      diets: {
        DietKind.vegetarian,
        DietKind.pescatarian,
        DietKind.meatNoFish,
        DietKind.highProtein,
      },
    ),
    RecipeCatalogItem(
      id: 'pepper-braised-basa',
      name: 'Cá basa kho tiêu',
      durationMinutes: 25,
      difficulty: RecipeDifficulty.medium,
      imageIndex: 14,
      ingredients: ['Cá basa fillet', 'Nước mắm', 'Hành lá'],
      categories: {RecipeCategory.dinner},
      diets: {
        DietKind.pescatarian,
        DietKind.highProtein,
        DietKind.noEgg,
        DietKind.lowerCarb,
      },
    ),
    RecipeCatalogItem(
      id: 'mackerel-sesame-salad',
      name: 'Salad cá thu dầu mè',
      durationMinutes: 5,
      difficulty: RecipeDifficulty.easy,
      imageIndex: 15,
      ingredients: ['Cá thu', 'Dưa leo', 'Hành lá'],
      categories: {RecipeCategory.summer},
      vegetableCentric: true,
      diets: {
        DietKind.pescatarian,
        DietKind.vegetableForward,
        DietKind.lowCalorie,
        DietKind.highProtein,
        DietKind.noEgg,
        DietKind.lowerCarb,
      },
    ),
    RecipeCatalogItem(
      id: 'tofu-tomato-sauce',
      name: 'Đậu hũ sốt cà chua',
      durationMinutes: 20,
      difficulty: RecipeDifficulty.easy,
      imageIndex: 4,
      ingredients: ['Đậu hũ', 'Cà chua', 'Hành lá'],
      categories: {RecipeCategory.summer, RecipeCategory.dinner},
      vegetableCentric: true,
      diets: {
        DietKind.vegetarian,
        DietKind.vegan,
        DietKind.pescatarian,
        DietKind.meatNoFish,
        DietKind.vegetableForward,
        DietKind.lowCalorie,
        DietKind.highProtein,
        DietKind.noEgg,
        DietKind.lowerCarb,
      },
    ),
    RecipeCatalogItem(
      id: 'pho-bo-tai',
      name: 'Phở bò tái',
      durationMinutes: 45,
      difficulty: RecipeDifficulty.hard,
      imageIndex: 2,
      ingredients: ['Thịt bò Mỹ', 'Bánh phở', 'Hành lá'],
      categories: {RecipeCategory.breakfast},
      diets: {DietKind.meatNoFish, DietKind.highProtein, DietKind.noEgg},
    ),
    RecipeCatalogItem(
      id: 'chicken-vegetable-stir-fry',
      name: 'Ức gà xào bông cải',
      durationMinutes: 25,
      difficulty: RecipeDifficulty.easy,
      imageIndex: 12,
      ingredients: ['Ức gà', 'Bông cải xanh', 'Cà rốt'],
      categories: {RecipeCategory.dinner},
      vegetableCentric: true,
      diets: {
        DietKind.meatNoFish,
        DietKind.vegetableForward,
        DietKind.highProtein,
        DietKind.noEgg,
        DietKind.lowerCarb,
      },
    ),
    RecipeCatalogItem(
      id: 'salmon-cucumber-salad',
      name: 'Salad cá hồi dưa leo',
      durationMinutes: 20,
      difficulty: RecipeDifficulty.easy,
      imageIndex: 15,
      ingredients: ['Cá hồi', 'Dưa leo', 'Cà chua', 'Xà lách'],
      categories: {RecipeCategory.summer},
      vegetableCentric: true,
      diets: {
        DietKind.pescatarian,
        DietKind.vegetableForward,
        DietKind.lowCalorie,
        DietKind.highProtein,
        DietKind.noEgg,
        DietKind.lowerCarb,
      },
    ),
    RecipeCatalogItem(
      id: 'tofu-mushroom-stir-fry',
      name: 'Đậu hũ xào nấm',
      durationMinutes: 20,
      difficulty: RecipeDifficulty.easy,
      imageIndex: 4,
      ingredients: ['Đậu hũ', 'Nấm đùi gà', 'Hành lá'],
      categories: {RecipeCategory.dinner},
      vegetableCentric: true,
      diets: {
        DietKind.vegetarian,
        DietKind.vegan,
        DietKind.pescatarian,
        DietKind.meatNoFish,
        DietKind.vegetableForward,
        DietKind.lowCalorie,
        DietKind.highProtein,
        DietKind.noEgg,
        DietKind.lowerCarb,
      },
    ),
    RecipeCatalogItem(
      id: 'pumpkin-tofu-soup',
      name: 'Canh bí đỏ đậu hũ',
      durationMinutes: 25,
      difficulty: RecipeDifficulty.easy,
      imageIndex: 4,
      ingredients: ['Bí đỏ', 'Đậu hũ', 'Hành lá'],
      categories: {RecipeCategory.dinner},
      vegetableCentric: true,
      diets: {
        DietKind.vegetarian,
        DietKind.vegan,
        DietKind.pescatarian,
        DietKind.meatNoFish,
        DietKind.vegetableForward,
        DietKind.lowCalorie,
        DietKind.noEgg,
      },
    ),
    RecipeCatalogItem(
      id: 'egg-tomato-stir-fry',
      name: 'Trứng xào cà chua',
      durationMinutes: 15,
      difficulty: RecipeDifficulty.easy,
      imageIndex: 13,
      ingredients: ['Trứng gà', 'Cà chua', 'Hành lá'],
      categories: {RecipeCategory.breakfast},
      diets: {
        DietKind.vegetarian,
        DietKind.pescatarian,
        DietKind.meatNoFish,
        DietKind.highProtein,
        DietKind.lowerCarb,
      },
    ),
    RecipeCatalogItem(
      id: 'beef-broccoli',
      name: 'Bò xào bông cải xanh',
      durationMinutes: 25,
      difficulty: RecipeDifficulty.easy,
      imageIndex: 12,
      ingredients: ['Thịt bò', 'Bông cải xanh', 'Tỏi'],
      categories: {RecipeCategory.dinner},
      vegetableCentric: true,
      diets: {
        DietKind.meatNoFish,
        DietKind.vegetableForward,
        DietKind.highProtein,
        DietKind.noEgg,
        DietKind.lowerCarb,
      },
    ),
    RecipeCatalogItem(
      id: 'shrimp-vegetable-soup',
      name: 'Canh tôm cải xanh',
      durationMinutes: 20,
      difficulty: RecipeDifficulty.easy,
      imageIndex: 11,
      ingredients: ['Tôm sú', 'Cải xanh', 'Hành lá'],
      categories: {RecipeCategory.dinner},
      vegetableCentric: true,
      diets: {
        DietKind.pescatarian,
        DietKind.vegetableForward,
        DietKind.lowCalorie,
        DietKind.highProtein,
        DietKind.noEgg,
        DietKind.lowerCarb,
      },
    ),
    RecipeCatalogItem(
      id: 'oat-banana-bowl',
      name: 'Yến mạch chuối sữa chua',
      durationMinutes: 10,
      difficulty: RecipeDifficulty.easy,
      imageIndex: 13,
      ingredients: ['Yến mạch', 'Chuối', 'Sữa chua'],
      categories: {RecipeCategory.breakfast},
      diets: {
        DietKind.vegetarian,
        DietKind.pescatarian,
        DietKind.meatNoFish,
        DietKind.noEgg,
      },
    ),
    RecipeCatalogItem(
      id: 'banana-oat-soy-bowl',
      name: 'Yến mạch chuối sữa đậu nành',
      durationMinutes: 10,
      difficulty: RecipeDifficulty.easy,
      imageIndex: 13,
      ingredients: ['Yến mạch', 'Chuối', 'Sữa đậu nành'],
      categories: {RecipeCategory.breakfast},
      diets: {
        DietKind.vegetarian,
        DietKind.vegan,
        DietKind.pescatarian,
        DietKind.meatNoFish,
        DietKind.noEgg,
      },
    ),
    RecipeCatalogItem(
      id: 'rice-chicken-cucumber',
      name: 'Cơm gạo lứt gà dưa leo',
      durationMinutes: 30,
      difficulty: RecipeDifficulty.easy,
      imageIndex: 12,
      ingredients: ['Gạo lứt', 'Ức gà', 'Dưa leo'],
      categories: {RecipeCategory.dinner},
      diets: {DietKind.meatNoFish, DietKind.highProtein, DietKind.noEgg},
    ),
    RecipeCatalogItem(
      id: 'mixed-vegetable-stir-fry',
      name: 'Rau củ xào nấm',
      durationMinutes: 20,
      difficulty: RecipeDifficulty.easy,
      imageIndex: 4,
      ingredients: ['Bông cải xanh', 'Cà rốt', 'Nấm đùi gà'],
      categories: {RecipeCategory.dinner},
      vegetableCentric: true,
      diets: {
        DietKind.vegetarian,
        DietKind.vegan,
        DietKind.pescatarian,
        DietKind.meatNoFish,
        DietKind.vegetableForward,
        DietKind.lowCalorie,
        DietKind.noEgg,
        DietKind.lowerCarb,
      },
    ),
    RecipeCatalogItem(
      id: 'tuna-tomato-salad',
      name: 'Salad cá ngừ cà chua',
      durationMinutes: 15,
      difficulty: RecipeDifficulty.easy,
      imageIndex: 15,
      ingredients: ['Cá ngừ', 'Cà chua', 'Xà lách'],
      categories: {RecipeCategory.summer},
      vegetableCentric: true,
      diets: {
        DietKind.pescatarian,
        DietKind.vegetableForward,
        DietKind.lowCalorie,
        DietKind.highProtein,
        DietKind.noEgg,
        DietKind.lowerCarb,
      },
    ),
  ];

  @override
  void initState() {
    super.initState();
    unawaited(refreshPreferredDiet());
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<DietKind>(
    valueListenable: preferredDiet,
    builder: (context, selectedDiet, _) => ValueListenableBuilder<int>(
      valueListenable: inventoryRevision,
      builder: (context, _, _) {
        final suitableRecipes = recipes
            .where(
              (recipe) =>
                  selectedDiet == DietKind.normal ||
                  recipe.diets.contains(selectedDiet),
            )
            .toList();
        final activeCategory = switch (category) {
          1 => RecipeCategory.summer,
          2 => RecipeCategory.breakfast,
          3 => RecipeCategory.dinner,
          _ => null,
        };
        final availableRecipeCount = suitableRecipes.where((recipe) {
          final detail = recipe.toDetailData();
          final availableCount = detail.ingredients
              .where((ingredient) => ingredient.available)
              .length;
          return detail.ingredients.isNotEmpty &&
              availableCount * 2 >= detail.ingredients.length;
        }).length;
        final filteredRecipes =
            suitableRecipes.where((recipe) {
              final detail = recipe.toDetailData();
              final matchesSearch =
                  query.trim().isEmpty ||
                  detail.name.toLowerCase().contains(
                    query.trim().toLowerCase(),
                  ) ||
                  detail.ingredients.any(
                    (item) => item.name.toLowerCase().contains(
                      query.trim().toLowerCase(),
                    ),
                  );
              final matchesCategory =
                  activeCategory == null ||
                  recipe.categories.contains(activeCategory);
              return matchesSearch && matchesCategory;
            }).toList()..sort((a, b) {
              final vegetablePriority = (b.vegetableCentric ? 1 : 0).compareTo(
                a.vegetableCentric ? 1 : 0,
              );
              if (vegetablePriority != 0) return vegetablePriority;
              final aReady = a
                  .toDetailData()
                  .ingredients
                  .where((ingredient) => ingredient.available)
                  .length;
              final bReady = b
                  .toDetailData()
                  .ingredients
                  .where((ingredient) => ingredient.available)
                  .length;
              return bReady.compareTo(aReady);
            });
        return Column(
          children: [
            const BrandHeader(title: 'Gợi ý món ăn'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  Card(
                    color: const Color(0xFFE7FAF3),
                    child: ListTile(
                      leading: const Icon(Icons.calendar_month, color: _green),
                      title: const Text(
                        'Thực đơn ngày & tuần',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: const Text(
                        '3 bữa mỗi ngày · Gợi ý theo chế độ ăn · Đi chợ',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MealPlanScreen(
                            catalog: [...recipes, ...menuSupportingRecipes],
                            onOpenShopping: (day, week) =>
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => Scaffold(
                                      appBar: AppBar(
                                        title: const Text('Đi chợ từ thực đơn'),
                                      ),
                                      body: ShoppingScreen(
                                        menuDay: day,
                                        menuWeekStart: week,
                                      ),
                                    ),
                                  ),
                                ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: tutorialTargetKeys[2],
                    onChanged: (value) => setState(() => query = value),
                    decoration: InputDecoration(
                      hintText: 'Tìm món ăn...',
                      prefixIcon: const Icon(Icons.search, size: 19),
                      filled: true,
                      fillColor: const Color(0xFFF1F3F5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    key: tutorialSectionKeys[2][0],
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7FAF3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedDiet == DietKind.normal
                              ? 'Có $availableRecipeCount món có từ 50% nguyên liệu sẵn'
                              : '${suitableRecipes.length} món phù hợp · ${selectedDiet.label}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: _ink,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          selectedDiet == DietKind.normal
                              ? 'Tỉ lệ được tính theo tủ lạnh gia đình đang chọn.'
                              : '$availableRecipeCount món có từ 50% nguyên liệu sẵn. Đổi chế độ ăn trong Hồ sơ.',
                          style: TextStyle(fontSize: 10, color: _muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    key: tutorialSectionKeys[2][1],
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: ['Tất cả', 'Mùa hè', 'Bữa sáng', 'Bữa tối']
                          .asMap()
                          .entries
                          .map(
                            (entry) => Padding(
                              padding: const EdgeInsets.only(right: 7),
                              child: ChoiceChip(
                                label: Text(entry.value),
                                selected: category == entry.key,
                                onSelected: (_) =>
                                    setState(() => category = entry.key),
                                selectedColor: _green,
                                labelStyle: TextStyle(
                                  fontSize: 11,
                                  color: category == entry.key
                                      ? Colors.white
                                      : _ink,
                                ),
                                showCheckmark: false,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (filteredRecipes.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          'Chưa có món phù hợp với bộ lọc này',
                          style: TextStyle(color: _muted),
                        ),
                      ),
                    ),
                  ...filteredRecipes.map(
                    (recipe) => _RecipeCard(
                      key: ValueKey(recipe.id),
                      recipe: recipe,
                      selectedDiet: selectedDiet,
                    ),
                  ),
                  Card(
                    color: const Color(0xFFFFFBEB),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Icon(Icons.lightbulb_outline, color: Colors.amber),
                          SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Mẹo nấu ăn thông minh',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: _ink,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Ưu tiên món dùng nguyên liệu sắp hết hạn để giảm lãng phí thực phẩm.',
                                  style: TextStyle(fontSize: 11, color: _muted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({
    super.key,
    required this.recipe,
    required this.selectedDiet,
  });
  final RecipeCatalogItem recipe;
  final DietKind selectedDiet;

  @override
  Widget build(BuildContext context) {
    final detail = recipe.toDetailData();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: detail)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                RecipeVisual(
                  name: recipe.name,
                  imageIndex: recipe.imageIndex,
                  height: 158,
                  width: double.infinity,
                ),
                Positioned(
                  top: 9,
                  left: 9,
                  child: _TinyBadge(
                    '${recipe.timeLabel}  ·  ${recipe.difficultyLabel}',
                    Colors.white,
                    _ink,
                  ),
                ),
                Positioned(
                  top: 9,
                  right: 9,
                  child: _TinyBadge(detail.match, _green, Colors.white),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    selectedDiet == DietKind.normal
                        ? 'Món ăn gợi ý từ những nguyên liệu đang có trong tủ lạnh của bạn.'
                        : 'Phù hợp với ${selectedDiet.label.toLowerCase()} · xem nguyên liệu trước khi nấu.',
                    style: const TextStyle(fontSize: 10, color: _muted),
                  ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: recipe.ingredients
                        .map(
                          (x) => _TinyBadge(x, const Color(0xFFE8FBF4), _green),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TinyBadge extends StatelessWidget {
  const _TinyBadge(this.text, this.bg, this.color);
  final String text;
  final Color bg, color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color),
    ),
  );
}

class ShoppingScreen extends StatefulWidget {
  const ShoppingScreen({super.key, this.menuDay, this.menuWeekStart});
  final DateTime? menuDay;
  final DateTime? menuWeekStart;
  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  final checked = shoppingChecked;
  int selectedCategory = 0;
  int _shoppingMutationRevision = 0;
  final items = shoppingItems;

  @override
  void initState() {
    super.initState();
    shoppingRevision.addListener(_onExternalShoppingChange);
    unawaited(_restoreShopping());
  }

  @override
  void dispose() {
    shoppingRevision.removeListener(_onExternalShoppingChange);
    super.dispose();
  }

  void _onExternalShoppingChange() {
    if (mounted) setState(() {});
  }

  Future<void> _restoreShopping() async {
    final revisionAtStart = _shoppingMutationRevision;
    if (AppServices.configured &&
        HouseholdService.instance.active.value != null) {
      final householdId = HouseholdService.instance.active.value!.id;
      try {
        final remoteItems = await HouseholdDataRepository.instance
            .loadShoppingItems();
        if (!mounted ||
            revisionAtStart != _shoppingMutationRevision ||
            HouseholdService.instance.active.value?.id != householdId) {
          return;
        }
        setState(() {
          items
            ..clear()
            ..addAll(remoteItems.map((entry) => entry.item));
          checked
            ..clear()
            ..addAll(
              remoteItems
                  .where((entry) => entry.checked)
                  .map((entry) => entry.item.id),
            );
        });
        shoppingRevision.value++;
      } catch (_) {
        if (!mounted ||
            revisionAtStart != _shoppingMutationRevision ||
            HouseholdService.instance.active.value?.id != householdId) {
          return;
        }
        setState(() {
          items.clear();
          checked.clear();
        });
        shoppingRevision.value++;
        HouseholdDataRepository.instance.syncStatus.value =
            'Chưa tải được danh sách đi chợ. Hãy kiểm tra kết nối rồi mở lại tab.';
      }
      return;
    }
    final snapshot = await restoreShopping();
    if (snapshot == null ||
        !mounted ||
        revisionAtStart != _shoppingMutationRevision) {
      return;
    }
    setState(() {
      items
        ..clear()
        ..addAll(snapshot.items);
      checked
        ..clear()
        ..addAll(
          snapshot.checked.where((id) => items.any((item) => item.id == id)),
        );
    });
    shoppingRevision.value++;
  }

  void _persistShopping() {
    unawaited(persistShopping(items, checked));
  }

  Future<void> _showAddItemDialog() async {
    final result = await showDialog<ShoppingSummary>(
      context: context,
      barrierColor: Colors.black45,
      builder: (_) => const AddShoppingItemDialog(),
    );
    if (result != null && mounted) {
      final duplicate = items.any(
        (item) => shoppingIdentity(item) == shoppingIdentity(result),
      );
      if (duplicate) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '${result.name} đã có trong danh sách',
              textAlign: TextAlign.center,
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }
      setState(() {
        final target = widget.menuDay ?? widget.menuWeekStart;
        items.add(
          target == null
              ? result
              : result.copyWith(menuDay: target, neededDate: target),
        );
        selectedCategory = 0;
      });
      _shoppingMutationRevision++;
      _persistShopping();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã thêm ${result.name} vào danh sách',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
  }

  void _deleteShoppingItem(int index) {
    final removed = items[index];
    final wasChecked = checked.contains(removed.id);
    setState(() {
      items.removeAt(index);
      checked.remove(removed.id);
    });
    _shoppingMutationRevision++;
    if (AppServices.configured &&
        HouseholdService.instance.active.value != null) {
      unawaited(
        HouseholdDataRepository.instance
            .deleteShoppingItem(removed)
            .catchError(
              (_) => HouseholdDataRepository.instance.syncStatus.value =
                  'Chưa xóa được món khỏi danh sách chung. Hãy kiểm tra mạng và thử lại.',
            ),
      );
    }
    _persistShopping();
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã xóa ${removed.name}', textAlign: TextAlign.center),
        action: SnackBarAction(
          label: 'Hoàn tác',
          onPressed: () {
            setState(() {
              items.insert(index, removed);
              if (wasChecked) checked.add(removed.id);
            });
            _shoppingMutationRevision++;
            _persistShopping();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const categories = ['Tất cả', 'Rau củ', 'Thịt cá', 'Đồ khô', 'Khác'];
    final indexedItems =
        items.asMap().entries.where((entry) {
          if (widget.menuWeekStart != null) {
            final date = entry.value.menuDay ?? entry.value.neededDate;
            if (date == null ||
                date.isBefore(widget.menuWeekStart!) ||
                !date.isBefore(
                  widget.menuWeekStart!.add(const Duration(days: 7)),
                )) {
              return false;
            }
          }
          if (widget.menuDay != null && entry.value.menuDay != widget.menuDay) {
            return false;
          }
          return selectedCategory == 0 ||
              entry.value.category == categories[selectedCategory];
        }).toList()..sort((a, b) {
          final done = (checked.contains(a.value.id) ? 1 : 0).compareTo(
            checked.contains(b.value.id) ? 1 : 0,
          );
          if (done != 0) return done;
          return (a.value.neededDate ?? DateTime(9999)).compareTo(
            b.value.neededDate ?? DateTime(9999),
          );
        });
    final remaining = widget.menuWeekStart == null
        ? items.length - checked.length
        : indexedItems.where((e) => !checked.contains(e.value.id)).length;
    return Column(
      children: [
        BrandHeader(
          title: 'Danh sách đi chợ',
          subtitle: '$remaining món cần mua',
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final counter = Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.shopping_basket_outlined,
                          color: _green,
                          size: 19,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '$remaining món',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: _ink,
                                  ),
                                ),
                                const TextSpan(
                                  text: ' cần mua',
                                  style: TextStyle(color: _muted),
                                ),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                  final addButton = FilledButton.icon(
                    key: tutorialTargetKeys[3],
                    onPressed: _showAddItemDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Thêm món'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );

                  if (constraints.maxWidth < 390) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        counter,
                        const SizedBox(height: 10),
                        addButton,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: counter),
                      const SizedBox(width: 12),
                      addButton,
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              SizedBox(
                key: tutorialSectionKeys[3][0],
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: categories.asMap().entries.map((entry) {
                    return _CategoryChip(
                      entry.value,
                      selectedCategory == entry.key,
                      onTap: () => setState(() => selectedCategory = entry.key),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 14),
              Card(
                key: tutorialSectionKeys[3][1],
                child: Column(
                  children: indexedItems
                      .map(
                        (e) => _ShoppingItem(
                          index: e.key,
                          item: e.value,
                          checked: checked.contains(e.value.id),
                          onChanged: () {
                            final purchased = !checked.contains(e.value.id);
                            setState(() {
                              if (purchased) {
                                checked.add(e.value.id);
                              } else {
                                checked.remove(e.value.id);
                              }
                            });
                            setShoppingPurchased(e.value, purchased);
                            _shoppingMutationRevision++;
                            _persistShopping();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  purchased
                                      ? 'Đã chuyển ${e.value.name} vào tủ lạnh'
                                      : 'Đã bỏ trạng thái đã mua',
                                  textAlign: TextAlign.center,
                                ),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          onDelete: () => _deleteShoppingItem(e.key),
                        ),
                      )
                      .toList(),
                ),
              ),
              if (indexedItems.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'Chưa có món nào trong danh mục này',
                      style: TextStyle(color: _muted),
                    ),
                  ),
                ),
              const SizedBox(height: 50),
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip(this.label, this.active, {required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 15),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? _green : Colors.white,
        border: Border.all(color: active ? _green : const Color(0xFFE7E9ED)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: active ? Colors.white : const Color(0xFF667085),
        ),
      ),
    ),
  );
}

class _ShoppingItem extends StatelessWidget {
  const _ShoppingItem({
    required this.index,
    required this.item,
    required this.checked,
    required this.onChanged,
    required this.onDelete,
  });
  final int index;
  final ShoppingSummary item;
  final bool checked;
  final VoidCallback onChanged;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) {
    final urgent = item.priority == 'Cần mua gấp';
    return InkWell(
      onTap: onChanged,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 17),
        margin: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: checked ? const Color(0xFFF5F7F6) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE6ECE9)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Checkbox(
              value: checked,
              onChanged: (_) => onChanged(),
              activeColor: _green,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final name = Text(
                        item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: checked ? _muted : _ink,
                          decoration: checked
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      );
                      final badge = _TinyBadge(
                        item.priority,
                        urgent
                            ? const Color(0xFFFFECEE)
                            : item.priority == 'Bình thường'
                            ? const Color(0xFFFFF8E5)
                            : const Color(0xFFF1F3F5),
                        urgent
                            ? Colors.redAccent
                            : item.priority == 'Bình thường'
                            ? Colors.orange
                            : _muted,
                      );
                      if (constraints.maxWidth < 210 ||
                          MediaQuery.textScalerOf(context).scale(1) >= 1.3) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [name, const SizedBox(height: 4), badge],
                        );
                      }
                      return Row(
                        children: [
                          Flexible(child: name),
                          const SizedBox(width: 8),
                          badge,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${shoppingQuantity(item.quantity)} ${item.unit}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: checked ? _muted : _green,
                    ),
                  ),
                  Text(
                    '${checked ? 'Đã mua' : 'Cần mua'}${item.neededDate == null ? '' : ' · Dùng từ ${item.neededDate!.day}/${item.neededDate!.month}'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF667085),
                    ),
                  ),
                  const SizedBox(height: 5),
                  if (item.menuPlanId != null)
                    TextButton.icon(
                      icon: const Icon(Icons.calendar_month, size: 16),
                      label: Text(
                        shoppingMenuUses(item.note).isEmpty
                            ? 'Xem món trong menu'
                            : 'Nấu: ${shoppingMenuUses(item.note).first.dish}${shoppingMenuUses(item.note).length > 1 ? ' +${shoppingMenuUses(item.note).length - 1} món' : ''}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: () => showShoppingMenuSheet(context, item),
                    ),
                  if (item.menuPlanId == null && item.note.isNotEmpty)
                    Text(
                      item.note,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF667085),
                      ),
                    ),
                  Text(
                    'Thêm bởi ${item.createdBy}',
                    style: const TextStyle(fontSize: 11, color: _muted),
                  ),
                ],
              ),
            ),
            if (checked) ...[
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Xóa món',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 19),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF7F8FA),
                  foregroundColor: const Color(0xFF344054),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AddShoppingItemDialog extends StatefulWidget {
  const AddShoppingItemDialog({super.key});

  @override
  State<AddShoppingItemDialog> createState() => _AddShoppingItemDialogState();
}

class _AddShoppingItemDialogState extends State<AddShoppingItemDialog> {
  final nameController = TextEditingController();
  final quantityController = TextEditingController(text: '1');
  final noteController = TextEditingController();
  String unit = 'gói';
  String category = 'Rau củ';
  String priority = 'Bình thường';
  bool showNameError = false;
  bool showQuantityError = false;

  @override
  void dispose() {
    nameController.dispose();
    quantityController.dispose();
    noteController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = nameController.text.trim();
    if (name.isEmpty) {
      setState(() => showNameError = true);
      return;
    }
    final quantityText = quantityController.text.trim();
    final quantity = quantityText.isEmpty
        ? 1.0
        : double.tryParse(quantityText.replaceAll(',', '.'));
    if (quantity == null || quantity <= 0) {
      setState(() => showQuantityError = true);
      return;
    }
    final note = noteController.text.trim();
    Navigator.pop(
      context,
      ShoppingSummary(
        householdId: HouseholdService.instance.active.value?.id,
        name: name,
        quantity: quantity,
        unit: unit,
        note: note,
        priority: priority,
        createdBy: 'Bạn',
        category: category,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxDialogHeight =
        (MediaQuery.sizeOf(context).height - bottomInset - 48)
            .clamp(280.0, 760.0)
            .toDouble();
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 520, maxHeight: maxDialogHeight),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Thêm món cần mua',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                              color: _ink,
                            ),
                          ),
                        ),
                        IconButton.filledTonal(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFF3F4F6),
                            foregroundColor: const Color(0xFF667085),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _FormLabel('Tên món'),
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      onChanged: (_) {
                        if (showNameError) {
                          setState(() => showNameError = false);
                        }
                      },
                      decoration: _inputDecoration(
                        'VD: Thịt gà, Rau muống...',
                        error: showNameError ? 'Vui lòng nhập tên món' : null,
                      ),
                    ),
                    const SizedBox(height: 14),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final quantityField = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _FormLabel('Số lượng'),
                            TextField(
                              controller: quantityController,
                              onChanged: (_) {
                                if (showQuantityError) {
                                  setState(() => showQuantityError = false);
                                }
                              },
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: _inputDecoration(
                                '1',
                                error: showQuantityError
                                    ? 'Nhập số lượng lớn hơn 0'
                                    : null,
                              ),
                            ),
                          ],
                        );
                        final unitField = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _FormLabel('Đơn vị'),
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: unit,
                              decoration: _inputDecoration(''),
                              items:
                                  const [
                                    'gói',
                                    'kg',
                                    'gram',
                                    'quả',
                                    'bó',
                                    'chai',
                                    'hộp',
                                    'miếng',
                                    'cây',
                                  ].map((value) {
                                    return DropdownMenuItem(
                                      value: value,
                                      child: Text(
                                        value,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    );
                                  }).toList(),
                              onChanged: (value) {
                                if (value != null) setState(() => unit = value);
                              },
                            ),
                          ],
                        );
                        if (constraints.maxWidth < 340) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              quantityField,
                              const SizedBox(height: 12),
                              unitField,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: quantityField),
                            const SizedBox(width: 12),
                            Expanded(child: unitField),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    _FormLabel('Danh mục'),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: _inputDecoration(''),
                      items: const ['Rau củ', 'Thịt cá', 'Đồ khô', 'Khác']
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => category = value!),
                    ),
                    const SizedBox(height: 14),
                    _FormLabel('Độ ưu tiên'),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: ['Cần mua gấp', 'Bình thường', 'Có cũng được']
                            .map(
                              (value) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(value),
                                  selected: priority == value,
                                  showCheckmark: false,
                                  selectedColor: _green,
                                  backgroundColor: const Color(0xFFF3F4F6),
                                  labelStyle: TextStyle(
                                    color: priority == value
                                        ? Colors.white
                                        : const Color(0xFF667085),
                                    fontWeight: FontWeight.w700,
                                  ),
                                  onSelected: (_) =>
                                      setState(() => priority = value),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _FormLabel('Ghi chú'),
                    TextField(
                      controller: noteController,
                      minLines: 2,
                      maxLines: 3,
                      decoration: _inputDecoration(
                        'VD: Mua loại tươi, chọn quả chín...',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        side: BorderSide.none,
                        backgroundColor: const Color(0xFFF3F4F6),
                        foregroundColor: const Color(0xFF475467),
                      ),
                      child: const Text('Hủy'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _submit,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      child: const Text('Thêm vào danh sách'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, {String? error}) {
    return InputDecoration(
      hintText: hint,
      errorText: error,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFDDE1E7)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFDDE1E7)),
      ),
    );
  }
}

class _FormLabel extends StatelessWidget {
  const _FormLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Color(0xFF475467),
      ),
    ),
  );
}

// ignore: unused_element
class _LegacyReportsScreen extends StatelessWidget {
  // ignore: unused_element_parameter
  const _LegacyReportsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: inventoryRevision,
      builder: (context, _, _) {
        int priceOf(FoodSummary food) {
          return food.priceVnd;
        }

        String vnd(int value) =>
            '${value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')}đ';
        final totalValue = inventoryFoods.fold<int>(
          0,
          (sum, food) => sum + priceOf(food),
        );
        final expiredValue = inventoryFoods
            .where((food) => food.status == 'Hết hạn')
            .fold<int>(0, (sum, food) => sum + priceOf(food));
        final wastePercent = totalValue == 0
            ? 0
            : ((expiredValue / totalValue) * 100).round();
        final pricedCount = inventoryFoods
            .where((food) => priceOf(food) > 0)
            .length;
        return Column(
          children: [
            const BrandHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) => GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: constraints.maxWidth < 400 ? 1 : 1.45,
                      children: [
                        _ReportStat(
                          'Giá trị trong tủ hiện tại',
                          vnd(totalValue),
                          '${inventoryFoods.length} thực phẩm đang theo dõi',
                          Icons.savings_outlined,
                          Color(0xFFE8FBF4),
                          _green,
                        ),
                        _ReportStat(
                          'Tỉ trọng giá trị hết hạn',
                          vnd(expiredValue),
                          'Cần xử lý sớm',
                          Icons.account_balance_wallet_outlined,
                          Color(0xFFFFEFF0),
                          Colors.redAccent,
                        ),
                        _ReportStat(
                          'Giá trị đã hết hạn',
                          '$wastePercent%',
                          'Tỉ trọng trong giá trị tủ',
                          Icons.emoji_events_outlined,
                          Color(0xFFFFF8E5),
                          Colors.orange,
                        ),
                        _ReportStat(
                          'Thực phẩm có giá',
                          '$pricedCount/${inventoryFoods.length}',
                          'Có thông tin giá trị',
                          Icons.sell_outlined,
                          Color(0xFFFFEFF7),
                          Colors.pinkAccent,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionTitle('Xu hướng (dữ liệu minh họa)'),
                          const SizedBox(height: 18),
                          SizedBox(
                            height: 145,
                            child: CustomPaint(
                              painter: _LineChartPainter(),
                              size: Size.infinite,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.square,
                                size: 11,
                                color: Color(0xFF34D399),
                              ),
                              Text(
                                ' Tiết kiệm  ',
                                style: TextStyle(fontSize: 10, color: _muted),
                              ),
                              Icon(
                                Icons.square,
                                size: 11,
                                color: Color(0xFFFFA4A8),
                              ),
                              Text(
                                ' Lãng phí',
                                style: TextStyle(fontSize: 10, color: _muted),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: const [
                          SectionTitle('So sánh (dữ liệu minh họa)'),
                          SizedBox(height: 13),
                          Row(
                            children: [
                              Expanded(
                                child: _CompareBox(
                                  'Giảm lãng phí',
                                  '-53%',
                                  '95.000đ → 45.000đ',
                                  Color(0xFFE8FBF4),
                                  _green,
                                ),
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: _CompareBox(
                                  'Tăng tiết kiệm',
                                  '+50%',
                                  '120.000đ → 180.000đ',
                                  Color(0xFFFFF8E5),
                                  Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionTitle('Lãng phí (dữ liệu minh họa)'),
                          const SizedBox(height: 18),
                          SizedBox(
                            height: 140,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: const [
                                _Bar('2.1kg', .9, 'Tháng 1'),
                                _Bar('1.7kg', .75, 'Tháng 2'),
                                _Bar('1.4kg', .64, 'Tháng 3'),
                                _Bar('1.1kg', .5, 'Tháng 4'),
                                _Bar('1.2kg', .55, 'Tháng 5'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          SectionTitle('Theo danh mục (dữ liệu minh họa)'),
                          SizedBox(height: 14),
                          _Retention('Rau củ', .82, Colors.green),
                          _Retention('Thịt cá', .88, Colors.redAccent),
                          _Retention('Đồ khô', .95, Colors.orange),
                          _Retention('Gia vị', .98, Colors.indigo),
                          _Retention('Đồ uống', .97, Colors.cyan),
                          _Retention('Đông lạnh', .92, Colors.blue),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  const SectionTitle(
                    'Mục tiêu mẫu',
                    trailing: 'Chưa theo dõi lịch sử',
                  ),
                  const SizedBox(height: 8),
                  const _Achievement(
                    'Tiết Kiệm Gia',
                    'Tiết kiệm tổng cộng hơn 500.000đ thực phẩm',
                    Icons.monetization_on_outlined,
                    Colors.amber,
                  ),
                  const _Achievement(
                    'Bếp Xanh',
                    'Giảm 50% lãng phí thực phẩm so với tháng đầu',
                    Icons.eco_outlined,
                    Colors.green,
                  ),
                  const _Achievement(
                    'Đầu Bếp Chăm Chỉ',
                    'Nấu ăn liên tục 30 ngày không lãng phí món nào',
                    Icons.local_fire_department_outlined,
                    Colors.orange,
                  ),
                  const _Achievement(
                    'Thực Đơn Đa Dạng',
                    'Nấu hơn 20 món khác nhau từ nguyên liệu tủ lạnh',
                    Icons.restaurant,
                    Colors.pinkAccent,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8FBF4),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFCFF5E4)),
                    ),
                    child: Column(
                      children: [
                        const CircleAvatar(
                          backgroundColor: Color(0xFFC9F8E2),
                          foregroundColor: _green,
                          child: Icon(Icons.share_outlined),
                        ),
                        const SizedBox(height: 9),
                        const Text(
                          'Tóm tắt dữ liệu hiện tại',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Tổng giá trị đang theo dõi: ${vnd(totalValue)}',
                          style: TextStyle(fontSize: 11, color: _muted),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: null,
                          icon: const Icon(Icons.share, size: 17),
                          label: const Text('Chia sẻ sắp ra mắt'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ReportStat extends StatelessWidget {
  const _ReportStat(
    this.label,
    this.value,
    this.note,
    this.icon,
    this.bg,
    this.color,
  );
  final String label, value, note;
  final IconData icon;
  final Color bg, color;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: color, size: 17),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 9, color: _muted),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: _ink,
            ),
          ),
          Text(
            note,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9, color: _muted),
          ),
        ],
      ),
    ),
  );
}

class _CompareBox extends StatelessWidget {
  const _CompareBox(this.title, this.value, this.note, this.bg, this.color);
  final String title, value, note;
  final Color bg, color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 10, color: _muted)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        Text(note, style: const TextStyle(fontSize: 8, color: _muted)),
      ],
    ),
  );
}

class _Bar extends StatelessWidget {
  const _Bar(this.value, this.height, this.month);
  final String value, month;
  final double height;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(value, style: const TextStyle(fontSize: 9, color: _ink)),
        const SizedBox(height: 4),
        SizedBox(
          height: 100 * height,
          child: Container(
            width: 28,
            decoration: const BoxDecoration(
              color: Color(0xFFFFA4A8),
              borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(month, style: const TextStyle(fontSize: 8, color: _muted)),
      ],
    ),
  );
}

class _Retention extends StatelessWidget {
  const _Retention(this.name, this.value, this.color);
  final String name;
  final double value;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      children: [
        Row(
          children: [
            Text(
              name,
              style: const TextStyle(fontSize: 10, color: Color(0xFF667085)),
            ),
            const Spacer(),
            Text(
              '${(value * 100).round()}% giữ lại',
              style: const TextStyle(fontSize: 9, color: _muted),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: value,
          minHeight: 7,
          borderRadius: BorderRadius.circular(8),
          color: color,
          backgroundColor: const Color(0xFFF0F2F4),
        ),
      ],
    ),
  );
}

class _Achievement extends StatelessWidget {
  const _Achievement(this.title, this.note, this.icon, this.color);
  final String title, note;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(note, style: const TextStyle(fontSize: 10, color: _muted)),
              ],
            ),
          ),
          const Icon(Icons.flag_outlined, color: Color(0xFF20C997), size: 18),
        ],
      ),
    ),
  );
}

class _LineChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0xFFEEF0F3)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    void line(List<double> values, Color color) {
      final paint = Paint()
        ..color = color
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final path = Path();
      for (var i = 0; i < values.length; i++) {
        final x = size.width * i / (values.length - 1);
        final y = size.height * (1 - values[i]);
        i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      canvas.drawPath(path, paint);
    }

    line([.35, .46, .58, .65, .82], const Color(0xFF34D399));
    line([.75, .62, .5, .38, .3], const Color(0xFFFFA4A8));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
