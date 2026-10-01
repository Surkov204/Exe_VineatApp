import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_services.dart';
import 'household_data_repository.dart';
import 'inventory_store.dart';

const _green = Color(0xFF079669);
const _ink = Color(0xFF253043);
const _muted = Color(0xFF98A2B3);

class FamilySettings extends StatefulWidget {
  const FamilySettings({super.key});
  @override
  State<FamilySettings> createState() => _FamilySettingsState();
}

class _FamilySettingsState extends State<FamilySettings> {
  List<Household> _households = const [];
  List<HouseholdMember> _members = const [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!AppServices.configured) {
      setState(() => _loading = false);
      return;
    }
    if (mounted) setState(() => _loading = true);
    replaceInventoryFromRemote(records: const [], events: const []);
    replaceShoppingFromRemote(items: const [], checked: const {});
    try {
      final households = await HouseholdService.instance.restoreActive();
      List<HouseholdMember> members = const [];
      if (households.isEmpty) {
        replaceInventoryFromRemote(records: const [], events: const []);
        replaceShoppingFromRemote(items: const [], checked: const {});
      } else {
        final active = HouseholdService.instance.active.value;
        if (active != null) {
          members = await HouseholdService.instance.listMembers(active.id);
        }
        final snapshot = await HouseholdDataRepository.instance
            .loadActiveHousehold();
        replaceInventoryFromRemote(
          records: snapshot.inventory,
          events: snapshot.events,
        );
        replaceShoppingFromRemote(
          items: snapshot.shopping.map((item) => item.item).toList(),
          checked: snapshot.shopping
              .where((entry) => entry.checked)
              .map((entry) => entry.item.id)
              .toSet(),
        );
      }
      if (!mounted) return;
      setState(() {
        _households = households;
        _members = members;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Không tải được danh sách gia đình. Kiểm tra kết nối.';
        });
      }
    }
  }

  Future<void> _switchHousehold(String? id) async {
    if (_busy || _loading) return;
    final selected = _households
        .where((household) => household.id == id)
        .firstOrNull;
    setState(() {
      _busy = true;
      _loading = true;
      _error = null;
    });
    replaceInventoryFromRemote(records: const [], events: const []);
    replaceShoppingFromRemote(items: const [], checked: const {});
    try {
      await HouseholdDataRepository.instance.runWithHouseholdRealtimePaused(
        () => HouseholdService.instance.select(selected),
      );
      final snapshot = await HouseholdDataRepository.instance
          .loadActiveHousehold();
      replaceInventoryFromRemote(
        records: snapshot.inventory,
        events: snapshot.events,
      );
      replaceShoppingFromRemote(
        items: snapshot.shopping.map((item) => item.item).toList(),
        checked: snapshot.shopping
            .where((entry) => entry.checked)
            .map((entry) => entry.item.id)
            .toSet(),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Chưa tải được dữ liệu gia đình đã chọn.');
      }
      HouseholdDataRepository.instance.syncStatus.value =
          'Chưa tải được gia đình. Dữ liệu cũ đã được ẩn để tránh hiển thị nhầm; hãy thử lại.';
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _busy = false;
        });
      }
    }
  }

  Future<void> _join() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tham gia gia đình'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Mã gia đình',
            hintText: '16 ký tự',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Tham gia'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (code == null || code.isEmpty || !mounted) return;
    await _mutate(() async {
      await HouseholdDataRepository.instance.runWithHouseholdRealtimePaused(
        () async {
          await HouseholdService.instance.join(code);
        },
      );
      await _load();
    });
  }

  Future<void> _create() async {
    final controller = TextEditingController(text: 'Gia đình của tôi');
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tạo gia đình'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 60,
          decoration: const InputDecoration(labelText: 'Tên gia đình'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Tạo'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || !mounted) return;
    await _mutate(() async {
      await HouseholdDataRepository.instance.runWithHouseholdRealtimePaused(
        () async {
          await HouseholdService.instance.create(name);
        },
      );
      await _load();
    });
  }

  Future<void> _mutate(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Thao tác chưa thành công. Vui lòng thử lại.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rotateCode(Household household) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đổi mã mời?'),
        content: const Text(
          'Mã cũ sẽ hết hiệu lực. Người chưa tham gia sẽ cần mã mới.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Giữ mã cũ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đổi mã'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _mutate(() async {
      await HouseholdService.instance.rotateInviteCode(household.id);
      await _load();
    });
  }

  Future<void> _leave(Household household) async {
    if (household.role == 'owner') return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rời gia đình?'),
        content: Text('Bạn sẽ mất quyền xem dữ liệu của “${household.name}”.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ở lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Rời gia đình'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _mutate(() async {
      await HouseholdDataRepository.instance.runWithHouseholdRealtimePaused(
        () => HouseholdService.instance.leave(household.id),
      );
      await _load();
    });
  }

  Future<void> _changeMemberRole(HouseholdMember member, String role) async {
    final household = HouseholdService.instance.active.value;
    if (household == null) return;
    await _mutate(() async {
      await HouseholdService.instance.setMemberRole(
        householdId: household.id,
        userId: member.userId,
        role: role,
      );
      await _load();
    });
  }

  Future<void> _removeMember(HouseholdMember member) async {
    final household = HouseholdService.instance.active.value;
    if (household == null) return;
    final name = _memberName(member);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa thành viên khỏi gia đình?'),
        content: Text('$name sẽ không còn xem được dữ liệu của gia đình này.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa thành viên'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _mutate(() async {
      await HouseholdService.instance.removeMember(
        householdId: household.id,
        userId: member.userId,
      );
      await _load();
    });
  }

  String _memberName(HouseholdMember member) {
    if (member.userId == AppServices.client.auth.currentUser?.id) return 'Bạn';
    if (member.displayName.trim().isNotEmpty && member.displayName != 'Bạn') {
      return member.displayName;
    }
    return 'Thành viên · ${member.userId.substring(0, 6).toUpperCase()}';
  }

  String _roleLabel(String role) => switch (role) {
    'owner' => 'Chủ gia đình',
    'adult' => 'Người lớn',
    _ => 'Thành viên',
  };

  @override
  Widget build(BuildContext context) {
    if (!AppServices.configured) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mã gia đình cần kết nối với dịch vụ đồng bộ.',
            style: TextStyle(color: _ink, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 5),
          Text(
            'Hiện chưa thể tạo mã mời hoặc tham gia gia đình trên thiết bị này.',
            style: TextStyle(fontSize: 11, color: _muted),
          ),
        ],
      );
    }
    final active = HouseholdService.instance.active.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_loading)
          const _FamilyLoadingSkeleton()
        else if (_households.isNotEmpty) ...[
          Text(
            'Đang quản lý ${_households.length} gia đình',
            style: const TextStyle(fontSize: 12, color: _muted),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: active?.id,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Gia đình đang xem',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.home_work_outlined),
            ),
            items: _households
                .map(
                  (h) => DropdownMenuItem(
                    value: h.id,
                    child: Text(h.name, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: _busy ? null : (id) => _switchHousehold(id),
          ),
          if (active?.inviteCode != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE8FBF4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.key_outlined, color: _green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Mã mời gia đình',
                          style: TextStyle(fontSize: 11, color: _muted),
                        ),
                        SelectableText(
                          active!.inviteCode!,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                            color: _ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Sao chép mã',
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: active.inviteCode!),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Đã sao chép mã mời',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy_outlined),
                  ),
                  if (active.role == 'owner')
                    IconButton(
                      tooltip: 'Đổi mã mời',
                      onPressed: _busy || _loading
                          ? null
                          : () => _rotateCode(active),
                      icon: const Icon(Icons.refresh),
                    ),
                ],
              ),
            ),
          ],
          if (active != null && _members.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Thành viên',
                    style: TextStyle(fontWeight: FontWeight.w800, color: _ink),
                  ),
                ),
                Text(
                  '${_members.length} người',
                  style: const TextStyle(fontSize: 11, color: _muted),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ..._members.map((member) {
              final isOwner = member.role == 'owner';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 17,
                      backgroundColor: const Color(0xFFE8FBF4),
                      child: Icon(
                        isOwner
                            ? Icons.workspace_premium_outlined
                            : Icons.person_outline,
                        size: 18,
                        color: _green,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _memberName(member),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: _ink,
                            ),
                          ),
                          Text(
                            _roleLabel(member.role),
                            style: const TextStyle(fontSize: 11, color: _muted),
                          ),
                        ],
                      ),
                    ),
                    if (active.role == 'owner' && !isOwner)
                      PopupMenuButton<String>(
                        tooltip: 'Quản lý thành viên',
                        enabled: !_busy && !_loading,
                        onSelected: (value) {
                          if (value == 'remove') {
                            _removeMember(member);
                          } else {
                            _changeMemberRole(member, value);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'adult',
                            child: Text(
                              member.role == 'adult'
                                  ? '✓ Người lớn'
                                  : 'Đặt vai trò Người lớn',
                            ),
                          ),
                          PopupMenuItem(
                            value: 'member',
                            child: Text(
                              member.role == 'member'
                                  ? '✓ Thành viên'
                                  : 'Đặt vai trò Thành viên',
                            ),
                          ),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: 'remove',
                            child: Text('Xóa khỏi gia đình'),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            }),
            const Text(
              'Email cá nhân không được hiển thị trong danh sách gia đình.',
              style: TextStyle(fontSize: 10, color: _muted),
            ),
          ],
          if (active != null && active.role != 'owner')
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _busy || _loading ? null : () => _leave(active),
                icon: const Icon(Icons.logout, size: 16),
                label: const Text('Rời gia đình đang chọn'),
              ),
            ),
        ] else
          const Text(
            'Tài khoản này chưa tham gia gia đình nào.',
            style: TextStyle(color: _muted),
          ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _busy || _loading ? null : _create,
              icon: const Icon(Icons.add_home_outlined),
              label: const Text('Tạo gia đình'),
            ),
            OutlinedButton.icon(
              onPressed: _busy || _loading ? null : _join,
              icon: const Icon(Icons.group_add_outlined),
              label: const Text('Nhập mã mời'),
            ),
          ],
        ),
        if (_busy) const LinearProgressIndicator(minHeight: 2),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
      ],
    );
  }
}

class _FamilyLoadingSkeleton extends StatelessWidget {
  const _FamilyLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: reduceMotion ? 0.62 : 0.38, end: 0.72),
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 420),
      curve: Curves.easeOut,
      builder: (context, opacity, _) => Opacity(
        opacity: opacity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SkeletonLine(width: 132, height: 12),
            const SizedBox(height: 10),
            Container(
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFFE8ECEB),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE8FBF4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  _SkeletonCircle(size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SkeletonLine(width: 108, height: 10),
                        SizedBox(height: 7),
                        _SkeletonLine(width: 156, height: 13),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            const _SkeletonLine(width: 88, height: 13),
            const SizedBox(height: 10),
            for (var index = 0; index < 2; index++) ...[
              if (index > 0) const SizedBox(height: 12),
              const Row(
                children: [
                  _SkeletonCircle(size: 34),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SkeletonLine(width: 124, height: 12),
                        SizedBox(height: 7),
                        _SkeletonLine(width: 76, height: 10),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: const Color(0xFFDDE3E1),
      borderRadius: BorderRadius.circular(height),
    ),
  );
}

class _SkeletonCircle extends StatelessWidget {
  const _SkeletonCircle({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      color: Color(0xFFDDE3E1),
      shape: BoxShape.circle,
    ),
  );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
