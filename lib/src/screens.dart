import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'app_services.dart';
import 'food_detail.dart';
import 'food_image.dart';
import 'global_search.dart';
import 'household_data_repository.dart';
import 'inventory_store.dart';
import 'profile_screen.dart';
import 'receipt_models.dart';
import 'receipt_ocr_service.dart';
import 'recipe_detail.dart';

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
  });
  final String? title;
  final String? subtitle;
  final bool search;

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
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: _green,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(Icons.eco, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'ViNeat',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: _ink,
                    ),
                  ),
                  const Spacer(),
                  if (showSearch)
                    IconButton.filledTonal(
                      onPressed: () => showGlobalSearch(context),
                      icon: const Icon(Icons.search),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFF3F4F6),
                      ),
                    ),
                  if (showSearch) const SizedBox(width: 4),
                  if (constraints.maxWidth >= 220)
                    IconButton.filledTonal(
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
  const SectionTitle(this.title, {super.key, this.trailing});
  final String title;
  final String? trailing;
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
        Text(
          trailing!,
          style: const TextStyle(
            fontSize: 12,
            color: _green,
            fontWeight: FontWeight.w700,
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

class _FridgeScreenState extends State<FridgeScreen> {
  Future<void> _addFood() async {
    final food = await showDialog<FoodSummary>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => const _AddFoodDialog(),
    );
    if (food == null || !mounted) return;
    addFoodsToInventory([food]);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Đã thêm ${food.$1} vào tủ lạnh')));
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
    final now = DateTime.now();
    final today = '${dayNames[now.weekday - 1]}, ${now.day} tháng ${now.month}';
    return ValueListenableBuilder<int>(
      valueListenable: inventoryRevision,
      builder: (_, _, _) {
        final expiredCount = inventoryFoods
            .where((food) => food.$3 == 'Hết hạn')
            .length;
        final warningCount = inventoryFoods
            .where((food) => food.$3.contains('Còn'))
            .length;
        final freshCount = inventoryFoods.length - expiredCount - warningCount;
        int priceOf(FoodSummary food) {
          final parts = food.$2.split('·');
          final raw = parts.length > 1 ? parts.last : parts.first;
          return int.tryParse(raw.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        }

        String vnd(int value) =>
            '${value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')}đ';
        final totalValue = inventoryFoods.fold<int>(
          0,
          (sum, food) => sum + priceOf(food),
        );
        final expiredValue = inventoryFoods
            .where((food) => food.$3 == 'Hết hạn')
            .fold<int>(0, (sum, food) => sum + priceOf(food));
        final wasteRatio = totalValue == 0 ? 0.0 : expiredValue / totalValue;
        return Stack(
          children: [
            Column(
              children: [
                BrandHeader(
                  title: 'Tủ lạnh của bạn',
                  subtitle: today,
                  search: true,
                ),
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
                          childAspectRatio: constraints.maxWidth < 400
                              ? 1.35
                              : 2.35,
                          children: [
                            _StatTile(
                              'Tổng số món',
                              '${inventoryFoods.length}',
                              Icons.kitchen_outlined,
                              Color(0xFFE9FAF3),
                              _green,
                            ),
                            _StatTile(
                              'Còn tươi',
                              '$freshCount',
                              Icons.eco_outlined,
                              Color(0xFFE9FAF0),
                              Color(0xFF16A34A),
                            ),
                            _StatTile(
                              'Sắp hết hạn',
                              '$warningCount',
                              Icons.warning_amber,
                              Color(0xFFFFF8E8),
                              Color(0xFFF59E0B),
                            ),
                            _StatTile(
                              'Đã hết hạn',
                              '$expiredCount',
                              Icons.cancel_outlined,
                              Color(0xFFFFF0F1),
                              Color(0xFFEF5350),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
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
                                      '$warningCount sắp hết hạn',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: _muted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 7,
                                runSpacing: 7,
                                children: inventoryFoods
                                    .where((food) => food.$3 != 'Tươi ngon')
                                    .take(5)
                                    .map(
                                      (food) => _AlertChip(
                                        food.$1,
                                        food.$3 == 'Hết hạn',
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const SectionTitle(
                        'Thực phẩm trong tủ',
                        trailing: 'Xem tất cả',
                      ),
                      const SizedBox(height: 8),
                      ...inventoryFoods.map(
                        (f) => _FoodTile(
                          name: f.$1,
                          detail: f.$2,
                          status: f.$3,
                          image: f.$4,
                          onDeleted: () {
                            removeFoodFromInventory(f);
                          },
                          onUpdated: (food) => updateFoodInInventory(f, (
                            food.name,
                            '${food.quantity} · ${food.price}',
                            food.status,
                            food.image,
                          )),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Card(
                        color: const Color(0xFFFFF9E8),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            children: [
                              SectionTitle(
                                'Dọn tủ lạnh cuối tuần',
                                trailing: '6 món cần xử lý',
                              ),
                              SizedBox(height: 10),
                              _MealSuggestion(
                                '30 phút',
                                'Thịt heo ba chỉ kho trứng',
                                'Thịt heo ba chỉ · Trứng gà · Nước mắm',
                              ),
                              _MealSuggestion(
                                '15 phút',
                                'Canh rau muống nấu tôm',
                                'Rau muống · Tôm sú · Hành lá',
                              ),
                            ],
                          ),
                        ),
                      ),
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
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              right: 20,
              bottom: 18,
              child: FloatingActionButton(
                heroTag: 'add-food',
                onPressed: _addFood,
                backgroundColor: _green,
                foregroundColor: Colors.white,
                child: const Icon(Icons.add, size: 30),
              ),
            ),
          ],
        );
      },
    );
  }
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
        const SnackBar(content: Text('Không thể mở ảnh trên thiết bị này')),
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
    if (imagePath != null) customFoodImagePaths[foodName] = imagePath;
    Navigator.pop<FoodSummary>(context, (
      foodName,
      '${quantity.text.trim()} $unit · $displayPrice',
      status,
      image,
    ));
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
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(11)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final missingExpiry = submitted && expiryDate == null;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: _decoration('Danh mục'),
                      items:
                          const [
                                'Rau củ',
                                'Thịt cá',
                                'Đồ khô',
                                'Đồ uống',
                                'Khác',
                              ]
                              .map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value),
                                ),
                              )
                              .toList(),
                      onChanged: (value) =>
                          setState(() => category = value ?? category),
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
                          child: DropdownButtonFormField<String>(
                            initialValue: unit,
                            decoration: _decoration('Đơn vị', required: true)
                                .copyWith(
                                  errorText: submitted && unit == null
                                      ? 'Bắt buộc'
                                      : null,
                                ),
                            hint: const Text('Chọn đơn vị'),
                            items:
                                const [
                                      'gram',
                                      'kg',
                                      'quả',
                                      'bó',
                                      'cây',
                                      'hộp',
                                      'chai',
                                      'miếng',
                                    ]
                                    .map(
                                      (value) => DropdownMenuItem(
                                        value: value,
                                        child: Text(value),
                                      ),
                                    )
                                    .toList(),
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

class _StatTile extends StatelessWidget {
  const _StatTile(this.label, this.value, this.icon, this.bg, this.color);
  final String label, value;
  final IconData icon;
  final Color bg, color;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(11),
    ),
    padding: const EdgeInsets.all(11),
    child: Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: _muted),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _AlertChip extends StatelessWidget {
  const _AlertChip(this.text, this.expired);
  final String text;
  final bool expired;
  @override
  Widget build(BuildContext context) => Container(
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
  );
}

class _FoodTile extends StatelessWidget {
  const _FoodTile({
    required this.name,
    required this.detail,
    required this.status,
    required this.image,
    required this.onDeleted,
    required this.onUpdated,
  });
  final String name, detail, status;
  final int image;
  final VoidCallback onDeleted;
  final ValueChanged<FoodDetailData> onUpdated;
  @override
  Widget build(BuildContext context) {
    final warning = status.contains('Còn');
    final expired = status == 'Hết hạn';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          final original = (name, detail, status, image);
          final result = await Navigator.of(context).push<Object?>(
            MaterialPageRoute(
              builder: (_) => FoodDetailScreen(
                food: FoodDetailData.fromSummary(
                  name: name,
                  detail: detail,
                  status: status,
                  image: image,
                ),
              ),
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
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: FoodImage(
                  name: name,
                  assetIndex: image,
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
                    Text(
                      detail,
                      style: const TextStyle(fontSize: 10, color: _muted),
                    ),
                    const SizedBox(height: 7),
                    LinearProgressIndicator(
                      value: warning
                          ? .65
                          : expired
                          ? .12
                          : .9,
                      minHeight: 3,
                      color: expired
                          ? Colors.redAccent
                          : warning
                          ? Colors.amber
                          : const Color(0xFF34D399),
                      backgroundColor: const Color(0xFFF1F3F5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
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

class _MealSuggestion extends StatelessWidget {
  const _MealSuggestion(this.time, this.name, this.ingredients);
  final String time, name, ingredients;
  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(10),
    onTap: () => Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecipeDetailScreen(
          recipe: RecipeDetailData.fromSummary(
            name: name,
            time: time,
            level: 'Vừa',
            match: '75% có sẵn',
            image: name.contains('Canh')
                ? 11
                : name.contains('Bò')
                ? 12
                : 13,
            ingredientsText: ingredients,
          ),
        ),
      ),
    ),
    child: Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🍴 $time',
            style: const TextStyle(
              fontSize: 10,
              color: Colors.orange,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w800, color: _ink),
          ),
          const SizedBox(height: 4),
          Text(
            ingredients,
            style: const TextStyle(fontSize: 10, color: _muted),
          ),
        ],
      ),
    ),
  );
}

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

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
  final selected = <int>{0, 1, 2, 3, 4, 5, 6, 7};
  final timers = <Timer>[];
  late final AnimationController rotation;

  final results = <ReceiptLine>[];

  Future<void> _chooseTemplate() async {
    final template = await showModalBottomSheet<List<(String, String, String)>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _FoodTemplateSheet(),
    );
    if (template == null || !mounted) return;
    setState(() {
      scanResult = null;
      results
        ..clear()
        ..addAll(template.map(_lineFromLegacy));
      selected
        ..clear()
        ..addAll(List.generate(results.length, (index) => index));
      stage = 2;
    });
  }

  Future<void> _manualEntry() async {
    final items = await showDialog<List<(String, String, String)>>(
      context: context,
      barrierColor: Colors.black45,
      builder: (_) => const _ManualFoodDialog(),
    );
    if (items == null || items.isEmpty || !mounted) return;
    setState(() {
      scanResult = null;
      results
        ..clear()
        ..addAll(items.map(_lineFromLegacy));
      selected
        ..clear()
        ..addAll(List.generate(results.length, (index) => index));
      stage = 2;
    });
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
          content: Text('Không đọc được ảnh hóa đơn. Hãy thử ảnh rõ hơn.'),
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
      final days = item.estimatedExpiryDate?.difference(DateTime.now()).inDays;
      final status = days == null
          ? 'Tươi ngon'
          : days < 0
          ? 'Hết hạn'
          : days <= 3
          ? 'Còn ${days < 1 ? 1 : days} ngày'
          : 'Tươi ngon';
      return (
        item.normalizedName,
        '${_decimal(item.quantity)} ${item.unit} · ${_formatVnd(item.totalPriceVnd)}',
        status,
        inventoryFoods.length % 10,
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
        addFoodsToInventory(foods);
      }
    } catch (_) {
      HouseholdDataRepository.instance.syncStatus.value =
          'Hóa đơn chưa được lưu trên máy chủ. Thông tin đang giữ ở bước rà soát; thử lưu lại khi có mạng.';
      if (mounted) {
        setState(() => importing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chưa lưu được hóa đơn. Hãy thử lại.')),
        );
      }
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã thêm ${selected.length} thực phẩm vào tủ lạnh'),
      ),
    );
    setState(() {
      importing = false;
      stage = 0;
      receiptImage = null;
      scanResult = null;
    });
  }

  ReceiptLine _lineFromLegacy((String, String, String) item) {
    final detail = item.$2.split('·').first.trim().split(' ');
    return ReceiptLine(
      rawName: item.$1,
      normalizedName: item.$1,
      quantity: double.tryParse(detail.first) ?? 1,
      unit: detail.length > 1 ? detail[1] : 'phần',
      totalPriceVnd:
          int.tryParse(item.$3.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
      estimatedExpiryDate: DateTime.now().add(const Duration(days: 7)),
    );
  }

  String _decimal(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2);
  String _formatVnd(int value) =>
      '${value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')}đ';

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
          content: Text('OCR chưa đọc được hóa đơn. Hãy chụp gần và rõ hơn.'),
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
      selected
        ..clear()
        ..addAll(List.generate(results.length, (index) => index));
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const BrandHeader(title: 'Scan hóa đơn', search: true),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _InputMethodCard(
              onScan: () => _pickReceipt(ImageSource.gallery),
              onTemplate: _chooseTemplate,
              onManual: _manualEntry,
            ),
            const SizedBox(height: 14),
            if (stage == 0) ...[
              Container(
                height: 360,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  children: [
                    if (receiptImage != null)
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(
                            File(receiptImage!.path),
                            fit: BoxFit.cover,
                            color: Colors.black38,
                            colorBlendMode: BlendMode.darken,
                          ),
                        ),
                      ),
                    const Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: EdgeInsets.only(top: 18),
                        child: Text(
                          'Đặt hóa đơn trong khung',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Container(
                        width: 280,
                        height: 180,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFF9AA0A6),
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 14,
                      top: 55,
                      child: Column(
                        children: [
                          IconButton.filled(
                            tooltip: 'Chọn ảnh hóa đơn từ thư viện',
                            onPressed: () => _pickReceipt(ImageSource.gallery),
                            icon: const Icon(Icons.image_outlined),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white24,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                height: 100,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton.filledTonal(
                      tooltip: 'Chọn ảnh hóa đơn từ thư viện',
                      onPressed: () => _pickReceipt(ImageSource.gallery),
                      icon: const Icon(Icons.image_outlined),
                    ),
                    const SizedBox(width: 28),
                    InkWell(
                      onTap: () => _pickReceipt(ImageSource.camera),
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFE4E7EC),
                            width: 5,
                          ),
                        ),
                        child: Center(
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: _green,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFD5D9E0),
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (stage == 1)
              _ScanningCard(rotation: rotation, step: scanStep)
            else
              _ScanResults(
                items: results,
                selected: selected,
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
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SectionTitle('Cửa hàng hỗ trợ'),
                    SizedBox(height: 12),
                    _Store(Icons.storefront_outlined, 'Winmart'),
                    _Store(Icons.store_outlined, 'Bách Hóa Xanh'),
                    _Store(Icons.apartment, 'Mega Market'),
                    _Store(Icons.apartment, 'Big C / GO!'),
                    _Store(Icons.apartment, 'Lotte Mart'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    SectionTitle('Quét gần đây', trailing: 'Xem tất cả'),
                    SizedBox(height: 10),
                    _RecentScan(
                      'Winmart',
                      '${_shortDate(DateTime.now().subtract(const Duration(days: 2)))} · 12 món',
                      '385.000đ',
                    ),
                    _RecentScan(
                      'Bách Hóa Xanh',
                      '${_shortDate(DateTime.now().subtract(const Duration(days: 5)))} · 8 món',
                      '156.000đ',
                    ),
                    _RecentScan(
                      'Co.op Mart',
                      '${_shortDate(DateTime.now().subtract(const Duration(days: 9)))} · 15 món',
                      '520.000đ',
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
          Row(
            children: [
              _InputMethod(
                icon: Icons.receipt_long_outlined,
                label: 'Quét hóa đơn',
                note: 'Chụp hoặc tải ảnh',
                active: true,
                onTap: onScan,
              ),
              const SizedBox(width: 8),
              _InputMethod(
                icon: Icons.dashboard_customize_outlined,
                label: 'Theo mẫu',
                note: 'Chọn danh sách có sẵn',
                onTap: onTemplate,
              ),
              const SizedBox(width: 8),
              _InputMethod(
                icon: Icons.edit_note_outlined,
                label: 'Thủ công',
                note: 'Tự nhập từng món',
                onTap: onManual,
              ),
              const SizedBox(width: 8),
              _InputMethod(
                icon: Icons.mic_none,
                label: 'Giọng nói',
                note: 'Chưa hỗ trợ',
                disabled: true,
                onTap: () {},
              ),
            ],
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
    this.disabled = false,
  });

  final IconData icon;
  final String label, note;
  final VoidCallback onTap;
  final bool active, disabled;

  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        height: 92,
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 9),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFFE9FBF4)
              : disabled
              ? const Color(0xFFF7F8FA)
              : Colors.white,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: active ? const Color(0xFF8BE1C3) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 23, color: disabled ? _muted : _green),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: disabled ? _muted : _ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              note,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 8, color: _muted),
            ),
          ],
        ),
      ),
    ),
  );
}

class _FoodTemplateSheet extends StatelessWidget {
  const _FoodTemplateSheet();

  static const templates = [
    (
      'Đi chợ hàng tuần',
      '8 món thiết yếu cho cả nhà',
      Icons.shopping_basket_outlined,
      [
        ('Thịt heo', '500g · HSD dự kiến: 7 ngày', '65.000đ'),
        ('Trứng gà', '10 quả · HSD dự kiến: 21 ngày', '35.000đ'),
        ('Rau muống', '2 bó · HSD dự kiến: 3 ngày', '15.000đ'),
        ('Cà chua', '5 quả · HSD dự kiến: 7 ngày', '25.000đ'),
        ('Cải thảo', '1 cây · HSD dự kiến: 7 ngày', '20.000đ'),
        ('Sữa tươi', '2 hộp · HSD dự kiến: 10 ngày', '32.000đ'),
        ('Đậu hũ', '4 miếng · HSD dự kiến: 3 ngày', '10.000đ'),
        ('Hành lá', '2 bó · HSD dự kiến: 3 ngày', '15.000đ'),
      ],
    ),
    (
      'Bữa sáng nhanh',
      '5 món cho bữa sáng trong tuần',
      Icons.free_breakfast_outlined,
      [
        ('Trứng gà', '10 quả · HSD dự kiến: 21 ngày', '35.000đ'),
        ('Bánh mì', '5 ổ · HSD dự kiến: 3 ngày', '20.000đ'),
        ('Sữa tươi', '5 hộp · HSD dự kiến: 10 ngày', '40.000đ'),
        ('Chuối', '1 nải · HSD dự kiến: 5 ngày', '25.000đ'),
        ('Yến mạch', '500g · HSD dự kiến: 180 ngày', '55.000đ'),
      ],
    ),
    (
      'Lẩu cuối tuần',
      '6 nguyên liệu cho 4 người',
      Icons.soup_kitchen_outlined,
      [
        ('Thịt bò', '500g · HSD dự kiến: 3 ngày', '125.000đ'),
        ('Tôm sú', '500g · HSD dự kiến: 2 ngày', '110.000đ'),
        ('Nấm kim châm', '3 gói · HSD dự kiến: 5 ngày', '30.000đ'),
        ('Rau cải', '2 bó · HSD dự kiến: 3 ngày', '24.000đ'),
        ('Đậu hũ', '4 miếng · HSD dự kiến: 3 ngày', '10.000đ'),
        ('Mì gói', '4 gói · HSD dự kiến: 180 ngày', '20.000đ'),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          ...templates.map(
            (template) => Card(
              margin: const EdgeInsets.only(bottom: 9),
              child: ListTile(
                onTap: () => Navigator.pop(context, template.$4),
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFE7FAF3),
                  foregroundColor: _green,
                  child: Icon(template.$3),
                ),
                title: Text(
                  template.$1,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(template.$2),
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
          ),
        ],
      ),
    ),
  );
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
  final items = <(String, String, String)>[];
  String unit = 'gram';
  String expiry = '3 ngày';

  @override
  void dispose() {
    name.dispose();
    quantity.dispose();
    price.dispose();
    super.dispose();
  }

  void _addItem() {
    if (name.text.trim().isEmpty || quantity.text.trim().isEmpty) return;
    final formattedPrice = price.text.trim().isEmpty
        ? 'Chưa nhập giá'
        : '${price.text.trim()}đ';
    setState(() {
      items.add((
        name.text.trim(),
        '${quantity.text.trim()} $unit · HSD dự kiến: $expiry',
        formattedPrice,
      ));
      name.clear();
      quantity.clear();
      price.clear();
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nhập thực phẩm thủ công'),
    content: SizedBox(
      width: 470,
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
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: quantity,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Số lượng *'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: unit,
                    decoration: const InputDecoration(labelText: 'Đơn vị'),
                    items: const ['gram', 'kg', 'quả', 'bó', 'hộp', 'chai']
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => unit = value ?? unit,
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
                  child: DropdownButtonFormField<String>(
                    initialValue: expiry,
                    decoration: const InputDecoration(labelText: 'Hạn dùng'),
                    items:
                        const [
                              '2 ngày',
                              '3 ngày',
                              '7 ngày',
                              '14 ngày',
                              '30 ngày',
                            ]
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                    onChanged: (value) => expiry = value ?? expiry,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
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
                  title: Text(entry.value.$1),
                  subtitle: Text(entry.value.$2),
                  trailing: IconButton(
                    onPressed: () => setState(() => items.removeAt(entry.key)),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ),
              ),
            ],
          ],
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
    required this.onToggle,
    required this.onToggleAll,
    required this.onReset,
    required this.onConfirm,
    required this.onEdit,
  });
  final List<ReceiptLine> items;
  final Set<int> selected;
  final ValueChanged<int> onToggle;
  final VoidCallback onToggleAll, onReset, onConfirm;
  final ValueChanged<int> onEdit;

  @override
  Widget build(BuildContext context) {
    final total = selected.fold<int>(
      0,
      (sum, index) => sum + items[index].totalPriceVnd,
    );
    final formattedTotal = total.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => '.',
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Kết quả quét',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: _ink,
                        ),
                      ),
                      Text(
                        'Đã chuẩn bị ${items.length} mặt hàng',
                        style: const TextStyle(fontSize: 11, color: _muted),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: onToggleAll,
                  child: Text(
                    selected.length == items.length
                        ? 'Bỏ chọn tất cả'
                        : 'Chọn tất cả',
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F3F5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '${selected.length}/${items.length}',
                    style: const TextStyle(fontSize: 11, color: _muted),
                  ),
                ),
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
                  border: Border(bottom: BorderSide(color: Color(0xFFF0F1F3))),
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
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: _ink,
                            ),
                          ),
                          Text(
                            '${entry.value.quantity == entry.value.quantity.roundToDouble() ? entry.value.quantity.toInt() : entry.value.quantity} ${entry.value.unit} · HSD ${entry.value.estimatedExpiryDate == null ? 'chưa rõ' : _shortDate(entry.value.estimatedExpiryDate!)} · ${(entry.value.confidence * 100).round()}%',
                            style: const TextStyle(fontSize: 11, color: _muted),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          '${entry.value.totalPriceVnd.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')}đ',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF475467),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Sửa kết quả OCR',
                          onPressed: () => onEdit(entry.key),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
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

class _Store extends StatelessWidget {
  const _Store(this.icon, this.name);
  final IconData icon;
  final String name;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFE8FBF4),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _green, size: 19),
        ),
        const SizedBox(width: 12),
        Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w600, color: _ink),
        ),
      ],
    ),
  );
}

class _RecentScan extends StatelessWidget {
  const _RecentScan(this.name, this.date, this.price);
  final String name, date, price;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        const Icon(Icons.receipt_long_outlined, color: Colors.orange),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              Text(date, style: const TextStyle(fontSize: 11, color: _muted)),
            ],
          ),
        ),
        Text(
          price,
          style: const TextStyle(fontWeight: FontWeight.w700, color: _ink),
        ),
      ],
    ),
  );
}

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key});
  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  int category = 0;
  String query = '';
  final recipes = const [
    (
      'Mì cay trứng lòng đào',
      '15 phút',
      'Dễ',
      '90% có sẵn',
      10,
      'Mì · Trứng gà · Hành lá · Nước mắm',
    ),
    (
      'Canh rau muống nấu tôm',
      '15 phút',
      'Dễ',
      '100% có sẵn',
      11,
      'Rau muống · Tôm sú · Hành lá',
    ),
    (
      'Bò xào cải thảo',
      '20 phút',
      'Dễ',
      '80% có sẵn',
      12,
      'Thịt bò Mỹ · Cải thảo · Dưa leo',
    ),
    (
      'Bánh mì ốp la trứng gà',
      '10 phút',
      'Dễ',
      '75% có sẵn',
      13,
      'Trứng gà · Bánh mì · Hành lá',
    ),
    (
      'Cá basa kho tiêu',
      '25 phút',
      'Vừa',
      '90% có sẵn',
      14,
      'Cá basa fillet · Nước mắm · Hành lá',
    ),
    (
      'Salad cá thu dầu mè',
      '5 phút',
      'Dễ',
      '90% có sẵn',
      15,
      'Cá chua · Dưa leo · Hành lá',
    ),
    (
      'Đậu hũ sốt cà chua',
      '20 phút',
      'Dễ',
      '100% có sẵn',
      4,
      'Đậu hũ · Cà chua · Hành lá',
    ),
    (
      'Phở bò tái',
      '45 phút',
      'Khó',
      '60% có sẵn',
      2,
      'Thịt bò Mỹ · Bánh phở · Hành lá',
    ),
  ];

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: inventoryRevision,
    builder: (context, _, _) {
      final filteredRecipes = recipes.where((recipe) {
        final detail = RecipeDetailData.fromSummary(
          name: recipe.$1,
          time: recipe.$2,
          level: recipe.$3,
          match: recipe.$4,
          image: recipe.$5,
          ingredientsText: recipe.$6,
        );
        final matchesSearch =
            query.trim().isEmpty ||
            detail.name.toLowerCase().contains(query.trim().toLowerCase()) ||
            detail.ingredients.any(
              (item) =>
                  item.name.toLowerCase().contains(query.trim().toLowerCase()),
            );
        final matchesCategory = switch (category) {
          1 => recipe.$5 == 11 || recipe.$5 == 15 || recipe.$5 == 4,
          2 => recipe.$5 == 10 || recipe.$5 == 13 || recipe.$5 == 2,
          3 => recipe.$5 == 12 || recipe.$5 == 14 || recipe.$5 == 4,
          _ => true,
        };
        return matchesSearch && matchesCategory;
      }).toList();
      return Column(
        children: [
          const BrandHeader(title: 'Gợi ý món ăn'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(14),
              children: [
                TextField(
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
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7FAF3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Có ${recipes.length} món phù hợp',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: _ink,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Ưu tiên món có từ 50% nguyên liệu trong tủ',
                        style: TextStyle(fontSize: 10, color: _muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
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
                        'Không tìm thấy món phù hợp',
                        style: TextStyle(color: _muted),
                      ),
                    ),
                  ),
                ...filteredRecipes.map(
                  (r) => _RecipeCard(
                    name: r.$1,
                    time: r.$2,
                    level: r.$3,
                    match: r.$4,
                    image: r.$5,
                    ingredients: r.$6,
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
  );
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({
    required this.name,
    required this.time,
    required this.level,
    required this.match,
    required this.image,
    required this.ingredients,
  });
  final String name, time, level, match, ingredients;
  final int image;
  @override
  Widget build(BuildContext context) {
    final recipe = RecipeDetailData.fromSummary(
      name: name,
      time: time,
      level: level,
      match: match,
      image: image,
      ingredientsText: ingredients,
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: recipe)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Image.asset(
                  '$_assetRoot${image == 0 ? 'search-image' : 'search-image($image)'}',
                  height: 158,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
                Positioned(
                  top: 9,
                  left: 9,
                  child: _TinyBadge('$time  ·  $level', Colors.white, _ink),
                ),
                Positioned(
                  top: 9,
                  right: 9,
                  child: _TinyBadge(recipe.match, _green, Colors.white),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Món ăn gợi ý từ những nguyên liệu đang có trong tủ lạnh của bạn.',
                    style: TextStyle(fontSize: 10, color: _muted),
                  ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: ingredients
                        .split(' · ')
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
  const ShoppingScreen({super.key});
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
                  .asMap()
                  .entries
                  .where((entry) => entry.value.checked)
                  .map((entry) => entry.key),
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
        ..addAll(snapshot.checked.where((index) => index < items.length));
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
      setState(() {
        items.add(result);
        selectedCategory = 0;
      });
      _shoppingMutationRevision++;
      _persistShopping();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã thêm ${result.$1} vào danh sách')),
      );
    }
  }

  void _deleteShoppingItem(int index) {
    final removed = items[index];
    final wasChecked = checked.contains(index);
    setState(() {
      items.removeAt(index);
      final shiftedChecked = checked
          .where((value) => value != index)
          .map((value) => value > index ? value - 1 : value)
          .toSet();
      checked
        ..clear()
        ..addAll(shiftedChecked);
    });
    _shoppingMutationRevision++;
    _persistShopping();
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã xóa ${removed.$1}'),
        action: SnackBarAction(
          label: 'Hoàn tác',
          onPressed: () {
            setState(() {
              final shiftedChecked = checked
                  .map((value) => value >= index ? value + 1 : value)
                  .toSet();
              checked
                ..clear()
                ..addAll(shiftedChecked);
              items.insert(index, removed);
              if (wasChecked) checked.add(index);
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
    final indexedItems = items.asMap().entries.where((entry) {
      return selectedCategory == 0 ||
          entry.value.$5 == categories[selectedCategory];
    }).toList();
    final remaining = items.length - checked.length;
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
                        Text(
                          '$remaining món',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: _ink,
                          ),
                        ),
                        SizedBox(width: 5),
                        Text('cần mua', style: TextStyle(color: _muted)),
                      ],
                    ),
                  );
                  final addButton = FilledButton.icon(
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

                  return Row(children: [counter, const Spacer(), addButton]);
                },
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 42,
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
                child: Column(
                  children: indexedItems
                      .map(
                        (e) => _ShoppingItem(
                          index: e.key,
                          item: e.value,
                          checked: checked.contains(e.key),
                          onChanged: () {
                            final purchased = !checked.contains(e.key);
                            setState(() {
                              if (purchased) {
                                checked.add(e.key);
                              } else {
                                checked.remove(e.key);
                              }
                            });
                            setShoppingPurchased(e.value, purchased);
                            _shoppingMutationRevision++;
                            _persistShopping();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  purchased
                                      ? 'Đã chuyển ${e.value.$1} vào tủ lạnh'
                                      : 'Đã bỏ trạng thái đã mua',
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
    final urgent = item.$3 == 'Cần mua gấp';
    return InkWell(
      onTap: onChanged,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 17),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFF0F1F3))),
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
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.$1,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: checked ? _muted : _ink,
                            decoration: checked
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _TinyBadge(
                        item.$3,
                        urgent
                            ? const Color(0xFFFFECEE)
                            : item.$3 == 'Bình thường'
                            ? const Color(0xFFFFF8E5)
                            : const Color(0xFFF1F3F5),
                        urgent
                            ? Colors.redAccent
                            : item.$3 == 'Bình thường'
                            ? Colors.orange
                            : _muted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: _muted),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Thêm bởi ${item.$4}',
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
    final quantity = quantityController.text.trim().isEmpty
        ? '1'
        : quantityController.text.trim();
    final note = noteController.text.trim();
    Navigator.pop(context, (
      name,
      '$quantity $unit${note.isEmpty ? '' : ' · $note'}',
      priority,
      'Bạn',
      category,
    ));
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
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: _inputDecoration('1'),
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
          final parts = food.$2.split('·');
          final raw = parts.length > 1 ? parts.last : parts.first;
          return int.tryParse(raw.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        }

        String vnd(int value) =>
            '${value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')}đ';
        final totalValue = inventoryFoods.fold<int>(
          0,
          (sum, food) => sum + priceOf(food),
        );
        final expiredValue = inventoryFoods
            .where((food) => food.$3 == 'Hết hạn')
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
