import 'package:shared_preferences/shared_preferences.dart';

enum SessionRole { parent, child }

class SessionData {
  final SessionRole? role;
  final String? parentUid;
  final String? childId;

  const SessionData({this.role, this.parentUid, this.childId});
}

class SessionStore {
  static const _kRole = 'donezy_role';
  static const _kParentUid = 'donezy_parentUid';
  static const _kChildId = 'donezy_childId';

  static Future<void> setRole(SessionRole role) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kRole, role.name);
  }

  static Future<void> setChildLink({required String parentUid, required String childId}) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kParentUid, parentUid);
    await sp.setString(_kChildId, childId);
  }

  static Future<SessionData> load() async {
    final sp = await SharedPreferences.getInstance();
    final roleStr = sp.getString(_kRole);
    SessionRole? role;
    if (roleStr == 'parent') role = SessionRole.parent;
    if (roleStr == 'child') role = SessionRole.child;

    return SessionData(
      role: role,
      parentUid: sp.getString(_kParentUid),
      childId: sp.getString(_kChildId),
    );
  }

  static Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kRole);
    await sp.remove(_kParentUid);
    await sp.remove(_kChildId);
  }
}
