import 'dart:io';
import 'package:path/path.dart';
import 'package:flutter/material.dart';
import '../NavigationService.dart';
import 'dart:convert';

class PlatformUtils {
  static String getCoreDir() {
    String mainPath = Platform.resolvedExecutable;
    if (Platform.isWindows) {
      return join(
          File(mainPath).parent.path, 'data', 'flutter_assets', 'assets', 'core');
    } else {
      return join(File(mainPath).parent.path, '..', 'Frameworks', 'App.framework',
          'Resources', 'flutter_assets', 'assets', 'core');
    }
  }

  static String getCoreExePath() {
    var clashEXE = 'clash-macos';
    if (Platform.isWindows) {
      clashEXE = join('win', 'clash.exe');
    }
    return join(getCoreDir(), clashEXE);
  }
}

void showToast(String msg) {
  BuildContext? context = NavigationService.navigatorKey.currentContext;
  if(context != null){
    final scaffold = ScaffoldMessenger.of(context);
    scaffold.showSnackBar(
      SnackBar(
        content: Text(msg),
        action: SnackBarAction(label: I18n.s('Dismiss', '关闭'), onPressed: scaffold.hideCurrentSnackBar),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}

class I18n {
  static bool get isZh => Platform.localeName.toLowerCase().startsWith('zh');
  static Map<String, String> _zh = {};
  static Map<String, String> _en = {};
  static Future<void> init(String dir) async {
    try {
      final file = File(join(dir, 'i18n.json'));
      if (await file.exists()) {
        final data = jsonDecode(await file.readAsString());
        if (data is Map) {
          if (data['zh'] is Map) {
            _zh = (data['zh'] as Map)
                .map((k, v) => MapEntry(k.toString(), v.toString()));
          }
          if (data['en'] is Map) {
            _en = (data['en'] as Map)
                .map((k, v) => MapEntry(k.toString(), v.toString()));
          }
        }
      }
    } catch (_) {}
  }
  static String s(String en, String zh) {
    if (isZh) {
      return _zh[en] ?? (zh.isNotEmpty ? zh : en);
    } else {
      return _en[en] ?? en;
    }
  }
}
