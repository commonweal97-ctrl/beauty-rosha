import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../screens/main_shell.dart';

class CountrySelectScreen extends StatelessWidget {
  const CountrySelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFdd1847),
              Color(0xFFc1163d),
              Color(0xFF8B0020),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Добро пожаловать!',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Пожалуйста, выберите страну',
                    style: TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                  const SizedBox(height: 40),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 10)),
                      ],
                    ),
                    child: Column(
                      children: [
                        _CountryTile(
                          flag: 'assets/flags/flag-for-flag-russia.svg',
                          name: 'Россия',
                          currency: '₽',
                          useNbrb: false,
                          onTap: () => _selectCountry(context, 'RUB'),
                        ),
                        const Divider(height: 1, indent: 72),
                        _CountryTile(
                          flag: 'assets/flags/flag-for-flag-belarus.svg',
                          name: 'Беларусь',
                          currency: '\u{E901}',
                          useNbrb: true,
                          onTap: () => _selectCountry(context, 'BYN'),
                        ),
                        const Divider(height: 1, indent: 72),
                        _CountryTile(
                          flag: 'assets/flags/flag-for-flag-kazakhstan.svg',
                          name: 'Казахстан',
                          currency: '₸',
                          useNbrb: false,
                          onTap: () => _selectCountry(context, 'KZT'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectCountry(BuildContext context, String currency) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currency', currency);
    await prefs.setBool('country_selected', true);

    // Отправляем валюту на сервер
    try {
      await ApiService.post('/api/currency/set', {'currency': currency});
    } catch (_) {}

    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    }
  }
}

class _CountryTile extends StatelessWidget {
  final String flag;
  final String name;
  final String currency;
  final bool useNbrb;
  final VoidCallback onTap;

  const _CountryTile({
    required this.flag,
    required this.name,
    required this.currency,
    required this.useNbrb,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SvgPicture.asset(flag, width: 40, height: 28, fit: BoxFit.cover),
            ),
            const SizedBox(width: 16),
            Text(name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: Color(0xFF1a1a1a))),
            const Spacer(),
            Text(
              currency,
              style: TextStyle(
                fontSize: useNbrb ? 22 : 15,
                color: Colors.grey,
                fontFamily: useNbrb ? 'NBRB' : null,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}