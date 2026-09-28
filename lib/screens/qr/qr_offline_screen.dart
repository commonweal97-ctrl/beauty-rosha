// lib/screens/qr/qr_offline_screen.dart
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/connectivity_service.dart';
import '../../core/app_colors.dart';

class QrOfflineScreen extends StatefulWidget {
  const QrOfflineScreen({super.key});

  @override
  State<QrOfflineScreen> createState() => _QrOfflineScreenState();
}

class _QrOfflineScreenState extends State<QrOfflineScreen> {
  String? _qrData;
  bool _hasCard = false;
  bool _isChecking = false;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _loadQrFromCache();
  }

  Future<void> _loadQrFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      final cached = prefs.getString('cached_qr_card');
      
      if (_isLoggedIn && cached != null && cached.isNotEmpty && mounted) {
        setState(() {
          _qrData = cached;
          _hasCard = true;
        });
      } else if (mounted) {
        setState(() {
          _hasCard = false;
          _qrData = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
        _hasCard = false;
        _qrData = null;
        _isLoggedIn = false;
      });
      }
    }
  }

  void _retryConnection() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);
    await ConnectivityService().retry();
    if (mounted) setState(() => _isChecking = false);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [context.colors.brand, Color(0xFFA01235)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              if (_hasCard) ...[
                const SizedBox(height: 16),
                const Text('Б•Карта', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                const Spacer(),
              ] else
                const Spacer(),
              
              if (_hasCard && _qrData != null) ...[
                Container(
                  width: 220, height: 220,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))],
                  ),
                  child: QrImageView(data: _qrData!, version: QrVersions.auto, size: 196, backgroundColor: Colors.white),
                ),
                const Spacer(),
              ],
              
              if (!_hasCard)
                const Padding(
                  padding: EdgeInsets.only(bottom: 20),
                  child: Text(
                    'Вы не в сети',
                    style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                ),
              
              Container(
                margin: EdgeInsets.symmetric(horizontal: _hasCard ? 24 : 32),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: _hasCard ? 12 : 20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(_hasCard ? 12 : 16),
                ),
                child: Row(
                  children: [
                    Icon(Icons.wifi_off, color: Colors.white70, size: _hasCard ? 20 : 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Не удалось загрузить страницу, попробуйте обновить её.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: _hasCard ? 13 : 17,
                          fontWeight: _hasCard ? FontWeight.w400 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              if (_hasCard) ...[
                const SizedBox(height: 40),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 30),
                  child: Text('Связь пропала, но выгода осталась', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
                ),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 30),
                  child: Text('Б•Карта доступна для начисления и списания. Проверьте подключение и обновите страницу.', style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.5), textAlign: TextAlign.center),
                ),
              ],
              
              const SizedBox(height: 32),
              
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    onPressed: _isChecking ? null : _retryConnection,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: context.colors.brand, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                    child: _isChecking
                        ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: context.colors.brand, strokeWidth: 2.5))
                        : const Text('Обновить страницу', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}