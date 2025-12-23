import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

import 'comment_models.dart';

class CommentApi {
  CommentApi(this.dio);

  final Dio dio;
  final _logger = Logger();

  Future<CommentResponse> createComment({
    required String ftpServerId,
    required String serverType,
    required String contentType,
    required String contentId,
    required String contentTitle,
    required String comment,
  }) async {
    try {
      final data = {
        'ftpServerId': ftpServerId,
        'serverType': serverType,
        'contentType': contentType,
        'contentId': contentId,
        'contentTitle': contentTitle,
        'comment': comment,
      };

      final res = await dio.post('/comments', data: data);
      _logger.d('Created comment: ${res.data}');
      return CommentResponse.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      _logger.e('Error creating comment', error: e);
      rethrow;
    }
  }

  Future<CommentListResponse> getCommentsByContent({
    required String ftpServerId,
    required String contentId,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final res = await dio.get(
        '/comments/content',
        queryParameters: {
          'ftpServerId': ftpServerId,
          'contentId': contentId,
          'page': page,
          'limit': limit,
        },
      );
      _logger.d('Fetched comments: ${res.data}');
      return CommentListResponse.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      _logger.e('Error fetching comments', error: e);
      rethrow;
    }
  }

  Future<CommentListResponse> getUserComments({
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final res = await dio.get(
        '/comments/user',
        queryParameters: {'page': page, 'limit': limit},
      );
      _logger.d('Fetched user comments: ${res.data}');
      return CommentListResponse.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      _logger.e('Error fetching user comments', error: e);
      rethrow;
    }
  }

  Future<CommentResponse> updateComment({
    required String id,
    required String comment,
  }) async {
    try {
      final res = await dio.put('/comments/$id', data: {'comment': comment});
      _logger.d('Updated comment: ${res.data}');
      return CommentResponse.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      _logger.e('Error updating comment', error: e);
      rethrow;
    }
  }

  Future<void> deleteComment(String id) async {
    try {
      await dio.delete('/comments/$id');
      _logger.d('Deleted comment: $id');
    } catch (e) {
      _logger.e('Error deleting comment', error: e);
      rethrow;
    }
  }
}
