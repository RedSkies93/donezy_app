class SessionStore {
  // Phase 1: minimal session shape
  String? userId;
  String mode = 'parent'; // 'parent' | 'child'

  bool get isSignedIn => userId != null;
}
