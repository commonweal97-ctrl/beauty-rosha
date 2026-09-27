class User {
  final int id;
  final String? name;
  final String? phone;
  final String? email;
  final String? role;
  final String? avatar;
  final String? fcmToken;

  User({
    required this.id,
    this.name,
    this.phone,
    this.email,
    this.role,
    this.avatar,
    this.fcmToken,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      name: json['name'],
      phone: json['phone'],
      email: json['email'],
      role: json['role'],
      avatar: json['avatar'],
      fcmToken: json['fcm_token'],
    );
  }

  bool get isLoggedIn => id > 0;
}