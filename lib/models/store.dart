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

  factory Store.fromJson(Map<String, dynamic> json) {
    return Store(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      phone: json['phone'] ?? '',
      workHours: json['work_hours'] ?? '',
      lat: (json['lat'] ?? 0).toDouble(),
      lon: (json['lon'] ?? 0).toDouble(),
      storageDays: json['storage_days'] ?? 3,
      pickupDate: json['pickup_date'] ?? '',
    );
  }
}