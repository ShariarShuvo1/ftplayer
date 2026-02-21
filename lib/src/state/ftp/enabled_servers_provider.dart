import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/ftp_servers/data/ftp_server_models.dart';
import '../../features/ftp_servers/data/enabled_servers_storage.dart';
import './working_ftp_servers_provider.dart';

final enabledServerIdsProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) async {
  ref.watch(enabledServersRefreshProvider);
  final storage = ref.read(enabledServersStorageProvider);
  return await storage.getEnabledServerIds();
});

final filteredWorkingServersProvider =
    FutureProvider.autoDispose<List<FtpServerDto>>((ref) async {
      final workingServersAsync = ref.watch(workingFtpServersProvider);
      final enabledIdsAsync = ref.watch(enabledServerIdsProvider);

      return workingServersAsync.when(
        data: (workingServers) {
          return enabledIdsAsync.when(
            data: (enabledIds) {
              return workingServers
                  .where((server) => enabledIds.contains(server.id))
                  .toList();
            },
            loading: () => [],
            error: (_, _) => [],
          );
        },
        loading: () => [],
        error: (_, _) => [],
      );
    });

final enabledServersControllerProvider =
    StateNotifierProvider<EnabledServersController, AsyncValue<void>>((ref) {
      return EnabledServersController(ref);
    });

class EnabledServersController extends StateNotifier<AsyncValue<void>> {
  EnabledServersController(this.ref) : super(const AsyncValue.data(null));

  final Ref ref;

  Future<void> toggleServer(String serverId) async {
    final storage = ref.read(enabledServersStorageProvider);
    final enabledIds = await storage.getEnabledServerIds();

    if (enabledIds.contains(serverId)) {
      await storage.disableServer(serverId);
    } else {
      await storage.enableServer(serverId);
    }

    ref.read(enabledServersRefreshProvider.notifier).state++;
  }

  Future<void> enableAllWorkingServers() async {
    final workingServersAsync = ref.read(workingFtpServersProvider);
    await workingServersAsync.when(
      data: (workingServers) async {
        final allIds = workingServers.map((s) => s.id).toList();
        final storage = ref.read(enabledServersStorageProvider);
        await storage.saveEnabledServerIds(allIds);
        ref.read(enabledServersRefreshProvider.notifier).state++;
      },
      loading: () async {},
      error: (_, _) async {},
    );
  }
}

final enabledServersRefreshProvider = StateProvider<int>((ref) => 0);
