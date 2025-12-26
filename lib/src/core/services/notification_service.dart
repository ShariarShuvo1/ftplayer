import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../features/downloads/data/download_models.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  late FlutterLocalNotificationsPlugin _notificationsPlugin;
  bool _isInitialized = false;

  NotificationService._();

  factory NotificationService() {
    return _instance;
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    _notificationsPlugin = FlutterLocalNotificationsPlugin();

    const androidSettings = AndroidInitializationSettings(
      '@drawable/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _notificationsPlugin.initialize(
      InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    _isInitialized = true;
  }

  Future<void> createDownloadNotificationChannel() async {
    const androidChannel = AndroidNotificationChannel(
      'download_channel',
      'Downloads',
      description: 'Notifications for active downloads',
      importance: Importance.high,
      enableVibration: false,
      playSound: false,
      ledColor: Color(0xFFFF8A00),
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(androidChannel);
  }

  Future<void> showDownloadNotification(DownloadTask task) async {
    if (task.status != DownloadStatus.downloading) {
      await cancelDownloadNotification();
      return;
    }

    await initialize();
    await createDownloadNotificationChannel();

    final progress = (task.progress * 100).toInt();

    final androidDetails = AndroidNotificationDetails(
      'download_channel',
      'Downloads',
      channelDescription: 'Notifications for active downloads',
      importance: Importance.high,
      priority: Priority.high,
      onlyAlertOnce: true,
      showProgress: true,
      maxProgress: 100,
      progress: progress,
      indeterminate: false,
      enableVibration: false,
      playSound: false,
      ongoing: task.status == DownloadStatus.downloading,
      autoCancel: false,
      color: const Color(0xFFFF8A00),
      colorized: true,
      icon: '@drawable/ic_launcher',
      styleInformation: BigTextStyleInformation(
        _buildNotificationBody(task),
        contentTitle: task.displayTitle,
        htmlFormatBigText: false,
        htmlFormatTitle: false,
        summaryText: _buildSummaryText(task),
      ),
      // tag: 'download_${task.id}',
      visibility: NotificationVisibility.public,
    );

    const iosPlatformChannelSpecifics = DarwinNotificationDetails(
      presentAlert: false,
      presentBadge: false,
      presentSound: false,
    );

    final platformChannelSpecifics = NotificationDetails(
      android: androidDetails,
      iOS: iosPlatformChannelSpecifics,
    );

    await _notificationsPlugin.show(
      1,
      task.displayTitle,
      _buildSummaryText(task),
      platformChannelSpecifics,
      payload: 'download_${task.id}',
    );
  }

  String _buildSummaryText(DownloadTask task) {
    final speedText = task.speed != null && task.speed! > 0
        ? '${_formatSpeed(task.speed!)} • '
        : '';
    return '$speedText${task.etaFormatted}';
  }

  String _buildNotificationBody(DownloadTask task) {
    final progress = (task.progress * 100).toInt();
    final downloaded = _formatFileSize(task.downloadedBytes);
    final total = _formatFileSize(task.totalBytes);

    return '$progress% • $downloaded / $total • ${task.speedFormatted}';
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    var size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(i == 0 ? 0 : 1)} ${suffixes[i]}';
  }

  String _formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond <= 0) return '0 B/s';
    const suffixes = ['B/s', 'KB/s', 'MB/s', 'GB/s'];
    var i = 0;
    var speed = bytesPerSecond;
    while (speed >= 1024 && i < suffixes.length - 1) {
      speed /= 1024;
      i++;
    }
    return '${speed.toStringAsFixed(i == 0 ? 0 : 1)} ${suffixes[i]}';
  }

  Future<void> cancelDownloadNotification() async {
    try {
      await _notificationsPlugin.cancel(1);
    } catch (e) {
      // Handle any errors during cancellation
    }
  }

  Future<void> clearAllNotifications() async {
    try {
      await _notificationsPlugin.cancelAll();
    } catch (e) {
      // Handle any errors during cancellation
    }
  }
}
