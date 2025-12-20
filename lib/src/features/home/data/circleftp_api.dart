import 'package:dio/dio.dart';

class CircleFtpApi {
  CircleFtpApi(this._dio, this.baseUrl);

  final Dio _dio;
  final String baseUrl;

  Future<Map<String, dynamic>> getHomePage() async {
    try {
      final response = await _dio.get(
        '$baseUrl/api/home-page/getHomePagePosts',
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> searchContent(String query) async {
    try {
      final response = await _dio.get(
        '$baseUrl/api/posts',
        queryParameters: {'searchTerm': query, 'limit': 20},
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      final data = response.data as Map<String, dynamic>;
      return (data['posts'] ?? []) as List<dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> browseByCategory(
    String categoryId, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _dio.get(
        '$baseUrl/api/posts',
        queryParameters: {
          'categoryExact': categoryId,
          'page': page,
          'limit': limit,
        },
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      final data = response.data as Map<String, dynamic>;
      return (data['posts'] ?? []) as List<dynamic>;
    } catch (e) {
      rethrow;
    }
  }
}
