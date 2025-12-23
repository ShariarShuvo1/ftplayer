import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

final _logger = Logger();

class NetworkOptimization {
  static const _networkChannel = MethodChannel('com.example.ftplayer/network');

  static Future<void> optimizeForStreaming() async {
    try {
      await _networkChannel.invokeMethod('optimizeNetworkBuffers');
      _logger.i('Network buffers optimized for streaming');
    } catch (e) {
      _logger.w('Could not optimize network buffers: $e');
    }
  }
}
