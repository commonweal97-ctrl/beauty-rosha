// lib/widgets/product/podeli_sheet.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/app_colors.dart';

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
                decoration: BoxDecoration(
                  color: context.colors.surfaceAlt,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    // Полоска на скругленном фоне
                    Container(
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      child: Center(
                        child: Container(
                          margin: const EdgeInsets.only(top: 12, bottom: 8),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: context.colors.border,
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
                            color: context.colors.surface,
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
                                            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: context.colors.textPrimary),
                                          ),
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: context.colors.success.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              'Без переплат',
                                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.colors.success),
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
                                                color: context.colors.surfaceAlt,
                                              ),
                                              errorWidget: (_, _, _) => Container(
                                                width: 56, height: 74,
                                                color: context.colors.surfaceAlt,
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
                                SizedBox(height: 20),
                                _buildConditionRow(context, '${_formatPrice(_monthlyPayment)} ₽ первый платёж'),
                                SizedBox(height: 10),
                                _buildConditionRow(context, 'Дальше 3 платежа по ${_formatPrice(_monthlyPayment)} ₽'),
                                Padding(
                                  padding: EdgeInsets.only(left: 32, top: 2),
                                  child: Text('Каждые 2 недели', style: TextStyle(fontSize: 12, color: context.colors.textMuted)),
                                ),
                                const SizedBox(height: 10),
                                _buildConditionRow(context, 'Подробный график платежей можно увидеть при оплате'),
                              ],
                            ),
                          ),

                          const SizedBox(height: 8),

                          // 🔥 Блок 2: Почему это удобно
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: context.colors.surface,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Почему это удобно', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
                                const SizedBox(height: 16),
                                _buildFeatureCard(context, 
                                  icon: Icons.money_off,
                                  title: 'Переплата 0 ₽',
                                  subtitle: 'Никаких скрытых комиссий — это регулируется федеральным законом',
                                ),
                                _buildFeatureCard(context, 
                                  icon: Icons.flash_on,
                                  title: 'Оформление за пару шагов',
                                  subtitle: 'Может понадобиться подтверждение через Госуслуги и короткая анкета',
                                ),
                                _buildFeatureCard(context, 
                                  icon: Icons.schedule,
                                  title: 'Досрочно или по графику',
                                  subtitle: 'Платежи будут списываться сами — или можно внести их досрочно',
                                ),
                                const SizedBox(height: 8),
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: context.colors.success.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Можно оплатить частями до 30 000 ₽',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.colors.success),
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
                              color: context.colors.surface,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Частые вопросы', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
                                const SizedBox(height: 16),
                                _buildFaqItem(context, 'Как оплатить частями?', 'При оформлении заказа выберите способ оплаты «Подели». Сумма заказа разделится на 4 равных платежа. Первый платёж спишется сразу, остальные — каждые 2 недели.'),
                                _buildFaqItem(context, 'Это кредит или рассрочка?', 'Нет. Это сервис оплаты частями без процентов и переплат. Вы платите ровно столько, сколько стоит товар.'),
                                _buildFaqItem(context, 'Что нужно для оформления?', 'Только паспортные данные и подтверждение через Госуслуги. Весь процесс занимает пару минут прямо при оформлении заказа.'),
                                _buildFaqItem(context, 'Можно ли оплатить досрочно?', 'Да, вы можете погасить оставшиеся платежи досрочно в любой момент в личном кабинете Подели.'),
                                _buildFaqItem(context, 'Что если я захочу вернуть товар?', 'Возврат оформляется как обычно — через магазин. Деньги вернутся от сервиса Подели с учётом уже внесённых платежей.'),
                                _buildFaqItem(context, 'Есть ли ограничения по сумме?', 'Максимальная сумма заказа для оплаты частями — 30 000 ₽. Минимальная сумма не ограничена.'),
                                _buildFaqItem(context, 'Как отслеживать график платежей?', 'График и статус платежей доступен в личном кабинете Подели. Также вы получите уведомления перед каждым списанием.'),
                                _buildFaqItem(context, 'Какие способы оплаты принимаете?', 'Оплата частями доступна только при оплате картой. Наложенным платежом или по счёту — недоступна.'),
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
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(top: BorderSide(color: context.colors.surfaceAlt)),
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [context.colors.brand, context.colors.brandDark],
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

  Widget _buildConditionRow(BuildContext context, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.check_circle_outline, size: 20, color: context.colors.success),
        SizedBox(width: 12),
        Expanded(child: Text(text, style: TextStyle(fontSize: 14, color: context.colors.textPrimary, height: 1.4))),
      ],
    );
  }

  Widget _buildFeatureCard(BuildContext context, {required IconData icon, required String title, required String subtitle}) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: context.colors.textMuted),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.colors.textPrimary)),
                SizedBox(height: 4),
                Text(subtitle, style: TextStyle(fontSize: 12, color: context.colors.textMuted, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqItem(BuildContext context, String question, String answer) {
    return Material(
      color: Colors.transparent,
      child: Theme(
        data: ThemeData(dividerColor: Colors.transparent, splashColor: Colors.transparent, highlightColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.only(bottom: 12),
          title: Text(question, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.colors.textPrimary)),
          trailing: Icon(Icons.keyboard_arrow_down, color: context.colors.textMuted),
          children: [
            Text(answer, style: TextStyle(fontSize: 13, color: context.colors.textSecondary, height: 1.5)),
          ],
        ),
      ),
    );
  }
}