// lib/screens/checkout/store_map_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/store.dart';
import '../../services/store_service.dart';
import '../../core/app_colors.dart';

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
      backgroundColor: context.colors.surfaceAlt,
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
        color: context.colors.surface,
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
              icon: Icon(Icons.arrow_back, color: context.colors.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => setState(() { _isMapView = true; _selectedStore = null; }),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: _isMapView ? context.colors.brand : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Text(
                        'На карте',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _isMapView ? context.colors.brand : context.colors.textMuted,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 20),
                  GestureDetector(
                    onTap: () => setState(() { _isMapView = false; _selectedStore = null; }),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: !_isMapView ? context.colors.brand : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Text(
                        'Списком',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: !_isMapView ? context.colors.brand : context.colors.textMuted,
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
            Builder(
              builder: (context) {
                final isDark = Theme.of(context).brightness ==
                    Brightness.dark;
                final layer = TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.beautyrosha.app',
            );
                if (!isDark) return layer;
                return ColorFiltered(
                  colorFilter: const ColorFilter.matrix([
                    -0.85, 0, 0, 0, 210,
                    0, -0.85, 0, 0, 210,
                    0, 0, -0.85, 0, 210,
                    0, 0, 0, 1, 0,
                  ]),
                  child: layer,
                );
              },
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
                      color: context.colors.brand,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 6, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Icon(Icons.store, color: Colors.white, size: 22),
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
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.colors.border),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: Offset(0, 2)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.location_on, size: 16, color: context.colors.brand),
                  SizedBox(width: 6),
                  Text(
                    'г. Брянск',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: context.colors.textPrimary),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down, size: 18, color: context.colors.textMuted),
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
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.colors.border),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: Offset(0, 2)),
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
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Divider(height: 1, color: context.colors.surfaceAlt),
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
      separatorBuilder: (_, _) => SizedBox(height: 12),
      itemBuilder: (context, index) {
        final store = _stores[index];
        return GestureDetector(
          onTap: () => setState(() => _selectedStore = store),
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.colors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: context.colors.brand,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.store, color: Colors.white, size: 22),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(store.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.colors.textPrimary)),
                      SizedBox(height: 4),
                      Text(store.address, style: TextStyle(fontSize: 13, color: context.colors.textMuted), maxLines: 2, overflow: TextOverflow.ellipsis),
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
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: context.colors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: context.colors.textSecondary)),
    );
  }

  Widget _buildStorePopup() {
    final store = _selectedStore!;
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20, offset: Offset(0, -4)),
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
                color: context.colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          SizedBox(height: 16),

          // Название и адрес
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: context.colors.brand,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.store, color: Colors.white, size: 24),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(store.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
                    SizedBox(height: 4),
                    Text(store.address, style: TextStyle(fontSize: 14, color: context.colors.textMuted)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _selectedStore = null),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: context.colors.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.close, size: 18, color: context.colors.textMuted),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          // Можно забрать + график
          Container(
            padding: EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.colors.surfaceAlt,
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
          SizedBox(height: 16),

          // Телефон
          _buildPopupInfoRow(Icons.phone_outlined, store.phone),
          SizedBox(height: 8),

          // Срок хранения
          _buildPopupInfoRow(Icons.inventory_2_outlined, 'Срок хранения заказа — ${store.storageDays} дня'),

          SizedBox(height: 20),

          // Кнопка выбора
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, store),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.brand,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: Text('Выбрать этот магазин', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopupInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: context.colors.textMuted),
        SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: context.colors.textPrimary))),
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
        child: Icon(icon, size: 22, color: context.colors.textPrimary),
      ),
    );
  }
}