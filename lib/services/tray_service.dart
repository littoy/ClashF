import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:system_tray/system_tray.dart' as system_tray;
import 'package:window_manager/window_manager.dart';
import '../utils/platform_utils.dart';

class TrayService {
  final system_tray.SystemTray _systemTray = system_tray.SystemTray();

  Future<void> init(VoidCallback onShow, VoidCallback onMenuOpen) async {
    String path =
        Platform.isWindows ? 'assets/app_icon.ico' : 'assets/app_icon.png';
    
    await _systemTray.initSystemTray(
      title: "",
      iconPath: path,
    );

    _systemTray.registerSystemTrayEventHandler((eventName) async {
      debugPrint("eventName: $eventName");
      if (eventName == "leftMouseDown") {
        // Optional: show window on click
      } else if (eventName == system_tray.kSystemTrayEventClick) {
        onMenuOpen();
        _systemTray.popUpContextMenu();
      } else if (eventName == "rightMouseDown") {
      } else if (eventName == system_tray.kSystemTrayEventRightClick) {
        onMenuOpen();
        _systemTray.popUpContextMenu();
      }
    });
  }

  Future<void> updateMenu({
    required bool isRunning,
    required bool isTunMode,
    required String mode,
    required List<String> profiles,
    required String activeProfile,
    required Map<String, dynamic> proxyGroups,
    required Map<String, int> proxyDelays,
    required Function(String, String) onProxyChange,
    required VoidCallback onShow,
    required VoidCallback onToggleRun,
    required VoidCallback onToggleTun,
    required Function(String) onModeChange,
    required Function(String) onProfileChange,
    required VoidCallback onOpenDashboard,
    required VoidCallback onReloadConfig,
    required VoidCallback onInstallHelper,
    required VoidCallback onHide,
    required VoidCallback onQuit,
    required VoidCallback onStopAndQuit,
  }) async {
    var runLabel = isRunning ? '✔' + I18n.s('Running', '运行中') : I18n.s('Run', '运行');
    var tunLabel = isTunMode ? '✔' + I18n.s('TUN mode', '增强模式') : I18n.s('TUN mode', '增强模式');
    final system_tray.Menu menu = system_tray.Menu();

    List<system_tray.MenuItemBase> menuItems = [
      system_tray.MenuItemLabel(label: I18n.s('Show', '显示'), onClicked: (menuItem) =>onShow()),
      system_tray.MenuItemLabel(
          label: runLabel,
          onClicked: (menuItem) => onToggleRun()),
      system_tray.MenuItemLabel(
          label: tunLabel,
          onClicked: (menuItem) => onToggleTun()),
      system_tray.SubMenu(
        label: I18n.s("Mode", "模式"),
        children: [
          system_tray.MenuItemLabel(
            label: (mode == 'rule' ? '✔' : '') + I18n.s('rule', '规则'),
            onClicked: (menuItem) => onModeChange('rule'),
          ),
          system_tray.MenuItemLabel(
            label: (mode == 'direct' ? '✔' : '') + I18n.s('direct', '直连'),
            onClicked: (menuItem) => onModeChange('direct'),
          ),
          system_tray.MenuItemLabel(
            label: (mode == 'global' ? '✔' : '') + I18n.s('global', '全局'),
            onClicked: (menuItem) => onModeChange('global'),
          ),
        ],
      ),
      system_tray.SubMenu(
        label: I18n.s("Profiles", "配置文件"),
        children: profiles.map((p) => system_tray.MenuItemLabel(
          label: (activeProfile == p ? '✔' : '') + p,
          onClicked: (menuItem) => onProfileChange(p),
        )).toList(),
      ),
    ];

    if (proxyGroups.isNotEmpty) {
      menuItems.add(system_tray.MenuSeparator());
      proxyGroups.forEach((groupName, groupData) {
        String now = groupData['now'] ?? '';
        List<dynamic> all = groupData['all'] ?? [];
        
        List<system_tray.MenuItemBase> children = all.map((node) {
          String nodeName = node.toString();
          String label = nodeName;
          if (proxyDelays.containsKey(nodeName)) {
            label = '$nodeName (${proxyDelays[nodeName]}ms)';
          }
          return system_tray.MenuItemLabel(
            label: (now == nodeName ? '✔ ' : '') + label,
            onClicked: (menuItem) => onProxyChange(groupName, nodeName),
          );
        }).toList();

        menuItems.add(system_tray.SubMenu(
          label: '$groupName: $now',
          children: children,
        ));
      });
    }

    menuItems.add(system_tray.MenuSeparator());
    if (isRunning) {
      menuItems.addAll([
        system_tray.MenuItemLabel(
            label: I18n.s('Dashboard', '控制面板'),
            onClicked: (menuItem) => onOpenDashboard()),
        system_tray.MenuItemLabel(
            label: I18n.s('Reload Config', '重载配置'),
            onClicked: (menuItem) => onReloadConfig()),
      ]);
    }
    
    if (Platform.isMacOS) {
      menuItems.add(system_tray.MenuItemLabel(label: I18n.s('Install Helper', '安装权限助手'), onClicked: (menuItem) => onInstallHelper()));
    }
    menuItems.addAll([
      system_tray.MenuItemLabel(label: I18n.s('Hide', '隐藏'), onClicked: (menuItem) => onHide()),
      system_tray.MenuSeparator(),
      system_tray.MenuItemLabel(label: I18n.s('Exit', '退出'), onClicked: (menuItem) => onQuit()),
      system_tray.MenuItemLabel(label: I18n.s('Stop & Exit', '停止并退出'), onClicked: (menuItem) => onStopAndQuit()),
    ]);

    await menu.buildFrom(menuItems);
    await _systemTray.setContextMenu(menu);
  }

  void setTitle(String title) {
    _systemTray.setTitle(title);
  }
}
