/// Whichever branch the app has been committed to for this install.
///
/// - [surface]  → first launch; no verdict has been persisted yet.
/// - [gray]     → returning launch; last time we opened the WebView.
/// - [game]     → returning launch; last time we opened the native
///                fishing game (permanent — see gate contract §9).
enum LaunchMode {
  gray,
  game,
  surface;

  static LaunchMode read(String? raw) {
    switch (raw) {
      case 'gray':
        return LaunchMode.gray;
      case 'game':
        return LaunchMode.game;
      default:
        return LaunchMode.surface;
    }
  }

  String write() => name;
}
