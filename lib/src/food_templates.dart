import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_services.dart';
import 'receipt_models.dart';

Future<bool> saveFoodTemplateDialog(
  BuildContext context,
  List<ReceiptLine> lines,
) async {
  final name = TextEditingController();
  final chosen = await showDialog<String>(
    context: context,
    builder: (dialog) => AlertDialog(
      backgroundColor: Colors.white,
      title: const Text('Lưu mẫu thực phẩm'),
      content: TextField(
        controller: name,
        maxLength: 80,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Tên mẫu',
          hintText: 'Ví dụ: Đi chợ cuối tuần',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () {
            if (name.text.trim().isNotEmpty) {
              Navigator.pop(dialog, name.text.trim());
            }
          },
          child: const Text('Lưu mẫu'),
        ),
      ],
    ),
  );
  // Let the closing dialog finish using its controller before disposal.
  await Future<void>.delayed(const Duration(milliseconds: 250));
  name.dispose();
  if (chosen == null || !context.mounted) return false;
  try {
    await FoodTemplateStore.save(chosen, lines);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Đã lưu mẫu của bạn. Hạn dùng sẽ được tính lại khi dùng mẫu.',
          ),
        ),
      );
    }
    return true;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Chưa lưu được mẫu. Vui lòng kiểm tra kết nối và thử lại.',
          ),
        ),
      );
    }
    return false;
  }
}

class SavedFoodTemplate {
  const SavedFoodTemplate(this.name, this.items);
  final String name;
  final List<Map<String, dynamic>> items;
  List<ReceiptLine> buildLines() => items
      .map(
        (v) => ReceiptLine(
          rawName: v['name'] as String,
          normalizedName: v['name'] as String,
          quantity: (v['quantity'] as num).toDouble(),
          unit: v['unit'] as String,
          totalPriceVnd: (v['price'] as num).toInt(),
          estimatedExpiryDate: v['days'] == null
              ? null
              : DateTime.now().add(Duration(days: (v['days'] as num).toInt())),
          confidence: 1,
        ),
      )
      .toList();
}

class FoodTemplateStore {
  static Future<List<SavedFoodTemplate>> load() async {
    if (AppServices.configured) {
      final rows = await AppServices.client
          .from('food_templates')
          .select('name,items')
          .eq('user_id', AppServices.client.auth.currentUser!.id)
          .order('created_at', ascending: false);
      return rows
          .map(
            (r) => SavedFoodTemplate(
              r['name'] as String,
              (r['items'] as List)
                  .map((v) => Map<String, dynamic>.from(v as Map))
                  .toList(),
            ),
          )
          .toList();
    }
    final prefs = await SharedPreferences.getInstance();
    final rows =
        jsonDecode(prefs.getString('vineat.personal.templates.local') ?? '[]')
            as List;
    return rows
        .map(
          (r) => SavedFoodTemplate(
            r['name'] as String,
            (r['items'] as List)
                .map((v) => Map<String, dynamic>.from(v as Map))
                .toList(),
          ),
        )
        .toList();
  }

  static Future<void> save(String name, List<ReceiptLine> lines) async {
    final now = DateTime.now();
    final base = DateTime(now.year, now.month, now.day);
    final items = lines.map((l) {
      final date = l.estimatedExpiryDate;
      final days = date == null
          ? null
          : DateTime(date.year, date.month, date.day).difference(base).inDays;
      return {
        'name': l.normalizedName,
        'quantity': l.quantity,
        'unit': l.unit,
        'price': l.totalPriceVnd,
        'days': days != null && days > 0 ? days : null,
      };
    }).toList();
    // Templates store relative days, never reuse an old invoice's absolute expiry.
    if (AppServices.configured) {
      await AppServices.client.from('food_templates').insert({
        'user_id': AppServices.client.auth.currentUser!.id,
        'name': name,
        'items': items,
      });
    } else {
      final prefs = await SharedPreferences.getInstance();
      final rows =
          jsonDecode(prefs.getString('vineat.personal.templates.local') ?? '[]')
              as List;
      rows.insert(0, {'name': name, 'items': items});
      await prefs.setString(
        'vineat.personal.templates.local',
        jsonEncode(rows),
      );
    }
  }
}
