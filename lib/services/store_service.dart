import '../models/store.dart';

class StoreService {
  static const List<Store> stores = [
    Store(
      id: 1,
      name: 'Б•Роща — Брянск',
      address: 'г. Брянск, проспект Станке Димитрова, д. 65',
      phone: '+7 (920) 844-77-32',
      workHours: 'Будни: 10:00–19:00, Выходные: 10:00–18:00',
      lat: 53.229247,
      lon: 34.322058,
      storageDays: 3,
      pickupDate: 'Завтра',
    ),
  ];

  static List<Store> getStores() => stores;

  static Store? getStoreById(int id) {
    try {
      return stores.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }
}