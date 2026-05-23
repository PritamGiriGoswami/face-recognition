class Attendance {
  final int? id;
  final String userId; // can be email or unique identifier
  final String base64Image;
  final DateTime timestamp;
  final double? latitude;
  final double? longitude;
  final bool synced;

  Attendance({
    this.id,
    required this.userId,
    required this.base64Image,
    required this.timestamp,
    this.latitude,
    this.longitude,
    this.synced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'image_base64': base64Image,
      'timestamp': timestamp.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'synced': synced ? 1 : 0,
    };
  }

  factory Attendance.fromMap(Map<String, dynamic> map) {
    return Attendance(
      id: map['id'] as int?,
      userId: map['user_id'] as String,
      base64Image: map['image_base64'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      synced: (map['synced'] as int) == 1,
    );
  }
}
