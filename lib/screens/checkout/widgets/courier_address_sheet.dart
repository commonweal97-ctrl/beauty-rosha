// lib/screens/checkout/widgets/courier_address_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:latlong2/latlong.dart';
import '../../../services/dadata_service.dart';
import '../../../core/app_colors.dart';

class CourierAddressSheet extends StatefulWidget {
  final String initialAddress;

  const CourierAddressSheet({super.key, this.initialAddress = ''});

  @override
  State<CourierAddressSheet> createState() => _CourierAddressSheetState();
}

class _CourierAddressSheetState extends State<CourierAddressSheet> {
  final _addressController = TextEditingController();
  final MapController _mapController = MapController();
  
  List<Map<String, dynamic>> _suggestions = [];
  bool _showSuggestions = false;
  bool _ignoreTextChanges = false;
  
  final _apartmentController = TextEditingController();
  final _floorController = TextEditingController();
  final _entranceController = TextEditingController();
  final _doorphoneController = TextEditingController();
  final _commentController = TextEditingController();
  
  bool _showDetails = false;
  
  final _allowedCities = ['брянск', 'путевка', 'супонево'];

  @override
  void initState() {
    super.initState();
    _addressController.text = widget.initialAddress;
    _addressController.addListener(_onAddressChanged);
  }

  @override
  void dispose() {
    _addressController.dispose();
    _apartmentController.dispose();
    _floorController.dispose();
    _entranceController.dispose();
    _doorphoneController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _onAddressChanged() async {
    if (_ignoreTextChanges) return;
    final text = _addressController.text.trim();

    if (text.length >= 3) {
      final suggestions = await DadataService.suggest(text);
      if (mounted) {
        setState(() {
          _suggestions = suggestions.where((s) {
            final city = (s['city'] as String?) ?? '';
            return _allowedCities.any((c) => city.toLowerCase().contains(c));
          }).toList();
          _showSuggestions = _suggestions.isNotEmpty;
        });
      }
    } else {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
    }
  }

  void _selectSuggestion(Map<String, dynamic> suggestion) {
    _ignoreTextChanges = true;
    _addressController.text = suggestion['value'] as String;
    setState(() {
      _showSuggestions = false;
      _suggestions = [];
    });
    _ignoreTextChanges = false;

    final lat = double.tryParse(suggestion['lat']?.toString() ?? '');
    final lon = double.tryParse(suggestion['lon']?.toString() ?? '');
    if (lat != null && lon != null) {
      _mapController.move(LatLng(lat, lon), 16);
    }
  }

  void _confirmAddress() {
    final address = _addressController.text.trim();
    if (address.length < 5) return;
    
    if (!_showDetails) {
      setState(() => _showDetails = true);
      return;
    }
    
    Navigator.pop(context, {
      'address': address,
      'apartment': _apartmentController.text,
      'floor': _floorController.text,
      'entrance': _entranceController.text,
      'doorphone': _doorphoneController.text,
      'comment': _commentController.text,
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = _showDetails ? 'Детали доставки' : 'Укажите адрес доставки';
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Хедер
            Container(
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFE8E8E8))),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: context.colors.textPrimary),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.colors.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // Контент
            Expanded(
              child: _showDetails ? _buildDetailsForm() : _buildMapAndAddress(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapAndAddress() {
    return Column(
      children: [
        // Карта
        Expanded(
          flex: 3,
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: const MapOptions(
                  initialCenter: LatLng(53.23, 34.32),
                  initialZoom: 14,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=oBJZC6WvtDIMzlY4WmP3',
                    userAgentPackageName: 'com.beautyrosha.app',
                  ),
                ],
              ),

              // Пин
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: context.colors.brand,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6, offset: Offset(0, 2)),
                        ],
                      ),
                    ),
                    Container(
                      width: 2,
                      height: 36,
                      color: context.colors.brand,
                    ),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Зум
              Positioned(
                right: 16,
                top: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE9ECEF)),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
                  ),
                  child: Column(
                    children: [
                      _ZoomButton(
                        icon: Icons.add,
                        onTap: () {
                          final zoom = _mapController.camera.zoom;
                          _mapController.move(_mapController.camera.center, zoom + 1);
                        },
                      ),
                      Container(height: 1, color: const Color(0xFFF0F0F0)),
                      _ZoomButton(
                        icon: Icons.remove,
                        onTap: () {
                          final zoom = _mapController.camera.zoom;
                          _mapController.move(_mapController.camera.center, zoom - 1);
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Геолокация
              Positioned(
                right: 16,
                bottom: 24,
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE9ECEF)),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
                    ),
                    child: Center(
                      child: SvgPicture.asset('assets/icons/cursor-svgrepo-com.svg', width: 22, height: 22),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Форма адреса
        Expanded(
          flex: 2,
          child: Container(
            color: Colors.white,
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    hintText: 'Улица, дом, корпус, строение',
                    filled: true,
                    fillColor: context.colors.surfaceAlt,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),

                if (_showSuggestions)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    constraints: const BoxConstraints(maxHeight: 160),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12)],
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _suggestions.length,
                      itemBuilder: (_, i) => ListTile(
                        dense: true,
                        title: Text(_suggestions[i]['value'] as String, style: TextStyle(fontSize: 14)),
                        onTap: () => _selectSuggestion(_suggestions[i]),
                      ),
                    ),
                  ),

                Spacer(),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _addressController.text.trim().length >= 5 ? _confirmAddress : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.colors.brand,
                      disabledBackgroundColor: context.colors.brand,
                      foregroundColor: Colors.white,
                      disabledForegroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Продолжить', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsForm() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Color(0xFFE8E8E8)),
            ),
            child: Text(_addressController.text, style: TextStyle(fontSize: 14, color: context.colors.textPrimary)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: TextField(controller: _apartmentController, decoration: _inputDecoration('Квартира'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _floorController, decoration: _inputDecoration('Этаж'))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: TextField(controller: _entranceController, decoration: _inputDecoration('Подъезд'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _doorphoneController, decoration: _inputDecoration('Домофон'))),
            ],
          ),
          SizedBox(height: 8),
          TextField(
            controller: _commentController,
            maxLines: 3,
            decoration: _inputDecoration('Комментарий курьеру'),
          ),
          SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _confirmAddress,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.brand,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('Сохранить адрес', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: context.colors.surfaceAlt,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        child: Icon(icon, size: 22, color: const Color(0xFF333333)),
      ),
    );
  }
}