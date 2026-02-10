import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:system_tray/system_tray.dart' as system_tray;
import 'package:window_manager/window_manager.dart';

class TrayService {
  final system_tray.SystemTray _systemTray = system_tray.SystemTray();

  Future<void> init(VoidCallback onShow) async {
    String path =
        Platform.isWindows ? 'assets/app_icon.ico' : 'assets/app_icon.png';
    
    await _systemTray.initSystemTray(
      title: "",
      iconPath: path,
    );

    _systemTray.registerSystemTrayEventHandler((eventName) {
      debugPrint("eventName: $eventName");
      if (eventName == "leftMouseDown") {
        // Optional: show window on click
      } else if (eventName == system_tray.kSystemTrayEventClick) {
        _systemTray.popUpContextMenu();
      } else if (eventName == "rightMouseDown") {
      } else if (eventName == system_tray.kSystemTrayEventRightClick) {
        _systemTray.popUpContextMenu();
      }
    });
  }

  Future<void> updateMenu({
    required bool isRunning,
    required bool isTunMode,
    required String mode,
    required VoidCallback onShow,
    required VoidCallback onToggleRun,
    required VoidCallback onToggleTun,
    required Function(String) onModeChange,
    required VoidCallback onOpenDashboard,
    required VoidCallback onInstallHelper,
    required VoidCallback onHide,
    required VoidCallback onQuit,
    required VoidCallback onStopAndQuit,
  }) async {
    var runLabel = isRunning ? '✔Running' : 'Run';
    var tunLabel = isTunMode ? '✔TUN' : 'TUN';
    final system_tray.Menu menu = system_tray.Menu();

    await menu.buildFrom( [
      system_tray.MenuItemLabel(label: 'Show', onClicked: (menuItem) =>onShow()),
      system_tray.MenuItemLabel(
          label: runLabel,
          onClicked: (menuItem) => onToggleRun()),
      system_tray.MenuItemLabel(
          label: tunLabel,
          onClicked: (menuItem) => onToggleTun()),
      system_tray.SubMenu(
        label: "Mode",
        children: [
          system_tray.MenuItemLabel(
            label: (mode == 'rule' ? '✔' : '') + 'rule',
            onClicked: (menuItem) => onModeChange('rule'),
          ),
          system_tray.MenuItemLabel(
            label: (mode == 'direct' ? '✔' : '') + 'direct',
            onClicked: (menuItem) => onModeChange('direct'),
          ),
          system_tray.MenuItemLabel(
            label: (mode == 'global' ? '✔' : '') + 'global',
            onClicked: (menuItem) => onModeChange('global'),
          ),
        ],
      ),
      system_tray.MenuItemLabel(
          label: 'Dashboard',
          onClicked: (menuItem) => onOpenDashboard()),
      if (Platform.isMacOS)
        system_tray.MenuItemLabel(label: 'Install Helper', onClicked: (menuItem) => onInstallHelper()),
      system_tray.MenuItemLabel(label: 'Hide', onClicked: (menuItem) => onHide()),
      system_tray.MenuSeparator(),
      system_tray.MenuItemLabel(label: 'Exit', onClicked: (menuItem) => onQuit()),
      system_tray.MenuItemLabel(label: 'Stop&Exit', onClicked: (menuItem) => onStopAndQuit()),
    ]);
    await _systemTray.setContextMenu(menu);
  }

  void setTitle(String title) {
    _systemTray.setTitle(title);
  }
}
