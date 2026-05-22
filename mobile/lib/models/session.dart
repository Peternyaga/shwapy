class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phoneNumber,
  });

  final int id;
  final String name;
  final String email;
  final String? phoneNumber;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as int,
      name: (json['name'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      phoneNumber: json['phone_number'] as String?,
    );
  }

  Map<String, String> toStorage() => {
        'id': id.toString(),
        'name': name,
        'email': email,
        'phone_number': phoneNumber ?? '',
      };
}

class AuthSession {
  const AuthSession({
    required this.token,
    required this.user,
  });

  final String token;
  final AuthUser user;

  int? get tokenId {
    final separator = token.indexOf('|');
    if (separator <= 0) {
      return null;
    }

    return int.tryParse(token.substring(0, separator));
  }
}
