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
      if (households.isEmpty) {
        replaceInventoryFromRemote(records: const [], events: const []);
        replaceShoppingFromRemote(items: const [], checked: const {});
      } else {
        final snapshot = await HouseholdDataRepository.instance
            .loadActiveHousehold();
        replaceInventoryFromRemote(
          records: snapshot.inventory,
          events: snapshot.events,
        );
        replaceShoppingFromRemote(
          items: snapshot.shopping.map((item) => item.item).toList(),
          checked: snapshot.shopping
              .asMap()
              .entries
              .where((entry) => entry.value.checked)
              .map((entry) => entry.key)
              .toSet(),
        );
      }
      if (!mounted) return;
      setState(() {
        _households = households;
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
    final selected = _households
        .where((household) => household.id == id)
        .firstOrNull;
    await HouseholdService.instance.select(selected);
    replaceInventoryFromRemote(records: const [], events: const []);
    replaceShoppingFromRemote(items: const [], checked: const {});
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final snapshot = await HouseholdDataRepository.instance
          .loadActiveHousehold();
      replaceInventoryFromRemote(
        records: snapshot.inventory,
        events: snapshot.events,
      );
      replaceShoppingFromRemote(
        items: snapshot.shopping.map((item) => item.item).toList(),
        checked: snapshot.shopping
            .asMap()
            .entries
            .where((entry) => entry.value.checked)
            .map((entry) => entry.key)
            .toSet(),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Chưa tải được dữ liệu gia đình đã chọn.');
      }
      HouseholdDataRepository.instance.syncStatus.value =
          'Chưa tải được gia đình. Dữ liệu cũ đã được ẩn để tránh hiển thị nhầm; hãy thử lại.';
    } finally {
      if (mounted) setState(() => _loading = false);
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
      await HouseholdService.instance.join(code);
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
      await HouseholdService.instance.create(name);
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
      await HouseholdService.instance.leave(household.id);
      await _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!AppServices.configured) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mã gia đình chưa khả dụng trong bản demo cục bộ.',
            style: TextStyle(color: _ink, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 5),
          Text(
            'Khi kết nối Supabase, bạn có thể tạo mã mời hoặc tham gia nhiều gia đình.',
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
          const LinearProgressIndicator(minHeight: 2)
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
                          const SnackBar(content: Text('Đã sao chép mã mời')),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy_outlined),
                  ),
                  if (active.role == 'owner')
                    IconButton(
                      tooltip: 'Đổi mã mời',
                      onPressed: _busy ? null : () => _rotateCode(active),
                      icon: const Icon(Icons.refresh),
                    ),
                ],
              ),
            ),
          ],
          if (active != null && active.role != 'owner')
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _busy ? null : () => _leave(active),
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
              onPressed: _busy ? null : _create,
              icon: const Icon(Icons.add_home_outlined),
              label: const Text('Tạo gia đình'),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : _join,
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

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
