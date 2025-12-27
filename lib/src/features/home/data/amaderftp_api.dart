import 'dart:math';

import 'package:dio/dio.dart';

import '../../../core/storage/amaderftp_session_storage.dart';

class AmaderFtpApi {
  AmaderFtpApi(this._dio, this.baseUrl);

  final Dio _dio;
  final String baseUrl;

  static const String _defaultUsername = 'user';
  static const String _defaultPassword = '1234';
  static const String _clientName = 'FTPlayer';
  static const String _deviceName = 'Mobile';
  static const String _version = '1.0.0';

  static const String _moviesLibraryId = '4f9a1aee122b0b1d02c34ba39f31e331';
  static const String _tvLibraryId = 'ea34d9f8d8b815c9ee04e1b30418f93d';

  String? _accessToken;
  String? _userId;

  String get _deviceId {
    final random = Random();
    return List.generate(
      16,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
  }

  String _buildAuthHeader({String? token}) {
    final base =
        'MediaBrowser Client="$_clientName", Device="$_deviceName", DeviceId="$_deviceId", Version="$_version"';
    if (token != null && token.isNotEmpty) {
      return '$base, Token="$token"';
    }
    return base;
  }

  Options _buildOptions({String? token, Map<String, dynamic>? extra}) {
    final headers = <String, dynamic>{
      'X-Emby-Authorization': _buildAuthHeader(token: token ?? _accessToken),
      'Content-Type': 'application/json',
    };
    return Options(
      headers: headers,
      sendTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      extra: extra,
    );
  }

  void setSession(AmaderFtpSession session) {
    _accessToken = session.accessToken;
    _userId = session.userId;
  }

  void clearSession() {
    _accessToken = null;
    _userId = null;
  }

  bool get hasSession => _accessToken != null && _userId != null;

  String? get userId => _userId;
  String? get accessToken => _accessToken;

  Future<AmaderFtpSession> authenticate({
    String? username,
    String? password,
  }) async {
    try {
      final response = await _dio.post(
        '$baseUrl/Users/authenticatebyname',
        data: {
          'Username': username ?? _defaultUsername,
          'Pw': password ?? _defaultPassword,
        },
        options: _buildOptions(),
      );

      final data = response.data as Map<String, dynamic>;
      final accessToken = data['AccessToken'] as String;
      final user = data['User'] as Map<String, dynamic>;
      final userId = user['Id'] as String;
      final serverId = data['ServerId'] as String? ?? '';

      _accessToken = accessToken;
      _userId = userId;

      return AmaderFtpSession(
        accessToken: accessToken,
        userId: userId,
        serverId: serverId,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> getLatestMovies({
    int limit = 20,
    int startIndex = 0,
  }) async {
    if (_userId == null) {
      throw Exception('Not authenticated. Call authenticate() first.');
    }

    try {
      final response = await _dio.get(
        '$baseUrl/Users/$_userId/Items',
        queryParameters: {
          'SortBy': 'PremiereDate,SortName,ProductionYear',
          'SortOrder': 'Descending',
          'IncludeItemTypes': 'Movie',
          'Recursive': true,
          'Fields': 'PrimaryImageAspectRatio,MediaSourceCount,BasicSyncInfo',
          'ImageTypeLimit': 1,
          'EnableImageTypes': 'Primary,Backdrop,Banner,Thumb',
          'StartIndex': startIndex,
          'ParentId': _moviesLibraryId,
          'Limit': limit,
        },
        options: _buildOptions(),
      );

      final data = response.data as Map<String, dynamic>;
      return (data['Items'] as List?) ?? [];
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> getLatestTvSeries({
    int limit = 20,
    int startIndex = 0,
  }) async {
    if (_userId == null) {
      throw Exception('Not authenticated. Call authenticate() first.');
    }

    try {
      final response = await _dio.get(
        '$baseUrl/Users/$_userId/Items',
        queryParameters: {
          'StartIndex': startIndex,
          'Limit': limit,
          'Fields':
              'PrimaryImageAspectRatio,SortName,Path,SongCount,ChildCount,MediaSourceCount',
          'ImageTypeLimit': 1,
          'ParentId': _tvLibraryId,
          'SortBy': 'DatePlayed,SortName',
          'SortOrder': 'Ascending',
        },
        options: _buildOptions(),
      );

      final data = response.data as Map<String, dynamic>;
      final items = (data['Items'] as List?) ?? [];
      return items.where((item) {
        final type = item['Type']?.toString();
        return type == 'Series';
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> searchContent(String query, {int limit = 24}) async {
    if (_userId == null) {
      throw Exception('Not authenticated. Call authenticate() first.');
    }

    try {
      final response = await _dio.get(
        '$baseUrl/Users/$_userId/Items',
        queryParameters: {
          'searchTerm': query,
          'Recursive': true,
          'IncludeMedia': true,
          'Limit': limit,
          'Fields':
              'PrimaryImageAspectRatio,MediaSourceCount,BasicSyncInfo,Overview,Genres,People,Studios,ProviderIds,MediaSources,ImageTags,BackdropImageTags',
        },
        options: _buildOptions(),
      );

      final data = response.data as Map<String, dynamic>;
      return (data['Items'] as List?) ?? [];
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getItemDetails(String itemId) async {
    if (_userId == null) {
      throw Exception('Not authenticated. Call authenticate() first.');
    }

    try {
      final response = await _dio.get(
        '$baseUrl/Users/$_userId/Items/$itemId',
        options: _buildOptions(),
      );

      return response.data as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> getSeriesEpisodes(
    String seriesId, {
    String? seasonId,
  }) async {
    if (_userId == null) {
      throw Exception('Not authenticated. Call authenticate() first.');
    }

    try {
      final queryParams = <String, dynamic>{
        'UserId': _userId,
        'Fields':
            'ItemCounts,PrimaryImageAspectRatio,BasicSyncInfo,CanDelete,MediaSourceCount,Overview',
      };
      if (seasonId != null) {
        queryParams['SeasonId'] = seasonId;
      }

      final response = await _dio.get(
        '$baseUrl/Shows/$seriesId/Episodes',
        queryParameters: queryParams,
        options: _buildOptions(),
      );

      final data = response.data as Map<String, dynamic>;
      return (data['Items'] as List?) ?? [];
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> getSeriesSeasons(String seriesId) async {
    if (_userId == null) {
      throw Exception('Not authenticated. Call authenticate() first.');
    }

    try {
      final response = await _dio.get(
        '$baseUrl/Shows/$seriesId/Seasons',
        queryParameters: {
          'UserId': _userId,
          'Fields':
              'ItemCounts,PrimaryImageAspectRatio,BasicSyncInfo,CanDelete,MediaSourceCount',
        },
        options: _buildOptions(),
      );

      final data = response.data as Map<String, dynamic>;
      return (data['Items'] as List?) ?? [];
    } catch (e) {
      rethrow;
    }
  }

  String buildImageUrl(
    String itemId,
    String imageTag, {
    String imageType = 'Primary',
    int? width,
    int? height,
    int quality = 96,
  }) {
    final params = <String, String>{
      'tag': imageTag,
      'quality': quality.toString(),
    };
    if (width != null) params['fillWidth'] = width.toString();
    if (height != null) params['fillHeight'] = height.toString();

    final queryString = params.entries
        .map((e) => '${e.key}=${e.value}')
        .join('&');
    return '$baseUrl/Items/$itemId/Images/$imageType?$queryString';
  }

  String buildStreamUrl(String itemId) {
    return '$baseUrl/Videos/$itemId/stream?static=true';
  }

  static int ticksToSeconds(int ticks) {
    return ticks ~/ 10000000;
  }

  static Duration ticksToDuration(int ticks) {
    return Duration(seconds: ticksToSeconds(ticks));
  }
}
