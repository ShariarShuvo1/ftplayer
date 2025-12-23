import 'package:flutter/services.dart';

class NetworkOptimization {
  static const _networkChannel = MethodChannel('com.example.ftplayer/network');

  static Future<void> optimizeForStreaming() async {
    await _networkChannel.invokeMethod('optimizeNetworkBuffers');
  }
}
