// lib/screens/checkout/pickup_map_screen.dart
import 'dart:async';
import 'dart:math';

import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/app_logger.dart';
import '../../providers/cart_provider.dart';
import '../../providers/city_provider.dart';
import '../../providers/currency_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/city_picker.dart';

// ============================================================
// МОДЕЛИ
// ============================================================

class PickupPoint {
  final String id;
  final String pointId;
  final String name;
  final String address;
  final String provider;
  final double lat;
  final double lng;
  final double deliveryCost;
  final double originalCost;
  final String deliveryDays;
  final bool isFree;
  final String schedule;
  final String phone;
  final double freeThreshold;

  PickupPoint({
    required this.id,
    required this.pointId,
    required this.name,
    required this.address,
    required this.provider,
    required this.lat,
    required this.lng,
    required this.deliveryCost,
    required this.originalCost,
    required this.deliveryDays,
    required this.isFree,
    this.schedule = '',
    this.phone = '',
    this.freeThreshold = 5000,
  });

  factory PickupPoint.fromJson(Map<String, dynamic> json) {
    return PickupPoint(
      id: json['id']?.toString() ?? json['point_id']?.toString() ?? '',
      pointId:
          json['point_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name'] ?? json['point_name'] ?? '',
      address: json['address'] ?? json['point_address'] ?? '',
      provider: json['provider'] ?? '',
      lat: (json['lat'] ?? 0).toDouble(),
      lng: (json['lng'] ?? 0).toDouble(),
      deliveryCost: (json['delivery_cost_rub'] ??
              json['delivery_cost'] ??
              0)
          .toDouble(),
      originalCost: (json['original_cost_rub'] ??
              json['original_cost'] ??
              json['delivery_cost_rub'] ??
              0)
          .toDouble(),
      deliveryDays: json['delivery_days'] ?? '',
      isFree: json['is_free'] ?? false,
      schedule: json['schedule'] ?? '',
      phone: json['phone'] ?? '',
      freeThreshold: (json['free_threshold_rub'] ??
              json['free_threshold'] ??
              5000)
          .toDouble(),
    );
  }
}

class PickupCluster {
  final double lat;
  final double lng;
  final int count;
  final String provider;
  final Map<String, double>? bounds;

  PickupCluster({
    required this.lat,
    required this.lng,
    required this.count,
    required this.provider,
    this.bounds,
  });

  factory PickupCluster.fromJson(Map<String, dynamic> j) {
    Map<String, double>? bounds;
    if (j['bounds'] != null) {
      final b = j['bounds'] as Map<String, dynamic>;
      bounds = {
        'minLat': (b['minLat'] as num).toDouble(),
        'maxLat': (b['maxLat'] as num).toDouble(),
        'minLng': (b['minLng'] as num).toDouble(),
        'maxLng': (b['maxLng'] as num).toDouble(),
      };
    }
    return PickupCluster(
      lat: (j['lat'] as num).toDouble(),
      lng: (j['lng'] as num).toDouble(),
      count: (j['count'] as num).toInt(),
      provider: j['provider'] ?? '',
      bounds: bounds,
    );
  }
}

class ProviderMeta {
  final String name;
  final Color color;
  final String logoAsset;

  const ProviderMeta({
    required this.name,
    required this.color,
    required this.logoAsset,
  });
}

// ============================================================
// ЭКРАН
// ============================================================

class PickupMapScreen extends StatefulWidget {
  final String city;

  const PickupMapScreen({super.key, this.city = 'Брянск'});

  @override
  State<PickupMapScreen> createState() => _PickupMapScreenState();
}

class _PickupMapScreenState extends State<PickupMapScreen> {
  static const _logTag = 'PickupMapScreen';

  bool _isMapView = true;
  PickupPoint? _selectedPoint;
  final MapController _mapController = MapController();

  List<PickupPoint> _allPoints = [];
  List<PickupCluster> _clusters = [];
  List<PickupPoint> _singles = [];

  final Set<String> _activeProviders = {
    'yandex',
    'ozon',
    'cdek',
    'fivepost',
    'russian_post',
  };
  bool _loading = true;
  String? _error;
  double _freeThreshold = 5000;
  bool _isFree = false;
  double _cartTotal = 0;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  LatLng? _userLocation;

  int _currentZoom = 12;
  LatLngBounds? _lastBounds;
  Timer? _debounce;
  bool _viewportLoading = false;
  final Map<String, List<dynamic>> _viewportCache = {};

  final Map<String, ProviderMeta> _providerMeta = {
    'yandex': const ProviderMeta(
      name: 'Яндекс',
      color: Color(0xFFFC3F1D),
      logoAsset: 'assets/images/YandexLogo.png',
    ),
    'ozon': const ProviderMeta(
      name: 'Ozon',
      color: Color(0xFF005BFF),
      logoAsset: 'assets/images/OzonLogo.png',
    ),
    'cdek': const ProviderMeta(
      name: 'СДЭК',
      color: Color(0xFF00A046),
      logoAsset: 'assets/images/CDEKLogo.png',
    ),
    'fivepost': const ProviderMeta(
      name: '5Post',
      color: Color(0xFF4CAF50),
      logoAsset: 'assets/images/5postlogo.png',
    ),
    'russian_post': const ProviderMeta(
      name: 'Почта',
      color: Color(0xFF2D3192),
      logoAsset: 'assets/images/Pochalogo.png',
    ),
  };

  ProviderMeta _getMeta(String provider) {
    final meta = _providerMeta[provider];
    if (meta == null) {
      return const ProviderMeta(
        name: 'ПВЗ',
        color: Color(0xFF999999),
        logoAsset: '',
      );
    }
    return meta;
  }

  @override
  void initState() {
    super.initState();
    _loadPoints();
    _preloadMapTiles();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _preloadMapTiles() async {
    LatLng center = const LatLng(53.23, 34.32);

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 3),
      );
      center = LatLng(position.latitude, position.longitude);
    } catch (_) {
      try {
        if (!mounted) return;
        final city = context.read<CityProvider>().city;
        final result = await ApiService.get(
          '/api/pickup/clusters'
          '?city=$city&bbox=50,30,60,40&zoom=11',
        );

        if (!mounted) return;

        if (result.isSuccess) {
          final data = result.valueOrNull?['data'];
          if (data is Map) {
            final clusters = (data['clusters'] as List?) ?? const [];
            final singles = (data['singles'] as List?) ?? const [];
            if (clusters.isNotEmpty && clusters.first is Map) {
              final first = clusters.first as Map;
              center = LatLng(
                (first['lat'] as num? ?? 53.23).toDouble(),
                (first['lng'] as num? ?? 34.32).toDouble(),
              );
            } else if (singles.isNotEmpty && singles.first is Map) {
              final first = singles.first as Map;
              center = LatLng(
                (first['lat'] as num? ?? 53.23).toDouble(),
                (first['lng'] as num? ?? 34.32).toDouble(),
              );
            }
          }
        }
      } catch (e) {
        AppLogger.warning(_logTag, 'preloadMapTiles/clusters failed', e);
      }
    }

    const zoom = 12;
    final n = pow(2, zoom).toDouble();
    final tileX = ((center.longitude + 180) / 360 * n).floor();
    final latRad = center.latitude * pi / 180;
    final tileY =
        ((1 - log(tan(latRad) + 1 / cos(latRad)) / pi) / 2 * n).floor();

    for (int dx = -1; dx <= 1; dx++) {
      for (int dy = -1; dy <= 1; dy++) {
        final url =
            'https://api.maptiler.com/maps/streets-v2/$zoom/'
            '${tileX + dx}/${tileY + dy}.png'
            '?key=oBJZC6WvtDIMzlY4WmP3';
        try {
          if (!mounted) return;
          await precacheImage(NetworkImage(url), context);
        } catch (_) {
          // Плитка не загрузилась — не критично.
        }
      }
    }
  }

  Future<void> _loadPoints() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final cart = context.read<CartProvider>();
    final checkedTotal = cart.finalTotal;

    final url = '/api/pickup/points'
        '?city=${widget.city}&limit=500&cart_total=$checkedTotal';

    final result = await ApiService.get(url);

    if (!mounted) return;

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'loadPoints failed: ${result.errorOrNull?.message}',
      );
      setState(() {
        _error = 'Ошибка загрузки';
        _loading = false;
      });
      return;
    }

    final data = result.valueOrNull?['data'];
    if (data is! Map) {
      setState(() {
        _error = 'Нет доступных пунктов';
        _loading = false;
      });
      return;
    }

    final rawPoints = (data['points'] as List?) ?? const [];
    final points = rawPoints
        .whereType<Map>()
        .map((p) => PickupPoint.fromJson(Map<String, dynamic>.from(p)))
        .toList();

    final deliveryInfo = data['delivery_info'];

    setState(() {
      _allPoints = points;
      if (deliveryInfo is Map) {
        _freeThreshold =
            (deliveryInfo['free_threshold'] as num? ?? 5000).toDouble();
        _isFree = deliveryInfo['is_free'] == true;
        _cartTotal =
            (deliveryInfo['cart_total'] as num? ?? 0).toDouble();
      }
      _loading = false;
    });
  }

  // ============================================================
  // ГЛАВНАЯ ЛОГИКА — bbox + zoom => clusters + singles
  // ============================================================

  void _onMapChanged(MapCamera camera, bool hasGesture) {
    final zoom = camera.zoom.round();
    final bounds = camera.visibleBounds;

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final zoomChanged = zoom != _currentZoom;
      final movedFar =
          _lastBounds == null || !_lastBounds!.contains(camera.center);

      if (zoomChanged || movedFar) {
        _currentZoom = zoom;
        _lastBounds = bounds;
        _loadForViewport(bounds, zoom);
      }
    });
  }

  Future<void> _loadForViewport(LatLngBounds b, int zoom) async {
    if (_viewportLoading) return;
    _viewportLoading = true;

    final bbox = '${b.south},${b.west},${b.north},${b.east}';
    final cart = context.read<CartProvider>();
    final cartTotal = cart.finalTotal;

    final cacheKey = '${bbox}_$zoom';

    if (_viewportCache.containsKey(cacheKey)) {
      final cached = _viewportCache[cacheKey]!;
      if (mounted) {
        setState(() {
          _clusters = cached[0] as List<PickupCluster>;
          _singles = cached[1] as List<PickupPoint>;
        });
      }
      _viewportLoading = false;
      return;
    }

    try {
      if (zoom < 15) {
        final res = await ApiService.get(
          '/api/pickup/clusters'
          '?bbox=$bbox&zoom=$zoom&city=${widget.city}'
          '&cart_total=$cartTotal',
        );

        if (!mounted) return;

        if (res.isFailure) {
          AppLogger.warning(
            _logTag,
            'clusters failed: ${res.errorOrNull?.message}',
          );
        } else {
          final data = res.valueOrNull?['data'];
          if (data is Map) {
            final clustersRaw =
                (data['clusters'] as List?) ?? const [];
            final singlesRaw = (data['singles'] as List?) ?? const [];

            final clusters = clustersRaw
                .whereType<Map>()
                .map((j) =>
                    PickupCluster.fromJson(Map<String, dynamic>.from(j)))
                .toList();
            final singles = singlesRaw
                .whereType<Map>()
                .map((j) =>
                    PickupPoint.fromJson(Map<String, dynamic>.from(j)))
                .toList();

            final meta = data['meta'];

            setState(() {
              _clusters = clusters;
              _singles = singles;
              _allPoints = [];
              if (meta is Map) {
                _freeThreshold = (meta['free_threshold'] as num? ??
                        _freeThreshold)
                    .toDouble();
                _isFree = (meta['is_free'] ?? _isFree) == true;
                _cartTotal = (meta['cart_total'] as num? ?? _cartTotal)
                    .toDouble();
              }
            });

            _viewportCache[cacheKey] = [clusters, singles];
          }
        }
      } else {
        final res = await ApiService.get(
          '/api/pickup/points'
          '?bbox=$bbox&limit=500&cart_total=$cartTotal'
          '&city=${widget.city}',
        );

        if (!mounted) return;

        if (res.isFailure) {
          AppLogger.warning(
            _logTag,
            'points failed: ${res.errorOrNull?.message}',
          );
        } else {
          final data = res.valueOrNull?['data'];
          if (data is Map) {
            final raw = (data['points'] as List?) ?? const [];
            final points = raw
                .whereType<Map>()
                .map((p) =>
                    PickupPoint.fromJson(Map<String, dynamic>.from(p)))
                .toList();
            final deliveryInfo = data['delivery_info'];

            setState(() {
              _allPoints = points;
              _clusters = [];
              _singles = [];
              if (deliveryInfo is Map) {
                _freeThreshold = (deliveryInfo['free_threshold'] as num? ??
                        _freeThreshold)
                    .toDouble();
                _isFree = (deliveryInfo['is_free'] ?? _isFree) == true;
                _cartTotal =
                    (deliveryInfo['cart_total'] as num? ?? _cartTotal)
                        .toDouble();
              }
            });
          }
        }
      }
    } catch (e) {
      AppLogger.warning(_logTag, 'loadForViewport failed', e);
    } finally {
      _viewportLoading = false;
    }
  }

  List<PickupPoint> get _filteredPoints {
    var points =
        _allPoints.where((p) => _activeProviders.contains(p.provider)).toList();
    if (_searchQuery.isNotEmpty) {
      points = points
          .where((p) =>
              p.name.toLowerCase().contains(_searchQuery) ||
              p.address.toLowerCase().contains(_searchQuery))
          .toList();
    }
    return points;
  }

  List<PickupCluster> get _filteredClusters {
    return _clusters
        .where((c) => _activeProviders.contains(c.provider))
        .toList();
  }

  List<PickupPoint> get _filteredSingles {
    return _singles
        .where((p) => _activeProviders.contains(p.provider))
        .toList();
  }

  String _formatDays(int days) {
    if (days % 10 == 1 && days % 100 != 11) return '$days день';
    if (days % 10 >= 2 &&
        days % 10 <= 4 &&
        (days % 100 < 10 || days % 100 >= 20)) {
      return '$days дня';
    }
    return '$days дней';
  }

  String _getProviderDaysLabel(String provider) {
    final points =
        _allPoints.where((p) => p.provider == provider).toList();
    if (points.isEmpty) return '';

    final days = points
        .map((p) => p.deliveryDays)
        .where((d) => d.isNotEmpty)
        .toList();
    if (days.isEmpty) return '';

    final allDays = <int>[];
    for (final d in days) {
      final parts = d.replaceAll(RegExp(r'[^0-9\-]'), '').split('-');
      for (final part in parts) {
        final day = int.tryParse(part.trim());
        if (day != null) allDays.add(day);
      }
    }

    if (allDays.isEmpty) return '';
    allDays.sort();

    final min = allDays.first;
    final max = allDays.last;

    if (min == max) return _formatDays(min);
    return '$min-${_formatDays(max)}';
  }

  String _formatDeliveryDays(String daysStr) {
    final parts = daysStr.replaceAll(RegExp(r'[^0-9\-]'), '').split('-');
    if (parts.length == 2) {
      final min = int.tryParse(parts[0]) ?? 0;
      final max = int.tryParse(parts[1]) ?? 0;
      if (min == max) return _formatDays(min);
      return '${_formatDays(min)} – ${_formatDays(max)}';
    }
    final single = int.tryParse(parts[0]) ?? 0;
    return _formatDays(single);
  }

  void _selectPoint(PickupPoint point) {
    setState(() => _selectedPoint = point);
  }

  Future<void> _confirmSelection() async {
    if (_selectedPoint == null) return;

    final result = await ApiService.post('/api/pickup/select', {
      'point_id': _selectedPoint!.pointId,
      'provider': _selectedPoint!.provider,
      'name': _selectedPoint!.name,
      'address': _selectedPoint!.address,
      'lat': _selectedPoint!.lat,
      'lng': _selectedPoint!.lng,
      'city': widget.city,
      'delivery_days': _selectedPoint!.deliveryDays,
    });

    if (!mounted) return;

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'confirmSelection failed: ${result.errorOrNull?.message}',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка выбора пункта')),
      );
      return;
    }

    Navigator.pop(context, _selectedPoint);
  }

  void _openCityPicker() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CityPicker(
        onSelect: (city, country) async {
          Navigator.pop(context);
        },
      ),
    );
  }

  String _formatPrice(double price) {
    final currency = context.read<CurrencyProvider>();
    if (currency.currency == 'BYN') {
      return price.toStringAsFixed(2);
    }
    return '${price.round()}';
  }

  String get _currencySymbol => context.read<CurrencyProvider>().symbol;

  Future<void> _goToMyLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Служба геолокации отключена')),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Геолокация заблокирована в настройках'),
          ),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;

      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
      });

      _mapController.move(_userLocation!, 15);
    } catch (e) {
      AppLogger.warning(_logTag, 'goToMyLocation failed', e);
    }
  }

  void _onClusterTap(PickupCluster c) {
    final newZoom = (_currentZoom + 2).clamp(1, 18).toDouble();
    _mapController.move(LatLng(c.lat, c.lng), newZoom);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFDD1847),
                      ),
                    )
                  : _error != null
                      ? Center(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: Color(0xFF999999),
                            ),
                          ),
                        )
                      : _isMapView
                          ? _buildMapView()
                          : _buildListView(),
            ),
            if (_selectedPoint != null) _buildPointPopup(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE8E8E8))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Color(0xFF1A1A1A),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => setState(() {
                          _isMapView = true;
                          _selectedPoint = null;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: _isMapView
                                    ? const Color(0xFFDD1847)
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                          child: Text(
                            'На карте',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: _isMapView
                                  ? const Color(0xFFDD1847)
                                  : const Color(0xFF999999),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      GestureDetector(
                        onTap: () => setState(() {
                          _isMapView = false;
                          _selectedPoint = null;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: !_isMapView
                                    ? const Color(0xFFDD1847)
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                          child: Text(
                            'Списком',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: !_isMapView
                                  ? const Color(0xFFDD1847)
                                  : const Color(0xFF999999),
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
          if (!_isMapView)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (v) =>
                    setState(() => _searchQuery = v.toLowerCase()),
                decoration: const InputDecoration(
                  hintText: 'Поиск пункта выдачи',
                  prefixIcon: Icon(
                    Icons.search,
                    color: Color(0xFF999999),
                    size: 20,
                  ),
                  filled: true,
                  fillColor: Color(0xFFF7F7F7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(35)),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSingleMarker(PickupPoint p) {
    final meta = _getMeta(p.provider);
    if (meta.logoAsset.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: meta.color,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 4,
            ),
          ],
        ),
        child: Center(
          child: Text(
            meta.name[0],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }
    return Image.asset(
      meta.logoAsset,
      width: 44,
      height: 44,
      errorBuilder: (_, _, _) => Container(
        decoration: BoxDecoration(
          color: meta.color,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 4,
            ),
          ],
        ),
        child: Center(
          child: Text(
            meta.name[0],
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMapView() {
    final points = _filteredPoints;
    final clusters = _filteredClusters;
    final singles = _filteredSingles;

    LatLng center = const LatLng(53.23, 34.32);
    if (points.isNotEmpty) {
      center = LatLng(points.first.lat, points.first.lng);
    } else if (singles.isNotEmpty) {
      center = LatLng(singles.first.lat, singles.first.lng);
    } else if (clusters.isNotEmpty) {
      center = LatLng(clusters.first.lat, clusters.first.lng);
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 12,
            onTap: (_, _) => setState(() => _selectedPoint = null),
            onPositionChanged: _onMapChanged,
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png'
                  '?key=oBJZC6WvtDIMzlY4WmP3',
              userAgentPackageName: 'com.beautyrosha.app',
              tileProvider: CachedTileProvider(store: MemCacheStore()),
            ),
            if (_currentZoom < 15 && clusters.isNotEmpty)
              MarkerLayer(
                markers: clusters.map((c) {
                  final meta = _getMeta(c.provider);
                  final size = (32 + c.count.clamp(0, 100) * 0.5).toDouble();
                  return Marker(
                    point: LatLng(c.lat, c.lng),
                    width: size,
                    height: size,
                    child: GestureDetector(
                      onTap: () => _onClusterTap(c),
                      child: Container(
                        decoration: BoxDecoration(
                          color: meta.color.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: meta.color.withValues(alpha: 0.4),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          c.count > 99 ? '99+' : '${c.count}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            if (_currentZoom < 15 && singles.isNotEmpty)
              MarkerLayer(
                markers: singles
                    .map(
                      (p) => Marker(
                        point: LatLng(p.lat, p.lng),
                        width: 44,
                        height: 44,
                        child: GestureDetector(
                          onTap: () => _selectPoint(p),
                          child: _buildSingleMarker(p),
                        ),
                      ),
                    )
                    .toList(),
              ),
            if (_currentZoom >= 15)
              MarkerLayer(
                markers: points
                    .map(
                      (p) => Marker(
                        point: LatLng(p.lat, p.lng),
                        width: 44,
                        height: 44,
                        child: GestureDetector(
                          onTap: () => _selectPoint(p),
                          child: _buildSingleMarker(p),
                        ),
                      ),
                    )
                    .toList(),
              ),
            if (_userLocation != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: _userLocation!,
                    width: 80,
                    height: 60,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2196F3),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2196F3)
                                    .withValues(alpha: 0.4),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    Colors.black.withValues(alpha: 0.1),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: const Text(
                            'Я тут',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2196F3),
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.arrow_drop_down,
                          size: 14,
                          color: Color(0xFF2196F3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
        if (_viewportLoading)
          Positioned(
            top: 70,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFDD1847),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Загрузка...',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        Positioned(
          top: 16,
          left: 16,
          child: GestureDetector(
            onTap: _openCityPicker,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE0E0E0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDD1847),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 6),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF1A1A1A),
                      ),
                      children: [
                        TextSpan(
                          text: 'г. ${widget.city}\n',
                          style:
                              const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(
                          text: _isFree
                              ? 'Бесплатно'
                              : 'Бесплатно от '
                                  '${_formatPrice(_freeThreshold)} '
                                  '$_currencySymbol',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF999999),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    size: 18,
                    color: Color(0xFF8F8F9A),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 20,
          left: 16,
          right: 16,
          child: SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _providerMeta.entries.map((e) {
                final provider = e.key;
                final meta = e.value;
                final isActive = _activeProviders.contains(provider);
                final daysLabel = _getProviderDaysLabel(provider);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isActive) {
                          _activeProviders.remove(provider);
                        } else {
                          _activeProviders.add(provider);
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isActive
                              ? meta.color
                              : const Color(0xFFE0E0E0),
                          width: 2,
                        ),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: Colors.black
                                      .withValues(alpha: 0.1),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (meta.logoAsset.isNotEmpty)
                            Image.asset(
                              meta.logoAsset,
                              width: 22,
                              height: 22,
                              errorBuilder: (_, _, _) => const SizedBox(
                                width: 22,
                                height: 22,
                              ),
                            )
                          else
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: meta.color,
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Center(
                                child: Text(
                                  meta.name[0],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(width: 6),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                meta.name,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isActive
                                      ? meta.color
                                      : const Color(0xFF999999),
                                ),
                              ),
                              if (daysLabel.isNotEmpty)
                                Text(
                                  daysLabel,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: isActive
                                        ? meta.color
                                            .withValues(alpha: 0.8)
                                        : const Color(0xFFBBBBBB),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        Positioned(
          right: 16,
          top: 100,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE0E0E0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Column(
              children: [
                _ZoomBtn(
                  Icons.add,
                  () => _mapController.move(
                    _mapController.camera.center,
                    _mapController.camera.zoom + 1,
                  ),
                ),
                Container(height: 1, color: const Color(0xFFF0F0F0)),
                _ZoomBtn(
                  Icons.remove,
                  () => _mapController.move(
                    _mapController.camera.center,
                    _mapController.camera.zoom - 1,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 80,
          child: GestureDetector(
            onTap: _goToMyLocation,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE9ECEF)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Center(
                child: SvgPicture.asset(
                  'assets/icons/cursor-svgrepo-com.svg',
                  width: 22,
                  height: 22,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListView() {
    final points = _filteredPoints;

    if (points.isEmpty) {
      return const Center(
        child: Text(
          'Нет пунктов выдачи',
          style: TextStyle(color: Color(0xFF999999)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: points.length,
      itemBuilder: (_, i) {
        final p = points[i];
        final meta = _getMeta(p.provider);
        return GestureDetector(
          onTap: () => _selectPoint(p),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
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
                    color: meta.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: meta.logoAsset.isNotEmpty
                        ? Image.asset(
                            meta.logoAsset,
                            width: 28,
                            height: 28,
                            errorBuilder: (_, _, _) => Text(
                              meta.name[0],
                              style: TextStyle(
                                color: meta.color,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          )
                        : Text(
                            meta.name[0],
                            style: TextStyle(
                              color: meta.color,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        p.address,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF8F8F9A),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            _formatDeliveryDays(p.deliveryDays),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFDD1847),
                            ),
                          ),
                          const Spacer(),
                          Consumer<CurrencyProvider>(
                            builder: (context, currency, _) {
                              return Text(
                                p.isFree
                                    ? 'Бесплатно'
                                    : '${_formatPrice(p.deliveryCost)} '
                                        '${currency.symbol}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: currency.fontFamily,
                                  color: p.isFree
                                      ? const Color(0xFF4CAF50)
                                      : const Color(0xFF1A1A1A),
                                ),
                              );
                            },
                          ),
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

  Widget _buildPointPopup() {
    final p = _selectedPoint!;
    final meta = _getMeta(p.provider);
    final currency = context.watch<CurrencyProvider>();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: meta.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: meta.logoAsset.isNotEmpty
                            ? Image.asset(
                                meta.logoAsset,
                                width: 32,
                                height: 32,
                                errorBuilder: (_, _, _) => Text(
                                  meta.name[0],
                                  style: TextStyle(
                                    color: meta.color,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 20,
                                  ),
                                ),
                              )
                            : Text(
                                meta.name[0],
                                style: TextStyle(
                                  color: meta.color,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 20,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            p.address,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF8F8F9A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () =>
                          setState(() => _selectedPoint = null),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 18,
                          color: Color(0xFF8F8F9A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _infoRow(
                        Icons.access_time,
                        'Срок доставки',
                        _formatDeliveryDays(p.deliveryDays),
                        valueColor: const Color(0xFFDD1847),
                      ),
                      const SizedBox(height: 8),
                      _infoRow(
                        Icons.local_shipping,
                        'Стоимость',
                        p.isFree
                            ? 'Бесплатно'
                            : '${_formatPrice(p.deliveryCost)} '
                                '${currency.symbol}',
                        valueColor: p.isFree
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFF1A1A1A),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _confirmSelection,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDD1847),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Выбрать этот пункт',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    final currency = context.read<CurrencyProvider>();
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF8F8F9A)),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF8F8F9A)),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            fontFamily: currency.fontFamily,
            color: valueColor ?? const Color(0xFF1A1A1A),
          ),
        ),
      ],
    );
  }
}

class _ZoomBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ZoomBtn(this.icon, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        child: Icon(icon, size: 22, color: const Color(0xFF333333)),
      ),
    );
  }
}