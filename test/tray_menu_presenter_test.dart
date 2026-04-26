import 'package:flutter_test/flutter_test.dart';
import 'package:ClashF/services/tray_menu_presenter.dart';

void main() {
  test('refreshes tray data before showing the menu', () async {
    final events = <String>[];
    final presenter = TrayMenuPresenter(
      refreshMenuData: () async {
        events.add('refresh-start');
        await Future<void>.delayed(Duration.zero);
        events.add('refresh-end');
      },
      showMenu: () {
        events.add('show');
      },
    );

    await presenter.openMenu();

    expect(events, ['refresh-start', 'refresh-end', 'show']);
  });
}
