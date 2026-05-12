class User {
  final String id;
  final String email;
  final String? phone;
  final String? location;
  final bool isEmailVerified;
  final bool isActive;

  const User({
    required this.id,
    required this.email,
    this.phone,
    this.location,
    required this.isEmailVerified,
    required this.isActive,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      location: json['location'] as String?,
      isEmailVerified: json['is_email_verified'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}
