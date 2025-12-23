import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../app/theme/app_colors.dart';
import '../../../../state/auth/auth_controller.dart';
import '../../../../state/comments/comment_provider.dart';
import '../../../comments/data/comment_models.dart';

class CommentsSection extends ConsumerStatefulWidget {
  const CommentsSection({
    required this.ftpServerId,
    required this.serverType,
    required this.contentType,
    required this.contentId,
    required this.contentTitle,
    super.key,
  });

  final String ftpServerId;
  final String serverType;
  final String contentType;
  final String contentId;
  final String contentTitle;

  @override
  ConsumerState<CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends ConsumerState<CommentsSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isExpanded = true;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;
  String? _editingCommentId;
  final int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    if (_isExpanded) {
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    if (_isExpanded) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(
      contentCommentsProvider((
        ftpServerId: widget.ftpServerId,
        contentId: widget.contentId,
        page: _currentPage,
      )),
    );

    return Column(
      children: [
        GestureDetector(
          onTap: _toggleExpanded,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppColors.outline.withValues(alpha: 0.5),
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Comments',
                    style: const TextStyle(
                      color: AppColors.textHigh,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _animationController.value * 3.14159,
                      child: Icon(
                        Icons.expand_less,
                        color: AppColors.primary,
                        size: 28,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        SizeTransition(
          sizeFactor: _animationController,
          axisAlignment: -1.0,
          child: Container(
            color: AppColors.black,
            child: Column(
              children: [
                _buildCommentInput(),
                commentsAsync.when(
                  data: (response) => _buildCommentsList(response),
                  loading: () => const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  error: (error, _) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Failed to load comments',
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 14,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCommentInput() {
    final authSession = ref.watch(authControllerProvider).value;

    if (authSession == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(
            color: AppColors.outline.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_editingCommentId != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Text(
                    'Editing comment',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _cancelEdit,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(50, 30),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: AppColors.textMid, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          TextField(
            controller: _commentController,
            maxLines: 4,
            minLines: 2,
            style: const TextStyle(color: AppColors.textHigh, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Write a comment...',
              hintStyle: const TextStyle(
                color: AppColors.textLow,
                fontSize: 13,
              ),
              filled: true,
              fillColor: AppColors.black,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: AppColors.outline.withValues(alpha: 0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: AppColors.outline.withValues(alpha: 0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _handleSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                minimumSize: const Size(double.infinity, 36),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isSubmitting
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.black,
                      ),
                    )
                  : Text(
                      _editingCommentId != null ? 'Update' : 'Post',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsList(CommentListResponse response) {
    if (response.comments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.comment_outlined,
                size: 40,
                color: AppColors.textLow.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 10),
              const Text(
                'No comments yet',
                style: TextStyle(color: AppColors.textLow, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: response.comments.length,
      itemBuilder: (context, index) {
        final comment = response.comments[index];
        return _buildCommentItem(comment);
      },
    );
  }

  Widget _buildCommentItem(Comment comment) {
    final authSession = ref.watch(authControllerProvider).value;
    final isOwnComment = authSession?.user.id == comment.userId;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    comment.user.name.isNotEmpty
                        ? comment.user.name[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            comment.user.name,
                            style: const TextStyle(
                              color: AppColors.textHigh,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          timeago.format(comment.createdAt),
                          style: const TextStyle(
                            color: AppColors.textLow,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    if (comment.createdAt != comment.updatedAt)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Edited',
                          style: const TextStyle(
                            color: AppColors.textLow,
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (isOwnComment)
                PopupMenuButton<String>(
                  color: AppColors.surface,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  icon: const Icon(
                    Icons.more_vert,
                    color: AppColors.textMid,
                    size: 18,
                  ),
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  onSelected: (value) {
                    if (value == 'edit') {
                      _startEdit(comment);
                    } else if (value == 'delete') {
                      _handleDelete(comment.id);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      height: 40,
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 16, color: AppColors.textMid),
                          SizedBox(width: 8),
                          Text(
                            'Edit',
                            style: TextStyle(
                              color: AppColors.textHigh,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      height: 40,
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 16, color: AppColors.danger),
                          SizedBox(width: 8),
                          Text(
                            'Delete',
                            style: TextStyle(
                              color: AppColors.danger,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            comment.comment,
            style: const TextStyle(
              color: AppColors.textMid,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  void _startEdit(Comment comment) {
    setState(() {
      _editingCommentId = comment.id;
      _commentController.text = comment.comment;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingCommentId = null;
      _commentController.clear();
    });
  }

  Future<void> _handleSubmit() async {
    final commentText = _commentController.text.trim();

    if (commentText.isEmpty) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      if (_editingCommentId != null) {
        await ref
            .read(commentNotifierProvider.notifier)
            .updateComment(id: _editingCommentId!, comment: commentText);
      } else {
        await ref
            .read(commentNotifierProvider.notifier)
            .createComment(
              ftpServerId: widget.ftpServerId,
              serverType: widget.serverType,
              contentType: widget.contentType,
              contentId: widget.contentId,
              contentTitle: widget.contentTitle,
              comment: commentText,
            );
      }

      ref.invalidate(
        contentCommentsProvider((
          ftpServerId: widget.ftpServerId,
          contentId: widget.contentId,
          page: _currentPage,
        )),
      );

      _commentController.clear();
      setState(() {
        _editingCommentId = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit comment'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _handleDelete(String commentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Delete Comment',
          style: TextStyle(color: AppColors.textHigh),
        ),
        content: const Text(
          'Are you sure you want to delete this comment?',
          style: TextStyle(color: AppColors.textMid),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textMid),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await ref.read(commentNotifierProvider.notifier).deleteComment(commentId);

      ref.invalidate(
        contentCommentsProvider((
          ftpServerId: widget.ftpServerId,
          contentId: widget.contentId,
          page: _currentPage,
        )),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete comment'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }
}
