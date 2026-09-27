// lib/screens/checkout/store_map_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/store.dart';
import '../../services/store_service.dart';

class StoreMapScreen extends StatefulWidget {
  const StoreMapScreen({super.key});

  @override
  State<StoreMapScreen> createState() => _StoreMapScreenState();
}

class _StoreMapScreenState extends State<StoreMapScreen> {
  bool _isMapView = true;
  Store? _selectedStore;
  final MapController _mapController = MapController();

  final List<Store> _stores = StoreService.getStores();

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Карта или список на весь экран
          Positioned.fill(
            child: _isMapView ? _buildMapView(topPadding) : _buildListView(topPadding),
          ),
          // Заголовок с белым фоном до верха экрана
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildHeader(topPadding),
          ),
          // Попап магазина снизу
          if (_selectedStore != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildStorePopup(),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(double topPadding) {
    return Container(
      padding: EdgeInsets.only(top: topPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => setState(() { _isMapView = true; _selectedStore = null; }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _isMapView ? const Color(0xFFDD1847) : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Text(
                        'На карте',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _isMapView ? const Color(0xFFDD1847) : const Color(0xFF999999),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  GestureDetector(
                    onTap: () => setState(() { _isMapView = false; _selectedStore = null; }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: !_isMapView ? const Color(0xFFDD1847) : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Text(
                        'Списком',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: !_isMapView ? const Color(0xFFDD1847) : const Color(0xFF999999),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildMapView(double topPadding) {
    final store = _stores.first;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: LatLng(store.lat, store.lon),
            initialZoom: 15.0,
            onTap: (_, _) => setState(() => _selectedStore = null),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=oBJZC6WvtDIMzlY4WmP3',
              userAgentPackageName: 'com.beautyrosha.app',
            ),
            MarkerLayer(
              markers: _stores.map((s) => Marker(
                point: LatLng(s.lat, s.lon),
                width: 44,
                height: 44,
                child: GestureDetector(
                  onTap: () => setState(() => _selectedStore = s),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDD1847),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 6, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: const Icon(Icons.store, color: Colors.white, size: 22),
                  ),
                ),
              )).toList(),
            ),
          ],
        ),

        // Селектор города
        Positioned(
          top: topPadding + 56 + 16,
          left: 16,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE0E0E0)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on, size: 16, color: Color(0xFFDD1847)),
                  const SizedBox(width: 6),
                  const Text(
                    'г. Брянск',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A)),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down, size: 18, color: Color(0xFF8F8F9A)),
                ],
              ),
            ),
          ),
        ),

        // Кнопки зума
        Positioned(
          right: 16,
          top: MediaQuery.of(context).size.height * 0.35,
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  children: [
                    _ZoomButton(
                      icon: Icons.add,
                      onTap: () {
                        final currentZoom = _mapController.camera.zoom;
                        _mapController.move(_mapController.camera.center, currentZoom + 1);
                      },
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Divider(height: 1, color: Color(0xFFF0F0F0)),
                    ),
                    _ZoomButton(
                      icon: Icons.remove,
                      onTap: () {
                        final currentZoom = _mapController.camera.zoom;
                        _mapController.move(_mapController.camera.center, currentZoom - 1);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildListView(double topPadding) {
    return ListView.separated(
      padding: EdgeInsets.only(
        top: topPadding + 56 + 16,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      itemCount: _stores.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final store = _stores[index];
        return GestureDetector(
          onTap: () => setState(() => _selectedStore = store),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE8E8E8)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDD1847),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.store, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(store.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
                      const SizedBox(height: 4),
                      Text(store.address, style: const TextStyle(fontSize: 13, color: Color(0xFF8F8F9A)), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _buildInfoChip('Можно забрать — ${store.pickupDate}'),
                          _buildInfoChip(store.workHours.split(',').first),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: const TextStyle(fontSize: 11, color: Color(0xFF666666))),
    );
  }

  Widget _buildStorePopup() {
    final store = _selectedStore!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, -4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Полоска
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Название и адрес
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFDD1847),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.store, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(store.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A))),
                    const SizedBox(height: 4),
                    Text(store.address, style: const TextStyle(fontSize: 14, color: Color(0xFF8F8F9A))),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _selectedStore = null),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.close, size: 18, color: Color(0xFF8F8F9A)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Можно забрать + график
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildPopupInfoRow(Icons.calendar_today, 'Можно забрать — ${store.pickupDate}'),
                const SizedBox(height: 8),
                _buildPopupInfoRow(Icons.access_time, store.workHours),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Телефон
          _buildPopupInfoRow(Icons.phone_outlined, store.phone),
          const SizedBox(height: 8),

          // Срок хранения
          _buildPopupInfoRow(Icons.inventory_2_outlined, 'Срок хранения заказа — ${store.storageDays} дня'),

          const SizedBox(height: 20),

          // Кнопка выбора
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, store),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDD1847),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text('Выбрать этот магазин', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopupInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF8F8F9A)),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A1A)))),
      ],
    );
  }
}

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ZoomButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        child: Icon(icon, size: 22, color: const Color(0xFF1A1A1A)),
      ),
    );
  }
}