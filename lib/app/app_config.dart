class AppConfig {
  final bool enableFirebase;

  const AppConfig({
    required this.enableFirebase,
  });

  static const mockFirst = AppConfig(enableFirebase: false);
}
