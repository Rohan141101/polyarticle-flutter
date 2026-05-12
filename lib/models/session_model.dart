class SessionModel {
  final String id;
  final String? deviceName;
  final String? deviceOS;
  final String? ipAddress;
  final String? createdAt;
  final String? expiresAt;
  final bool isCurrent;

  const SessionModel({
    required this.id,
    this.deviceName,
    this.deviceOS,
    this.ipAddress,
    this.createdAt,
    this.expiresAt,
    this.isCurrent = false,
  });

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      id: json['id'] as String,
      deviceName: json['device_name'] as String?,
      deviceOS: json['device_os'] as String?,
      ipAddress: json['ip_address'] as String?,
      createdAt: json['created_at'] as String?,
      expiresAt: json['expires_at'] as String?,
      isCurrent: json['is_current'] as bool? ?? false,
    );
  }
}
