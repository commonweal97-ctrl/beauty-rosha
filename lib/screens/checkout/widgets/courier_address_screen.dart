// lib/screens/checkout/widgets/courier_address_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import '../../../services/dadata_service.dart';

class CourierAddressScreen extends StatefulWidget {
  final String initialAddress;
  final double? userLatitude;
  final double? userLongitude;

  const CourierAddressScreen({
    super.key,
    this.initialAddress = '',
    this.userLatitude,
    this.userLongitude,
  });

  @override
  State<CourierAddressScreen> createState() => _CourierAddressScreenState();
}

class _CourierAddressScreenState extends State<CourierAddressScreen> {
  final _addressController = TextEditingController();
  final MapController _mapController = MapController();
  final FocusNode _addressFocus = FocusNode();
  
  List<Map<String, dynamic>> _suggestions = [];
  bool _showSuggestions = false;
  bool _ignoreTextChanges = false;
  
  final _apartmentController = TextEditingController();
  final _floorController = TextEditingController();
  final _entranceController = TextEditingController();
  final _doorphoneController = TextEditingController();
  final _commentController = TextEditingController();
  
  bool _showDetails = false;
  bool _addressError = false;
  String _errorText = '';
  
  // Анимация подъёма формы
  bool _isAddressFocused = false;
  
  final _allowedCities = ['брянск', 'путевка', 'супонево'];

  @override
  void initState() {
    super.initState();
    _addressController.text = widget.initialAddress;
    _addressController.addListener(_onAddressChanged);
    
    _addressFocus.addListener(() {
      if (!mounted) return;
      setState(() {
        _isAddressFocused = _addressFocus.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _addressController.dispose();
    _addressFocus.dispose();
    _apartmentController.dispose();
    _floorController.dispose();
    _entranceController.dispose();
    _doorphoneController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  bool _isCityAllowed(String text) {
    final lower = text.toLowerCase();
    return _allowedCities.any((c) => lower.contains(c));
  }

  void _onAddressChanged() async {
    if (_ignoreTextChanges) return;
    
    if (_addressError) {
      setState(() { _addressError = false; _errorText = ''; });
    }
    
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
      setState(() { _suggestions = []; _showSuggestions = false; });
    }
  }

  void _selectSuggestion(Map<String, dynamic> suggestion) {
    _ignoreTextChanges = true;
    _addressController.text = suggestion['value'] as String;
    
    setState(() { 
      _showSuggestions = false; 
      _suggestions = [];
      _addressError = false;
      _errorText = '';
    });
    
    FocusScope.of(context).unfocus();
    _ignoreTextChanges = false;
    
    final lat = double.tryParse(suggestion['lat']?.toString() ?? '');
    final lon = double.tryParse(suggestion['lon']?.toString() ?? '');
    if (lat != null && lon != null) {
      _mapController.move(LatLng(lat, lon), 16);
    }
  }

  void _moveToUserLocation() async {
    if (widget.userLatitude != null && widget.userLongitude != null) {
      _mapController.move(LatLng(widget.userLatitude!, widget.userLongitude!), 16);
      
      try {
        final placemarks = await placemarkFromCoordinates(
          widget.userLatitude!, 
          widget.userLongitude!,
        );
        if (placemarks.isNotEmpty && mounted) {
          _updateAddressFromPlacemark(placemarks.first);
        }
      } catch (_) {}
    }
  }

  void _onMapEvent(MapEvent event) {
    if (event is MapEventMoveEnd) {
      final center = _mapController.camera.center;
      _reverseGeocode(center);
    }
  }

  Future<void> _reverseGeocode(LatLng center) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        center.latitude,
        center.longitude,
      );
      if (placemarks.isNotEmpty && mounted) {
        _updateAddressFromPlacemark(placemarks.first);
      }
    } catch (_) {}
  }

  void _updateAddressFromPlacemark(Placemark p) {
    final city = p.locality ?? p.administrativeArea ?? '';
    
    final lower = city.toLowerCase();
    if (['брянск', 'путевка', 'супонево'].any((c) => lower.contains(c))) {
      final street = p.street ?? '';
      final house = p.subThoroughfare ?? '';
      
      String address;
      if (house.isNotEmpty && street.contains(house)) {
        address = street;
      } else if (street.isNotEmpty && house.isNotEmpty) {
        address = '$street, $house';
      } else {
        address = street.isNotEmpty ? street : house;
      }
      
      if (address.isNotEmpty) {
        final cityPrefix = city.toLowerCase() == 'брянск' ? 'г Брянск' : city;
        final fullAddress = '$cityPrefix, $address';
        _ignoreTextChanges = true;
        _addressController.text = fullAddress;
        _ignoreTextChanges = false;
        
        _onAddressChanged();
      }
    }
  }

  void _confirmAddress() {
    final address = _addressController.text.trim();
    
    if (address.length < 5) {
      setState(() {
        _addressError = true;
        _errorText = 'Укажите полный адрес';
      });
      return;
    }
    
    if (!_isCityAllowed(address)) {
      setState(() {
        _addressError = true;
        _errorText = 'Доставка только по Брянску, Путевке и Супонево';
      });
      return;
    }
    
    setState(() { _addressError = false; _errorText = ''; });
    
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            // Хедер
            Container(
              height: 56,
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE8E8E8))),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      _showDetails ? 'Детали доставки' : 'Укажите адрес доставки',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            
            // Контент
            Expanded(
              child: _showDetails ? _buildDetailsForm() : _buildMapAndForm(bottomInset),
            ),
          ],
        ),
      ),
    );
  }

    Widget _buildMapAndForm(double bottomInset) {
    final address = _addressController.text.trim();
    final isValid = address.length >= 5 && _isCityAllowed(address);
    
    return Column(
      children: [
        // Карта — скрывается при фокусе
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          height: _isAddressFocused ? 0 : MediaQuery.of(context).size.height * 0.40,
          width: double.infinity,
          child: _isAddressFocused
              ? const SizedBox.shrink()
              : Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: LatLng(
                          widget.userLatitude ?? 53.23,
                          widget.userLongitude ?? 34.32,
                        ),
                        initialZoom: widget.userLatitude != null ? 16 : 14,
                        onMapEvent: _onMapEvent,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=oBJZC6WvtDIMzlY4WmP3',
                          userAgentPackageName: 'com.beautyrosha.app',
                        ),
                      ],
                    ),

                    // Пин — с FittedBox для предотвращения overflow
                    Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: const Color(0xFFDD1847),
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 1)),
                                ],
                              ),
                            ),
                            Container(width: 2, height: 18, color: const Color(0xFFDD1847)),
                            Container(
                              width: 6, height: 6,
                              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.2), shape: BoxShape.circle),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Зум
                    Positioned(
                      right: 16, top: 16,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE9ECEF)),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _ZoomButton(icon: Icons.add, onTap: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1)),
                            Container(height: 1, color: const Color(0xFFF0F0F0)),
                            _ZoomButton(icon: Icons.remove, onTap: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1)),
                          ],
                        ),
                      ),
                    ),

                    // Геолокация
                    Positioned(
                      right: 16, bottom: 24,
                      child: GestureDetector(
                        onTap: _moveToUserLocation,
                        child: Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFE9ECEF)),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
                          ),
                          child: Center(child: SvgPicture.asset('assets/icons/cursor-svgrepo-com.svg', width: 22, height: 22)),
                        ),
                      ),
                    ),
                  ],
                ),
        ),

        // Форма
        Expanded(
          child: SingleChildScrollView(
            child: Container(
              color: Colors.white,
              padding: EdgeInsets.only(bottom: bottomInset > 0 ? bottomInset + 20 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Заголовок
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'Адрес доставки',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),

                  // Поле адреса
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _addressController,
                          focusNode: _addressFocus,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1A1A1A),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Улица, дом, корпус, строение',
                            hintStyle: TextStyle(
                              fontSize: 15,
                              color: Colors.grey[400],
                              fontWeight: FontWeight.w400,
                            ),
                            filled: true,
                            fillColor: _addressError ? const Color(0xFFFFF5F5) : const Color(0xFFF5F5F7),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: _addressError ? const BorderSide(color: Color(0xFFDD1847), width: 1.5) : BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: _addressError ? const BorderSide(color: Color(0xFFDD1847), width: 1.5) : BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Color(0xFFDD1847), width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                          ),
                        ),
                        
                        // Текст ошибки
                        if (_addressError)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF5F5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _errorText,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFFDD1847),
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Подсказки
                  if (_showSuggestions && !_addressError)
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                      constraints: const BoxConstraints(maxHeight: 220),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 4))],
                        border: Border.all(color: const Color(0xFFF0F0F0)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Material(
                        color: Colors.transparent,
                        child: ListView.builder(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: _suggestions.length,
                          itemBuilder: (_, i) => ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            leading: const Icon(Icons.location_on_outlined, size: 20, color: Color(0xFFBBBBBB)),
                            title: Text(
                              _suggestions[i]['value'] as String,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF333333),
                              ),
                            ),
                            onTap: () {
                              FocusScope.of(context).unfocus();
                              _selectSuggestion(_suggestions[i]);
                            },
                          ),
                        ),
                      ),
                    ),

                  // Кнопка
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isValid ? _confirmAddress : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDD1847),
                          disabledBackgroundColor: const Color(0xFFDD1847),
                          foregroundColor: Colors.white,
                          disabledForegroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Продолжить',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок
          Text(
            'Адрес',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE8E8E8)),
            ),
            child: Text(
              _addressController.text,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: TextField(controller: _apartmentController, style: _inputStyle, decoration: _dec('Квартира'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _floorController, style: _inputStyle, decoration: _dec('Этаж'))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: TextField(controller: _entranceController, style: _inputStyle, decoration: _dec('Подъезд'))),
              const SizedBox(width: 8),
              Expanded(child: TextField(controller: _doorphoneController, style: _inputStyle, decoration: _dec('Домофон'))),
            ],
          ),
          const SizedBox(height: 8),
          TextField(controller: _commentController, maxLines: 3, style: _inputStyle, decoration: _dec('Комментарий курьеру')),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _confirmAddress,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDD1847),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text(
                'Сохранить адрес',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Общий стиль для полей ввода
  TextStyle get _inputStyle => const TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: Color(0xFF1A1A1A),
  );

  InputDecoration _dec(String h) {
    return InputDecoration(
      hintText: h,
      hintStyle: TextStyle(
        fontSize: 14,
        color: Colors.grey[400],
        fontWeight: FontWeight.w400,
      ),
      filled: true,
      fillColor: const Color(0xFFF5F5F7),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFDD1847), width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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