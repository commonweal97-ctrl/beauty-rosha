// lib/screens/service/service_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/dadata_service.dart';
import '../../services/delivery_service.dart';
import '../../services/service_service.dart';
import '../../core/app_colors.dart';

class ServiceScreen extends StatefulWidget {
  const ServiceScreen({super.key});

  @override
  State<ServiceScreen> createState() => _ServiceScreenState();
}

class _ServiceScreenState extends State<ServiceScreen>
    with TickerProviderStateMixin {
  final _addressController = TextEditingController();
  final _itemsController = TextEditingController();
  bool _agreed = false;
  bool _loading = false;
  bool _success = false;
  String? _selectedDate;
  String? _selectedTime;
  String _addressError = '';
  bool _addressValid = false;
  bool _showSlots = false;
  List<Map<String, dynamic>> _suggestions = [];
  bool _showSuggestions = false;
  List<Map<String, String>> _dates = [];
  bool _loadingDates = false;
  bool _ignoreTextChanges = false;

  final _allowedCities = ['брянск', 'путевка', 'супонево'];

  final _allTimes = [
    '09:00-12:00',
    '12:00-15:00',
    '15:00-18:00',
    '18:00-21:00',
  ];

  final _months = [
    'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
    'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
  ];
  final _weekdays = ['вс', 'пн', 'вт', 'ср', 'чт', 'пт', 'сб'];

  AnimationController? _carouselAnimController;
  late PageController _pageController;
  int _currentPage = 0;

  List<String> get _availableTimes {
    if (_selectedDate == null) return [];
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    List<String> times = List.from(_allTimes);

    if (_selectedDate == todayStr) {
      final currentMinutes = now.hour * 60 + now.minute;
      times = times.where((t) {
        final startHour = int.parse(t.split(':')[0]);
        return currentMinutes < startHour * 60;
      }).toList();
    }

    return times;
  }

  final _sharpening = [
    {'name': 'Маникюрные ножницы и твизеры', 'price': 350},
    {'name': 'Кусачки маникюрные/педикюрные', 'price': 400},
    {'name': 'Книпсер', 'price': 200},
    {'name': 'Парикмахерские ножницы', 'price': 700},
    {'name': 'Ножи для машинки', 'price': 700},
    {'name': 'Реставрация ножниц', 'price': 1400},
    {'name': 'Пинцет', 'price': 300},
    {'name': 'Пушер/шабер', 'price': 300},
    {'name': 'Ремонт пружины кусачек', 'price': 150},
  ];

  final _repairs = [
    {'name': 'Чистка наконечника', 'price': 'от 700 руб'},
    {'name': 'Замена переднего подшипника', 'price': 'от 600 руб'},
    {'name': 'Замена заднего подшипника', 'price': 'от 600 руб'},
    {'name': 'Замена радиального подшипника', 'price': 'от 600 руб'},
    {'name': 'Замена щёток', 'price': 'от 600 руб'},
    {'name': 'Замена/ремонт двигателя', 'price': 'от 3 000 руб'},
    {'name': 'Замена/ремонт провода', 'price': 'договорная'},
    {'name': 'Ремонт блока управления', 'price': 'договорная'},
    {'name': 'Замена цанги', 'price': 'договорная'},
  ];
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _formKey = GlobalKey();

  @override
  void initState() {
    super.initState();
_generateDates();
    _addressController.addListener(_onAddressChanged);

    _carouselAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _pageController = PageController(initialPage: 0);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startCarouselAnimation();
    });
  }

  void _startCarouselAnimation() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted || _carouselAnimController == null) return false;

      if (!_pageController.hasClients) return true;

      final totalPages = (_sharpening.length / 2).ceil();
      if (totalPages <= 1) return false;

      final nextPage = (_currentPage + 1) % totalPages;

      _carouselAnimController!.forward(from: 0);

      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted && _pageController.hasClients) {
        try {
          _pageController.animateToPage(
            nextPage,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        } catch (_) {
          // Игнорируем ошибки при переключении
        }
      }

      return mounted;
    });
  }

  void _generateDates() {
    final now = DateTime.now();
    final currentHour = now.hour;
    final startDate =
        currentHour < 18 ? now : now.add(const Duration(days: 1));

    final dates = <Map<String, String>>[];
    for (int i = 0; i < 7; i++) {
      final date = startDate.add(Duration(days: i));
      final value =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final day = '${date.day}';
      final month = _months[date.month - 1];
      final weekday = _weekdays[date.weekday % 7];
      final label = i == 0 ? 'сегодня' : (i == 1 ? 'завтра' : weekday);
      dates.add({
        'value': value,
        'label': '$day $month',
        'chip_label': '$day $month, $label',
      });
    }
    _dates = dates;
    _selectBestDate();
  }

  Future<void> _selectBestDate() async {
    if (!mounted) return;
    setState(() => _loadingDates = true);

    for (final date in _dates) {
      try {
        final exceptions =
            await DeliveryService.checkExceptions(date['value']!);
        final fullDayBlocked = exceptions['full_day_blocked'] == true;

        if (!fullDayBlocked) {
          _selectedDate = date['value'];
          final times = _availableTimes;
          final blockedSlots =
              List<String>.from(exceptions['blocked_slots'] ?? []);
          final available =
              times.where((t) => !blockedSlots.contains(t)).toList();
          _selectedTime = available.isNotEmpty ? available[0] : null;
          if (_selectedTime != null) break;
        }
      } catch (_) {
        _selectedDate = date['value'];
        _selectedTime =
            _availableTimes.isNotEmpty ? _availableTimes[0] : null;
        if (_selectedTime != null) break;
      }
    }

    if (!mounted) return;
    setState(() => _loadingDates = false);
  }

  void _onAddressChanged() async {
    if (_ignoreTextChanges) return;

    final text = _addressController.text.trim();
    _validateCity(text);

    if (text.length >= 3) {
      final suggestions = await DadataService.suggest(text);
      if (!mounted) return;
      setState(() {
        _suggestions = suggestions;
        _showSuggestions = suggestions.isNotEmpty;
      });
    } else {
      if (!mounted) return;
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
    }
  }

  void _validateCity(String text) {
    final lower = text.toLowerCase();
    if (lower.length >= 3) {
      final found = _allowedCities.any((city) => lower.contains(city));
      setState(() {
        _addressValid = found;
        _addressError =
            found ? '' : 'Доставка только по Брянску, Путевке и Супонево';
        _showSlots = found;
      });
    } else {
      setState(() {
        _addressValid = false;
        _addressError = '';
        _showSlots = false;
      });
    }
  }

  void _selectSuggestion(Map<String, dynamic> suggestion) {
    _ignoreTextChanges = true;
    _addressController.text = suggestion['value'] as String;
    final city = (suggestion['city'] as String?) ?? '';
    setState(() {
      _showSuggestions = false;
      _suggestions = [];
    });
    _validateCity(city);
    _ignoreTextChanges = false;
  }

  Future<void> _submit() async {
    if (_addressController.text.trim().length < 5) {
      setState(() => _addressError = 'Укажите полный адрес');
      return;
    }
    if (!_addressValid) {
      setState(() =>
          _addressError = 'Доставка только по Брянску, Путевке и Супонево');
      return;
    }
    if (!_agreed) return;
    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите время доставки')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final result = await ServiceService.submitCourierRequest(
        address: _addressController.text.trim(),
        date: _selectedDate!,
        time: _selectedTime!,
        items: _itemsController.text.trim(),
      );

      if (!mounted) return;

      if (result.isFailure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.errorOrNull?.userMessage ?? 'Ошибка',
            ),
          ),
        );
        setState(() => _loading = false);
        return;
      }

      setState(() {
        _success = true;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка соединения')),
      );
      setState(() => _loading = false);
    }
  }

  void _scrollToForm() {
    final ctx = _formKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _itemsController.dispose();
    _scrollController.dispose();
    _pageController.dispose();
    _carouselAnimController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: context.colors.surfaceAlt,
        body: Stack(
          children: [
            Positioned.fill(
              child: Column(
                children: [
                  SizedBox(height: topPadding + 48),
                  Expanded(
                    child: _success ? _buildSuccess() : _buildForm(),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ClipRRect(
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(20)),
                child: Container(
                  padding: EdgeInsets.only(top: topPadding, bottom: 4),
                  color: Colors.white,
                  child: Row(
                    children: [
                      SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back,
                          color: context.colors.error,
                          size: 22,
                        ),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Сервисный центр',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textPrimary,
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () async {
                            final url = Uri.parse('tel:+79208447732');
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url);
                            }
                          },
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: context.colors.surfaceAlt,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.support_agent,
                              color: context.colors.textSecondary,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (!_success)
              Positioned(
                bottom: bottomPadding > 0 ? bottomPadding + 5 : 16,
                left: 16,
                right: 16,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [context.colors.brand, context.colors.brandDark],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: context.colors.brand
                            .withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: Offset(0, 6),
                      ),
                      BoxShadow(
                        color: context.colors.brand
                            .withValues(alpha: 0.15),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: _scrollToForm,
                      borderRadius: BorderRadius.circular(16),
                      splashColor: Colors.white.withValues(alpha: 0.2),
                      highlightColor: Colors.white.withValues(alpha: 0.1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        child: const Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Вызвать курьера',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Color(0xFFDCFCE7),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.check,
                size: 40,
                color: Color(0xFF15803D),
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Заявка принята!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 8),
            Text(
              'Мы свяжемся с вами в ближайшее время',
              style: TextStyle(fontSize: 14, color: context.colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final totalPages = (_sharpening.length / 2).ceil();

    return SingleChildScrollView(
      controller: _scrollController,
      padding: EdgeInsets.only(bottom: bottomPadding + 140),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [context.colors.brand, context.colors.brandDark],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Сервисный центр',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Заточка инструмента и ремонт оборудования\n'
                        'для бьюти-мастеров в Брянске',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                const Text(
                  'Заточка инструмента',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                if (_carouselAnimController != null) ...[
                  SizedBox(
                    height: 100,
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (page) {
                        setState(() => _currentPage = page);
                        _carouselAnimController!.forward(from: 0);
                      },
                      itemCount: totalPages,
                      itemBuilder: (context, pageIndex) {
                        final firstIndex = pageIndex * 2;
                        final secondIndex = firstIndex + 1;

                        return AnimatedBuilder(
                          animation: _carouselAnimController!,
                          builder: (context, child) {
                            return Row(
                              children: [
                                Expanded(
                                  child: Transform.scale(
                                    scale: 1.0 +
                                        (_carouselAnimController!.value * 0.03),
                                    child: Opacity(
                                      opacity: 0.85 +
                                          (_carouselAnimController!.value *
                                              0.15),
                                      child: _buildServiceCard(
                                        _sharpening[firstIndex]['name']
                                            as String,
                                        _sharpening[firstIndex]['price'] as int,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: secondIndex < _sharpening.length
                                      ? Transform.scale(
                                          scale: 1.0 +
                                              (_carouselAnimController!.value *
                                                  0.03),
                                          child: Opacity(
                                            opacity: 0.85 +
                                                (_carouselAnimController!
                                                        .value *
                                                    0.15),
                                            child: _buildServiceCard(
                                              _sharpening[secondIndex]['name']
                                                  as String,
                                              _sharpening[secondIndex]['price']
                                                  as int,
                                            ),
                                          ),
                                        )
                                      : const SizedBox(),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                  if (totalPages > 1)
                    Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(totalPages, (index) {
                            return AnimatedContainer(
                              duration: Duration(milliseconds: 300),
                              margin:
                                  EdgeInsets.symmetric(horizontal: 3),
                              width: index == _currentPage ? 16 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: index == _currentPage
                                    ? context.colors.brand
                                    : const Color(0xFFDDDDDD),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 24),

                const Text(
                  'Ремонт и диагностика',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: _buildInfoCard(
                      'Диагностика',
                      'Бесплатная диагностика оборудования.',
                      'Бесплатно',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildInfoCard(
                      'Ремонтные работы',
                      'Замена подшипников, щёток, чистка.',
                      'от 700 руб',
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                _buildRepairList(),
                const SizedBox(height: 24),

                const Text(
                  'Курьерская доставка по Брянску',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: _buildInfoCard(
                      'Забор инструмента',
                      'Курьер заберёт по вашему адресу.',
                      'от 400 руб',
                      note: '0 руб при заказе от 2 000 руб',
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _buildInfoCard(
                      'Доставка готового',
                      'Курьер привезёт обратно.',
                      'от 400 руб',
                      note: '0 руб при заказе от 2 000 руб',
                    ),
                  ),
                ]),
                SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: context.colors.surfaceAlt),
                  ),
                  child: Text(
                    'Забор + доставка: 800 руб\n'
                    '0 руб при заказе от 4 000 руб',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: context.colors.textSecondary),
                  ),
                ),
                const SizedBox(height: 24),

                const Text(
                  'Мы на карте',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SizedBox(
                    height: 200,
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(53.229247, 34.322058),
                        initialZoom: 15,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=oBJZC6WvtDIMzlY4WmP3',
                          userAgentPackageName: 'com.beautyrosha.app',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(53.229247, 34.322058),
                              width: 40,
                              height: 40,
                              child: Image.asset(
                                'assets/images/logo.png',
                                width: 40,
                                height: 40,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Container(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Вызвать курьера',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 12),
                      Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: context.colors.surfaceAlt),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'АДРЕС ЗАБОРА',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: context.colors.textMuted,
                              ),
                            ),
                            SizedBox(height: 6),
                            Container(
                              decoration: BoxDecoration(
                                color: context.colors.surfaceAlt,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _addressError.isNotEmpty
                                      ? context.colors.brand
                                          .withValues(alpha: 0.5)
                                      : const Color(0xFFE8E8E8),
                                ),
                              ),
                              child: TextField(
                                controller: _addressController,
                                decoration: InputDecoration(
                                  hintText: 'Начните вводить адрес...',
                                  hintStyle:
                                      TextStyle(color: Colors.grey[400]),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  errorText: _addressError.isNotEmpty
                                      ? _addressError
                                      : null,
                                  errorStyle: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                            if (_showSuggestions)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: _suggestions.map((suggestion) {
                                    return Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () =>
                                            _selectSuggestion(suggestion),
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.location_on_outlined,
                                                size: 16,
                                                color: context.colors.textDisabled,
                                              ),
                                              SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  suggestion['value']
                                                      as String,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: context.colors.textSecondary,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            if (_showSlots && _loadingDates)
                              Padding(
                                padding: EdgeInsets.only(top: 12),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: context.colors.brand,
                                  ),
                                ),
                              )
                            else if (_showSlots && _dates.isNotEmpty) ...[
                              SizedBox(height: 12),
                              Text(
                                'ДАТА',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: context.colors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              SizedBox(
                                height: 36,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  children: _dates.map((d) {
                                    return Padding(
                                      padding: EdgeInsets.only(right: 6),
                                      child: GestureDetector(
                                        onTap: () => setState(() {
                                          _selectedDate = d['value'];
                                          _selectedTime =
                                              _availableTimes.isNotEmpty
                                                  ? _availableTimes[0]
                                                  : null;
                                        }),
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _selectedDate == d['value']
                                                ? context.colors.brandLight
                                                : Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                              color: _selectedDate == d['value']
                                                  ? context.colors.brand
                                                  : Color(0xFFE8E8E8),
                                              width: 2,
                                            ),
                                          ),
                                          child: Text(
                                            d['chip_label']!,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: _selectedDate == d['value']
                                                  ? context.colors.brand
                                                  : context.colors.textSecondary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                              SizedBox(height: 12),
                              Text(
                                'ВРЕМЯ',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: context.colors.textMuted,
                                ),
                              ),
                              SizedBox(height: 6),
                              if (_availableTimes.isEmpty)
                                Container(
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Color(0xFFFFF5F5),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'На выбранную дату нет доступных слотов',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.colors.brand,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              else
                                SizedBox(
                                  height: 36,
                                  child: ListView(
                                    scrollDirection: Axis.horizontal,
                                    children: _availableTimes.map((t) {
                                      return Padding(
                                        padding:
                                            EdgeInsets.only(right: 6),
                                        child: GestureDetector(
                                          onTap: () => setState(
                                            () => _selectedTime = t,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets
                                                .symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  _selectedTime == t
                                                      ? context.colors.brandLight
                                                      : Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: _selectedTime == t
                                                    ? context.colors.brand
                                                    : Color(0xFFE8E8E8),
                                                width: 2,
                                              ),
                                            ),
                                            child: Text(
                                              t.replaceAll('-', ' до '),
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                color: _selectedTime == t
                                                    ? context.colors.brand
                                                    : context.colors.textSecondary,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                            ] else ...[
                              if (_addressError.isNotEmpty)
                                Padding(
                                  padding: EdgeInsets.only(top: 4),
                                  child: Text(
                                    _addressError,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.colors.brand,
                                    ),
                                  ),
                                )
                              else
                                Padding(
                                  padding: EdgeInsets.only(top: 4),
                                  child: Text(
                                    'Введите адрес в Брянске для выбора даты и времени',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.colors.textMuted,
                                    ),
                                  ),
                                ),
                            ],
                            SizedBox(height: 16),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: Checkbox(
                                    value: _agreed,
                                    onChanged: (v) => setState(
                                      () => _agreed = v ?? false,
                                    ),
                                    activeColor: context.colors.brand,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () async {
                                      final uri = Uri.parse(
                                        'https://бьютироща.рф/privacy',
                                      );
                                      if (await canLaunchUrl(uri)) {
                                        await launchUrl(
                                          uri,
                                          mode: LaunchMode.externalApplication,
                                        );
                                      }
                                    },
                                    child: Text.rich(
                                      TextSpan(
                                        text:
                                            'Согласен с правилами и условиями забора и доставки инструмента, а также ',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: context.colors.textMuted,
                                        ),
                                        children: [
                                          TextSpan(
                                            text:
                                                'политикой конфиденциальности.',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: context.colors.brand,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: GestureDetector(
                                onTap: (_agreed &&
                                        _addressValid &&
                                        !_loading &&
                                        _selectedTime != null)
                                    ? _submit
                                    : null,
                                child: AnimatedContainer(
                                  duration:
                                      Duration(milliseconds: 200),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    gradient: (_agreed &&
                                            _addressValid &&
                                            !_loading &&
                                            _selectedTime != null)
                                        ? LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              context.colors.brand,
                                              context.colors.brandDark,
                                            ],
                                          )
                                        : null,
                                    color: (_agreed &&
                                            _addressValid &&
                                            !_loading &&
                                            _selectedTime != null)
                                        ? null
                                        : Colors.grey,
                                    boxShadow: (_agreed &&
                                            _addressValid &&
                                            !_loading &&
                                            _selectedTime != null)
                                        ? [
                                            BoxShadow(
                                              color: context.colors.brand
                                                  .withValues(alpha: 0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Center(
                                    child: _loading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child:
                                                CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              'Отправить заявку',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                              maxLines: 1,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),

                Center(
                  child: GestureDetector(
                    onTap: () async {
                      final url = Uri.parse('tel:+79208447732');
                      if (await canLaunchUrl(url)) await launchUrl(url);
                    },
                    child: Text.rich(
                      TextSpan(
                        text: 'Или позвоните: ',
                        style: TextStyle(
                          fontSize: 14,
                          color: context.colors.textMuted,
                        ),
                        children: [
                          TextSpan(
                            text: '+7 (920) 844-77-32',
                            style: TextStyle(
                              color: context.colors.brand,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(String name, int price) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.surfaceAlt),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            'от $price руб',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: context.colors.brand,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    String title,
    String subtitle,
    String price, {
    String? note,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.surfaceAlt),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: context.colors.textMuted),
          ),
          SizedBox(height: 6),
          Text(
            price,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.colors.brand,
            ),
          ),
          if (note != null)
            Text(
              note,
              style: TextStyle(
                fontSize: 11,
                color: context.colors.textDisabled,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRepairList() {
    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.surfaceAlt),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Популярные ремонтные работы',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 12),
          ..._repairs.map(
            (r) => Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      r['name'] as String,
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                  Text(
                    r['price'] as String,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.colors.brand,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}