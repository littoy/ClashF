import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as status;

import 'clash_service.dart';

class WebSocketService {
  IOWebSocketChannel? _channel;
  String get _wsUrl => "ws://127.0.0.1:${ClashService.extPort}/traffic?token=";

  Stream<Map<String, dynamic>> connect() {
    // ignore: close_sinks
    StreamController<Map<String, dynamic>> controller = StreamController();

    WebSocket.connect(_wsUrl).then((ws) {
      _channel = IOWebSocketChannel(ws);
      _channel!.stream.listen((message) {
        try {
          Map<String, dynamic> stat = jsonDecode(message);
          controller.add(stat);
        } catch (e) {
          // ignore error
        }
      }, onError: (error) {
        controller.addError(error);
      }, onDone: () {
        controller.close();
      });
    }).catchError((onError) {
      controller.addError(onError);
    });

    return controller.stream;
  }

  void close() {
    _channel?.sink.close(status.goingAway);
    _channel = null;
  }

  bool isConnected() {
    return _channel != null;
  }
}
