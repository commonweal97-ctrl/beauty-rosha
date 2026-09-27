// lib/screens/checkout/widgets/delivery_slots.dart
import 'package:flutter/material.dart';
import '../../../services/delivery_service.dart';

class DeliverySlots extends StatefulWidget {
  final Function(String date, String time) onSlotSelected;
  final double deliveryCost;
  final bool isFree;

  const DeliverySlots({
    super.key,
    required this.onSlotSelected,
    this.deliveryCost = 0,
    this.isFree = true,
  });

  @override
  State<DeliverySlots> createState() => _DeliverySlotsState();
}

class _DeliverySlotsState extends State<DeliverySlots> {
  List<Map<String, dynamic>> _dates = [];
  final List<String> _allTimes = ['09:00-12:00', '12:00-15:00', '15:00-18:00', '18:00-21:00'];
  List<String> _availableTimes = [];
  String? _selectedDate;
  String? _selectedTime;
  bool _loadingDates = true;

  final _months = ['января', 'февраля', 'марта', 'апреля', 'мая', 'июня', 'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря'];
  final _weekdays = ['вс', 'пн', 'вт', 'ср', 'чт', 'пт', 'сб'];

  @override
  void initState() {
    super.initState();
    _generateDates();
  }

  void _generateDates() async {
    final now = DateTime.now();
    final startDate = now.hour < 18 ? now : now.add(const Duration(days: 1));
    
    final dates = <Map<String, dynamic>>[];
    for (int i = 0; i < 7; i++) {
      final date = startDate.add(Duration(days: i));
      final value = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final day = '${date.day}';
      final month = _months[date.month - 1];
      final weekday = _weekdays[date.weekday % 7];
      final diffDays = date.difference(now).inDays;
      final label = diffDays == 0 ? 'сегодня' : (diffDays == 1 ? 'завтра' : weekday);
      dates.add({
        'value': value,
        'display': '$day $month',
        'chip_label': '$day $month, $label',
        'full_label': label,
        'blocked_slots': <String>[],
      });
    }
    
    for (final d in dates) {
      try {
        final exceptions = await DeliveryService.checkExceptions(d['value'] as String);
        if (exceptions['full_day_blocked'] == true) {
          d['full_day_blocked'] = true;
        } else {
          d['blocked_slots'] = List<String>.from(exceptions['blocked_slots'] ?? []);
        }
      } catch (_) {}
    }
    
    dates.removeWhere((d) => d['full_day_blocked'] == true);
    
    if (mounted) {
      setState(() {
        _dates = dates;
        _loadingDates = false;
        if (_dates.isNotEmpty) {
          _selectedDate = _dates[0]['value'] as String;
          _updateTimesForDate(_selectedDate!);
        }
      });
    }
  }

  void _updateTimesForDate(String dateValue) {
    final date = _dates.firstWhere(
      (d) => d['value'] == dateValue,
      orElse: () => {'blocked_slots': <String>[]},
    );
    final blockedSlots = List<String>.from(date['blocked_slots'] ?? []);
    
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    
    List<String> times = List.from(_allTimes);
    times.removeWhere((t) => blockedSlots.contains(t));
    
    if (dateValue == todayStr) {
      final currentMinutes = now.hour * 60 + now.minute;
      times.removeWhere((t) {
        final startHour = int.parse(t.split(':')[0]);
        return currentMinutes >= startHour * 60;
      });
    }
    
    setState(() {
      _availableTimes = times;
      _selectedTime = times.isNotEmpty ? times[0] : null;
      if (_selectedTime != null) {
        widget.onSlotSelected(_selectedDate!, _selectedTime!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingDates) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFDD1847)));
    }
    
    if (_dates.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF5F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('Доставка недоступна в ближайшие 7 дней', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFDD1847))),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Заголовок с датой и временем
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Доставим ', style: TextStyle(fontSize: 14, color: Color(0xFF1A1A1A))),
                TextSpan(
                  text: _getSelectedDateLabel(),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFDD1847)),
                ),
                const TextSpan(text: ' с ', style: TextStyle(fontSize: 14, color: Color(0xFF1A1A1A))),
                TextSpan(
                  text: (_selectedTime ?? '').replaceAll('-', ' до '),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFDD1847)),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Даты
        const Text('Дата', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF999999))),
        const SizedBox(height: 6),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: _dates.map((d) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () {
                  setState(() => _selectedDate = d['value'] as String);
                  _updateTimesForDate(_selectedDate!);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _selectedDate == d['value'] ? const Color(0xFFFDF2F5) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _selectedDate == d['value'] ? const Color(0xFFDD1847) : const Color(0xFFE8E8E8),
                      width: 2,
                    ),
                  ),
                  child: Text(
                    d['chip_label'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _selectedDate == d['value'] ? const Color(0xFFDD1847) : const Color(0xFF666666),
                    ),
                  ),
                ),
              ),
            )).toList(),
          ),
        ),

        const SizedBox(height: 12),

        // Время
        const Text('Время', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF999999))),
        const SizedBox(height: 6),
        if (_availableTimes.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF5F5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('На выбранную дату нет доступных интервалов', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Color(0xFFDD1847))),
          )
        else
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _availableTimes.map((t) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _selectedTime = t);
                    widget.onSlotSelected(_selectedDate!, _selectedTime!);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _selectedTime == t ? const Color(0xFFFDF2F5) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _selectedTime == t ? const Color(0xFFDD1847) : const Color(0xFFE8E8E8),
                        width: 2,
                      ),
                    ),
                    child: Text(
                      t.replaceAll('-', ' до '),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _selectedTime == t ? const Color(0xFFDD1847) : const Color(0xFF666666),
                      ),
                    ),
                  ),
                ),
              )).toList(),
            ),
          ),
      ],
    );
  }

  String _getSelectedDateLabel() {
    if (_selectedDate == null) return '';
    final date = _dates.firstWhere(
      (d) => d['value'] == _selectedDate,
      orElse: () => {'full_label': ''},
    );
    return date['full_label'] as String;
  }
}