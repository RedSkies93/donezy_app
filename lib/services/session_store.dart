class SessionStore {
  String userId = '';
  bool isParentMode = true;

  /// Phase 2: single-family demo scope (visible data immediately)
  /// Later: replace with real family-code/linking flow.
  String familyId = 'demo_family';

  void setUserId(String id) {
    userId = id;
  }

  void setFamilyId(String id) {
    familyId = id.isEmpty ? 'demo_family' : id;
  }
}
