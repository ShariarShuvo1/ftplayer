import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final connectivityProvider = StreamProvider<bool>((ref) {
  final connectivity = Connectivity();

  return connectivity.onConnectivityChanged.map((results) {
    if (results.isEmpty) return false;
    return results.any(
      (result) =>
          result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.ethernet,
    );
  });
});

final isOnlineProvider = Provider<bool>((ref) {
  final connectivityAsync = ref.watch(connectivityProvider);
  return connectivityAsync.when(
    data: (isOnline) => isOnline,
    loading: () => false,
    error: (_, _) => false,
  );
});

final wasOnlineProvider = StateProvider<bool>((ref) => true);

final offlineModeProvider = Provider<bool>((ref) {
  final isOnline = ref.watch(isOnlineProvider);
  final wasOnline = ref.watch(wasOnlineProvider);

  if (isOnline && !wasOnline) {
    Future.microtask(() {
      ref.read(wasOnlineProvider.notifier).state = true;
    });
  } else if (isOnline) {
    Future.microtask(() {
      ref.read(wasOnlineProvider.notifier).state = true;
    });
  } else {
    Future.microtask(() {
      ref.read(wasOnlineProvider.notifier).state = false;
    });
  }

  return !isOnline;
});
