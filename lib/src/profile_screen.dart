import 'package:flutter/material.dart';

import 'app_tutorial.dart';
import 'app_services.dart';
import 'family_settings.dart';
import 'global_search.dart';
import 'inventory_store.dart';

const _green = Color(0xFF079669);
const _ink = Color(0xFF253043);
const _muted = Color(0xFF98A2B3);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String name = 'Mẹ';
  String role = 'Chủ tủ';
  int diet = 0;
  final notifications = <bool>[true, true, true, true];

  Future<void> _editProfile() async {
    final nameController = TextEditingController(text: name);
    final roleController = TextEditingController(text: role);
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Chỉnh sửa hồ sơ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Tên hiển thị'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: roleController,
              decoration: const InputDecoration(labelText: 'Vai trò'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, (
              nameController.text.trim(),
              roleController.text.trim(),
            )),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    nameController.dispose();
    roleController.dispose();
    if (result != null && result.$1.isNotEmpty && mounted) {
      setState(() {
        name = result.$1;
        role = result.$2.isEmpty ? role : result.$2;
      });
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _resetDemo() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đặt lại tủ lạnh mẫu?'),
        content: const Text(
          'Tủ lạnh sẽ trở về dữ liệu mẫu để bạn chạy lại kịch bản trình diễn.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Đặt lại'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await resetDemoInventory();
    if (mounted) _message('Đã đặt lại tủ lạnh mẫu');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFFAFAFB),
    appBar: AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      leading: IconButton(
        tooltip: 'Quay lại',
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(Icons.arrow_back),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _green,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.eco, color: Colors.white, size: 19),
          ),
          const SizedBox(width: 9),
          const Text(
            'ViNeat',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: _ink,
            ),
          ),
        ],
      ),
      actions: [
        IconButton.filledTonal(
          onPressed: () => showGlobalSearch(context),
          icon: const Icon(Icons.search),
          style: IconButton.styleFrom(backgroundColor: const Color(0xFFF3F4F6)),
        ),
        const SizedBox(width: 4),
        IconButton.filledTonal(
          tooltip: 'Thông báo',
          onPressed: () => _message('Bạn chưa có thông báo mới'),
          icon: const Icon(Icons.notifications_none),
          style: IconButton.styleFrom(backgroundColor: const Color(0xFFF3F4F6)),
        ),
        const SizedBox(width: 4),
        IconButton.filledTonal(
          tooltip: 'Hồ sơ hiện tại',
          onPressed: () => _message('Bạn đang ở trang hồ sơ'),
          icon: const Icon(Icons.person_outline),
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFFD9FAEA),
            foregroundColor: _green,
          ),
        ),
        const SizedBox(width: 10),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(42),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.fromLTRB(17, 4, 17, 12),
            child: Text(
              'Cài đặt',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: _ink,
              ),
            ),
          ),
        ),
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Panel(
          title: 'Hồ sơ cá nhân',
          child: Row(
            children: [
              const CircleAvatar(
                radius: 34,
                backgroundColor: Color(0xFFCBF7E2),
                foregroundColor: _green,
                child: Icon(Icons.person_outline, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: _ink,
                      ),
                    ),
                    Text(
                      '$role · Tham gia từ ${DateTime.now().year}',
                      style: const TextStyle(fontSize: 11, color: _muted),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: _editProfile,
                      child: const Text(
                        'Chỉnh sửa hồ sơ',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _green,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Panel(
          title: 'Chế độ ăn uống',
          child: Column(
            children:
                const [
                  ('Ăn thường', 'Không giới hạn thực phẩm', Icons.restaurant),
                  ('Giảm cân', 'Ưu tiên thực phẩm ít calo', Icons.balance),
                  ('Ăn chay', 'Chỉ thực phẩm chay', Icons.spa_outlined),
                  (
                    'Tăng cơ',
                    'Ưu tiên thực phẩm giàu protein',
                    Icons.fitness_center,
                  ),
                  ('Khác', 'Chế độ tùy chỉnh', Icons.more_horiz),
                ].asMap().entries.map((entry) {
                  final item = entry.value;
                  return _DietOption(
                    title: item.$1,
                    subtitle: item.$2,
                    icon: item.$3,
                    selected: diet == entry.key,
                    onTap: () => setState(() => diet = entry.key),
                  );
                }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        _Panel(
          title: 'Thông báo',
          child: Column(
            children:
                const [
                  (
                    'Cảnh báo thực phẩm sắp hết hạn',
                    'Nhận thông báo khi có món sắp hết hạn trong 3 ngày tới',
                    Icons.timer_outlined,
                  ),
                  (
                    'Dọn tủ lạnh thứ 6',
                    'Popup gợi ý món ăn mỗi tối thứ 6 hàng tuần',
                    Icons.kitchen_outlined,
                  ),
                  (
                    'Thành tựu mới',
                    'Thông báo khi bạn mở khóa thành tựu mới',
                    Icons.emoji_events_outlined,
                  ),
                  (
                    'Hoạt động gia đình',
                    'Khi thành viên thêm/xóa thực phẩm hoặc cập nhật danh sách đi chợ',
                    Icons.people_outline,
                  ),
                ].asMap().entries.map((entry) {
                  final item = entry.value;
                  return _NotificationOption(
                    icon: item.$3,
                    title: item.$1,
                    subtitle: item.$2,
                    value: notifications[entry.key],
                    onChanged: (value) =>
                        setState(() => notifications[entry.key] = value),
                  );
                }).toList(),
          ),
        ),
        const SizedBox(height: 14),
        _Panel(title: 'Gia đình', child: const FamilySettings()),
        const SizedBox(height: 14),
        _Panel(
          title: 'Trợ giúp',
          child: _LinkRow(
            'Xem hướng dẫn từng trang',
            () => showAppTutorial(context),
          ),
        ),
        const SizedBox(height: 14),
        _Panel(
          title: 'Về ViNeat',
          child: Column(
            children: [
              const _AboutRow('Phiên bản', '1.0.0-beta'),
              _AboutRow(
                'Cập nhật lần cuối',
                '${DateTime.now().day.toString().padLeft(2, '0')}/'
                    '${DateTime.now().month.toString().padLeft(2, '0')}/'
                    '${DateTime.now().year}',
              ),
              _LinkRow(
                'Điều khoản sử dụng',
                () => _message('Đang mở điều khoản sử dụng'),
              ),
              _LinkRow(
                'Chính sách bảo mật',
                () => _message('Đang mở chính sách bảo mật'),
              ),
              _LinkRow('Liên hệ hỗ trợ', () => _message('Đang mở kênh hỗ trợ')),
            ],
          ),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: _resetDemo,
          icon: const Icon(Icons.restart_alt),
          label: const Text('Đặt lại tủ lạnh mẫu'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            foregroundColor: _green,
          ),
        ),
        if (AppServices.configured) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () async {
              try {
                await AppServices.client.auth.signOut();
              } catch (_) {
                if (mounted) _message('Chưa đăng xuất được. Vui lòng thử lại.');
              }
            },
            icon: const Icon(Icons.logout),
            label: const Text('Đăng xuất'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              foregroundColor: Colors.redAccent,
            ),
          ),
        ],
        const SizedBox(height: 18),
        const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'Bản demo lưu dữ liệu trên thiết bị này; chưa bật đăng nhập hoặc đồng bộ gia đình.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: _muted),
            ),
          ),
        ),
        const SizedBox(height: 30),
      ],
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    color: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: Color(0xFFEEF0F3)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: _ink,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    ),
  );
}

class _DietOption extends StatelessWidget {
  const _DietOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String title, subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE9FBF4) : const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xFF9DEACD) : const Color(0xFFEEF0F3),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFFCCF7E3)
                    : const Color(0xFFE7EAF0),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                icon,
                size: 19,
                color: selected ? _green : const Color(0xFF7E899A),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: selected ? _green : _ink,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 10, color: _muted),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle,
                size: 17,
                color: Color(0xFF19BB85),
              ),
          ],
        ),
      ),
    ),
  );
}

class _NotificationOption extends StatelessWidget {
  const _NotificationOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFF0F2F5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF7E899A), size: 18),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, color: _ink)),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 10, color: _muted),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          activeTrackColor: const Color(0xFF18BD87),
          onChanged: onChanged,
        ),
      ],
    ),
  );
}

class _AboutRow extends StatelessWidget {
  const _AboutRow(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF667085))),
        const Spacer(),
        Text(value, style: const TextStyle(color: _muted)),
      ],
    ),
  );
}

class _LinkRow extends StatelessWidget {
  const _LinkRow(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF667085))),
          const Spacer(),
          const Icon(Icons.chevron_right, color: _muted, size: 18),
        ],
      ),
    ),
  );
}
