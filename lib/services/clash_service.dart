import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:process_run/shell_run.dart';

import '../utils/platform_utils.dart';

class ClashService {
  static const String _apiBaseUrl = 'http://127.0.0.1:9393';

  Future<String> getWorkDir() async {
    Directory directory = Platform.isIOS || Platform.isMacOS
        ? await getLibraryDirectory()
        : await getApplicationDocumentsDirectory();
    var folder = join(directory.path, "clashCore");
    if(Platform.isWindows){
      folder = "${PlatformUtils.getCoreDir()}\\win";
    }
    return folder;

  }

  Future<void> installHelper() async {
    if (!Platform.isMacOS) return;

    var script = join(PlatformUtils.getCoreDir(), 'install_helper.sh');
    // Ensure it's executable
    await Process.run('chmod', ['+x', script]);

    // Run with osascript
    // escaping quotes for AppleScript
    var cmd = "do shell script \"'$script'\" with administrator privileges";

    try {
      var result = await Process.run('/usr/bin/osascript', ['-e', cmd]);
      if (result.exitCode == 0) {
        showToast("Helper installed successfully.");
      } else {
        showToast("Helper install failed: ${result.stderr}");
      }
    } catch (e) {
      showToast("Helper install error: $e");
    }
  }

  Future<void> stopAndQuit(bool isRunning) async {
    if (isRunning) {
      await switchCore(false);
    }
  }

  Future<void> switchCore(bool isTargetRunning) async {
    var clashWorkdir = await getWorkDir();
    var coreDir = PlatformUtils.getCoreDir();
    var workspace = coreDir;
    var startCMD =
        '/bin/bash "$coreDir/start.sh" "$clashWorkdir"';
    var stopCMD =
        '/bin/bash "$coreDir/stop.sh" "$clashWorkdir"';
    if (Platform.isWindows) {
      startCMD = "$coreDir\\win\\start.cmd";
      stopCMD = "$coreDir\\win\\stop.cmd";
      workspace = "$coreDir\\win";
    }
    var throwOnError = Platform.isWindows ? false : true;
    if (isTargetRunning) {
      // Start
      await run(startCMD, throwOnError: throwOnError, workingDirectory: workspace);
    } else {
      // Stop
      await run(stopCMD, throwOnError: throwOnError, workingDirectory: workspace);
    }
  }

  Future<Map<String, dynamic>?> loadConfig() async {
    var uri = Uri.parse('$_apiBaseUrl/configs');
    try {
      var response = await http.get(uri, headers: {
        'Content-Type': 'application/json',
      });
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      if (kDebugMode) {
        print("Load config failed: $e");
      }
    }
    return null;
  }

  Future<bool> reloadConfig() async {
    var uri = Uri.parse('$_apiBaseUrl/configs');
    try {
      var response = await http.put(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
        body: "{}",
      );
      if (response.statusCode == 204) {
        showToast(I18n.s('Reload Config', '重载配置') + " " + I18n.s('Success', '成功'));
        return true;
      }
    } catch (e) {
      showToast("Load config error: $e");
    }
    return false;
  }

  Future<bool> patchConfig(String? mode, String? openTun) async {
    var uri = Uri.parse('$_apiBaseUrl/configs');
    var tun = <String, dynamic>{};
    if (openTun != null && openTun.isNotEmpty) {
      tun['enable'] = openTun == 'false' ? false : true;
      if(Platform.isWindows){
        tun['stack'] = 'gvisor';
      }else{
        tun['stack'] = 'system';
      }
      tun['auto-route'] = true;
      tun['dns-hijack'] = ['0.0.0.0:53'];
    }
    try {
      var response = await http.patch(uri,
          headers: {
            'Content-Type': 'application/json',
          },
          body: mode != null && mode.isNotEmpty
              ? '{"mode":"$mode"}'
              : '{"tun":${jsonEncode(tun)}}');
      
      if (response.statusCode != 204) {
        showToast("Update config fail: ${response.statusCode}");
        return false;
      }
      return true;
    } catch (e) {
      showToast("Update config fail: $e");
      return false;
    }
  }

  Future<void> chooseConfig() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      String? filePath = result.files.single.path;
      Directory directory = Platform.isIOS || Platform.isMacOS
      ? await getLibraryDirectory()
      : await getApplicationDocumentsDirectory();
      var folder = join(directory.path, "clashCore");
      if(Platform.isWindows){
       folder = "${PlatformUtils.getCoreDir()}\\win";
      }
      File file = File(filePath!);
      if(file.existsSync()){
        try{
          var config = file.readAsStringSync(encoding: const Utf8Codec(allowMalformed: true));
          RegExp rx = RegExp(r'external-controller:\s+:(\d+)');
          var match = rx.firstMatch(config);
          if (match != null) {
              if (kDebugMode) {
                print(match.group(1));
              }
              var port = match.group(1);
              if(port != '9393'){
                var destConfig = config.replaceAll(RegExp(r'external-controller:\s+:(\d+)'), 'external-controller: :9393');
                await File(join(folder, 'config.yaml')).writeAsString(destConfig.toString());
              }else{
                file.copy(join(folder, 'config.yaml'));
              }
          }else{
            file.copy(join(folder, 'config.yaml'));
          }
          showToast("Update success.");
        }catch(e){
          showToast("Parse config error: $e,just copy");
          await file.copy(join(folder, 'config.yaml'));
        }
      }else{
        showToast("File not found.");
      }
    }
  }
}
