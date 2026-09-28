import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabasePublicKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
  defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY'),
);
const appOAuthRedirect = String.fromEnvironment(
  'VINEAT_OAUTH_REDIRECT',
  defaultValue: kDebugMode
      ? 'com.vineat.team.vineat_app.preview://login-callback'
      : 'com.vineat.team.vineat_app://login-callback',
);

class AppServices {
  AppServices._();

  static bool initialized = false;
  static bool configured = false;
  static String? initializationError;
  static SupabaseClient? _client;

  static SupabaseClient get client {
    final value = _client;
    if (value == null) throw StateError('Supabase is not configured.');
    return value;
  }

  static Future<void> initialize() async {
    if (initialized) return;
    initialized = true;
    final parsedUrl = Uri.tryParse(_supabaseUrl);
    final secureHostedUrl =
        parsedUrl?.scheme == 'https' && parsedUrl?.host.isNotEmpty == true;
    // Supabase's local stack is plain HTTP. Keep that escape hatch restricted
    // to the loopback/emulator gateway and debug builds so an insecure URL can
    // never silently become a release configuration.
    final localDebugUrl =
        kDebugMode &&
        parsedUrl?.scheme == 'http' &&
        const {'localhost', '127.0.0.1', '10.0.2.2'}.contains(parsedUrl?.host);
    configured =
        (secureHostedUrl || localDebugUrl) && _supabasePublicKey.isNotEmpty;
    if (!configured) return;
    try {
      await Supabase.initialize(
        url: _supabaseUrl,
        publishableKey: _supabasePublicKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
      );
      _client = Supabase.instance.client;
    } catch (error) {
      configured = false;
      initializationError = error.toString();
    }
  }
}

class Household {
  const Household({
    required this.id,
    required this.name,
    required this.role,
    this.inviteCode,
  });

  final String id;
  final String name;
  final String role;
  final String? inviteCode;

  factory Household.fromJson(Map<String, dynamic> json) => Household(
    id: json['id'] as String,
    name: json['name'] as String? ?? 'Gia đình',
    role: json['role'] as String? ?? json['member_role'] as String? ?? 'member',
    inviteCode: json['invite_code'] as String?,
  );
}

class HouseholdMember {
  const HouseholdMember({
    required this.userId,
    required this.displayName,
    required this.role,
  });

  final String userId;
  final String displayName;
  final String role;
}

/// Households are fetched from membership rows; the active household is a
/// device preference, while all household data remains protected by RLS.
class HouseholdService {
  HouseholdService._();
  static final HouseholdService instance = HouseholdService._();
  static const _activeHouseholdKey = 'vineat.active_household.v1';

  final active = ValueNotifier<Household?>(null);

  Future<List<Household>> listMine() async {
    final userId = AppServices.client.auth.currentUser?.id;
    if (userId == null) return const [];
    final memberships = await AppServices.client
        .from('household_members')
        .select('household_id, member_role')
        .eq('user_id', userId);
    if (memberships.isEmpty) return const [];
    final roles = <String, String>{
      for (final row in memberships)
        row['household_id'] as String:
            row['member_role'] as String? ?? 'member',
    };
    final households = await AppServices.client
        .from('households')
        .select('id, name, invite_code')
        .inFilter('id', roles.keys.toList());
    return households
        .map(
          (row) => Household.fromJson({
            ...row,
            'member_role': roles[row['id'] as String],
          }),
        )
        .toList();
  }

  Future<List<Household>> restoreActive() async {
    final households = await listMine();
    final preferences = await SharedPreferences.getInstance();
    final savedId = preferences.getString(_activeHouseholdKey);
    final selected =
        households.where((h) => h.id == savedId).firstOrNull ??
        (households.isEmpty ? null : households.first);
    await select(selected);
    return households;
  }

  Future<void> select(Household? household) async {
    active.value = household;
    final preferences = await SharedPreferences.getInstance();
    if (household == null) {
      await preferences.remove(_activeHouseholdKey);
    } else {
      await preferences.setString(_activeHouseholdKey, household.id);
    }
  }

  Future<Household> create(String name) async {
    final data = await _invoke('create', {'name': name.trim()});
    final household = Household.fromJson(data);
    await select(household);
    return household;
  }

  Future<Household> join(String code) async {
    final data = await _invoke('join', {'code': code.trim().toUpperCase()});
    final household = Household.fromJson(data);
    await select(household);
    return household;
  }

  Future<String> rotateInviteCode(String householdId) async {
    final data = await _invoke('rotate', {'householdId': householdId});
    return data['inviteCode'] as String;
  }

  Future<void> leave(String householdId) async {
    await _invoke('leave', {'householdId': householdId});
    if (active.value?.id == householdId) await select(null);
  }

  Future<List<HouseholdMember>> listMembers(String householdId) async {
    final data = await _invoke('members', {'householdId': householdId});
    final rows = data['members'];
    if (rows is! List) return const [];
    return rows
        .whereType<Map>()
        .map(
          (row) => HouseholdMember(
            userId: row['user_id'] as String? ?? '',
            displayName: row['display_name'] as String? ?? 'Thành viên',
            role: row['member_role'] as String? ?? 'member',
          ),
        )
        .toList();
  }

  Future<void> setMemberRole({
    required String householdId,
    required String userId,
    required String role,
  }) async {
    await _invoke('set-role', {
      'householdId': householdId,
      'userId': userId,
      'role': role,
    });
  }

  Future<void> removeMember({
    required String householdId,
    required String userId,
  }) async {
    await _invoke('remove-member', {
      'householdId': householdId,
      'userId': userId,
    });
  }

  Future<Map<String, dynamic>> _invoke(
    String action,
    Map<String, dynamic> payload,
  ) async {
    final response = await AppServices.client.functions.invoke(
      'household',
      body: {'action': action, ...payload},
    );
    if (response.status < 200 || response.status >= 300) {
      throw StateError('Không thể cập nhật gia đình (${response.status}).');
    }
    final body = response.data;
    if (body is! Map) throw StateError('Phản hồi máy chủ không hợp lệ.');
    return Map<String, dynamic>.from(body);
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
