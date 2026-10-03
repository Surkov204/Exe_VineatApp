import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_services.dart';

const expirySource =
    'https://www.foodsafety.gov/food-safety-charts/cold-food-storage-charts';

class ExpiryPreferences {
  const ExpiryPreferences({this.enabled = true, this.automatic = false});
  final bool enabled, automatic;
  static Future<ExpiryPreferences> load() async {
    Map data;
    if (AppServices.configured) {
      final row = await AppServices.client
          .from('profiles')
          .select('expiry_preferences')
          .eq('id', AppServices.client.auth.currentUser!.id)
          .maybeSingle();
      data = row?['expiry_preferences'] as Map? ?? {};
    } else {
      final prefs = await SharedPreferences.getInstance();
      data = jsonDecode(prefs.getString('vineat.expiry.local') ?? '{}') as Map;
    }
    return ExpiryPreferences(
      enabled: data['enabled'] as bool? ?? true,
      automatic: data['automatic'] as bool? ?? false,
    );
  }

  Future<void> save() async {
    final data = {'enabled': enabled, 'automatic': automatic};
    if (AppServices.configured) {
      await AppServices.client
          .from('profiles')
          .update({'expiry_preferences': data})
          .eq('id', AppServices.client.auth.currentUser!.id);
    } else {
      await (await SharedPreferences.getInstance()).setString(
        'vineat.expiry.local',
        jsonEncode(data),
      );
    }
  }
}

// Conservative lower end of FoodSafety.gov refrigerator guidance. Unknown
// products and packaged goods require label dates, not invented predictions.
String normalizeExpiryFoodName(String value) {
  var result = value.toLowerCase();
  const groups = {
    'a': 'àáạảãâầấậẩẫăằắặẳẵ',
    'e': 'èéẹẻẽêềếệểễ',
    'i': 'ìíịỉĩ',
    'o': 'òóọỏõôồốộổỗơờớợởỡ',
    'u': 'ùúụủũưừứựửữ',
    'y': 'ỳýỵỷỹ',
    'd': 'đ',
  };
  for (final entry in groups.entries) {
    result = result.replaceAll(RegExp('[${entry.value}]'), entry.key);
  }
  return result
      .replaceAll(RegExp(r'[\u0300-\u036f]'), '')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();
}

int? suggestedExpiryDays(String name, String condition) {
  final n = normalizeExpiryFoodName(name);
  if (condition == 'Theo bao bì' || n.isEmpty) return null;
  bool has(String words) => RegExp('(?:^| )$words(?: |\$)').hasMatch(n);
  final protein = ['thit', 'ga', 'bo', 'heo', 'lon', 'tom', 'trung'].any(has);
  if (condition == 'Đã nấu chín') {
    if (has('trung luoc')) return 7;
    if (protein || has('canh') || has('sup')) return 3;
    return null;
  }
  if (['chin', 'luoc', 'chien', 'kho'].any(has)) {
    return null;
  }
  if (['thit bam', 'thit xay', 'thit ga', 'uc ga'].any(has)) {
    return 1;
  }
  if (['thit bo', 'thit heo', 'thit lon'].any(has)) {
    return 3;
  }
  if (n == 'trung ga' || n == 'trung vit') return 21;
  return null;
}

class ExpiryAssistant extends StatefulWidget {
  const ExpiryAssistant({
    super.key,
    required this.name,
    required this.baseDate,
    required this.expiry,
    required this.onChanged,
  });
  final TextEditingController name;
  final DateTime baseDate;
  final DateTime? expiry;
  final ValueChanged<DateTime?> onChanged;
  @override
  State<ExpiryAssistant> createState() => _ExpiryAssistantState();
}

class _ExpiryAssistantState extends State<ExpiryAssistant> {
  ExpiryPreferences prefs = const ExpiryPreferences(enabled: false);
  String condition = 'Theo bao bì';
  Timer? timer;
  bool _useSuggestion = false;
  DateTime? _lastSuggestion;
  @override
  void initState() {
    super.initState();
    widget.name.addListener(_changed);
    ExpiryPreferences.load()
        .then((v) {
          if (mounted) {
            setState(() => prefs = v);
            _changed();
          }
        })
        .catchError((_) {});
  }

  void _changed() {
    timer?.cancel();
    timer = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      setState(() {});
      // Never modify the input/controller while a Vietnamese IME composes text.
      if (!widget.name.value.composing.isCollapsed) return;
      final days = suggestedExpiryDays(widget.name.text, condition);
      if (prefs.enabled &&
          (_useSuggestion || prefs.automatic) &&
          (widget.expiry == null || widget.expiry == _lastSuggestion)) {
        final next = days == null ? null : _suggestedDate(days);
        if (next != widget.expiry) {
          _lastSuggestion = next;
          widget.onChanged(next);
        }
      }
    });
  }

  DateTime _suggestedDate(int days) => DateTime(
    widget.baseDate.year,
    widget.baseDate.month,
    widget.baseDate.day,
  ).add(Duration(days: days));

  @override
  void didUpdateWidget(covariant ExpiryAssistant oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.name != widget.name) {
      oldWidget.name.removeListener(_changed);
      widget.name.addListener(_changed);
    }
    if (widget.expiry != null && widget.expiry != _lastSuggestion) {
      _useSuggestion = false;
    }
    if (oldWidget.baseDate.year != widget.baseDate.year ||
        oldWidget.baseDate.month != widget.baseDate.month ||
        oldWidget.baseDate.day != widget.baseDate.day) {
      _changed();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    widget.name.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!prefs.enabled) return const SizedBox.shrink();
    final days = suggestedExpiryDays(widget.name.text, condition);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF8F1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gợi ý hạn dùng thông minh',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          Wrap(
            spacing: 6,
            children: ['Theo bao bì', 'Tươi / sống', 'Đã nấu chín']
                .map(
                  (v) => ChoiceChip(
                    label: Text(v),
                    selected: condition == v,
                    onSelected: (_) {
                      setState(() => condition = v);
                      _changed();
                    },
                  ),
                )
                .toList(),
          ),
          Text(
            days == null
                ? 'Chưa đủ thông tin để gợi ý. Hãy nhập ngày trên bao bì hoặc chọn đúng trạng thái thực phẩm.'
                : 'Tham khảo $days ngày từ ngày mua/chế biến, chỉ khi bảo quản liên tục ở ≤4°C. Trứng tươi: còn nguyên vỏ. Ưu tiên hạn trên bao bì nếu sớm hơn.',
            style: const TextStyle(fontSize: 12),
          ),
          if (days != null)
            TextButton.icon(
              onPressed: () {
                setState(() => _useSuggestion = true);
                _lastSuggestion = _suggestedDate(days);
                widget.onChanged(_lastSuggestion);
              },
              icon: const Icon(Icons.event_available),
              label: Text(
                _useSuggestion
                    ? 'Đang tự điền theo gợi ý'
                    : 'Dùng gợi ý tự động',
              ),
            ),
          const Text(
            'Nguồn: FoodSafety.gov · Không bảo đảm an toàn chỉ dựa vào ngày. Không dùng gợi ý cho đồ đã để ngoài tủ lạnh lâu.',
            style: TextStyle(fontSize: 10, color: Colors.blueGrey),
          ),
        ],
      ),
    );
  }
}
