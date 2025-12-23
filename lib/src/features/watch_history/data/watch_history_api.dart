import 'package:dio/dio.dart';

import 'watch_history_models.dart';

class WatchHistoryApi {
  WatchHistoryApi(this.dio);

  final Dio dio;

  Future<WatchHistoryResponse> updateWatchProgress({
    required String ftpServerId,
    required String serverType,
    required String contentType,
    required String contentId,
    required String contentTitle,
    String? status,
    Map<String, dynamic>? progress,
    int? seasonNumber,
    int? episodeNumber,
    String? episodeId,
    String? episodeTitle,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final data = <String, dynamic>{
        'ftpServerId': ftpServerId,
        'serverType': serverType,
        'contentType': contentType,
        'contentId': contentId,
        'contentTitle': contentTitle,
      };

      if (status != null) data['status'] = status;
      if (progress != null) data['progress'] = progress;
      if (seasonNumber != null) data['seasonNumber'] = seasonNumber;
      if (episodeNumber != null) data['episodeNumber'] = episodeNumber;
      if (episodeId != null) data['episodeId'] = episodeId;
      if (episodeTitle != null) data['episodeTitle'] = episodeTitle;
      if (metadata != null) data['metadata'] = metadata;

      final res = await dio.post('/watch-history/progress', data: data);
      return WatchHistoryResponse.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  Future<WatchHistoryResponse> updateContentStatus({
    required String id,
    required String status,
  }) async {
    try {
      final res = await dio.put(
        '/watch-history/status/$id',
        data: {'status': status},
      );
      return WatchHistoryResponse.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  Future<WatchHistoryResponse?> getContentWatchHistory({
    required String ftpServerId,
    required String contentId,
  }) async {
    try {
      final res = await dio.get(
        '/watch-history/content',
        queryParameters: {'ftpServerId': ftpServerId, 'contentId': contentId},
      );
      return WatchHistoryResponse.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteWatchHistory(String id) async {
    try {
      await dio.delete('/watch-history/$id');
    } catch (e) {
      rethrow;
    }
  }

  Future<WatchHistoryListResponse> getWatchHistory({
    String? status,
    String? contentType,
    String? serverType,
    String? ftpServerId,
    int limit = 50,
    int page = 1,
  }) async {
    try {
      final params = <String, dynamic>{'limit': limit, 'page': page};

      if (status != null) params['status'] = status;
      if (contentType != null) params['contentType'] = contentType;
      if (serverType != null) params['serverType'] = serverType;
      if (ftpServerId != null) params['ftpServerId'] = ftpServerId;

      final res = await dio.get('/watch-history', queryParameters: params);
      return WatchHistoryListResponse.fromJson(
        res.data as Map<String, dynamic>,
      );
    } catch (e) {
      rethrow;
    }
  }
}
