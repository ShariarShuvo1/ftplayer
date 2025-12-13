import 'package:dio/dio.dart';

class ApiError implements Exception {
  ApiError(this.message);

  final String message;

  static ApiError from(Object error) {
    if (error is ApiError) return error;
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['message'] is String) {
        return ApiError(data['message'] as String);
      }
      if (error.message != null && error.message!.trim().isNotEmpty) {
        return ApiError(error.message!.trim());
      }
      return ApiError('Request failed');
    }
    return ApiError('Unexpected error');
  }
}
