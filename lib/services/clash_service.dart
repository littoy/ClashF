import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:process_run/shell_run.dart';
import 'package:yaml/yaml.dart';

import '../utils/platform_utils.dart';

class ClashService {
  static String extPort = '9393';
  static String get _apiBaseUrl => 'http://127.0.0.1:$extPort';

  static Future<void> initExtPort() async {
    try {
      var folder = await ClashService().getWorkDir();
      var file = File(join(folder, "config.yaml"));
      if (file.existsSync()) {
        var configStr = await file.readAsString(encoding: const Utf8Codec(allowMalformed: true));
        var doc = loadYaml(configStr);
        if (doc != null && doc['external-controller'] != null) {
          String extCtrl = doc['external-controller'].toString();
          extPort = extCtrl.split(':').last;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("Init extPort error: $e");
      }
    }
  }

  static Future<String> getClashVersion() async {
    try {
      var coreExePath = PlatformUtils.getCoreExePath();
      var result = await Process.run(coreExePath, ['-v']);
      if (result.exitCode == 0) {
        var output = result.stdout.toString().trim();
        if (output.isNotEmpty) {
          return output.split('\n').first;
        }
      }
    } catch (e) {
      debugPrint("getClashVersion error: $e");
    }
    return 'Unknown';
  }

  Future<String> getActiveProfile() async {
    try {
      var folder = await getWorkDir();
      var file = File(join(folder, '.active_profile'));
      if (file.existsSync()) {
        return await file.readAsString();
      }
    } catch (e) {
      if (kDebugMode) {
        print("Read active profile error: $e");
      }
    }
    return '';
  }

  Future<void> setActiveProfile(String profile) async {
    try {
      var folder = await getWorkDir();
      var file = File(join(folder, '.active_profile'));
      await file.writeAsString(profile);
    } catch (e) {
      if (kDebugMode) {
        print("Save active profile error: $e");
      }
    }
  }

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

  Future<Map<String, dynamic>?> getProxies() async {
    var uri = Uri.parse('$_apiBaseUrl/proxies');
    try {
      var response = await http.get(uri, headers: {
        'Content-Type': 'application/json',
      });
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      if (kDebugMode) {
        print("Load proxies failed: $e");
      }
    }
    return null;
  }

  Future<int> getProxyDelay(String name) async {
    var nameEncoded = Uri.encodeComponent(name);
    var url = 'http://www.apple.com/library/test/success.html';
    var urlEncoded = Uri.encodeComponent(url);
    var uri = Uri.parse('$_apiBaseUrl/proxies/$nameEncoded/delay?timeout=5000&url=$urlEncoded');
    
    try {
      var response = await http.get(uri);
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        return data['delay'] as int;
      }
    } catch (e) {
      if (kDebugMode) {
        print("Test delay failed for $name: $e");
      }
    }
    return 0; // 0 represents timeout or error
  }

  Future<bool> selectProxy(String group, String proxy) async {
    // URL encode the proxy group name and proxy name to handle special characters
    var groupEncoded = Uri.encodeComponent(group);
    var uri = Uri.parse('$_apiBaseUrl/proxies/$groupEncoded');
    try {
      var response = await http.put(
        uri,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({"name": proxy}),
      );
      if (response.statusCode == 204) {
        return true;
      }
    } catch (e) {
      if (kDebugMode) {
        print("Select proxy failed: $e");
      }
    }
    return false;
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

  Future<List<String>> getConfigList() async {
    var folder = await getWorkDir();
    var dir = Directory(folder);
    if (!dir.existsSync()) return [];
    var files = dir.listSync();
    List<String> list = [];
    for (var f in files) {
      if (f is File) {
        var name = basename(f.path);
        if (name.endsWith('.yaml') || name.endsWith('.yml')) {
          if (name == 'config.yaml') continue; // Hide the active copy file
          list.add(name);
        }
      }
    }
    return list;
  }

  Future<bool> changeProfile(String filename, {bool isRunning = false}) async {
    try {
      var folder = await getWorkDir();
      var file = File(join(folder, filename));
      if (!file.existsSync()) return false;
      var configStr = await file.readAsString(encoding: const Utf8Codec(allowMalformed: true));
      var doc = loadYaml(configStr);
      
      String? newExtPort;
      if (doc != null && doc['external-controller'] != null) {
          String extCtrl = doc['external-controller'].toString();
          newExtPort = extCtrl.split(':').last;
          if (kDebugMode) {
            print("Found new port: $newExtPort");
          }
      }
      
      if (filename != 'config.yaml') {
        await file.copy(join(folder, 'config.yaml'));
      }
      
      if (newExtPort != null && newExtPort != extPort) {
        // Port changed! We must restart the core to apply this.
        if (isRunning) {
           await switchCore(false); // Stop
        }
        extPort = newExtPort;
        if (isRunning) {
           await Future.delayed(const Duration(milliseconds: 600));
           await switchCore(true); // Start with new config
        }
      } else {
        if (isRunning) {
          await reloadConfig();
        }
      }
      showToast("Changed profile to $filename");
      return true;
    } catch (e) {
      showToast("Change profile error: $e");
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
          var configStr = file.readAsStringSync(encoding: const Utf8Codec(allowMalformed: true));
          var doc = loadYaml(configStr);
          if (doc != null && doc['external-controller'] != null) {
              String extCtrl = doc['external-controller'].toString();
              var port = extCtrl.split(':').last;
              if (kDebugMode) {
                print("Found port: $port");
              }
              extPort = port;
          }
          await file.copy(join(folder, 'config.yaml'));
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
