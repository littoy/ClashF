import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:ClashF/services/profile_sync_service.dart';

void main() {
  test('syncs selected profile into config.yaml before startup', () async {
    final tempDir = await Directory.systemTemp.createTemp('profile-sync');
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    await File(join(tempDir.path, 'config.yaml'))
        .writeAsString('external-controller: 127.0.0.1:7890\n');
    await File(join(tempDir.path, 'work.yaml'))
        .writeAsString('external-controller: 127.0.0.1:9999\n');

    final result = await ProfileSyncService.syncSelectedProfile(
      folder: tempDir.path,
      preferredProfile: 'work.yaml',
    );

    expect(result.activeProfile, 'work.yaml');
    expect(result.externalControllerPort, '9999');
    expect(
      await File(join(tempDir.path, 'config.yaml')).readAsString(),
      contains('127.0.0.1:9999'),
    );
  });

  test('falls back to config.yaml when selected profile is missing', () async {
    final tempDir = await Directory.systemTemp.createTemp('profile-sync');
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    await File(join(tempDir.path, 'config.yaml'))
        .writeAsString('external-controller: 127.0.0.1:7890\n');

    final result = await ProfileSyncService.syncSelectedProfile(
      folder: tempDir.path,
      preferredProfile: 'missing.yaml',
    );

    expect(result.activeProfile, 'config.yaml');
    expect(result.externalControllerPort, '7890');
    expect(
      await File(join(tempDir.path, 'config.yaml')).readAsString(),
      contains('127.0.0.1:7890'),
    );
  });
}
