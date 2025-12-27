import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/amaderftp_session_storage.dart';
import '../../features/home/data/amaderftp_api.dart';

final amaderFtpSessionProvider =
    StateNotifierProvider<AmaderFtpSessionNotifier, AmaderFtpSessionState>((
      ref,
    ) {
      final storage = ref.read(amaderFtpSessionStorageProvider);
      return AmaderFtpSessionNotifier(storage);
    });

enum AmaderFtpSessionStatus { initial, loading, authenticated, failed }

class AmaderFtpSessionState {
  const AmaderFtpSessionState({
    required this.status,
    this.session,
    this.errorMessage,
  });

  final AmaderFtpSessionStatus status;
  final AmaderFtpSession? session;
  final String? errorMessage;

  factory AmaderFtpSessionState.initial() {
    return const AmaderFtpSessionState(status: AmaderFtpSessionStatus.initial);
  }

  AmaderFtpSessionState copyWith({
    AmaderFtpSessionStatus? status,
    AmaderFtpSession? session,
    String? errorMessage,
  }) {
    return AmaderFtpSessionState(
      status: status ?? this.status,
      session: session ?? this.session,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  bool get isAuthenticated =>
      status == AmaderFtpSessionStatus.authenticated && session != null;
  bool get hasValidSession => session != null && !session!.isExpired;
}

class AmaderFtpSessionNotifier extends StateNotifier<AmaderFtpSessionState> {
  AmaderFtpSessionNotifier(this._storage)
    : super(AmaderFtpSessionState.initial()) {
    _loadStoredSession();
  }

  final AmaderFtpSessionStorage _storage;
  final Dio _dio = Dio();

  static const String _baseUrl = 'http://amaderftp.net:8096';

  Future<void> _loadStoredSession() async {
    final session = await _storage.readSession();
    if (session != null && !session.isExpired) {
      state = state.copyWith(
        status: AmaderFtpSessionStatus.authenticated,
        session: session,
      );
    }
  }

  Future<bool> ensureAuthenticated() async {
    if (state.hasValidSession) {
      return true;
    }

    final storedSession = await _storage.readSession();
    if (storedSession != null && !storedSession.isExpired) {
      state = state.copyWith(
        status: AmaderFtpSessionStatus.authenticated,
        session: storedSession,
      );
      return true;
    }

    return await authenticate();
  }

  Future<bool> authenticate({String? username, String? password}) async {
    state = state.copyWith(status: AmaderFtpSessionStatus.loading);

    try {
      final api = AmaderFtpApi(_dio, _baseUrl);
      final session = await api.authenticate(
        username: username,
        password: password,
      );

      await _storage.writeSession(session);

      state = state.copyWith(
        status: AmaderFtpSessionStatus.authenticated,
        session: session,
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        status: AmaderFtpSessionStatus.failed,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  Future<void> logout() async {
    await _storage.deleteSession();
    state = AmaderFtpSessionState.initial();
  }

  AmaderFtpApi? getAuthenticatedApi() {
    if (!state.hasValidSession) return null;
    final api = AmaderFtpApi(_dio, _baseUrl);
    api.setSession(state.session!);
    return api;
  }

  @override
  void dispose() {
    _dio.close();
    super.dispose();
  }
}

final amaderFtpApiProvider = Provider<AmaderFtpApi?>((ref) {
  final sessionState = ref.watch(amaderFtpSessionProvider);
  if (!sessionState.hasValidSession) return null;

  final dio = Dio();
  final api = AmaderFtpApi(dio, 'http://amaderftp.net:8096');
  api.setSession(sessionState.session!);
  return api;
});
