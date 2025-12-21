import 'package:dio/dio.dart';

class ContentDetailsApi {
  ContentDetailsApi(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> getCircleFtpDetails(
    String baseUrl,
    String contentId,
  ) async {
    try {
      final response = await _dio.get(
        '$baseUrl/api/posts/$contentId',
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
}
