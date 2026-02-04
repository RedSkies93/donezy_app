import 'package:shared_preferences/shared_preferences.dart';

enum SessionRole { parent, child }

class SessionData {
  final SessionRole? role;
  final String? parentUid;
  final String? childId;

  const SessionData({
    this.role,
    this.parentUid,
    this.childId,
  });
}

class SessionStore {
  static const _kRole = 'role';
  static const _kParentUid = 'parentUid';
  static const _kChildId = 'childId';

  static Future<void> setRole(SessionRole role) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kRole, role.name);
  }

  static Future<void> setChildLink({
    required String parentUid,
    required String childId,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kParentUid, parentUid);
    await p.setString(_kChildId, childId);
  }

  static Future<SessionData> load() async {
    final p = await SharedPreferences.getInstance();
    final roleStr = p.getString(_kRole);
    final parentUid = p.getString(_kParentUid);
    final childId = p.getString(_kChildId);

    SessionRole? role;
    if (roleStr != null) {
      role = SessionRole.values.where((e) => e.name == roleStr).firstOrNull;
    }

    return SessionData(
      role: role,
      parentUid: parentUid,
      childId: childId,
    );
  }

  static Future<void> clearAll() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kRole);
    await p.remove(_kParentUid);
    await p.remove(_kChildId);
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
