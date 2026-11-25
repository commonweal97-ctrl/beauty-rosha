// lib/widgets/city_picker.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../providers/city_provider.dart';
import '../services/city_service.dart';
import '../services/dadata_service.dart';

class CityPicker extends StatefulWidget {
  final Function(String city, String country) onSelect;

  const CityPicker({super.key, required this.onSelect});

  @override
  State<CityPicker> createState() => _CityPickerState();
}

class _CityPickerState extends State<CityPicker> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  final _searchResults = [];
  bool _isSearching = false;
  bool _isDetectingLocation = false;
  String? _locationError;
  Timer? _debounceTimer;

  final _popularCities = List.from([
    {'city': 'Москва', 'country': 'Россия'},
    {'city': 'Брянск', 'country': 'Россия'},
    {'city': 'Санкт-Петербург', 'country': 'Россия'},
    {'city': 'Казань', 'country': 'Россия'},
    {'city': 'Воронеж', 'country': 'Россия'},
    {'city': 'Минск', 'country': 'Беларусь'},
    {'city': 'Гомель', 'country': 'Беларусь'},
    {'city': 'Астана', 'country': 'Казахстан'},
    {'city': 'Алматы', 'country': 'Казахстан'},
  ]);

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searchFocus.removeListener(_onFocusChange);
    _searchController.dispose();
    _searchFocus.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();

    final trimmed = query.trim();
    if (trimmed.length < 2) {
      if (mounted) {
        setState(() {
          _searchResults.clear();
          _isSearching = false;
        });
      }
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      setState(() => _isSearching = true);

      try {
        final rawSuggestions = await DadataService.suggest(trimmed);

        final seen = <String>{};
        final merged = [];

        for (final item in rawSuggestions) {
          final rawCity = (item['city'] ?? '').toString().trim();
          final rawValue = (item['value'] ?? '').toString().trim();
          if (rawCity.isEmpty && rawValue.isEmpty) continue;

          final parts = rawValue
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();

          final name = rawCity.isNotEmpty
              ? rawCity
              : (parts.isNotEmpty ? parts.first : '');
          if (name.isEmpty) continue;

          final rest = parts.length > 1 ? parts.sublist(1) : [];
          final country = rest.isNotEmpty &&
                  (rest.last == 'Россия' ||
                      rest.last == 'Беларусь' ||
                      rest.last == 'Казахстан')
              ? rest.last
              : 'Россия';
          final region = rest.isNotEmpty
              ? (country == rest.last
                  ? rest.sublist(0, rest.length - 1).join(', ')
                  : rest.join(', '))
              : '';

          final key = '${name.toLowerCase()}|${region.toLowerCase()}|${country.toLowerCase()}';
          if (seen.add(key)) {
            merged.add({
              'name': name,
              'region': region,
              'country': country,
            });
          }
        }

        if (mounted) {
          setState(() {
            _searchResults
              ..clear()
              ..addAll(merged);
            _isSearching = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isSearching = false);
      }
    });
  }

  Future<void> _detectCurrentLocation() async {
    if (_isDetectingLocation) return;
    setState(() {
      _isDetectingLocation = true;
      _locationError = null;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _isDetectingLocation = false;
            _locationError = 'Включите геолокацию в настройках устройства';
          });
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _isDetectingLocation = false;
            _locationError = 'Нет доступа к геопозиции — выберите город вручную';
          });
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );

      final detected = await CityService.detectCity(
        position.latitude,
        position.longitude,
      );

      final detectedCity = detected?['city']?.trim() ?? '';
      final detectedCountry = detected?['country']?.trim();

      if (detectedCity.isEmpty) {
        if (mounted) {
          setState(() {
            _isDetectingLocation = false;
            _locationError = 'Не удалось определить город по координатам';
          });
        }
        return;
      }

      if (!mounted) return;
      setState(() => _isDetectingLocation = false);
      _selectCity(
        detectedCity,
        (detectedCountry == null || detectedCountry.isEmpty)
            ? 'Россия'
            : detectedCountry,
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _isDetectingLocation = false;
          _locationError = 'Не удалось определить город — попробуйте поиск';
        });
      }
    }
  }

  void _selectCity(String city, String country) {
    _searchFocus.unfocus();
    context.read<CityProvider>().setCity(city, country);
    widget.onSelect(city, country);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final currentCity = context.watch<CityProvider>().city;
    final hasQuery = _searchController.text.trim().length >= 2;
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final safeBottom = mediaQuery.padding.bottom;
    final maxSheetHeight = mediaQuery.size.height * 0.86;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxSheetHeight),
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
                child: Text(
                  'Город доставки',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  decoration: BoxDecoration(
                    color: colors.surfaceAlt,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _searchFocus.hasFocus
                          ? colors.brand.withValues(alpha: 0.45)
                          : colors.border.withValues(alpha: 0.65),
                      width: 1.2,
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocus,
                    textInputAction: TextInputAction.search,
                    onChanged: (value) {
                      setState(() {});
                      _onSearchChanged(value);
                    },
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: colors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Найти город или населённый пункт',
                      hintStyle: TextStyle(
                        color: colors.textMuted,
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: _searchFocus.hasFocus
                            ? colors.brand
                            : colors.textMuted,
                        size: 20,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchResults.clear());
                                _onSearchChanged('');
                              },
                              icon: Icon(
                                Icons.cancel_rounded,
                                color: colors.textMuted,
                                size: 18,
                              ),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 13,
                        horizontal: 4,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: hasQuery
                    ? _buildSearchResults(colors, safeBottom)
                    : _buildDefaultContent(colors, currentCity, safeBottom),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultContent(
    AppColors colors,
    String currentCity,
    double safeBottom,
  ) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 2, 16, 18 + safeBottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: colors.brandLight,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: _isDetectingLocation ? null : _detectCurrentLocation,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: colors.brand.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: _isDetectingLocation
                          ? Padding(
                              padding: const EdgeInsets.all(7),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colors.brand,
                              ),
                            )
                          : Icon(
                              Icons.near_me_rounded,
                              size: 17,
                              color: colors.brand,
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _isDetectingLocation
                                ? 'Определяем ваш город...'
                                : 'Определить моё местоположение',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: colors.brand,
                              letterSpacing: -0.2,
                            ),
                          ),
                          Text(
                            'Сейчас выбран: $currentCity',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: colors.brand.withValues(alpha: 0.75),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_locationError != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                _locationError!,
                style: TextStyle(
                  fontSize: 12,
                  color: colors.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          Text(
            'Популярные города',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _popularCities.map((item) {
              final cityName = item['city']!;
              final countryName = item['country']!;
              final isSelected =
                  cityName.toLowerCase() == currentCity.toLowerCase();

              return Material(
                color: isSelected ? colors.brandLight : colors.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => _selectCity(cityName, countryName),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? colors.brand.withValues(alpha: 0.45)
                            : colors.border.withValues(alpha: 0.55),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isSelected) ...[
                          Icon(
                            Icons.check_rounded,
                            size: 15,
                            color: colors.brand,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          cityName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? colors.brand
                                : colors.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(AppColors colors, double safeBottom) {
    if (_isSearching) {
      return Padding(
        padding: EdgeInsets.fromLTRB(16, 28, 16, 28 + safeBottom),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              color: colors.brand,
              strokeWidth: 2.2,
            ),
          ),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, 28 + safeBottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.brandLight,
              ),
              child: Icon(
                Icons.location_off_outlined,
                size: 22,
                color: colors.brand,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Город не найден',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Проверьте написание или выберите из популярных',
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.fromLTRB(16, 2, 16, 18 + safeBottom),
      itemCount: _searchResults.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final result = _searchResults[index];
        final name = (result['name'] ?? '').toString();
        final country = (result['country'] ?? 'Россия').toString();
        final region = (result['region'] ?? '').toString();
        final subtitle = region.isNotEmpty ? '$region · $country' : country;

        return Material(
          color: colors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => _selectCity(name, country),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colors.textMuted,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
