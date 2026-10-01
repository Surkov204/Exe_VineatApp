import 'package:flutter/material.dart';

/// Used by the shell to keep the selected tab in sync with the replay tour.
final tutorialPageRequest = ValueNotifier<int?>(null);

/// Real, visible controls that the first-use coachmark points to.
final tutorialTargetKeys = List<GlobalKey>.generate(
  6,
  (index) => GlobalKey(debugLabel: 'vineat-tutorial-target-$index'),
  growable: false,
);

/// Stable anchors for the individual controls/sections on every tab.
final tutorialSectionKeys = List<List<GlobalKey>>.generate(
  6,
  (page) => List<GlobalKey>.generate(
    3,
    (section) => GlobalKey(debugLabel: 'vineat-tour-$page-$section'),
    growable: false,
  ),
  growable: false,
);

/// The home header can restart the guided tour without signing out.
final replayAppTutorialRequest = ValueNotifier<int>(0);

/// The selected page is also used to pause embedded platform views off-screen.
final activeAppTabIndex = ValueNotifier<int>(-1);

/// Requests a home-page add action from the shell-level floating toolbar button.
final homeAddFoodRequest = ValueNotifier<int>(0);

String pageTutorialPreferenceKey({
  required String userId,
  required String pageKey,
}) => 'vineat_page_tutorial_${userId}_${pageKey}_v4';

const _tutorialPages = <_TutorialPage>[
  _TutorialPage(
    title: 'Tủ lạnh',
    description:
        'Xem thực phẩm đang có, hạn dùng và giá trị ước tính. Dùng nút + để thêm món; chạm một món để cập nhật hoặc xóa.',
    icon: Icons.kitchen_outlined,
  ),
  _TutorialPage(
    title: 'Nhập thực phẩm',
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
        'Thêm món cần mua và đánh dấu khi đã mua. Khi đăng nhập, danh sách được đồng bộ với các thành viên gia đình.',
    icon: Icons.shopping_basket_outlined,
  ),
  _TutorialPage(
    title: 'Báo cáo',
    description:
        'Xem giá trị tủ hiện tại và lịch sử từ thao tác đã ghi nhận; các chỉ số ước tính được ghi rõ để bạn dễ đối chiếu.',
    icon: Icons.bar_chart_rounded,
  ),
  _TutorialPage(
    title: 'Xuất nguyên liệu',
    description:
        'Ghi lượng đã dùng theo món hoặc thủ công. Chỉ xác nhận xuất mới trừ tồn; lập thực đơn và đi chợ không trừ tồn.',
    icon: Icons.outbox_outlined,
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

class AnchoredTutorialCoachmark extends StatefulWidget {
  const AnchoredTutorialCoachmark({
    super.key,
    required this.targetKey,
    required this.title,
    required this.description,
    required this.step,
    required this.totalSteps,
    required this.onNext,
    required this.onSkip,
  });

  final GlobalKey targetKey;
  final String title;
  final String description;
  final int step;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  State<AnchoredTutorialCoachmark> createState() =>
      _AnchoredTutorialCoachmarkState();
}

class _AnchoredTutorialCoachmarkState extends State<AnchoredTutorialCoachmark> {
  Rect? _target;

  @override
  void initState() {
    super.initState();
    _measureAfterLayout();
  }

  @override
  void didUpdateWidget(covariant AnchoredTutorialCoachmark oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.targetKey != widget.targetKey ||
        oldWidget.step != widget.step) {
      _target = null;
    }
    _measureAfterLayout();
  }

  void _measureAfterLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final measured = _targetRect();
      if (_target != measured) setState(() => _target = measured);
    });
  }

  Rect? _targetRect() {
    final targetContext = widget.targetKey.currentContext;
    final targetObject = targetContext?.findRenderObject();
    final overlayObject = context.findRenderObject();
    if (targetObject is! RenderBox ||
        !targetObject.attached ||
        !targetObject.hasSize ||
        overlayObject is! RenderBox ||
        !overlayObject.attached ||
        !overlayObject.hasSize) {
      return null;
    }
    final globalTopLeft = targetObject.localToGlobal(Offset.zero);
    final localTopLeft = overlayObject.globalToLocal(globalTopLeft);
    return localTopLeft & targetObject.size;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final target = _target;
      final media = MediaQuery.of(context);
      return Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: CustomPaint(
              painter: _CoachmarkScrimPainter(target),
              child: const SizedBox.expand(),
            ),
          ),
          if (target != null)
            Positioned.fromRect(
              rect: target.inflate(7),
              child: IgnorePointer(
                child: DecoratedBox(
                  key: const ValueKey('tutorial-highlight-outline'),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFF38D39F),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
          CustomSingleChildLayout(
            delegate: _CoachmarkPositionDelegate(
              target: target,
              safeTop: media.padding.top + 12,
              safeBottom: media.padding.bottom + 12,
            ),
            child: _CoachmarkCard(
              title: widget.title,
              description: widget.description,
              step: widget.step,
              totalSteps: widget.totalSteps,
              onNext: widget.onNext,
              onSkip: widget.onSkip,
            ),
          ),
        ],
      );
    },
  );
}

class _CoachmarkPositionDelegate extends SingleChildLayoutDelegate {
  const _CoachmarkPositionDelegate({
    required this.target,
    required this.safeTop,
    required this.safeBottom,
  });

  final Rect? target;
  final double safeTop;
  final double safeBottom;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        maxWidth: (constraints.maxWidth - 32).clamp(0, 360),
        maxHeight: (constraints.maxHeight - safeTop - safeBottom).clamp(0, 420),
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final anchor = target;
    final left = anchor == null
        ? (size.width - childSize.width) / 2
        : (anchor.center.dx - childSize.width / 2).clamp(
            16,
            size.width - childSize.width - 16,
          );
    final below = anchor == null
        ? false
        : anchor.bottom + 12 + childSize.height <= size.height - safeBottom;
    final top = anchor == null || !below
        ? ((anchor?.top ?? size.height / 2) - childSize.height - 14).clamp(
            safeTop,
            size.height - safeBottom - childSize.height,
          )
        : (anchor.bottom + 12).clamp(
            safeTop,
            size.height - safeBottom - childSize.height,
          );
    return Offset(left.toDouble(), top.toDouble());
  }

  @override
  bool shouldRelayout(covariant _CoachmarkPositionDelegate oldDelegate) =>
      oldDelegate.target != target ||
      oldDelegate.safeTop != safeTop ||
      oldDelegate.safeBottom != safeBottom;
}

class _CoachmarkCard extends StatelessWidget {
  const _CoachmarkCard({
    required this.title,
    required this.description,
    required this.step,
    required this.totalSteps,
    required this.onNext,
    required this.onSkip,
  });

  final String title;
  final String description;
  final int step;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFC9F1E1)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline, color: Color(0xFF079669)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF253043),
                  ),
                ),
              ),
              Text(
                '$step/$totalSteps',
                style: const TextStyle(color: Color(0xFF667085), fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(description, style: const TextStyle(fontSize: 13, height: 1.4)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: onSkip, child: const Text('Bỏ qua')),
              const SizedBox(width: 6),
              FilledButton(
                onPressed: onNext,
                child: Text(step == totalSteps ? 'Xong' : 'Tiếp'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _CoachmarkScrimPainter extends CustomPainter {
  const _CoachmarkScrimPainter(this.target);
  final Rect? target;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addRect(Offset.zero & size);
    final anchor = target;
    if (anchor != null) {
      path
        ..addRRect(
          RRect.fromRectAndRadius(anchor.inflate(8), const Radius.circular(18)),
        )
        ..fillType = PathFillType.evenOdd;
    }
    canvas.drawPath(path, Paint()..color = const Color(0xB8000000));
  }

  @override
  bool shouldRepaint(covariant _CoachmarkScrimPainter oldDelegate) =>
      oldDelegate.target != target;
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
