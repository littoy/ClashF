import 'dart:io';
import 'dart:ui';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:process_run/shell_run.dart';
import 'package:window_manager/window_manager.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:flutter/cupertino.dart';
import 'package:flutter_macos_webview/flutter_macos_webview.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:http_server/http_server.dart';
import 'package:localstorage/localstorage.dart';
import 'package:system_tray/system_tray.dart';

String getCoreDir() {
  String mainPath = Platform.resolvedExecutable;
  return join(File(mainPath).parent.path, '..', 'Frameworks', 'App.framework',
      'Resources', 'flutter_assets', 'assets', 'core');
}

String getCoreExePath() {
  var clashEXE = 'clash';
  if (Platform.isWindows) {
    clashEXE = clashEXE + '.exe';
  }
  return join(getCoreDir(), clashEXE);
}

void main() async {
  String packageVersion = '1.1';
  WidgetsFlutterBinding.ensureInitialized();
  // Must add this line.
  await windowManager.ensureInitialized();

  // Use it only after calling `hiddenWindowAtLaunch`
  windowManager.waitUntilReadyToShow().then((_) async {
    // Hide window title bar
    await windowManager.setTitleBarStyle('hidden');
    await windowManager.setSize(const Size(290, 460));
    await windowManager.center();
    await windowManager.hide();
    await windowManager.setSkipTaskbar(true);
  });

  final storage = new LocalStorage('mainconf.json');
  await storage.ready;
  String? ver = await storage.getItem('ver');
  Directory directory = await getLibraryDirectory();
  var foler = join(directory.path, "clashCore");

  var corePath = getCoreExePath();

  print("package version:" + ver!);
  print("corePath:" + corePath);

  if (ver != packageVersion) {
    try {
      Directory(foler).createSync();
    } catch (e) {
      print(e);
    }
    //Dash board html
    // var data = await rootBundle.load("assets/core/public.zip");
    // var bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    // File zipFile = await File(join(foler, 'public.zip')).writeAsBytes(bytes);
    // final destinationDir = Directory(join(foler,'html'));
    // try {
    //   ZipFile.extractToDirectory(zipFile: zipFile, destinationDir: destinationDir);
    // } catch (e) {
    //   print(e);
    // }
    // String fileName = 'start.sh';
    // data = await rootBundle.load("assets/core/" + fileName);
    // bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    // await File(join(foler, fileName)).writeAsBytes(bytes);

    // fileName = 'stop.sh';
    // data = await rootBundle.load("assets/core/" + fileName);
    // bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    // await File(join(foler, fileName)).writeAsBytes(bytes);

    var fileName = 'Country.mmdb';
    var data = await rootBundle.load("assets/core/" + fileName);
    var bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    await File(join(foler, fileName)).writeAsBytes(bytes);

    fileName = 'geosite.dat';
    data = await rootBundle.load("assets/core/" + fileName);
    bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    await File(join(foler, fileName)).writeAsBytes(bytes);

    if (Platform.isWindows) {
      String fileName = 'win/start.cmd';
      data = await rootBundle.load("assets/core/" + fileName);
      bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await File(join(foler, fileName)).writeAsBytes(bytes);
      fileName = 'win/stop.cmd';
      data = await rootBundle.load("assets/core/" + fileName);
      bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await File(join(foler, fileName)).writeAsBytes(bytes);
      fileName = 'win/winsw.exe';
      data = await rootBundle.load("assets/core/" + fileName);
      bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await File(join(foler, fileName)).writeAsBytes(bytes);
      fileName = 'win/winsw.xml';
      data = await rootBundle.load("assets/core/" + fileName);
      bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await File(join(foler, fileName)).writeAsBytes(bytes);
      fileName = 'win/wintun.dll';
      data = await rootBundle.load("assets/core/" + fileName);
      bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await File(join(foler, fileName)).writeAsBytes(bytes);
    }

    storage.setItem('ver', packageVersion);
  }
  startHttpServer(join(getCoreDir(), 'public'));
  runApp(const MyApp());
}

void startHttpServer(String webdir) async {
  HttpServer.bind('127.0.0.1', 8571).then((HttpServer server) {
    VirtualDirectory vd = new VirtualDirectory(webdir);
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
      title: 'Clash Core Manager',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Clash Core Manager'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WindowListener {
  bool _runing = false;
  String _runState = 'Stoped';
  bool _tunmode = false;
  String _result = '';
  String _speed = '';
  String _mode = '';
  var _channel;
  var icon = const Icon(Icons.play_circle);
  final SystemTray _systemTray = SystemTray();
  final AppWindow _appWindow = AppWindow();

  Future<void> show() async {
    await windowManager.show();
    await windowManager.setSkipTaskbar(false);
  }

  Future<void> hide() async {
    await windowManager.hide();
    await windowManager.setSkipTaskbar(true);
  }

  Future<void> quit() async {
    await windowManager.destroy();
  }

  Future<void> stopAndQuit() async {
    if (_runing) {
      await _switch();
    }
    await windowManager.destroy();
  }

  Future<void> updateSystemTrayMenu() async {
    var runLabel = 'Run';
    var tunLabel = 'TUN';
    var ruleLabel = 'rule';
    var globalLabel = 'global';
    var directLabel = 'direct';
    if (_runing) {
      runLabel = '✔Runing';
    }
    if (_tunmode) {
      tunLabel = '✔TUN';
    }
    final menu = [
      MenuItem(label: 'Show', onClicked: show),
      MenuItem(
          label: runLabel,
          onClicked: () {
            _switch();
          }),
      MenuItem(
          label: tunLabel,
          onClicked: () {
            _patchConfig('', _tunmode ? 'false' : 'true');
          }),
      SubMenu(
        label: "Mode",
        children: [
          MenuItem(
            label: (_mode == 'rule' ? '✔' : '') + ruleLabel,
            onClicked: () {
              setState(() {
                        this._mode = 'rule';
              });
              _patchConfig(this._mode, '');
            },
          ),
          MenuItem(
            label: (_mode == 'direct' ? '✔' : '') + directLabel,
            onClicked: () {
              setState(() {
                        this._mode = 'direct';
              });
              _patchConfig(this._mode, '');
            },
          ),
          MenuItem(
            label: (_mode == 'global' ? '✔' : '') + globalLabel,
            onClicked: () {
              setState(() {
                        this._mode = 'global';
              });
              _patchConfig(this._mode, '');
            },
          ),
        ],
      ),
      MenuItem(label: 'Dashboard', onClicked: (){
        _onOpenDashboard(PresentationStyle.sheet);
      }),
      MenuItem(label: 'Hide', onClicked: hide),
      MenuSeparator(),
      MenuItem(label: 'Exit', onClicked: quit),
      MenuItem(label: 'Stop&Exit', onClicked: stopAndQuit),
    ];
    await _systemTray.setContextMenu(menu);
  }

  Future<void> initSystemTray() async {
    String path =
        Platform.isWindows ? 'assets/app_icon.ico' : 'assets/app_icon.png';
    // We first init the systray menu and then add the menu entries
    await _systemTray.initSystemTray(
      title: "",
      iconPath: path,
    );

    await updateSystemTrayMenu();
    // handle system tray event
    _systemTray.registerSystemTrayEventHandler((eventName) {
      debugPrint("eventName: $eventName");
      if (eventName == "leftMouseDown") {
      } else if (eventName == "leftMouseUp") {
        _systemTray.popUpContextMenu();
      } else if (eventName == "rightMouseDown") {
      } else if (eventName == "rightMouseUp") {
        _systemTray.popUpContextMenu();
      }
    });
  }

  void _connectws() async {
    WebSocket.connect("ws://127.0.0.1:9090/traffic?token=").then((ws) {
      // create the stream channel
      setState(() {
        icon = const Icon(Icons.stop_circle);
        _runState = 'Runing';
        _runing = true;
      });
      _loadConfig();

      _channel = IOWebSocketChannel(ws);
      _channel.stream.listen((message) {
        Map stat = jsonDecode(message);
        _systemTray.setTitle(stat['count'].toString());
        setState(() {
          _speed = message.toString();
        });
      });
    }).catchError((onError) {
      if (_runState == 'Runing') {
        Future.delayed(const Duration(seconds: 2), () {
          _connectws();
        });
      }
    });
  }

  void _closews() {
    _channel.sink.close(status.goingAway);
    setState(() {
      _speed = '';
    });
  }

  Future<void> _switch() async {
    Directory directory = await getLibraryDirectory();
    var clashWorkdir = join(directory.path, "clashCore");
    var startCMD =
        '/bin/bash "' + getCoreDir() + '/start.sh" "' + clashWorkdir + '"';
    var stopCMD =
        '/bin/bash "' + getCoreDir() + '/stop.sh" "' + clashWorkdir + '"';
    if (Platform.isWindows) {
      startCMD = getCoreDir() + "win\\start.cmd";
      stopCMD = getCoreDir() + "win\\stop.cmd";
    }
    _runing = !_runing;
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _runing without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _runState = _runing ? 'Runing' : 'Stoped';
    });
    if (_runing) {
      await run(startCMD)
          .then((result) => {
                Future.delayed(const Duration(seconds: 1), () {
                  _connectws();
                }),
                setState(() {
                  _result = result.outText;
                  icon = const Icon(Icons.stop_circle);
                })
              }).catchError((onError) {
                Future.delayed(const Duration(seconds: 1), () {
                  _connectws();
                });
                setState(() {
                  _result = '';
                  _runing = false;
                  icon = const Icon(Icons.play_circle);
                });
                print('start error!');
              });
    } else {
      await run(stopCMD)
          .then((result) => {
                // _closews(),
                setState(() {
                  _result = result.outText;
                  icon = const Icon(Icons.play_circle);
                  _tunmode = false;
                }),
                _systemTray.setTitle(''),
                _loadConfig()
              }).catchError((onError) {
                print('stop error!');
              });
    }
  }

  Future<void> _onOpenDashboard(PresentationStyle presentationStyle) async {
    final webview = FlutterMacOSWebView(
      onOpen: () => print('Opened'),
      onClose: () => print('Closed'),
      onPageStarted: (url) => print('Page started: $url'),
      onPageFinished: (url) => print('Page finished: $url'),
      onWebResourceError: (err) {
        print(
          'Error: ${err.errorCode}, ${err.errorType}, ${err.domain}, ${err.description}',
        );
      },
    );
    final width = window.physicalSize.width;
    await webview.open(
      url: 'http://127.0.0.1:8571/index.html#/proxies',
      presentationStyle: presentationStyle,
      size: Size( width > 1280 ? 1200.0:860.0, 600.0),
      modalTitle: 'DashBoard',
      userAgent:
          'Mozilla/5.0 (iPhone; CPU iPhone OS 14_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Mobile/15E148 Safari/604.1',
    );

    // await Future.delayed(Duration(seconds: 5));
    // await webview.close();
  }

  Future<void> _onReloadConfigPressed() async {
    var uri = Uri.parse('http://127.0.0.1:9090/configs');
    var response = await http.put(
      uri,
      headers: {
        'Content-Type': 'application/json',
      },
      body: "{}",
    );
    if (response.statusCode == 204) {
      setState(() {
        _speed = 'reloaded';
      });
    } else {
      setState(() {
        _speed = 'Failed';
      });
    }
    _loadConfig();
  }

  Future<void> _onChooseConfig() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      String? filePath = result.files.single.path;
      Directory directory = await getLibraryDirectory();
      var foler = join(directory.path, "clashCore");
      File file = File(filePath!);
      await file.copy(join(foler, 'config.yaml'));
      await _onReloadConfigPressed();
    } else {
      // User canceled the picker
    }
  }

  Future<void> _loadConfig() async {
    var uri = Uri.parse('http://127.0.0.1:9090/configs');
    try {
      var response = await http.get(uri, headers: {
        'Content-Type': 'application/json',
      });
      if (response.statusCode == 200) {
        // print(response.body);
        Map config = jsonDecode(response.body);
        setState(() {
          _mode = config['mode'];
          _tunmode = config['tun'];
        });
      }
    } catch (e) {
      setState(() {
        _mode = '';
        _tunmode = false;
      });
    }
    updateSystemTrayMenu();
  }

  Future<void> _patchConfig(String mode, String tun) async {
    var uri = Uri.parse('http://127.0.0.1:9090/configs');
    try {
      var response = await http.patch(uri,
          headers: {
            'Content-Type': 'application/json',
          },
          body: mode != ''
              ? '{"mode":"' + mode + '"}'
              : '{"tun":{"enable":' + tun + '}}');
      if (response.statusCode == 204) {
        _loadConfig();
      } else {
        if (mode != '') {
          setState(() {
            _mode = '';
            _tunmode = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _mode = '';
        _tunmode = false;
      });
    }
  }

  @override
  void initState() {
    windowManager.addListener(this);
    super.initState();
    _connectws();
    _loadConfig();
    initSystemTray();
  }

  @override
  void onWindowClose() {
    // do something
    windowManager.setSkipTaskbar(true);
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _switch method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Invoke "debug painting" (press "p" in the console, choose the
          // "Toggle Debug Paint" action from the Flutter Inspector in Android
          // Studio, or the "Toggle Debug Paint" command in Visual Studio Code)
          // to see the wireframe for each widget.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'Clash Run Status:',
            ),
            Text(
              _runState,
              style: Theme.of(context).textTheme.headline5,
            ),
            Text(
              _speed,
            ),
            SwitchListTile(
              title: const Text('Tun'),
              value: _tunmode,
              onChanged: (bool value) {
                setState(() {
                  _tunmode = value;
                });
                _patchConfig('', _tunmode ? 'true' : 'false');
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // SizedBox(
                //   width: 10,
                // ),
                // Text("Model"),
                Radio(
                    value: 'rule',
                    groupValue: _mode,
                    onChanged: (value) {
                      setState(() {
                        this._mode = 'rule';
                      });
                      _patchConfig(this._mode, '');
                    }),
                const Text("Rule"),
                Radio(
                    value: 'global',
                    groupValue: _mode,
                    onChanged: (value) {
                      setState(() {
                        this._mode = 'global';
                      });
                      _patchConfig(this._mode, '');
                    }),
                const Text("Global"),
                Radio(
                    value: 'direct',
                    groupValue: _mode,
                    onChanged: (value) {
                      setState(() {
                        this._mode = 'direct';
                      });
                      _patchConfig(this._mode, '');
                    }),
                const Text("Direct"),
              ],
            ),
            CupertinoButton(
              child: Text('DashBoard'),
              onPressed: () => _onOpenDashboard(PresentationStyle.modal),
            ),
            CupertinoButton(
              child: Text('ReloadConfig'),
              onPressed: () => _onReloadConfigPressed(),
            ),
            CupertinoButton(
              child: Text('ChooseConfig'),
              onPressed: () => _onChooseConfig(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _switch,
        tooltip: 'Start or Stop',
        child: icon,
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
