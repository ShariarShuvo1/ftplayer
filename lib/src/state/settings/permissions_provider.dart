import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

enum PermissionType { notification, storage, backgroundDownloads }

enum PermissionStatus { granted, denied, notRequired }

class PermissionState {
  final Map<PermissionType, PermissionStatus> permissions;
  final bool isLoading;

  PermissionState({required this.permissions, this.isLoading = false});

  PermissionState copyWith({
    Map<PermissionType, PermissionStatus>? permissions,
    bool? isLoading,
  }) {
    return PermissionState(
      permissions: permissions ?? this.permissions,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class PermissionsNotifier extends StateNotifier<PermissionState> {
  final FlutterLocalNotificationsPlugin _notificationsPlugin;
  final Logger _logger = Logger();

  PermissionsNotifier(this._notificationsPlugin)
    : super(PermissionState(permissions: {})) {
    _checkAllPermissions();
  }

  Future<void> _checkAllPermissions() async {
    state = state.copyWith(isLoading: true);

    final permissions = <PermissionType, PermissionStatus>{};

    permissions[PermissionType.notification] =
        await _checkNotificationPermission();
    permissions[PermissionType.storage] = await _checkStoragePermission();
    permissions[PermissionType.backgroundDownloads] =
        _checkBackgroundDownloadsPermission();

    state = state.copyWith(permissions: permissions, isLoading: false);
  }

  Future<PermissionStatus> _checkNotificationPermission() async {
    if (!Platform.isAndroid) {
      return PermissionStatus.notRequired;
    }

    try {
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (androidImplementation != null) {
        final granted =
            await androidImplementation.areNotificationsEnabled() ?? false;
        return granted ? PermissionStatus.granted : PermissionStatus.denied;
      }
    } catch (e) {
      _logger.e('Error checking notification permission: $e');
    }

    return PermissionStatus.denied;
  }

  Future<PermissionStatus> _checkStoragePermission() async {
    if (!Platform.isAndroid) {
      return PermissionStatus.notRequired;
    }

    try {
      const platform = MethodChannel('com.example.ftplayer/permissions');
      final result = await platform.invokeMethod('checkStoragePermission');
      return result == true
          ? PermissionStatus.granted
          : PermissionStatus.denied;
    } catch (e) {
      _logger.e('Error checking storage permission: $e');
      return PermissionStatus.granted;
    }
  }

  Future<void> requestNotificationPermission() async {
    if (!Platform.isAndroid) return;

    state = state.copyWith(isLoading: true);

    try {
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (androidImplementation != null) {
        final granted = await androidImplementation
            .requestNotificationsPermission();

        final updatedPermissions = Map<PermissionType, PermissionStatus>.from(
          state.permissions,
        );
        updatedPermissions[PermissionType.notification] = granted == true
            ? PermissionStatus.granted
            : PermissionStatus.denied;

        state = state.copyWith(permissions: updatedPermissions);
      }
    } catch (e) {
      _logger.e('Error requesting notification permission: $e');
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> requestStoragePermission() async {
    if (!Platform.isAndroid) return;

    state = state.copyWith(isLoading: true);

    try {
      const platform = MethodChannel('com.example.ftplayer/permissions');
      final granted = await platform.invokeMethod('requestStoragePermission');

      final updatedPermissions = Map<PermissionType, PermissionStatus>.from(
        state.permissions,
      );
      updatedPermissions[PermissionType.storage] = granted == true
          ? PermissionStatus.granted
          : PermissionStatus.denied;

      state = state.copyWith(permissions: updatedPermissions);
    } catch (e) {
      _logger.e('Error requesting storage permission: $e');
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> openAppSettings() async {
    try {
      const platform = MethodChannel('com.example.ftplayer/permissions');
      await platform.invokeMethod('openAppSettings');
    } catch (e) {
      _logger.e('Error opening app settings: $e');
    }
  }

  Future<void> refreshPermissions() async {
    await _checkAllPermissions();
  }

  PermissionStatus _checkBackgroundDownloadsPermission() {
    if (!Platform.isAndroid) {
      return PermissionStatus.notRequired;
    }

    return PermissionStatus.notRequired;
  }
}

final permissionsProvider =
    StateNotifierProvider<PermissionsNotifier, PermissionState>((ref) {
      return PermissionsNotifier(FlutterLocalNotificationsPlugin());
    });
