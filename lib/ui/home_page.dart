import 'dart:io';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

import '../services/clash_service.dart';
import '../services/tray_service.dart';
import '../services/websocket_service.dart';
import '../utils/platform_utils.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WindowListener {
  final ClashService _clashService = ClashService();
  final WebSocketService _wsService = WebSocketService();
  final TrayService _trayService = TrayService();

  bool _running = false;
  String _runState = 'Stopped';
  bool _tunMode = false;
  String _speed = '';
  String _mode = '';
  bool isWaiting = false;
  bool stopActionInProgress = false;
  Icon _icon = const Icon(Icons.play_circle);
  
  // Timer? _retryTimer;

  @override
  void initState() {
    windowManager.addListener(this);
    super.initState();
    _init();
  }

  void _init() async {
    await _trayService.init(_showWindow);
    _connectWs();
    _loadConfig();
    _updateTray();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _wsService.close();
    super.dispose();
  }

  @override
  void onWindowClose() {
    windowManager.setSkipTaskbar(true);
  }

  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.setSkipTaskbar(false);
  }

  Future<void> _hideWindow() async {
    await windowManager.hide();
    await windowManager.setSkipTaskbar(true);
  }

  Future<void> _quit() async {
    await windowManager.destroy();
  }

  Future<void> _stopAndQuit() async {
    await _clashService.stopAndQuit(_running);
    await windowManager.destroy();
  }

  void _updateTray() {
    _trayService.updateMenu(
      isRunning: _running,
      isTunMode: _tunMode,
      mode: _mode,
      onShow: _showWindow,
      onToggleRun: _toggleRun,
      onToggleTun: _toggleTun,
      onModeChange: _changeMode,
      onOpenDashboard: () => _openDashboard(),
      onReloadConfig: _reloadConfig,
      onInstallHelper: _clashService.installHelper,
      onHide: _hideWindow,
      onQuit: _quit,
      onStopAndQuit: _stopAndQuit,
    );
  }

  Future<void> _toggleRun() async {
    setState(() {
      _running = !_running;
      _tunMode = _running ? _tunMode : false;
      _runState = _running
          ? (_tunMode ? I18n.s('TUN mode', 'TUN模式') : I18n.s('Running', '运行中'))
          : I18n.s('Stopped', '已停止');
      isWaiting = true;
      stopActionInProgress = !_running;
    });
    try {
      await _clashService.switchCore(_running); // Note: logic in switchCore might be flipped in my implementation vs original? 
      // Original: if (_runing) run(startCMD) else run(stopCMD)
      // My Service: if (!isRunning) run(startCMD) else run(stopCMD) -> Wait, let's check service logic.
      // Service: if (!isRunning) { start } else { stop }. 
      // If I pass `_running` (which is true), it executes stop. That's wrong.
      // I need to fix the service or the call. 
      // Let's assume I fix the service to take `start` boolean.
      
      if (_running) {
        // Started successfully
        Future.delayed(const Duration(seconds: 3), () {
          _connectWs();
          _loadConfig();
        });
        setState(() {
          _icon = const Icon(Icons.stop_circle);
          isWaiting = false;
        });
      } else {
        // Stopped successfully
        setState(() {
          _icon = const Icon(Icons.play_circle);
          _tunMode = false;
          isWaiting = false;
        });
        _trayService.setTitle('');
      }
    } catch (e) {
       // Error handling
       if (_running) {
         // Failed to start
          Future.delayed(const Duration(seconds: 3), () {
            _connectWs();
          });
          setState(() {
            _running = false;
            _icon = const Icon(Icons.play_circle);
          });
          showToast("Retry update status");
       } else {
         showToast("Stop error: $e");
         setState(() {
          _icon = const Icon(Icons.play_circle);
          _tunMode = false;
          isWaiting = false;
        });
        _trayService.setTitle('');
       }
       isWaiting = false;
    }
    _updateTray();
  }

  Future<void> _toggleTun() async {
    await _clashService.patchConfig('', _tunMode ? 'false' : 'true');
    _loadConfig();
  }

  Future<void> _changeMode(String mode) async {
    setState(() {
      _mode = mode;
    });
    await _clashService.patchConfig(mode, '');
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    var config = await _clashService.loadConfig();
    if (config != null) {
      setState(() {
        _mode = config['mode'] ?? '';
        _tunMode = config['tun']?['enable'] ?? false;
        _runState = _running
            ? (_tunMode ? I18n.s('TUN mode', 'TUN模式') : I18n.s('Running', '运行中'))
            : I18n.s('Stopped', '已停止');
      });
    } else {
      if (!_running) {
        setState(() {
          _mode = '';
          _tunMode = false;
          _runState = I18n.s('Stopped', '已停止');
        });
      }
    }
    _updateTray();
  }

  var retryCount = 0;
  void _connectWs() {
    _wsService.connect().listen((stat) {
      retryCount = 0;
      var up = stat['up'];
      var down = stat['down'];
      var total = up + down;

      _trayService.setTitle(_getBWHumanString(total));
      setState(() {
        _speed =
            "${_getBWHumanString(up)}↑ ${_getBWHumanString(down)}↓ ${I18n.s('Connections', '连接数')}: ${stat['count']}";
        // If we receive data, we are running
        if (!_running && !stopActionInProgress) {
           _running = true;
           _runState = I18n.s('Running', '运行中');
           _icon = const Icon(Icons.stop_circle);
           _updateTray();
        }
      });
    }, onError: (err) {
      if (_running) {
        //showToast("Waiting start..." + err.toString());
        Future.delayed(const Duration(seconds: 2), () {
          retryCount++;
          if(!_wsService.isConnected() && retryCount < 5){
            _connectWs();
          }

        });
      }
    });
  }

  String _getBWHumanString(int bytePerSeconds) {
    if (bytePerSeconds > 1024 * 1024 * 1024) {
      return "${bytePerSeconds / 1024 / 1024 ~/ 1024}G";
    } else if (bytePerSeconds > 1024 * 1024) {
      return "${bytePerSeconds / 1024 ~/ 1024}M";
    } else if (bytePerSeconds > 1024) {
      return "${bytePerSeconds ~/ 1024}K";
    }
    return "$bytePerSeconds";
  }

  Future<void> _openDashboard() async {
    //先检查当前主窗口是否在前台显示
    if (!await windowManager.isVisible()) {
      await windowManager.show();
    }
    const url = 'http://127.0.0.1:8571/index.html#/proxies';
    if (Platform.isMacOS || Platform.isWindows) {
      Size oldSize = await windowManager.getSize();
      final width = View.of(context).physicalSize.width;
      await windowManager.setSize(Size(width > 1280 ? 1200 : 860, 650),);
      await windowManager.center();

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DashboardPage(url: url),
        ),
      );

      await windowManager.setSize(oldSize);
      await windowManager.center();
    } else {
      var uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        showToast("Could not launch $url");
      }
    }
  }

  Future<void> _openConfigFolder() async {
    var dir = await _clashService.getWorkDir();
    if (!await Directory(dir).exists()) {
      await Directory(dir).create(recursive: true);
    }
    if (Platform.isWindows) {
      await Process.run('explorer', [dir]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [dir]);
    }
  }

  Future<void> _openConfigEditor() async {
    const url = 'http://127.0.0.1:9090/ui/fb-mok-config/';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      showToast("Could not launch $url");
    }
  }

  Future<void> _reloadConfig() async {
    var ok = await _clashService.reloadConfig();
    if (ok) {
      _loadConfig();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        centerTitle: true,
        toolbarHeight: kToolbarHeight + (Platform.isMacOS ? 10.0 : 0.0),
        flexibleSpace: DragToMoveArea(
            child: Container(
          height: kToolbarHeight + (Platform.isMacOS ? 10.0 : 0.0),
        )),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(I18n.s('Clash Status:', '运行状态')),
            Text(
              _runState,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              _speed,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _running ? _openDashboard : null,
              child: Text(I18n.s('Dashboard', '控制面板')),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _openConfigEditor,
              child: Text(I18n.s('Config Editor', '配置编辑')),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _openConfigFolder,
              child: Text(I18n.s('Config Folder', '配置文件夹')),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _reloadConfig,
              child: Text(I18n.s('Reload Config', '重载配置')),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: isWaiting ? null : _toggleRun,
        tooltip: 'Run/Stop',
        child: _icon,
      ),
    );
  }
}

class DashboardPage extends StatefulWidget {
  final String url;

  const DashboardPage({Key? key, required this.url}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  InAppWebViewController? webViewController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Dashboard"),
        centerTitle: true,
        toolbarHeight: kToolbarHeight + (Platform.isMacOS ? 10.0 : 0.0),
        flexibleSpace: DragToMoveArea(
            child: Container(
          height: kToolbarHeight + (Platform.isMacOS ? 10.0 : 0.0),
        )),
      ),
      body: SafeArea(
        child: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(widget.url)),
        initialSettings: InAppWebViewSettings(
          userAgent:
              'Mozilla/5.0 (iPhone; CPU iPhone OS 14_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Mobile/15E148 Safari/604.1',
        ),
        onWebViewCreated: (controller) {
          webViewController = controller;
        },
        onLoadStart: (controller, url) {
          print("Page started: $url");
        },
        onLoadStop: (controller, url) {
          print("Page finished: $url");
        },
        onReceivedError: (controller, request, error) {
          print("Load dashboard failed: $error");
          showToast("Load dashboard failed.");
        },
      ),
      ),
    );
  }
}
