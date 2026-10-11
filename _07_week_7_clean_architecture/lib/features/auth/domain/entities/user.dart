class User {
  const User({
    required this.id,
    required this.email,
    required this.name,
    this.token,
  });

  final String id;
  final String email;
  final String name;
  final String? token;

  bool get isAuthenticated => token != null && token!.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          email == other.email &&
          token == other.token;

  @override
  int get hashCode => id.hashCode ^ email.hashCode ^ token.hashCode;
}
