// lib/screens/checkout/widgets/delivery_slots.dart
import 'package:flutter/material.dart';
import '../../../services/delivery_service.dart';
import '../../../core/app_colors.dart';

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
      return Center(child: CircularProgressIndicator(color: context.colors.brand));
    }
    
    if (_dates.isEmpty) {
      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text('Доставка недоступна в ближайшие 7 дней', textAlign: TextAlign.center, style: TextStyle(color: context.colors.brand)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Заголовок с датой и временем
        Container(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: 'Доставим ', style: TextStyle(fontSize: 14, color: context.colors.textPrimary)),
                TextSpan(
                  text: _getSelectedDateLabel(),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.colors.brand),
                ),
                TextSpan(text: ' с ', style: TextStyle(fontSize: 14, color: context.colors.textPrimary)),
                TextSpan(
                  text: (_selectedTime ?? '').replaceAll('-', ' до '),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.colors.brand),
                ),
              ],
            ),
          ),
        ),

        SizedBox(height: 12),

        // Даты
        Text('Дата', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.colors.textMuted)),
        SizedBox(height: 6),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: _dates.map((d) => Padding(
              padding: EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () {
                  setState(() => _selectedDate = d['value'] as String);
                  _updateTimesForDate(_selectedDate!);
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _selectedDate == d['value'] ? context.colors.brandLight : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _selectedDate == d['value'] ? context.colors.brand : context.colors.border,
                      width: 2,
                    ),
                  ),
                  child: Text(
                    d['chip_label'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _selectedDate == d['value'] ? context.colors.brand : context.colors.textSecondary,
                    ),
                  ),
                ),
              ),
            )).toList(),
          ),
        ),

        SizedBox(height: 12),

        // Время
        Text('Время', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.colors.textMuted)),
        SizedBox(height: 6),
        if (_availableTimes.isEmpty)
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('На выбранную дату нет доступных интервалов', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: context.colors.brand)),
          )
        else
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _availableTimes.map((t) => Padding(
                padding: EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _selectedTime = t);
                    widget.onSlotSelected(_selectedDate!, _selectedTime!);
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _selectedTime == t ? context.colors.brandLight : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _selectedTime == t ? context.colors.brand : context.colors.border,
                        width: 2,
                      ),
                    ),
                    child: Text(
                      t.replaceAll('-', ' до '),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _selectedTime == t ? context.colors.brand : context.colors.textSecondary,
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