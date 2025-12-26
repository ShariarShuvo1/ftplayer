import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:media_kit/media_kit.dart';

import 'src/app/app.dart';
import 'src/core/config/env.dart';
import 'src/core/network/network_optimization.dart';
import 'src/core/services/notification_service.dart';
import 'src/features/downloads/data/download_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  MediaKit.ensureInitialized();

  await Hive.initFlutter();

  await dotenv.load(fileName: '.env');
  await Env.initAndroidFallback();

  await NetworkOptimization.optimizeForStreaming();

  await NotificationService().initialize();

  await DownloadManager.instance.initialize();

  runApp(const ProviderScope(child: App()));
}
