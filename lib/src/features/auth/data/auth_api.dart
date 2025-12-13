import 'package:dio/dio.dart';

import '../../../core/network/api_error.dart';
import 'auth_models.dart';

class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  Future<AuthResponse> signup({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final res = await _dio.post(
        '/auth/signup',
        data: {'name': name, 'email': email, 'password': password},
      );
      return AuthResponse.fromJson((res.data as Map).cast<String, dynamic>());
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _dio.post(
        '/auth/login',
        data: {'email': email, 'password': password},
      );
      return AuthResponse.fromJson((res.data as Map).cast<String, dynamic>());
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<MeResponse> me() async {
    try {
      final res = await _dio.get('/auth/me');
      return MeResponse.fromJson((res.data as Map).cast<String, dynamic>());
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}
