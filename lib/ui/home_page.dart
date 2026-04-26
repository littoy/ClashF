import 'dart:io';
import 'dart:collection';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:localstorage/localstorage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

import '../main.dart'; // for appVersion
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
  String _activeProfile = '';
  List<String> _profiles = [];
  Map<String, dynamic> _proxyGroups = {};
  Map<String, int> _proxyDelays = {};
  Map<String, bool> _expandedGroups = {};
  int _port = 0;
  int _socksPort = 0;
  bool isWaiting = false;
  bool stopActionInProgress = false;
  
  String _clashVersion = 'Unknown';
  Timer? _refreshTimer;

  int get _currentSegmentIndex {
    if (!_running) return 0;
    if (_tunMode) return 2;
    return 1;
  }

  Future<void> _setRunState(int index) async {
    if (isWaiting) return;
    
    bool targetRunning = index != 0;
    bool targetTun = index == 2;

    if (_running == targetRunning && _tunMode == targetTun) {
      return; 
    }

    if (_running != targetRunning) {
      await _toggleRun();
      if (targetRunning && _tunMode != targetTun) {
         await Future.delayed(const Duration(milliseconds: 1000));
         await _toggleTun();
      }
    } else if (_running && _tunMode != targetTun) {
      await _toggleTun();
    }
  }

  @override
  void initState() {
    windowManager.addListener(this);
    super.initState();
    _init();
    // 增加定时刷新，确保托盘数据不滞后
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (_running) {
        _loadProxies();
      }
    });
  }

  void _init() async {
    _clashVersion = await ClashService.getClashVersion();
    await _trayService.init(_showWindow, _onMenuOpen);
    var savedProfile = await _clashService.getActiveProfile();
    if (savedProfile.isEmpty) {
      savedProfile = localStorage.getItem('active_profile') ?? 'config.yaml';
    }
    _activeProfile = savedProfile;
    _profiles = await _clashService.getConfigList();
    if (!_profiles.contains(_activeProfile)) {
      _profiles.insert(0, _activeProfile);
    }
    if (_profiles.isEmpty) {
      _profiles.add('config.yaml');
    }
    _connectWs();
    _loadConfig();
    _loadProxies();
    _updateTray();
  }

  Future<void> _onMenuOpen() async {
    // 仅在非等待状态下静默刷新
    if (!isWaiting) {
      await _loadProxies();
    }
  }

  Future<void> _changeProfile(String profile) async {
    if (isWaiting) return;
    setState(() {
      _activeProfile = profile;
      isWaiting = true;
    });
    _updateTray();

    try {
      localStorage.setItem('active_profile', profile);
      await _clashService.setActiveProfile(profile);
      
      String oldPort = ClashService.extPort;
      await _clashService.changeProfile(profile, isRunning: _running);
      
      _profiles = await _clashService.getConfigList();
      if (!_profiles.contains(_activeProfile)) {
        _profiles.insert(0, _activeProfile);
      }
      
      if (oldPort != ClashService.extPort) {
        _wsService.close();
        if (_running) {
          _connectWs();
        }
      }
      
      await _loadConfig();
      await _loadProxies();
    } finally {
      setState(() {
        isWaiting = false;
      });
      _updateTray();
    }
  }

  Future<void> _changeProxy(String groupName, String proxyName) async {
    if (isWaiting) return;
    bool success = await _clashService.selectProxy(groupName, proxyName);
    if (success) {
      await _loadProxies();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    windowManager.removeListener(this);
    _wsService.close();
    super.dispose();
  }

  @override
  void onWindowClose() {
    windowManager.setSkipTaskbar(true);
  }

  @override
  void onWindowFocus() {
    if (_running) {
      _loadProxies();
    }
  }

  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.setSkipTaskbar(false);
    if (_running) {
      _loadProxies();
    }
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
      isWaiting: isWaiting,
      mode: _mode,
      profiles: _profiles,
      activeProfile: _activeProfile,
      proxyGroups: _proxyGroups,
      proxyDelays: _proxyDelays,
      appVersion: appVersion,
      clashVersion: _clashVersion,
      onProxyChange: _changeProxy,
      onShow: _showWindow,
      onToggleRun: _toggleRun,
      onToggleTun: _toggleTun,
      onModeChange: _changeMode,
      onProfileChange: _changeProfile,
      onOpenDashboard: () => _openDashboard(),
      onReloadConfig: _reloadConfig,
      onOpenConfigFolder: _openConfigFolder,
      onSpeedTest: _speedTest,
      onInstallHelper: _clashService.installHelper,
      onHide: _hideWindow,
      onQuit: _quit,
      onStopAndQuit: _stopAndQuit,
    );
  }

  Future<void> _speedTest() async {
    if (isWaiting || !_running) return;
    setState(() {
      isWaiting = true;
    });
    _updateTray();

    showToast(I18n.s('Testing latency...', '正在进行节点测速...'));
    
    try {
      // Get current proxies to find all node names
      var data = await _clashService.getProxies();
      if (data != null && data['proxies'] != null) {
        Map<String, dynamic> proxies = data['proxies'];
        List<String> nodesToTest = [];
        
        proxies.forEach((key, value) {
          // Typically we only want to test real nodes, not groups
          if (value['type'] != 'Selector' && value['type'] != 'URLTest' && value['type'] != 'Fallback' && value['type'] != 'LoadBalance') {
            nodesToTest.add(key);
          }
        });

        // Test in parallel with a concurrency limit if needed, but for now simple parallel
        await Future.wait(nodesToTest.map((name) => _clashService.getProxyDelay(name)));
        
        showToast(I18n.s('Speed test completed.', '节点测速完成'));
      }
    } finally {
      setState(() {
        isWaiting = false;
      });
      await _loadProxies();
    }
  }

  Future<void> _toggleRun() async {
    if (isWaiting) return;
    setState(() {
      isWaiting = true;
      _running = !_running;
      _tunMode = _running ? _tunMode : false;
      _runState = _running
          ? (_tunMode ? I18n.s('TUN mode', 'TUN模式') : I18n.s('Running', '运行中'))
          : I18n.s('Stopped', '已停止');
      stopActionInProgress = !_running;
    });
    _updateTray();

    try {
      await _clashService.switchCore(_running); 
      
      if (_running) {
        await Future.delayed(const Duration(seconds: 3));
        _connectWs();
        await _loadConfig();
        await _loadProxies();
        setState(() {
          isWaiting = false;
        });
      } else {
        setState(() {
          _tunMode = false;
          isWaiting = false;
          _proxyGroups = {};
          _proxyDelays = {};
        });
        _trayService.setTitle('');
      }
    } catch (e) {
       showToast("Core error: $e");
       setState(() {
        isWaiting = false;
      });
    }
    _updateTray();
  }

  Future<void> _toggleTun() async {
    if (isWaiting) return;
    setState(() {
      isWaiting = true;
    });
    _updateTray();

    try {
      await _clashService.patchConfig('', _tunMode ? 'false' : 'true');
      await _loadConfig();
    } finally {
      setState(() {
        isWaiting = false;
      });
      _updateTray();
    }
  }

  Future<void> _changeMode(String mode) async {
    if (isWaiting) return;
    setState(() {
      _mode = mode;
      isWaiting = true;
    });
    _updateTray();

    try {
      await _clashService.patchConfig(mode, '');
      await _loadConfig();
      await _loadProxies();
    } finally {
      setState(() {
        isWaiting = false;
      });
      _updateTray();
    }
  }

  Future<void> _loadConfig() async {
    var config = await _clashService.loadConfig();
    if (config != null) {
      setState(() {
        _mode = config['mode'] ?? '';
        _port = config['port'] ?? 0;
        _socksPort = config['socks-port'] ?? 0;
        _tunMode = config['tun']?['enable'] ?? false;
        _runState = _running
            ? (_tunMode ? I18n.s('TUN mode', 'TUN模式') : I18n.s('Running', '运行中'))
            : I18n.s('Stopped', '已停止');
      });
    }
    _updateTray();
  }

  Future<void> _loadProxies() async {
    if (!_running) return;
    var data = await _clashService.getProxies();
    if (data != null && data['proxies'] != null) {
      Map<String, dynamic> proxies = data['proxies'];
      Map<String, dynamic> groups = {};
      Map<String, int> delays = {};
      
      proxies.forEach((key, value) {
        if (value['history'] != null && value['history'] is List && (value['history'] as List).isNotEmpty) {
          var history = value['history'] as List;
          var last = history.last;
          if (last['delay'] != null) {
            delays[key] = last['delay'] as int;
          }
        }

        if (value['all'] != null && value['all'] is List && (value['all'] as List).isNotEmpty) {
          if (value['type'] == 'Selector' || value['type'] == 'URLTest' || value['type'] == 'Fallback' || value['type'] == 'LoadBalance') {
             groups[key] = value;
          }
        }
      });
      
      Map<String, dynamic> sortedGroups = {};
      var keys = groups.keys.toList();
      keys.remove('GLOBAL');
      
      if (groups.containsKey('GLOBAL') && groups['GLOBAL']['all'] is List) {
        var globalAll = groups['GLOBAL']['all'] as List;
        keys.sort((a, b) {
          int indexA = globalAll.indexOf(a);
          int indexB = globalAll.indexOf(b);
          if (indexA == -1) indexA = 999999;
          if (indexB == -1) indexB = 999999;
          return indexA.compareTo(indexB);
        });
      }

      for (var k in keys) {
        sortedGroups[k] = groups[k];
      }
      if (groups.containsKey('GLOBAL')) {
        sortedGroups['GLOBAL'] = groups['GLOBAL'];
      }

      setState(() {
        _proxyGroups = sortedGroups;
        _proxyDelays = delays;
      });
      _updateTray(); // 确保数据更新到托盘
    }
  }

  String _getProxyDisplayName(String name) {
    if (_proxyDelays.containsKey(name)) {
      return '$name (${_proxyDelays[name]}ms)';
    }
    return name;
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
        if (!_running && !stopActionInProgress) {
           _running = true;
           _runState = I18n.s('Running', '运行中');
           _loadProxies();
        }
      });
    }, onError: (err) {
      if (_running) {
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
    if (!await windowManager.isVisible()) {
      await windowManager.show();
    }
    final url = 'http://127.0.0.1:8571/index.html?hostname=127.0.0.1&port=${ClashService.extPort}#/proxies';
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
    final url = 'http://127.0.0.1:${ClashService.extPort}/ui/fb-mok-config/';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      showToast("Could not launch $url");
    }
  }

  Future<void> _reloadConfig() async {
    if (isWaiting) return;
    setState(() {
      isWaiting = true;
    });
    _updateTray();

    try {
      var ok = await _clashService.reloadConfig();
      if (ok) {
        await _loadConfig();
        await _loadProxies();
      }
    } finally {
      setState(() {
        isWaiting = false;
      });
      _updateTray();
    }
  }

  Color _getDelayColor(int? delay) {
    if (delay == null) return Colors.transparent;
    if (delay == 0) return Colors.red;
    if (delay < 500) return Colors.green;
    return Colors.orange;
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(I18n.s('Clash Status:', '运行状态')),
              const SizedBox(height: 10),
              CupertinoSlidingSegmentedControl<int>(
                groupValue: _currentSegmentIndex,
                thumbColor: Colors.blue,
                children: {
                  0: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        I18n.s('Off', '关'),
                        style: TextStyle(
                            color: _currentSegmentIndex == 0
                                ? Colors.white
                                : null),
                      )),
                  1: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        I18n.s('On', '开'),
                        style: TextStyle(
                            color: _currentSegmentIndex == 1
                                ? Colors.white
                                : null),
                      )),
                  2: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        I18n.s('Tun', '增强'),
                        style: TextStyle(
                            color: _currentSegmentIndex == 2
                                ? Colors.white
                                : null),
                      )),
                },
                onValueChanged: (int? value) {
                  if (isWaiting) return;
                  if (value != null) {
                    _setRunState(value);
                  }
                },
              ),
              const SizedBox(height: 10),
              Text(
                _speed,
              ),
              const SizedBox(height: 10),
              Text('${I18n.s('Profile:', '配置文件:')} $_activeProfile'),
              Text('Port: $_port   Socks: $_socksPort   Mode: $_mode'),
              if (_running) ...[
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _openDashboard,
                  child: Text(I18n.s('Dashboard', '控制面板')),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _openConfigEditor,
                  child: Text(I18n.s('Config Editor', '配置编辑')),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: isWaiting ? null : _reloadConfig,
                  child: Text(I18n.s('Reload Config', '重载配置')),
                ),
              ],
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _openConfigFolder,
                child: Text(I18n.s('Config Folder', '配置文件夹')),
              ),
              if (_proxyGroups.isNotEmpty) const SizedBox(height: 20),
              if (_proxyGroups.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _proxyGroups.entries.map((entry) {
                      String groupName = entry.key;
                      String currentProxy = entry.value['now'] ?? '';
                      String groupType = entry.value['type'] ?? 'Selector';
                      List<dynamic> allProxies = entry.value['all'] ?? [];
                      
                      bool isExpanded = _expandedGroups[groupName] ?? false;
                      bool showExpandButton = allProxies.length > 8;
                      List<dynamic> displayProxies = isExpanded || !showExpandButton ? allProxies : allProxies.take(8).toList();
                      
                      if (!isExpanded && showExpandButton && !displayProxies.contains(currentProxy) && currentProxy.isNotEmpty) {
                         if (displayProxies.isNotEmpty) {
                           displayProxies[displayProxies.length - 1] = currentProxy;
                         }
                      }
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.5))),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 110,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(groupName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.blue),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(groupType, style: const TextStyle(color: Colors.blue, fontSize: 11)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Wrap(
                                spacing: 8.0,
                                runSpacing: 8.0,
                                children: displayProxies.map((dynamic value) {
                                  String nodeName = value.toString();
                                  bool isSelected = nodeName == currentProxy;
                                  int? delay = _proxyDelays[nodeName];
                                  Color statusColor = _getDelayColor(delay);
                                  
                                  return InkWell(
                                    onTap: isWaiting ? null : () {
                                      _changeProxy(groupName, nodeName);
                                    },
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isSelected ? Colors.blue : Colors.transparent,
                                        border: Border.all(
                                          color: isSelected 
                                            ? Colors.blue 
                                            : (delay != null ? statusColor : Theme.of(context).dividerColor),
                                          width: isSelected ? 1.0 : (delay != null ? 1.5 : 1.0),
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Text(
                                        _getProxyDisplayName(nodeName),
                                        style: TextStyle(
                                          color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            if (showExpandButton)
                              Padding(
                                padding: const EdgeInsets.only(left: 8.0),
                                child: TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _expandedGroups[groupName] = !isExpanded;
                                    });
                                  },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    isExpanded ? I18n.s('Collapse', '收起') : I18n.s('Expand', '展开'),
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
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
        onLoadStart: (controller, url) {},
        onLoadStop: (controller, url) {},
        onReceivedError: (controller, request, error) {
          showToast("Load dashboard failed.");
        },
      ),
      ),
    );
  }
}
