import 'package:dio/dio.dart';

class DflixApi {
  DflixApi(this._dio, this.baseUrl);

  final Dio _dio;
  final String baseUrl;

  Future<List<dynamic>> searchContent(String query) async {
    try {
      final response = await _dio.get(
        '$baseUrl/api/v1/search.php',
        queryParameters: {'search': query},
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      return response.data as List<dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> getMovies({
    int limit = 20,
    String sortBy = 'uploadTime DESC',
    String? category,
  }) async {
    try {
      final params = <String, dynamic>{'limit': limit, 'sort_by': sortBy};
      if (category != null) {
        params['category'] = category;
      }

      final response = await _dio.get(
        '$baseUrl/api/v1/movies.php',
        queryParameters: params,
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      return response.data as List<dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> getTvShows({int limit = 20, String? category}) async {
    try {
      final params = <String, dynamic>{'limit': limit};
      if (category != null) {
        params['category'] = category;
      }

      final response = await _dio.get(
        '$baseUrl/api/v1/tvshows.php',
        queryParameters: params,
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      return response.data as List<dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> getMoviesByCategory({
    required String category,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _dio.get(
        '$baseUrl/api/v1/sorting.php',
        queryParameters: {'category': category, 'page': page, 'limit': limit},
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      return response.data as List<dynamic>;
    } catch (e) {
      rethrow;
    }
  }
}
