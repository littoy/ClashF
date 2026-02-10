import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http_server/http_server.dart';
import 'package:localstorage/localstorage.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

import 'NavigationService.dart';
import 'ui/home_page.dart';
import 'utils/platform_utils.dart';

void main() async {
  String packageVersion = '1.3';
  WidgetsFlutterBinding.ensureInitialized();
  // Must add this line.
  await windowManager.ensureInitialized();

  // Use it only after calling `hiddenWindowAtLaunch`
  windowManager.waitUntilReadyToShow().then((_) async {
    // Hide window title bar
    if (Platform.isMacOS) await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    await windowManager.setSize(const Size(290, 460));
    await windowManager.center();
    await windowManager.hide();
    await windowManager.setSkipTaskbar(true);
  });

  // final storage = LocalStorage('mainconf');
  // await storage.ready;
  await initLocalStorage();
  String? ver = localStorage.getItem('ver');
  Directory directory = Platform.isIOS || Platform.isMacOS
      ? await getLibraryDirectory()
      : await getApplicationDocumentsDirectory();
  var folder = join(directory.path, "clashCore");
  if(Platform.isWindows){
    folder = "${PlatformUtils.getCoreDir()}\\win";
  }

  var corePath = PlatformUtils.getCoreExePath();

  if(ver!=null){
    if (kDebugMode) {
      print("package version:$ver");
    }
  }
  if (kDebugMode) {
    print("corePath:$corePath");
  }

  File file = File(join(folder,"config.yaml"));
  
  if (ver != packageVersion || !file.existsSync()) {
    try {
      Directory(folder).createSync();
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }

    var fileName = 'Country.mmdb';
    var data = await rootBundle.load("assets/core/$fileName");
    var bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    await File(join(folder, fileName)).writeAsBytes(bytes);

    fileName = 'geosite.dat';
    data = await rootBundle.load("assets/core/$fileName");
    bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    await File(join(folder, fileName)).writeAsBytes(bytes);

    if(!file.existsSync()){
      fileName = 'config.yaml';
      data = await rootBundle.load("assets/core/$fileName");
      bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await File(join(folder, fileName)).writeAsBytes(bytes);
    }

    file = File(join(folder,"fbbusiness_view.yaml"));
    if(!file.existsSync()){
      fileName = 'fbbusiness_view.yaml';
      data = await rootBundle.load("assets/core/$fileName");
      bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await File(join(folder, fileName)).writeAsBytes(bytes);
    }

    file = File(join(folder,"fb_ads_config.yaml"));
    if(!file.existsSync()){
      fileName = 'fb_ads_config.yaml';
      data = await rootBundle.load("assets/core/$fileName");
      bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await File(join(folder, fileName)).writeAsBytes(bytes);
    }


    if (Platform.isWindows) {}

    localStorage.setItem('ver', packageVersion);
  }
  startHttpServer(join(PlatformUtils.getCoreDir(), 'public'));
  runApp(const MyApp());
}

void startHttpServer(String webdir) async {
  HttpServer.bind('127.0.0.1', 8571).then((HttpServer server) {
    VirtualDirectory vd = VirtualDirectory(webdir);
    vd.jailRoot = false;
    server.listen((request) {
      // print("request.uri.path: " + request.uri.path);
      if (request.uri.path == '/services') {
      } else {
        // print('File request');
        vd.serveRequest(request);
      }
    });
  });
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: NavigationService.navigatorKey,
      title: 'Clash Core Manager',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomePage(title: 'Clash Core Manager'),
    );
  }
}
