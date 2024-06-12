import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

/// MainActivityで実装するメソッドチャネル名
// ignore: constant_identifier_names
const String _METHOD_CHANNEL_NAME = "com.oec.onlineCommunication/method";

// ignore: constant_identifier_names
const String _PEER_EVENT_CHANNEL_NAME = "com.oec.onlineCommunication/event";

enum CaptureEvent {
  /// SFUまたはMeshルームをオープンした(自分が入室した)
  OnOpenRoom,
}

typedef OnCaptureEventCallback = void Function(
    CaptureEvent event, Map<dynamic, dynamic> args);

/// プラットフォーム側関係の処理へアクセスするためのメソッドチャネル
const MethodChannel _channel = MethodChannel(_METHOD_CHANNEL_NAME);

/// Skyway関係のプラットフォーム側実装へアクセスするためのラッパークラス
class CapturePeer {
//--------------------------------------------------------------------------------
  // final String peerId;
  final OnCaptureEventCallback onEvent;
  StreamSubscription<dynamic> _eventSubscription;

  /// 内部使用のコンストラクタ
  // CapturePeer._internal({required this.peerId, required this.onEvent})
  // : assert(onEvent != null);
  CapturePeer._internal({
    // required this.peerId,
    required this.onEvent,
  }) : _eventSubscription = StreamController<dynamic>().stream.listen((_) {});

  /// 画面共有映像停止
  Future<void> stopCaptureStream() async {
    debugPrint("stopCaptureStream:");
    return await _channel.invokeMethod('stopCaptureStream');
  }

  /// foreground サービス開始
  static Future<CapturePeer?> startForegroundService(
      OnCaptureEventCallback onEvent) async {
    debugPrint("startForegroundService:");
    await _channel.invokeMethod('startForegroundService');

    return CapturePeer._internal(onEvent: onEvent).._initialize();
  }

  /// 画面共有映像の取得開始
  Future<bool> startCaptureStream() async {
    debugPrint("startCaptureStream:");
    bool isStartCapture = await _channel.invokeMethod('startCaptureStream');
    return isStartCapture;
  }

//--------------------------------------------------------------------------------
  /// 初期化処理
  void _initialize() {
    // debugPrint("initialize:peerId=$peerId");
    _eventSubscription = EventChannel(_PEER_EVENT_CHANNEL_NAME)
        .receiveBroadcastStream()
        .listen(_eventListener, onError: _errorListener);
  }

  /// イベントチャネルでイベントを受信したときの処理
  void _eventListener(dynamic event) {
    debugPrint("_eventListener:$event");
  }

  /// イベントチャネルでエラーが発生したときの処理
  void _errorListener(Object obj) {
    debugPrint("_eventListener:$obj");
    debugPrint('onError: $obj');
  }
}
