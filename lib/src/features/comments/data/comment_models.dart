class CommentUser {
  CommentUser({required this.id, required this.name, required this.email});

  final String id;
  final String name;
  final String email;

  factory CommentUser.fromJson(Map<String, dynamic> json) {
    return CommentUser(
      id: json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'_id': id, 'name': name, 'email': email};
  }
}

class Comment {
  Comment({
    required this.id,
    required this.userId,
    required this.user,
    required this.ftpServerId,
    required this.serverType,
    required this.contentType,
    required this.contentId,
    required this.contentTitle,
    required this.comment,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final CommentUser user;
  final String ftpServerId;
  final String serverType;
  final String contentType;
  final String contentId;
  final String contentTitle;
  final String comment;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['_id']?.toString() ?? '',
      userId: json['userId'] is String
          ? json['userId'].toString()
          : (json['userId']?['_id']?.toString() ?? ''),
      user: json['userId'] is Map<String, dynamic>
          ? CommentUser.fromJson(json['userId'] as Map<String, dynamic>)
          : CommentUser(
              id: json['userId']?.toString() ?? '',
              name: 'Unknown User',
              email: '',
            ),
      ftpServerId: json['ftpServerId']?.toString() ?? '',
      serverType: json['serverType']?.toString() ?? '',
      contentType: json['contentType']?.toString() ?? '',
      contentId: json['contentId']?.toString() ?? '',
      contentTitle: json['contentTitle']?.toString() ?? '',
      comment: json['comment']?.toString() ?? '',
      createdAt: DateTime.parse(
        json['createdAt']?.toString() ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updatedAt']?.toString() ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'userId': userId,
      'ftpServerId': ftpServerId,
      'serverType': serverType,
      'contentType': contentType,
      'contentId': contentId,
      'contentTitle': contentTitle,
      'comment': comment,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class CommentListResponse {
  CommentListResponse({
    required this.message,
    required this.comments,
    this.pagination,
  });

  final String message;
  final List<Comment> comments;
  final CommentPagination? pagination;

  factory CommentListResponse.fromJson(Map<String, dynamic> json) {
    return CommentListResponse(
      message: json['message']?.toString() ?? '',
      comments:
          (json['comments'] as List<dynamic>?)
              ?.map((e) => Comment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      pagination: json['pagination'] != null
          ? CommentPagination.fromJson(
              json['pagination'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

class CommentPagination {
  CommentPagination({
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  final int total;
  final int page;
  final int limit;
  final int totalPages;

  factory CommentPagination.fromJson(Map<String, dynamic> json) {
    return CommentPagination(
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      limit: json['limit'] as int? ?? 50,
      totalPages: json['totalPages'] as int? ?? 1,
    );
  }
}

class CommentResponse {
  CommentResponse({required this.message, required this.comment});

  final String message;
  final Comment comment;

  factory CommentResponse.fromJson(Map<String, dynamic> json) {
    return CommentResponse(
      message: json['message']?.toString() ?? '',
      comment: Comment.fromJson(json['comment'] as Map<String, dynamic>),
    );
  }
}
