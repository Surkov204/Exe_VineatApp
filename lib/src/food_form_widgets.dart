import 'package:flutter/material.dart';

Widget foodDatePickerTheme(BuildContext context, Widget? child) => Theme(
  data: Theme.of(context).copyWith(
    datePickerTheme: DatePickerThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: const Color(0xFFE4F7EE),
      headerForegroundColor: const Color(0xFF079669),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
  ),
  child: child!,
);

String foodPersonName(String? value) =>
    value == null || value.trim().isEmpty || value.contains('@')
    ? 'Chưa ghi nhận'
    : value.trim();

class FoodChoiceField extends StatelessWidget {
  const FoodChoiceField({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.errorText,
  });
  final String label;
  final List<String> options;
  final String? value, errorText;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(14),
    onTap: () async {
      FocusManager.instance.primaryFocus?.unfocus();
      final chosen = await showModalBottomSheet<String>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: Colors.white,
        builder: (sheet) => FractionallySizedBox(
          heightFactor: .65,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Chọn $label',
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  children: options
                      .map(
                        (option) => ListTile(
                          title: Text(
                            option,
                            style: TextStyle(
                              fontWeight: option == value
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          trailing: option == value
                              ? const Icon(
                                  Icons.check_circle,
                                  color: Color(0xFF079669),
                                )
                              : null,
                          onTap: () => Navigator.pop(sheet, option),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      );
      if (chosen != null) onChanged(chosen);
    },
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF7FAF9),
        errorText: errorText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        suffixIcon: const Icon(Icons.keyboard_arrow_down),
      ),
      child: Text(
        value ?? 'Chọn $label',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: value == null ? Colors.grey : const Color(0xFF253043),
        ),
      ),
    ),
  );
}
