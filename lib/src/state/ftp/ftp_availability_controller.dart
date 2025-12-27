import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../amaderftp/amaderftp_session_provider.dart';
import '../../features/ftp_servers/data/ftp_server_models.dart';
import '../../features/ftp_servers/data/ftp_server_repository.dart';
import '../connectivity/connectivity_provider.dart';
import 'working_ftp_servers_provider.dart';
import 'all_ftp_servers_provider.dart';

final ftpAvailabilityControllerProvider =
    StateNotifierProvider<FtpAvailabilityController, FtpAvailabilityState>((
      ref,
    ) {
      return FtpAvailabilityController(
        repository: ref.read(ftpServerRepositoryProvider),
        ref: ref,
      );
    });

enum ServerAvailabilityStatus { pending, checking, available, unavailable }

class ServerCheckResult {
  ServerCheckResult({
    required this.server,
    required this.status,
    this.errorMessage,
    this.pingUrl,
    this.statusCode,
    this.responseTime,
  });

  final FtpServerDto server;
  final ServerAvailabilityStatus status;
  final String? errorMessage;
  final String? pingUrl;
  final int? statusCode;
  final Duration? responseTime;

  ServerCheckResult copyWith({
    FtpServerDto? server,
    ServerAvailabilityStatus? status,
    String? errorMessage,
    String? pingUrl,
    int? statusCode,
    Duration? responseTime,
  }) {
    return ServerCheckResult(
      server: server ?? this.server,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      pingUrl: pingUrl ?? this.pingUrl,
      statusCode: statusCode ?? this.statusCode,
      responseTime: responseTime ?? this.responseTime,
    );
  }
}

class FtpAvailabilityState {
  FtpAvailabilityState({
    required this.checkResults,
    required this.isScanning,
    required this.currentIndex,
    required this.isComplete,
    required this.hasError,
  });

  final List<ServerCheckResult> checkResults;
  final bool isScanning;
  final int currentIndex;
  final bool isComplete;
  final bool hasError;

  factory FtpAvailabilityState.initial() {
    return FtpAvailabilityState(
      checkResults: [],
      isScanning: false,
      currentIndex: 0,
      isComplete: false,
      hasError: false,
    );
  }

  FtpAvailabilityState copyWith({
    List<ServerCheckResult>? checkResults,
    bool? isScanning,
    int? currentIndex,
    bool? isComplete,
    bool? hasError,
  }) {
    return FtpAvailabilityState(
      checkResults: checkResults ?? this.checkResults,
      isScanning: isScanning ?? this.isScanning,
      currentIndex: currentIndex ?? this.currentIndex,
      isComplete: isComplete ?? this.isComplete,
      hasError: hasError ?? this.hasError,
    );
  }

  int get totalServers => checkResults.length;
  int get checkedServers => checkResults
      .where(
        (r) =>
            r.status == ServerAvailabilityStatus.available ||
            r.status == ServerAvailabilityStatus.unavailable,
      )
      .length;
  int get availableServers => checkResults
      .where((r) => r.status == ServerAvailabilityStatus.available)
      .length;
  int get unavailableServers => checkResults
      .where((r) => r.status == ServerAvailabilityStatus.unavailable)
      .length;
  double get progress => totalServers == 0 ? 0 : checkedServers / totalServers;
  List<FtpServerDto> get workingServers => checkResults
      .where((r) => r.status == ServerAvailabilityStatus.available)
      .map((r) => r.server)
      .toList();
}

class FtpAvailabilityController extends StateNotifier<FtpAvailabilityState> {
  FtpAvailabilityController({required this.repository, required this.ref})
    : super(FtpAvailabilityState.initial());

  final FtpServerRepository repository;
  final Ref ref;
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 3),
      receiveTimeout: const Duration(seconds: 3),
      validateStatus: (_) => true,
    ),
  );

  Future<void> startAvailabilityCheck() async {
    final isOffline = ref.read(offlineModeProvider);

    if (isOffline) {
      state = state.copyWith(
        isScanning: false,
        isComplete: true,
        checkResults: [],
      );
      return;
    }

    try {
      state = state.copyWith(isScanning: true, hasError: false);

      final servers = await repository.getAllPublicServers();

      if (servers.isEmpty) {
        state = state.copyWith(
          isScanning: false,
          isComplete: true,
          checkResults: [],
        );
        return;
      }

      final results = servers
          .map(
            (s) => ServerCheckResult(
              server: s,
              status: ServerAvailabilityStatus.pending,
            ),
          )
          .toList();

      state = state.copyWith(checkResults: results);

      for (int i = 0; i < results.length; i++) {
        state = state.copyWith(currentIndex: i);

        final updatedResults = List<ServerCheckResult>.from(state.checkResults);
        updatedResults[i] = updatedResults[i].copyWith(
          status: ServerAvailabilityStatus.checking,
          pingUrl: results[i].server.pingUrl ?? results[i].server.ispProvider,
        );
        state = state.copyWith(checkResults: updatedResults);

        final result = await _checkServerAvailability(results[i].server);

        final finalResults = List<ServerCheckResult>.from(state.checkResults);
        finalResults[i] = result;

        state = state.copyWith(checkResults: finalResults);

        await Future.delayed(const Duration(milliseconds: 300));
      }

      state = state.copyWith(isScanning: false, isComplete: true);
    } catch (e) {
      state = state.copyWith(
        isScanning: false,
        hasError: true,
        isComplete: true,
      );
    }
  }

  Future<ServerCheckResult> _checkServerAvailability(
    FtpServerDto server,
  ) async {
    final url = server.pingUrl ?? server.ispProvider;

    if (url.isEmpty) {
      return ServerCheckResult(
        server: server,
        status: ServerAvailabilityStatus.unavailable,
        errorMessage: 'No ping URL configured',
        pingUrl: 'N/A',
      );
    }

    final stopwatch = Stopwatch()..start();
    try {
      final response = await _dio.get(
        url,
        options: Options(
          followRedirects: true,
          maxRedirects: 3,
          sendTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
        ),
      );
      stopwatch.stop();

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 500) {
        if (server.serverType == 'amaderftp') {
          await _authenticateAmaderFtp();
        }

        return ServerCheckResult(
          server: server,
          status: ServerAvailabilityStatus.available,
          pingUrl: url,
          statusCode: response.statusCode,
          responseTime: stopwatch.elapsed,
        );
      } else {
        return ServerCheckResult(
          server: server,
          status: ServerAvailabilityStatus.unavailable,
          errorMessage: 'HTTP ${response.statusCode}',
          pingUrl: url,
          statusCode: response.statusCode,
          responseTime: stopwatch.elapsed,
        );
      }
    } catch (e) {
      stopwatch.stop();
      String errorMsg = 'Connection failed';
      if (e is DioException) {
        switch (e.type) {
          case DioExceptionType.connectionTimeout:
            errorMsg = 'Connection timeout';
            break;
          case DioExceptionType.receiveTimeout:
            errorMsg = 'Receive timeout';
            break;
          case DioExceptionType.connectionError:
            errorMsg = 'Connection error';
            break;
          case DioExceptionType.badResponse:
            errorMsg = 'Bad response';
            break;
          default:
            errorMsg = e.message ?? 'Unknown error';
        }
      }
      return ServerCheckResult(
        server: server,
        status: ServerAvailabilityStatus.unavailable,
        errorMessage: errorMsg,
        pingUrl: url,
        responseTime: stopwatch.elapsed,
      );
    }
  }

  Future<void> saveWorkingServers() async {
    try {
      final workingServerIds = state.workingServers.map((s) => s.id).toList();
      await repository.updateWorkingServers(ftpServerIds: workingServerIds);
      ref.read(workingFtpServersRefreshProvider.notifier).state++;
      ref.read(allFtpServersRefreshProvider.notifier).state++;
    } catch (e) {
      rethrow;
    }
  }

  void reset() {
    state = FtpAvailabilityState.initial();
  }

  Future<void> _authenticateAmaderFtp() async {
    try {
      final sessionNotifier = ref.read(amaderFtpSessionProvider.notifier);
      await sessionNotifier.ensureAuthenticated();
    } catch (_) {}
  }

  @override
  void dispose() {
    _dio.close();
    super.dispose();
  }
}
