import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final amaderFtpSessionStorageProvider = Provider<AmaderFtpSessionStorage>((
  ref,
) {
  return AmaderFtpSessionStorage(const FlutterSecureStorage());
});

class AmaderFtpSession {
  const AmaderFtpSession({
    required this.accessToken,
    required this.userId,
    required this.serverId,
    required this.createdAt,
  });

  final String accessToken;
  final String userId;
  final String serverId;
  final DateTime createdAt;

  bool get isExpired {
    final now = DateTime.now();
    return now.difference(createdAt) > const Duration(hours: 12);
  }

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'userId': userId,
    'serverId': serverId,
    'createdAt': createdAt.toIso8601String(),
  };

  factory AmaderFtpSession.fromJson(Map<String, dynamic> json) {
    return AmaderFtpSession(
      accessToken: json['accessToken'] as String,
      userId: json['userId'] as String,
      serverId: json['serverId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class AmaderFtpSessionStorage {
  AmaderFtpSessionStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const _sessionKey = 'amaderftp_session';

  AndroidOptions get _androidOptions =>
      const AndroidOptions(resetOnError: true);

  IOSOptions get _iosOptions =>
      const IOSOptions(accessibility: KeychainAccessibility.first_unlock);

  Future<AmaderFtpSession?> readSession() async {
    try {
      final jsonString = await _storage.read(
        key: _sessionKey,
        aOptions: _androidOptions,
        iOptions: _iosOptions,
      );
      if (jsonString == null || jsonString.isEmpty) return null;
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return AmaderFtpSession.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  Future<void> writeSession(AmaderFtpSession session) async {
    try {
      final jsonString = jsonEncode(session.toJson());
      await _storage.write(
        key: _sessionKey,
        value: jsonString,
        aOptions: _androidOptions,
        iOptions: _iosOptions,
      );
    } catch (_) {
      await deleteSession();
      rethrow;
    }
  }

  Future<void> deleteSession() async {
    try {
      await _storage.delete(
        key: _sessionKey,
        aOptions: _androidOptions,
        iOptions: _iosOptions,
      );
    } catch (_) {}
  }

  Future<bool> hasValidSession() async {
    final session = await readSession();
    return session != null && !session.isExpired;
  }
}
