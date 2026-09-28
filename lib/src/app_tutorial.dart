import 'package:flutter/material.dart';

/// Used by the shell to keep the selected tab in sync with the replay tour.
final tutorialPageRequest = ValueNotifier<int?>(null);

const _tutorialPages = <_TutorialPage>[
  _TutorialPage(
    title: 'Tủ lạnh',
    description:
        'Xem thực phẩm đang có, hạn dùng và giá trị ước tính. Dùng nút + để thêm món; chạm một món để cập nhật hoặc xóa.',
    icon: Icons.kitchen_outlined,
  ),
  _TutorialPage(
    title: 'Scan hóa đơn',
    description:
        'Chụp/chọn ảnh hóa đơn, kiểm tra kết quả nhận dạng rồi bỏ chọn hoặc sửa dòng chưa chính xác trước khi nhập vào tủ.',
    icon: Icons.document_scanner_outlined,
  ),
  _TutorialPage(
    title: 'Món ăn',
    description:
        'Tìm món theo nguyên liệu có sẵn, mở thẻ để xem cách nấu và thời gian chuẩn bị.',
    icon: Icons.restaurant_menu,
  ),
  _TutorialPage(
    title: 'Đi chợ',
    description:
        'Thêm món cần mua, đánh dấu khi đã mua. Danh sách demo được lưu trên thiết bị này.',
    icon: Icons.shopping_basket_outlined,
  ),
  _TutorialPage(
    title: 'Báo cáo',
    description:
        'Theo dõi các chỉ số hiện tại. Biểu đồ lịch sử có nhãn minh họa cho đến khi ứng dụng có dữ liệu theo dõi thật.',
    icon: Icons.bar_chart_rounded,
  ),
];

Future<void> showAppTutorial(
  BuildContext context, {
  ValueChanged<int>? onStepChanged,
}) async {
  onStepChanged?.call(0);
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _TutorialDialog(onStepChanged: onStepChanged),
  );
}

class _TutorialPage {
  const _TutorialPage({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;
}

class _TutorialDialog extends StatefulWidget {
  const _TutorialDialog({this.onStepChanged});

  final ValueChanged<int>? onStepChanged;

  @override
  State<_TutorialDialog> createState() => _TutorialDialogState();
}

class _TutorialDialogState extends State<_TutorialDialog> {
  int _index = 0;

  void _next() {
    if (_index == _tutorialPages.length - 1) {
      Navigator.of(context).pop();
      return;
    }
    final nextIndex = _index + 1;
    setState(() => _index = nextIndex);
    widget.onStepChanged?.call(nextIndex);
  }

  void _skip() {
    widget.onStepChanged?.call(0);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final page = _tutorialPages[_index];
    return AlertDialog(
      icon: Icon(page.icon, color: const Color(0xFF079669), size: 32),
      title: Text(_index == 0 ? 'Bắt đầu với ViNeat' : page.title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trang ${_index + 1}/${_tutorialPages.length} · ${page.title}',
            ),
            const SizedBox(height: 10),
            Text(page.description),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _tutorialPages.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: index == _index ? 18 : 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: index == _index
                        ? const Color(0xFF079669)
                        : const Color(0xFFD0D5DD),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _skip, child: const Text('Bỏ qua')),
        FilledButton(
          onPressed: _next,
          child: Text(
            _index == _tutorialPages.length - 1 ? 'Bắt đầu sử dụng' : 'Tiếp',
          ),
        ),
      ],
    );
  }
}
