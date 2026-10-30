class Store {
  final int id;
  final String name;
  final String address;
  final String phone;
  final String workHours;
  final double lat;
  final double lon;
  final int storageDays;
  final String pickupDate;

  const Store({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    required this.workHours,
    required this.lat,
    required this.lon,
    required this.storageDays,
    required this.pickupDate,
  });

  /// Логика: до 18:00 — «сегодня», после 18:00 — «завтра».
  /// Если в БД есть pickup_date (строка) — используем её.
  String get pickupDateLabel {
    if (pickupDate.isNotEmpty) return pickupDate;
    final now = DateTime.now();
    return now.hour < 18 ? 'сегодня' : 'завтра';
  }

  factory Store.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0;
      return 0;
    }

    return Store(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      workHours: json['work_hours']?.toString() ?? '',
      lat: parseDouble(json['lat']),
      lon: parseDouble(json['lng'] ?? json['lon']),
      storageDays: json['storage_days'] is int ? json['storage_days'] : 3,
      pickupDate: json['pickup_date']?.toString() ?? '',
    );
  }
}