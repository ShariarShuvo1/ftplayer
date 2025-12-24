import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'download_models.dart';
import 'download_adapters.dart';

class DownloadManager {
  DownloadManager._();

  static final DownloadManager instance = DownloadManager._();

  static const _tasksBoxName = 'download_tasks';
  static const _downloadsBoxName = 'downloaded_content';

  Box<DownloadTask>? _tasksBox;
  Box<DownloadedContent>? _downloadsBox;

  bool _isInitialized = false;
  bool _isProcessing = false;

  final _tasksController = StreamController<List<DownloadTask>>.broadcast();
  final _downloadsController =
      StreamController<List<DownloadedContent>>.broadcast();
  final _activeDownloadController = StreamController<DownloadTask?>.broadcast();

  Stream<List<DownloadTask>> get tasksStream {
    return _tasksController.stream.asBroadcastStream();
  }

  Stream<List<DownloadedContent>> get downloadsStream {
    return _downloadsController.stream.asBroadcastStream();
  }

  Stream<DownloadTask?> get activeDownloadStream {
    return _activeDownloadController.stream.asBroadcastStream();
  }

  CancelToken? _currentCancelToken;
  Dio? _dio;
  Timer? _speedTimer;
  int _lastDownloadedBytes = 0;
  DateTime? _lastSpeedCheck;

  Future<void> initialize() async {
    if (_isInitialized) return;

    if (!Hive.isAdapterRegistered(10)) {
      Hive.registerAdapter(DownloadedContentAdapter());
    }
    if (!Hive.isAdapterRegistered(11)) {
      Hive.registerAdapter(DownloadTaskAdapter());
    }
    if (!Hive.isAdapterRegistered(12)) {
      Hive.registerAdapter(DownloadStatusAdapter());
    }

    _tasksBox = await Hive.openBox<DownloadTask>(_tasksBoxName);
    _downloadsBox = await Hive.openBox<DownloadedContent>(_downloadsBoxName);

    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(hours: 2),
        sendTimeout: const Duration(seconds: 30),
      ),
    );

    _isInitialized = true;

    // Restore interrupted downloads: change any "downloading" status to "queued"
    final allTasks = _tasksBox?.values.toList() ?? [];
    for (final task in allTasks) {
      if (task.status == DownloadStatus.downloading) {
        final restoredTask = task.copyWith(status: DownloadStatus.queued);
        await _tasksBox?.put(task.id, restoredTask);
      }
    }

    _notifyTasksUpdate();
    _notifyDownloadsUpdate();

    _processQueue();
  }

  Future<void> dispose() async {
    _speedTimer?.cancel();
    _tasksController.close();
    _downloadsController.close();
    _activeDownloadController.close();
    await _tasksBox?.close();
    await _downloadsBox?.close();
  }

  List<DownloadTask> get tasks {
    return _tasksBox?.values.toList() ?? [];
  }

  List<DownloadedContent> get downloads {
    return _downloadsBox?.values.toList() ?? [];
  }

  DownloadTask? get activeDownload {
    return tasks
        .where((t) => t.status == DownloadStatus.downloading)
        .firstOrNull;
  }

  List<DownloadTask> get queuedTasks {
    return tasks.where((t) => t.status == DownloadStatus.queued).toList();
  }

  List<DownloadTask> get pausedTasks {
    return tasks.where((t) => t.status == DownloadStatus.paused).toList();
  }

  bool isContentDownloaded(
    String contentId, {
    int? seasonNumber,
    int? episodeNumber,
  }) {
    return downloads.any((d) {
      if (d.contentId != contentId) return false;
      if (seasonNumber != null && episodeNumber != null) {
        return d.seasonNumber == seasonNumber &&
            d.episodeNumber == episodeNumber;
      }
      return d.seasonNumber == null && d.episodeNumber == null;
    });
  }

  bool isContentDownloading(
    String contentId, {
    int? seasonNumber,
    int? episodeNumber,
  }) {
    return tasks.any((t) {
      if (t.contentId != contentId) return false;
      if (t.status != DownloadStatus.downloading &&
          t.status != DownloadStatus.queued) {
        return false;
      }
      if (seasonNumber != null && episodeNumber != null) {
        return t.seasonNumber == seasonNumber &&
            t.episodeNumber == episodeNumber;
      }
      return t.seasonNumber == null && t.episodeNumber == null;
    });
  }

  DownloadTask? getTaskForContent(
    String contentId, {
    int? seasonNumber,
    int? episodeNumber,
  }) {
    return tasks.where((t) {
      if (t.contentId != contentId) return false;
      if (seasonNumber != null && episodeNumber != null) {
        return t.seasonNumber == seasonNumber &&
            t.episodeNumber == episodeNumber;
      }
      return t.seasonNumber == null && t.episodeNumber == null;
    }).firstOrNull;
  }

  DownloadedContent? getDownloadedContent(
    String contentId, {
    int? seasonNumber,
    int? episodeNumber,
  }) {
    return downloads.where((d) {
      if (d.contentId != contentId) return false;
      if (seasonNumber != null && episodeNumber != null) {
        return d.seasonNumber == seasonNumber &&
            d.episodeNumber == episodeNumber;
      }
      return d.seasonNumber == null && d.episodeNumber == null;
    }).firstOrNull;
  }

  Future<void> addDownload({
    required String contentId,
    required String title,
    required String posterUrl,
    required String description,
    required String serverName,
    required String serverType,
    required String ftpServerId,
    required String contentType,
    required String videoUrl,
    String? year,
    String? quality,
    double? rating,
    int? seasonNumber,
    int? episodeNumber,
    String? episodeTitle,
    String? seriesTitle,
    int? totalSeasons,
    Map<String, dynamic>? metadata,
  }) async {
    await initialize();

    final existingDownload = getTaskForContent(
      contentId,
      seasonNumber: seasonNumber,
      episodeNumber: episodeNumber,
    );
    if (existingDownload != null) return;

    final existingTask = getTaskForContent(
      contentId,
      seasonNumber: seasonNumber,
      episodeNumber: episodeNumber,
    );
    if (existingTask != null) return;

    final id =
        '${contentId}_${seasonNumber ?? 0}_${episodeNumber ?? 0}_${DateTime.now().millisecondsSinceEpoch}';

    final task = DownloadTask(
      id: id,
      contentId: contentId,
      title: title,
      posterUrl: posterUrl,
      description: description,
      serverName: serverName,
      serverType: serverType,
      ftpServerId: ftpServerId,
      contentType: contentType,
      videoUrl: videoUrl,
      status: DownloadStatus.queued,
      progress: 0,
      downloadedBytes: 0,
      totalBytes: 0,
      createdAt: DateTime.now(),
      year: year,
      quality: quality,
      rating: rating,
      seasonNumber: seasonNumber,
      episodeNumber: episodeNumber,
      episodeTitle: episodeTitle,
      seriesTitle: seriesTitle,
      totalSeasons: totalSeasons,
      metadata: metadata,
    );

    await _tasksBox?.put(id, task);
    _notifyTasksUpdate();
    _processQueue();
  }

  Future<void> pauseDownload(String taskId) async {
    final task = _tasksBox?.get(taskId);
    if (task == null) return;

    if (task.status == DownloadStatus.downloading) {
      _currentCancelToken?.cancel('paused');
      _speedTimer?.cancel();
    }

    final updatedTask = task.copyWith(status: DownloadStatus.paused);
    await _tasksBox?.put(taskId, updatedTask);
    _notifyTasksUpdate();
    _activeDownloadController.add(null);
    _isProcessing = false;
    _processQueue();
  }

  Future<void> pauseAllDownloads() async {
    final allTasks = _tasksBox?.values.toList() ?? [];
    for (final task in allTasks) {
      if (task.status == DownloadStatus.downloading ||
          task.status == DownloadStatus.queued) {
        await pauseDownload(task.id);
      }
    }
  }

  Future<void> resumeDownload(String taskId) async {
    final task = _tasksBox?.get(taskId);
    if (task == null) return;

    final updatedTask = task.copyWith(status: DownloadStatus.queued);
    await _tasksBox?.put(taskId, updatedTask);
    _notifyTasksUpdate();
    _processQueue();
  }

  Future<void> cancelDownload(String taskId) async {
    final task = _tasksBox?.get(taskId);
    if (task == null) return;

    if (task.status == DownloadStatus.downloading) {
      _currentCancelToken?.cancel('cancelled');
      _speedTimer?.cancel();
    }

    if (task.localPath != null) {
      try {
        final file = File(task.localPath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }

    await _tasksBox?.delete(taskId);
    _notifyTasksUpdate();
    _activeDownloadController.add(null);
    _isProcessing = false;
    _processQueue();
  }

  Future<void> deleteDownload(String downloadId) async {
    final download = _downloadsBox?.get(downloadId);
    if (download == null) return;

    try {
      final file = File(download.localPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}

    if (download.localPosterPath != null) {
      try {
        final posterFile = File(download.localPosterPath!);
        if (await posterFile.exists()) {
          await posterFile.delete();
        }
      } catch (_) {}
    }

    await _downloadsBox?.delete(downloadId);
    _notifyDownloadsUpdate();
  }

  Future<void> retryDownload(String taskId) async {
    final task = _tasksBox?.get(taskId);
    if (task == null) return;

    final updatedTask = task.copyWith(
      status: DownloadStatus.queued,
      progress: 0,
      error: null,
    );
    await _tasksBox?.put(taskId, updatedTask);
    _notifyTasksUpdate();
    _processQueue();
  }

  void _processQueue() async {
    if (_isProcessing) return;
    if (activeDownload != null) return;

    final queuedTask = queuedTasks.firstOrNull;
    if (queuedTask == null) return;

    _isProcessing = true;
    await _startDownload(queuedTask);
  }

  Future<void> _startDownload(DownloadTask task) async {
    _currentCancelToken = CancelToken();
    _lastDownloadedBytes = task.downloadedBytes;
    _lastSpeedCheck = DateTime.now();
    final updatedTask = task.copyWith(status: DownloadStatus.downloading);
    await _tasksBox?.put(task.id, updatedTask);
    _notifyTasksUpdate();
    _activeDownloadController.add(updatedTask);

    _speedTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _updateSpeed(task.id);
    });

    try {
      final dir = await getApplicationDocumentsDirectory();
      final downloadDir = Directory('${dir.path}/downloads');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      final posterDir = Directory('${dir.path}/posters');
      if (!await posterDir.exists()) {
        await posterDir.create(recursive: true);
      }

      String? localPosterPath;
      if (task.posterUrl.isNotEmpty) {
        localPosterPath = await _downloadPoster(
          task.posterUrl,
          task.contentId,
          posterDir.path,
        );
      }

      final fileName = _generateFileName(task);
      final filePath = '${downloadDir.path}/$fileName';

      final file = File(filePath);
      int downloadedBytes = 0;

      if (await file.exists() && task.downloadedBytes > 0) {
        downloadedBytes = task.downloadedBytes;
      }

      final response = await _dio!.get<ResponseBody>(
        task.videoUrl,
        options: Options(
          responseType: ResponseType.stream,
          headers: downloadedBytes > 0
              ? {'Range': 'bytes=$downloadedBytes-'}
              : null,
        ),
        cancelToken: _currentCancelToken,
      );

      final totalBytes =
          int.tryParse(response.headers.value('content-length') ?? '0') ?? 0;
      final actualTotal = downloadedBytes + totalBytes;

      final taskWithSize = task.copyWith(
        status: DownloadStatus.downloading,
        totalBytes: actualTotal,
        localPath: filePath,
      );
      await _tasksBox?.put(task.id, taskWithSize);
      _notifyTasksUpdate();
      _activeDownloadController.add(taskWithSize);

      final sink = file.openWrite(
        mode: downloadedBytes > 0 ? FileMode.append : FileMode.write,
      );

      await for (final chunk in response.data!.stream) {
        if (_currentCancelToken?.isCancelled ?? false) {
          await sink.close();
          return;
        }

        sink.add(chunk);
        downloadedBytes += chunk.length;

        final progress = actualTotal > 0 ? downloadedBytes / actualTotal : 0.0;

        final currentTask = _tasksBox?.get(task.id);
        final progressTask = taskWithSize.copyWith(
          progress: progress,
          downloadedBytes: downloadedBytes,
          speed: currentTask?.speed ?? taskWithSize.speed,
          eta: currentTask?.eta ?? taskWithSize.eta,
        );
        await _tasksBox?.put(task.id, progressTask);
        _notifyTasksUpdate();
        _activeDownloadController.add(progressTask);
      }

      await sink.close();
      _speedTimer?.cancel();

      final finalSize = await file.length();
      final downloadedContent = task.toDownloadedContent(
        filePath,
        finalSize,
        localPosterPath: localPosterPath,
      );
      await _downloadsBox?.put(task.id, downloadedContent);

      await _tasksBox?.delete(task.id);
      _notifyTasksUpdate();
      _notifyDownloadsUpdate();
      _activeDownloadController.add(null);
    } on DioException catch (e) {
      _speedTimer?.cancel();

      if (e.type == DioExceptionType.cancel) {
        return;
      }

      final failedTask = task.copyWith(
        status: DownloadStatus.failed,
        error: e.message ?? 'Download failed',
      );
      await _tasksBox?.put(task.id, failedTask);
      _notifyTasksUpdate();
      _activeDownloadController.add(null);
    } catch (e) {
      _speedTimer?.cancel();

      final failedTask = task.copyWith(
        status: DownloadStatus.failed,
        error: e.toString(),
      );
      await _tasksBox?.put(task.id, failedTask);
      _notifyTasksUpdate();
      _activeDownloadController.add(null);
    } finally {
      _isProcessing = false;
      _processQueue();
    }
  }

  Future<String?> _downloadPoster(
    String posterUrl,
    String contentId,
    String posterDir,
  ) async {
    try {
      final extension = _getFileExtension(posterUrl);
      final posterFileName =
          '${contentId.replaceAll(RegExp(r'[^\w]'), '_')}$extension';
      final posterPath = '$posterDir/$posterFileName';

      final posterFile = File(posterPath);
      if (await posterFile.exists()) {
        return posterPath;
      }

      final response = await _dio!.get<List<int>>(
        posterUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.data != null) {
        await posterFile.writeAsBytes(response.data!);
        return posterPath;
      }
    } catch (_) {}
    return null;
  }

  void _updateSpeed(String taskId) {
    final task = _tasksBox?.get(taskId);
    if (task == null) return;

    final now = DateTime.now();
    final elapsed = now.difference(_lastSpeedCheck ?? now).inMilliseconds;
    if (elapsed <= 0) return;

    final bytesDownloaded = task.downloadedBytes - _lastDownloadedBytes;
    final speed = (bytesDownloaded / elapsed) * 1000;

    int? eta;
    if (speed > 0 && task.totalBytes > 0) {
      final remaining = task.totalBytes - task.downloadedBytes;
      eta = (remaining / speed).round();
    }

    final updatedTask = task.copyWith(speed: speed, eta: eta);
    _tasksBox?.put(taskId, updatedTask);
    _notifyTasksUpdate();
    _activeDownloadController.add(updatedTask);

    _lastDownloadedBytes = task.downloadedBytes;
    _lastSpeedCheck = now;
  }

  String _generateFileName(DownloadTask task) {
    final sanitizedTitle = task.title
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(' ', '_');
    final extension = _getFileExtension(task.videoUrl);

    if (task.seasonNumber != null && task.episodeNumber != null) {
      return '${sanitizedTitle}_S${task.seasonNumber}E${task.episodeNumber}_${task.id}.$extension';
    }
    return '${sanitizedTitle}_${task.id}.$extension';
  }

  String _getFileExtension(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return 'mp4';

    final path = uri.path.toLowerCase();
    if (path.endsWith('.mkv')) return 'mkv';
    if (path.endsWith('.avi')) return 'avi';
    if (path.endsWith('.mov')) return 'mov';
    if (path.endsWith('.webm')) return 'webm';
    return 'mp4';
  }

  void _notifyTasksUpdate() {
    _tasksController.add(tasks);
  }

  void _notifyDownloadsUpdate() {
    _downloadsController.add(downloads);
  }
}
