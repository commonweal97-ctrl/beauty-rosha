// lib/widgets/product/podeli_sheet.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PodeliSheet extends StatelessWidget {
  final double price;
  final String? productImage;

  const PodeliSheet({super.key, required this.price, this.productImage});

  double get _monthlyPayment => (price / 4).roundToDouble();

  static void show(BuildContext context, {required double price, String? productImage}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      isDismissible: true,
      builder: (_) => PodeliSheet(price: price, productImage: productImage),
    );
  }

  String _formatPrice(double p) {
    if (p == p.roundToDouble()) return '${p.toInt()}';
    return p.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: () {},
          child: DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    // Полоска на скругленном фоне
                    Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      child: Center(
                        child: Container(
                          margin: const EdgeInsets.only(top: 12, bottom: 8),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: EdgeInsets.zero,
                        children: [
                          // 🔥 Блок 1: Заголовок и условия
                          Container(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                            color: Colors.white, // Убрал borderRadius, он уже у родителя
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Частями ${_formatPrice(_monthlyPayment)} ₽ x 4',
                                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)),
                                          ),
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE8F5E9),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              'Без переплат',
                                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF00B341)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (productImage != null) ...[
                                      const SizedBox(width: 8),
                                      Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(10),
                                            child: CachedNetworkImage(
                                              imageUrl: productImage!,
                                              width: 56,
                                              height: 74,
                                              fit: BoxFit.cover,
                                              placeholder: (_, _) => Container(
                                                width: 56, height: 74,
                                                color: const Color(0xFFF6F6F9),
                                              ),
                                              errorWidget: (_, _, _) => Container(
                                                width: 56, height: 74,
                                                color: const Color(0xFFF6F6F9),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            left: -10,
                                            top: 6,
                                            child: Transform.rotate(
                                              angle: 0.5,
                                              child: Image.asset(
                                                'assets/payment/logo_podeli.png',
                                                width: 20,
                                                height: 20,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 20),
                                _buildConditionRow('${_formatPrice(_monthlyPayment)} ₽ первый платёж'),
                                const SizedBox(height: 10),
                                _buildConditionRow('Дальше 3 платежа по ${_formatPrice(_monthlyPayment)} ₽'),
                                const Padding(
                                  padding: EdgeInsets.only(left: 32, top: 2),
                                  child: Text('Каждые 2 недели', style: TextStyle(fontSize: 12, color: Color(0xFF999999))),
                                ),
                                const SizedBox(height: 10),
                                _buildConditionRow('Подробный график платежей можно увидеть при оплате'),
                              ],
                            ),
                          ),

                          const SizedBox(height: 8),

                          // 🔥 Блок 2: Почему это удобно
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Почему это удобно', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A))),
                                const SizedBox(height: 16),
                                _buildFeatureCard(
                                  icon: Icons.money_off,
                                  title: 'Переплата 0 ₽',
                                  subtitle: 'Никаких скрытых комиссий — это регулируется федеральным законом',
                                ),
                                _buildFeatureCard(
                                  icon: Icons.flash_on,
                                  title: 'Оформление за пару шагов',
                                  subtitle: 'Может понадобиться подтверждение через Госуслуги и короткая анкета',
                                ),
                                _buildFeatureCard(
                                  icon: Icons.schedule,
                                  title: 'Досрочно или по графику',
                                  subtitle: 'Платежи будут списываться сами — или можно внести их досрочно',
                                ),
                                const SizedBox(height: 8),
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE8F5E9),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'Можно оплатить частями до 30 000 ₽',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF00B341)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 8),

                          // 🔥 Блок 3: Вопросы и ответы
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Частые вопросы', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A))),
                                const SizedBox(height: 16),
                                _buildFaqItem('Как оплатить частями?', 'При оформлении заказа выберите способ оплаты «Подели». Сумма заказа разделится на 4 равных платежа. Первый платёж спишется сразу, остальные — каждые 2 недели.'),
                                _buildFaqItem('Это кредит или рассрочка?', 'Нет. Это сервис оплаты частями без процентов и переплат. Вы платите ровно столько, сколько стоит товар.'),
                                _buildFaqItem('Что нужно для оформления?', 'Только паспортные данные и подтверждение через Госуслуги. Весь процесс занимает пару минут прямо при оформлении заказа.'),
                                _buildFaqItem('Можно ли оплатить досрочно?', 'Да, вы можете погасить оставшиеся платежи досрочно в любой момент в личном кабинете Подели.'),
                                _buildFaqItem('Что если я захочу вернуть товар?', 'Возврат оформляется как обычно — через магазин. Деньги вернутся от сервиса Подели с учётом уже внесённых платежей.'),
                                _buildFaqItem('Есть ли ограничения по сумме?', 'Максимальная сумма заказа для оплаты частями — 30 000 ₽. Минимальная сумма не ограничена.'),
                                _buildFaqItem('Как отслеживать график платежей?', 'График и статус платежей доступен в личном кабинете Подели. Также вы получите уведомления перед каждым списанием.'),
                                _buildFaqItem('Какие способы оплаты принимаете?', 'Оплата частями доступна только при оплате картой. Наложенным платежом или по счёту — недоступна.'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.only(
                        left: 20, right: 20, top: 12,
                        bottom: 12 + MediaQuery.of(context).padding.bottom,
                      ),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(top: BorderSide(color: Color(0xFFF0F0F5))),
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFDD1847), Color(0xFFB01038)],
                            ),
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text('К оформлению', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildConditionRow(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle_outline, size: 20, color: Color(0xFF00B341)),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A1A), height: 1.4))),
      ],
    );
  }

  Widget _buildFeatureCard({required IconData icon, required String title, required String subtitle}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: const Color(0xFF999999)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF8F8F9A), height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return Material(
      color: Colors.transparent,
      child: Theme(
        data: ThemeData(dividerColor: Colors.transparent, splashColor: Colors.transparent, highlightColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 12),
          title: Text(question, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
          trailing: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF999999)),
          children: [
            Text(answer, style: const TextStyle(fontSize: 13, color: Color(0xFF666666), height: 1.5)),
          ],
        ),
      ),
    );
  }
}