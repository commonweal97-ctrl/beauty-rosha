// lib/screens/profile/notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_logger.dart';
import '../../services/api_service.dart';
import '../../core/app_colors.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const _logTag = 'NotificationsScreen';

  bool _orderStatusEmail = true;
  bool _orderStatusPush = true;
  bool _paymentEmail = true;
  bool _paymentPush = true;
  bool _marketingEmail = true;
  bool _marketingPush = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    final result =
        await ApiService.get('/api/user/notification-settings');

    if (!mounted) return;

    if (result.isSuccess) {
      final data = result.valueOrNull?['data'];
      if (data is Map) {
        final orderStatus = data['order_status'];
        final payment = data['payment'];
        final marketing = data['marketing'];

        setState(() {
          if (orderStatus is Map) {
            _orderStatusEmail = orderStatus['email'] ?? true;
            _orderStatusPush = orderStatus['push'] ?? true;
          }
          if (payment is Map) {
            _paymentEmail = payment['email'] ?? true;
            _paymentPush = payment['push'] ?? true;
          }
          if (marketing is Map) {
            _marketingEmail = marketing['email'] ?? true;
            _marketingPush = marketing['push'] ?? true;
          }
          _isLoading = false;
        });

        await _saveToLocal();
        return;
      }
    } else {
      AppLogger.warning(
        _logTag,
        'loadSettings failed: ${result.errorOrNull?.message}',
      );
    }

    await _loadFromLocal();
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _loadFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _orderStatusEmail =
          prefs.getBool('notif_order_status_email') ?? true;
      _orderStatusPush =
          prefs.getBool('notif_order_status_push') ?? true;
      _paymentEmail = prefs.getBool('notif_payment_email') ?? true;
      _paymentPush = prefs.getBool('notif_payment_push') ?? true;
      _marketingEmail =
          prefs.getBool('notif_marketing_email') ?? true;
      _marketingPush =
          prefs.getBool('notif_marketing_push') ?? true;
    });
  }

  Future<void> _saveToLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_order_status_email', _orderStatusEmail);
    await prefs.setBool('notif_order_status_push', _orderStatusPush);
    await prefs.setBool('notif_payment_email', _paymentEmail);
    await prefs.setBool('notif_payment_push', _paymentPush);
    await prefs.setBool('notif_marketing_email', _marketingEmail);
    await prefs.setBool('notif_marketing_push', _marketingPush);
  }

  Future<void> _saveToServer() async {
    final result = await ApiService.post(
      '/api/user/save-notification-settings',
      {
        'order_status': {
          'email': _orderStatusEmail,
          'push': _orderStatusPush,
        },
        'payment': {
          'email': _paymentEmail,
          'push': _paymentPush,
        },
        'marketing': {
          'email': _marketingEmail,
          'push': _marketingPush,
        },
      },
    );

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'saveToServer failed: ${result.errorOrNull?.message}',
      );
    }
  }

  Future<void> _toggle(String key, bool value) async {
    setState(() {
      switch (key) {
        case 'order_status_email':
          _orderStatusEmail = value;
          break;
        case 'order_status_push':
          _orderStatusPush = value;
          break;
        case 'payment_email':
          _paymentEmail = value;
          break;
        case 'payment_push':
          _paymentPush = value;
          break;
        case 'marketing_email':
          _marketingEmail = value;
          break;
        case 'marketing_push':
          _marketingPush = value;
          break;
      }
    });
    await _saveToLocal();
    await _saveToServer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.surfaceAlt,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Уведомления',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        backgroundColor: context.colors.brand,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: context.colors.brand),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.only(top: 16, bottom: 100),
              child: Column(
                children: [
                  _buildBlock(
                    icon: Icons.local_shipping_outlined,
                    title: 'Статус заказа',
                    subtitle:
                        'Сообщим, когда заказ привезут в пункт выдачи или передадут курьеру',
                    emailKey: 'order_status_email',
                    emailValue: _orderStatusEmail,
                    pushKey: 'order_status_push',
                    pushValue: _orderStatusPush,
                  ),
                  const SizedBox(height: 12),
                  _buildBlock(
                    icon: Icons.payment_outlined,
                    title: 'Платежи',
                    subtitle: 'Напоминания об оплате и статус платежа',
                    emailKey: 'payment_email',
                    emailValue: _paymentEmail,
                    pushKey: 'payment_push',
                    pushValue: _paymentPush,
                  ),
                  const SizedBox(height: 12),
                  _buildBlock(
                    icon: Icons.discount_outlined,
                    title: 'Акции и предложения',
                    subtitle:
                        'Персональные рекомендации, скидки и бонусы',
                    emailKey: 'marketing_email',
                    emailValue: _marketingEmail,
                    pushKey: 'marketing_push',
                    pushValue: _marketingPush,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildBlock({
    required IconData icon,
    required String title,
    required String subtitle,
    required String emailKey,
    required bool emailValue,
    required String pushKey,
    required bool pushValue,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: context.colors.brandLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 22,
                    color: context.colors.brand,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _NotificationToggle(
              icon: Icons.email_outlined,
              label: 'Email',
              value: emailValue,
              onChanged: (v) => _toggle(emailKey, v),
            ),
            const Divider(height: 24),
            _NotificationToggle(
              icon: Icons.notifications_outlined,
              label: 'Push-уведомления',
              value: pushValue,
              onChanged: (v) => _toggle(pushKey, v),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _NotificationToggle({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 22, color: context.colors.textSecondary),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: context.colors.textPrimary,
            ),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: context.colors.brand,
        ),
      ],
    );
  }
}