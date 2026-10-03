import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Both values identify the public hosted project; neither grants privileged
// database access. Dart defines can still override them for another project.
const _supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://kumtkpsgthcxnovbjzjv.supabase.co',
);
const _supabasePublicKey = String.fromEnvironment(
  'SUPABASE_PUBLISHABLE_KEY',
  defaultValue: String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_oEFSiw1QilTgiJUcosUQug__5lTni9Q',
  ),
);
const debugDemoAuthRequested = bool.fromEnvironment('VINEAT_DEBUG_DEMO_AUTH');
const debugDemoEmail = String.fromEnvironment(
  'VINEAT_DEBUG_DEMO_EMAIL',
  defaultValue: 'demo@vineat.test',
);
const debugDemoOtp = String.fromEnvironment(
  'VINEAT_DEBUG_DEMO_OTP',
  defaultValue: '123456',
);
const _debugDemoSessionKey = 'vineat.debug_auth_session.v1';
final debugDemoAuthenticated = ValueNotifier<bool>(false);

bool get debugOtpDemoEnabled =>
    kDebugMode &&
    debugDemoAuthRequested &&
    debugDemoEmail.contains('@') &&
    RegExp(r'^\d{6}$').hasMatch(debugDemoOtp);
const debugOAuthRedirect =
    'com.vineat.team.vineat_app.preview://login-callback';
const profileOAuthRedirect =
    'com.vineat.team.vineat_app.profile://login-callback';
const releaseOAuthRedirect = 'com.vineat.team.vineat_app://login-callback';

const appOAuthRedirect = String.fromEnvironment(
  'VINEAT_OAUTH_REDIRECT',
  defaultValue: kDebugMode
      ? debugOAuthRedirect
      : kProfileMode
      ? profileOAuthRedirect
      : releaseOAuthRedirect,
);

class AppServices {
  static String inventoryActorName = 'Bạn';
  static String? inventoryActorUserId;
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
    // The fixed OTP is an explicitly opted-in, offline-only debug fixture.
    // Never initialize cloud services or use this path in profile/release.
    if (debugOtpDemoEnabled) {
      try {
        final preferences = await SharedPreferences.getInstance();
        debugDemoAuthenticated.value =
            preferences.getBool(_debugDemoSessionKey) ?? false;
      } catch (_) {
        debugDemoAuthenticated.value = false;
      }
      return;
    }
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

  static Future<void> signInDebugDemo() async {
    if (!debugOtpDemoEnabled) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_debugDemoSessionKey, true);
    debugDemoAuthenticated.value = true;
  }

  static Future<void> signOutDebugDemo() async {
    if (!debugOtpDemoEnabled) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_debugDemoSessionKey);
    debugDemoAuthenticated.value = false;
  }

  static Future<void> signOut() async {
    final userId = client.auth.currentUser?.id;
    await client.auth.signOut();
    if (userId != null) {
      await HouseholdService.instance.clearSelectionForUser(userId);
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

/// The selected family is a device preference, scoped to one signed-in user.
/// An absent or stale choice always returns to the family picker.
class HouseholdSelectionStore {
  static String keyFor(String userId) => 'vineat.active_household.v2.$userId';

  static Future<String?> read(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(keyFor(userId));
  }

  static Future<void> save(String userId, String householdId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(keyFor(userId), householdId);
  }

  static Future<void> clear(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(keyFor(userId));
  }

  static Household? match(String? savedId, List<Household> households) {
    for (final household in households) {
      if (household.id == savedId) return household;
    }
    return null;
  }
}

/// Households are fetched from membership rows; the active household is a
/// device preference, while all household data remains protected by RLS.
class HouseholdService {
  HouseholdService._();
  static final HouseholdService instance = HouseholdService._();
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
    final userId = AppServices.client.auth.currentUser?.id;
    if (userId == null) {
      active.value = null;
      return const [];
    }
    final households = await listMine();
    final savedId = await HouseholdSelectionStore.read(userId);
    final selected = HouseholdSelectionStore.match(savedId, households);
    active.value = selected;
    if (savedId != null && selected == null) {
      await HouseholdSelectionStore.clear(userId);
    }
    return households;
  }

  Future<void> select(Household? household) async {
    final userId = AppServices.client.auth.currentUser?.id;
    if (userId == null) throw StateError('No authenticated user.');
    if (household == null) {
      await HouseholdSelectionStore.clear(userId);
    } else {
      await HouseholdSelectionStore.save(userId, household.id);
    }
    active.value = household;
  }

  Future<void> clearSelectionForUser(String userId) async {
    await HouseholdSelectionStore.clear(userId);
    active.value = null;
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
