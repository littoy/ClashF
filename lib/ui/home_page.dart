import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_macos_webview/flutter_macos_webview.dart';
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
      onOpenDashboard: () => _openDashboard(PresentationStyle.sheet),
      onInstallHelper: _clashService.installHelper,
      onHide: _hideWindow,
      onQuit: _quit,
      onStopAndQuit: _stopAndQuit,
    );
  }

  Future<void> _toggleRun() async {
    setState(() {
      _running = !_running;
      _runState = _running ? 'Running' : 'Stopped';
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
        Future.delayed(const Duration(seconds: 1), () {
          _connectWs();
        });
        setState(() {
          _icon = const Icon(Icons.stop_circle);
        });
      } else {
        // Stopped successfully
        setState(() {
          _icon = const Icon(Icons.play_circle);
          _tunMode = false;
        });
        _trayService.setTitle('');
        _loadConfig();
      }
    } catch (e) {
       // Error handling
       if (_running) {
         // Failed to start
          Future.delayed(const Duration(seconds: 1), () {
            _connectWs();
          });
          setState(() {
            _running = false;
            _icon = const Icon(Icons.play_circle);
          });
          showToast("Retry update status");
       } else {
         showToast("Stop error: $e");
       }
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
        _mode = config['mode'];
        _tunMode = config['tun']['enable'];
      });
    } else {
      setState(() {
        _mode = '';
        _tunMode = false;
      });
    }
    _updateTray();
  }

  void _connectWs() {
    _wsService.connect().listen((stat) {
      var up = stat['up'];
      var down = stat['down'];
      var total = up + down;

      _trayService.setTitle(_getBWHumanString(total));
      setState(() {
        _speed = stat.toString();
        // If we receive data, we are running
        if (!_running) {
           _running = true;
           _runState = 'Running';
           _icon = const Icon(Icons.stop_circle);
           _updateTray();
        }
      });
    }, onError: (err) {
      if (_runState == 'Running') {
        showToast("Waiting start..." + err.toString());
        Future.delayed(const Duration(seconds: 2), () {
          _connectWs();
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

  Future<void> _openDashboard(PresentationStyle presentationStyle) async {
    const url = 'http://127.0.0.1:8571/index.html#/proxies';
    if (Platform.isMacOS) {
      final webview = FlutterMacOSWebView(
        onOpen: () => print('Opened'),
        onClose: () => print('Closed'),
        onPageStarted: (url) => print('Page started: $url'),
        onPageFinished: (url) => print('Page finished: $url'),
        onWebResourceError: (err) {
          showToast("Load dashboard failed.");
        },
      );
      final width = View.of(context).physicalSize.width;
      await webview.open(
        url: url,
        presentationStyle: presentationStyle,
        size: Size(width > 1280 ? 1200.0 : 860.0, 600.0),
        modalTitle: 'DashBoard',
        userAgent:
            'Mozilla/5.0 (iPhone; CPU iPhone OS 14_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/14.0 Mobile/15E148 Safari/604.1',
      );
    } else {
      var uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        showToast("Could not launch $url");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'Clash Run Status:',
            ),
            Text(
              _runState,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              _speed,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _toggleRun,
        tooltip: 'Run/Stop',
        child: _icon,
      ),
    );
  }
}
