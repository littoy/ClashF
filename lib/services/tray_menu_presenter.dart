import 'dart:async';

class TrayMenuPresenter {
  TrayMenuPresenter({
    required this.refreshMenuData,
    required this.showMenu,
    this.refreshTimeout = const Duration(seconds: 2),
  });

  final Future<void> Function() refreshMenuData;
  final FutureOr<void> Function() showMenu;
  final Duration refreshTimeout;

  Future<void> openMenu() async {
    try {
      await refreshMenuData().timeout(refreshTimeout);
    } catch (_) {
      // Showing a slightly stale menu is better than making the tray feel dead.
    }

    await showMenu();
  }
}
