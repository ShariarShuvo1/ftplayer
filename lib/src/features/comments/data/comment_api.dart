import 'package:dio/dio.dart';

import 'comment_models.dart';

class CommentApi {
  CommentApi(this.dio);

  final Dio dio;

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
      return CommentResponse.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
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
      return CommentListResponse.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
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
      return CommentListResponse.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  Future<CommentResponse> updateComment({
    required String id,
    required String comment,
  }) async {
    try {
      final res = await dio.put('/comments/$id', data: {'comment': comment});
      return CommentResponse.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteComment(String id) async {
    try {
      await dio.delete('/comments/$id');
    } catch (e) {
      rethrow;
    }
  }
}
