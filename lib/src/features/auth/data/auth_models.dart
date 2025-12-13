class UserDto {
  UserDto({required this.id, required this.name, required this.email});

  final String id;
  final String name;
  final String email;

  factory UserDto.fromJson(Map<String, dynamic> json) {
    return UserDto(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
    );
  }
}

class AuthResponse {
  AuthResponse({
    required this.message,
    required this.token,
    required this.user,
  });

  final String message;
  final String token;
  final UserDto user;

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      message: (json['message'] ?? '').toString(),
      token: (json['token'] ?? '').toString(),
      user: UserDto.fromJson((json['user'] as Map).cast<String, dynamic>()),
    );
  }
}

class MeResponse {
  MeResponse({required this.user});

  final UserDto user;

  factory MeResponse.fromJson(Map<String, dynamic> json) {
    return MeResponse(
      user: UserDto.fromJson((json['user'] as Map).cast<String, dynamic>()),
    );
  }
}
