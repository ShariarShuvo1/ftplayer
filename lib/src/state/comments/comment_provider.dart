import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_provider.dart';
import '../../features/comments/data/comment_api.dart';
import '../../features/comments/data/comment_models.dart';

final commentApiProvider = Provider<CommentApi>((ref) {
  final dio = ref.watch(dioProvider);
  return CommentApi(dio);
});

final contentCommentsProvider = FutureProvider.family
    .autoDispose<
      CommentListResponse,
      ({String ftpServerId, String contentId, int page})
    >((ref, params) async {
      final api = ref.watch(commentApiProvider);
      return api.getCommentsByContent(
        ftpServerId: params.ftpServerId,
        contentId: params.contentId,
        page: params.page,
      );
    });

final userCommentsProvider = FutureProvider.family
    .autoDispose<CommentListResponse, ({int page})>((ref, params) async {
      final api = ref.watch(commentApiProvider);
      return api.getUserComments(page: params.page);
    });

class CommentNotifier extends AutoDisposeAsyncNotifier<Comment?> {
  @override
  Future<Comment?> build() async {
    return null;
  }

  Future<void> createComment({
    required String ftpServerId,
    required String serverType,
    required String contentType,
    required String contentId,
    required String contentTitle,
    required String comment,
  }) async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      final api = ref.read(commentApiProvider);
      final response = await api.createComment(
        ftpServerId: ftpServerId,
        serverType: serverType,
        contentType: contentType,
        contentId: contentId,
        contentTitle: contentTitle,
        comment: comment,
      );
      return response.comment;
    });
  }

  Future<void> updateComment({
    required String id,
    required String comment,
  }) async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      final api = ref.read(commentApiProvider);
      final response = await api.updateComment(id: id, comment: comment);
      return response.comment;
    });
  }

  Future<void> deleteComment(String id) async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      final api = ref.read(commentApiProvider);
      await api.deleteComment(id);
      return null;
    });
  }
}

final commentNotifierProvider =
    AutoDisposeAsyncNotifierProvider<CommentNotifier, Comment?>(
      CommentNotifier.new,
    );
