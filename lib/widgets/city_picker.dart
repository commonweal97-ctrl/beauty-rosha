// lib/widgets/city_picker.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/city_provider.dart';
import '../services/city_service.dart';

class CityPicker extends StatefulWidget {
  final Function(String city, String country) onSelect;

  const CityPicker({super.key, required this.onSelect});

  @override
  State<CityPicker> createState() => _CityPickerState();
}

class _CityPickerState extends State<CityPicker> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounceTimer;

  final List<Map<String, String>> _popularCities = [
    {'city': 'Москва', 'country': 'Россия'},
    {'city': 'Брянск', 'country': 'Россия'},
    {'city': 'Санкт-Петербург', 'country': 'Россия'},
    {'city': 'Казань', 'country': 'Россия'},
    {'city': 'Минск', 'country': 'Беларусь'},
    {'city': 'Гомель', 'country': 'Беларусь'},
    {'city': 'Астана', 'country': 'Казахстан'},
    {'city': 'Алматы', 'country': 'Казахстан'},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();

    if (query.length < 2) {
      if (mounted) setState(() => _searchResults = []);
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      setState(() => _isSearching = true);

      try {
        final results = await Future.wait([
          CityService.searchCities(query, country: 'Россия'),
          CityService.searchCities(query, country: 'Беларусь'),
          CityService.searchCities(query, country: 'Казахстан'),
        ]);

        final allResults = [...results[0], ...results[1], ...results[2]];

        if (mounted) {
          setState(() {
            _searchResults = allResults;
            _isSearching = false;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _isSearching = false);
      }
    });
  }

  void _selectCity(String city, String country) {
    context.read<CityProvider>().setCity(city, country);
    widget.onSelect(city, country);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final showSearchResults = _searchController.text.length >= 2;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            behavior: HitTestBehavior.translucent,
            child: Container(color: Colors.transparent),
          ),
        ),
        DraggableScrollableSheet(
          initialChildSize: 0.90,
          minChildSize: 0.90,
          maxChildSize: 0.90,
          builder: (context, scrollController) {
            return GestureDetector(
              onTap: () {
                _searchFocus.unfocus();
              },
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 20,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(top: 10),
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
                        child: Text(
                          'Выберите город',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A1A),
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F7),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFE8E8EC),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocus,
                            onChanged: _onSearchChanged,
                            decoration: InputDecoration(
                              hintText: 'Поиск города...',
                              hintStyle: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 16,
                              ),
                              prefixIcon: const Icon(
                                Icons.search,
                                color: Color(0xFFBBBBBB),
                                size: 22,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 4,
                              ),
                              suffixIcon:
                                  _searchController.text.isNotEmpty
                                      ? GestureDetector(
                                          onTap: () {
                                            _searchController.clear();
                                            _onSearchChanged('');
                                          },
                                          child: const Icon(
                                            Icons.close,
                                            color: Color(0xFFBBBBBB),
                                            size: 20,
                                          ),
                                        )
                                      : null,
                            ),
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Flexible(
                        child: showSearchResults
                            ? _buildSearchResults(
                                scrollController,
                                bottomPadding + keyboardHeight,
                              )
                            : _buildPopularCities(
                                scrollController,
                                bottomPadding + keyboardHeight,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPopularCities(
    ScrollController scrollController,
    double bottomPadding,
  ) {
    return ListView(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(16, 0, 16, 24 + bottomPadding),
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            'Популярные города',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF999999),
              letterSpacing: 0.6,
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _popularCities.map((city) {
            final cityName = city['city']!;
            final country = city['country']!;

            return GestureDetector(
              onTap: () => _selectCity(cityName, country),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F8FA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      country,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF999999),
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cityName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSearchResults(
    ScrollController scrollController,
    double bottomPadding,
  ) {
    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFDD1847),
          strokeWidth: 2,
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFDD1847).withValues(alpha: 0.06),
              ),
              child: const Icon(
                Icons.search_off,
                size: 24,
                color: Color(0xFF999999),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Ничего не найдено',
              style: TextStyle(
                color: Color(0xFF666666),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Попробуйте изменить запрос',
              style: TextStyle(color: Color(0xFF999999), fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(16, 0, 16, 24 + bottomPadding),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final result = _searchResults[index];
        final name = result['name'] ?? '';
        final country = result['country'] ?? 'Россия';
        final region = result['region'] ?? '';

        return GestureDetector(
          onTap: () => _selectCity(name, country),
          child: Container(
            margin: const EdgeInsets.only(bottom: 3),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F8FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (region.isNotEmpty || country != 'Россия')
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            region.isNotEmpty ? region : country,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF999999),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: Color(0xFFDDDDDD),
                  size: 20,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}