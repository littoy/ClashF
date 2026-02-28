import 'dart:io';
import 'package:path/path.dart';
import 'package:flutter/material.dart';
import '../NavigationService.dart';

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
        action: SnackBarAction(label: 'Dismiss', onPressed: scaffold.hideCurrentSnackBar),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}
