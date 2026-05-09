import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart';
import 'package:yaml/yaml.dart';

class ProfileSyncResult {
  const ProfileSyncResult({
    required this.activeProfile,
    this.externalControllerPort,
  });

  final String activeProfile;
  final String? externalControllerPort;
}

class ProfileSyncService {
  static const String activeConfigName = 'config.yaml';

  static Future<ProfileSyncResult> syncSelectedProfile({
    required String folder,
    String? preferredProfile,
  }) async {
    var selectedProfile = preferredProfile?.trim();
    if (selectedProfile == null || selectedProfile.isEmpty) {
      selectedProfile = activeConfigName;
    }

    var sourceFile = File(join(folder, selectedProfile));
    if (!sourceFile.existsSync()) {
      selectedProfile = activeConfigName;
      sourceFile = File(join(folder, activeConfigName));
    }

    if (selectedProfile != activeConfigName && sourceFile.existsSync()) {
      await sourceFile.copy(join(folder, activeConfigName));
    }

    final activeConfigFile = File(join(folder, activeConfigName));
    final port = await _readExternalControllerPort(
      activeConfigFile.existsSync() ? activeConfigFile : sourceFile,
    );

    return ProfileSyncResult(
      activeProfile: selectedProfile,
      externalControllerPort: port,
    );
  }

  static Future<String?> _readExternalControllerPort(File file) async {
    if (!file.existsSync()) return null;

    final configStr =
        await file.readAsString(encoding: const Utf8Codec(allowMalformed: true));
    final doc = loadYaml(configStr);
    if (doc == null || doc['external-controller'] == null) {
      return null;
    }

    final extCtrl = doc['external-controller'].toString();
    return extCtrl.split(':').last;
  }
}
