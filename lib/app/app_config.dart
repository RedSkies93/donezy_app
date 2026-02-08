class AppConfig {
  final bool enableFirebase;

  const AppConfig({
    required this.enableFirebase,
  });

  static const mockFirst = AppConfig(enableFirebase: true);

  /// Phase 2 (live Firestore on)
  static const liveFirebase = AppConfig(enableFirebase: true);
}


