// lib/screens/checkout/widgets/delivery_method_selector.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../../providers/checkout_provider.dart';
import '../../../models/store.dart';
import '../store_map_screen.dart';
import '../pickup_map_screen.dart';
import 'courier_delivery_form.dart';
import '../../../core/app_colors.dart';
import '../../../core/price_formatter.dart';

class DeliveryMethodSelector extends StatelessWidget {
  final String city;

  const DeliveryMethodSelector({super.key, this.city = 'Брянск'});

  bool _isBryanskCity(String city) {
    final lower = city.toLowerCase();
    return ['брянск', 'путевка', 'супонево'].any((c) => lower == c || lower.contains(c));
  }

  bool _isBryanskOblast(String city) {
    final lower = city.toLowerCase();
    if (_isBryanskCity(city)) return false;
    
    final oblastCities = [
      'почеп', 'погар', 'унеча', 'дятьково', 'сельцо', 'фокино', 'клинцы',
      'новозыбков', 'стародуб', 'трубчевск', 'карачев', 'жуковка', 'сураж',
      'мглин', 'суземка', 'комаричи', 'навля', 'выгоничи',
    ];
    return oblastCities.any((c) => lower.contains(c));
  }

  List<String> _getAvailableMethods(String city) {
    if (_isBryanskCity(city)) return ['pickup-store', 'courier'];
    if (_isBryanskOblast(city)) return ['pickup-store', 'pickup-point'];
    return ['pickup-point'];
  }

  static const _providerMeta = {
    'yandex': ProviderMeta(name: 'Яндекс', color: Color(0xFFFC3F1D), logoAsset: 'assets/images/YandexLogo.png'),
    'ozon': ProviderMeta(name: 'Ozon', color: Color(0xFF005BFF), logoAsset: 'assets/images/OzonLogo.png'),
    'cdek': ProviderMeta(name: 'СДЭК', color: Color(0xFF00A046), logoAsset: 'assets/images/CDEKLogo.png'),
    'fivepost': ProviderMeta(name: '5Post', color: Color(0xFF4CAF50), logoAsset: 'assets/images/5postlogo.png'),
    'russian_post': ProviderMeta(name: 'Почта', color: Color(0xFF2D3192), logoAsset: 'assets/images/Pochalogo.png'),
};

  String _formatDays(int days) {
    if (days % 10 == 1 && days % 100 != 11) return '$days день';
    if (days % 10 >= 2 && days % 10 <= 4 && (days % 100 < 10 || days % 100 >= 20)) return '$days дня';
    return '$days дней';
  }

  String _formatDeliveryDays(String daysStr) {
    final parts = daysStr.replaceAll(RegExp(r'[^0-9\-]'), '').split('-');
    if (parts.length == 2) {
      final min = int.tryParse(parts[0]) ?? 0;
      final max = int.tryParse(parts[1]) ?? 0;
      if (min == max) return _formatDays(min);
      return '${_formatDays(min)} – ${_formatDays(max)}';
    }
    final single = int.tryParse(parts[0]) ?? 0;
    return _formatDays(single);
  }

  @override
  Widget build(BuildContext context) {
    final checkout = context.watch<CheckoutProvider>();
    final methods = _getAvailableMethods(city);
    final hasCourier = methods.contains('courier');
    final hasPickupPoint = methods.contains('pickup-point');
    final showSwitcher = hasCourier;
    
    return Container(
      color: context.colors.surface,
      margin: EdgeInsets.only(top: 8),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Способ доставки', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
          const SizedBox(height: 16),
          
          if (showSwitcher) _buildSwitcher(context, checkout),
          SizedBox(height: showSwitcher ? 16 : 0),
          
          // 🔥 Показываем pickup-опции только если метод НЕ courier
          if (checkout.deliveryMethod != 'courier' && (methods.contains('pickup-store') || methods.contains('pickup-point')))
            _buildPickupOptions(checkout, context, hasPickupPoint),
            
          if (checkout.deliveryMethod == 'courier' && hasCourier)
            CourierDeliveryForm(),
        ],
      ),
    );
  }

  Widget _buildSwitcher(BuildContext context, CheckoutProvider checkout) {
    return Container(
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.colors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => checkout.setDeliveryMethod('pickup-store'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: checkout.deliveryMethod == 'pickup-store' ? context.colors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: checkout.deliveryMethod == 'pickup-store'
                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2))]
                      : null,
                ),
                child: const Text('Самовывоз', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => checkout.setDeliveryMethod('courier'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: checkout.deliveryMethod == 'courier' ? context.colors.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: checkout.deliveryMethod == 'courier'
                      ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2))]
                      : null,
                ),
                child: const Text('Курьером', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickupOptions(CheckoutProvider checkout, BuildContext context, bool hasPickupPoint) {
    final methods = _getAvailableMethods(city);
    final hasStore = methods.contains('pickup-store');
    
    return Column(
      children: [
        // 🔥 Показываем "Забрать из магазина" только если доступен
        if (hasStore)
          _buildDeliveryOption(context, 
            isSelected: checkout.deliveryMethod == 'pickup-store',
            icon: Icons.store_outlined,
            title: 'Забрать из магазина',
            subtitle: checkout.selectedStore != null ? checkout.selectedStore!.name : 'Бесплатно',
            onTap: () => checkout.setDeliveryMethod('pickup-store'),
          ),
        
        if (hasPickupPoint) ...[
          if (hasStore) const SizedBox(height: 8),
          _buildDeliveryOption(context, 
            isSelected: checkout.deliveryMethod == 'pickup-point',
            icon: Icons.location_on_outlined,
            title: 'Из пункта выдачи',
            subtitle: checkout.selectedPickupPoint != null 
                ? checkout.selectedPickupPoint!.name 
                : 'от 2 дней',
            onTap: () => checkout.setDeliveryMethod('pickup-point'),
          ),
        ],
        
        const SizedBox(height: 8),
        
        if (hasStore && checkout.deliveryMethod == 'pickup-store') ...[
          _buildStorePickerButton(context, checkout),
          if (checkout.selectedStore != null) _buildStoreServices(context),
        ],
        
        if (hasPickupPoint && checkout.deliveryMethod == 'pickup-point') ...[
          _buildPickupPointButton(context, checkout),
          if (checkout.selectedPickupPoint != null) ...[
            SizedBox(height: 12),
            _buildSelectedPickupInfo(checkout.selectedPickupPoint!),
          ],
        ],
      ],
    );
  }

  Widget _buildSelectedPickupInfo(PickupPoint point) {
    final meta = _providerMeta[point.provider];
    
    return Consumer<CheckoutProvider>(
      builder: (context, checkout, _) {
        final actualPoint = checkout.selectedPickupPoint ?? point;
        
        return Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.colors.border),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: (meta?.color ?? context.colors.textMuted).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Image.asset(
                        meta?.logoAsset ?? '',
                        width: 28, height: 28,
                        errorBuilder: (_, _, _) => Icon(Icons.location_on, color: meta?.color ?? context.colors.textMuted),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(actualPoint.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.colors.textPrimary)),
                        SizedBox(height: 2),
                        Text(actualPoint.address, style: TextStyle(fontSize: 14, color: context.colors.textMuted), maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 12),
              
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: context.colors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Срок', style: TextStyle(fontSize: 14, color: context.colors.textMuted)),
                        Text(
                          _formatDeliveryDays(actualPoint.deliveryDays),
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.colors.brand),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Стоимость', style: TextStyle(fontSize: 14, color: context.colors.textMuted)),
                        actualPoint.isFree
                            ? Text(
                                'Бесплатно',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF4CAF50),
                                ),
                              )
                            : context.formatPrice(
                                actualPoint.deliveryCost,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: context.colors.textPrimary,
                              ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStorePickerButton(BuildContext context, CheckoutProvider checkout) {
    return GestureDetector(
      onTap: () async {
        final store = await Navigator.of(context, rootNavigator: true).push<Store>(
          MaterialPageRoute(builder: (_) => StoreMapScreen()),
        );
        if (store != null) checkout.setSelectedStore(store);
      },
      child: Container(
        width: double.infinity, height: 70,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), image: DecorationImage(image: AssetImage('assets/images/kartaphoto.webp'), fit: BoxFit.cover)),
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withValues(alpha: 0.15), Colors.black.withValues(alpha: 0.08)])),
          child: Center(
            child: Container(
              width: double.infinity, margin: EdgeInsets.symmetric(horizontal: 16), padding: EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: context.colors.surface.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(8)),
              child: Text(checkout.selectedStore != null ? 'Изменить магазин' : 'Выбрать магазин', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPickupPointButton(BuildContext context, CheckoutProvider checkout) {
    return GestureDetector(
      onTap: () async {
        final point = await Navigator.of(context, rootNavigator: true).push<PickupPoint>(
          MaterialPageRoute(builder: (_) => PickupMapScreen()),
        );
        if (point != null) {
          checkout.setDeliveryMethod('pickup-point');
          checkout.setSelectedPickupPoint(point);
        }
      },
      child: Container(
        width: double.infinity, height: 70,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), image: DecorationImage(image: AssetImage('assets/images/kartaphoto.webp'), fit: BoxFit.cover)),
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withValues(alpha: 0.15), Colors.black.withValues(alpha: 0.08)])),
          child: Center(
            child: Container(
              width: double.infinity, margin: EdgeInsets.symmetric(horizontal: 16), padding: EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: context.colors.surface.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(8)),
              child: Text(checkout.selectedPickupPoint != null ? 'Изменить пункт выдачи' : 'Выбрать пункт выдачи', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.colors.textPrimary)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStoreServices(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(color: context.colors.surfaceAlt, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.colors.surfaceAlt)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Дополнительные услуги в данной точке:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.colors.textPrimary)),
          SizedBox(height: 12),
          _buildServiceItem(context, 'assets/icons/repair-svgrepo-com.svg', 'Ремонт оборудования', 'Починка и обслуживание ногтевого оборудования'),
          SizedBox(height: 10),
          _buildServiceItem(context, 'assets/icons/scissors-tool-cut-separate-svgrepo-com.svg', 'Заточка инструмента', 'Профессиональная заточка инструментов'),
          SizedBox(height: 10),
          _buildServiceItem(context, 'assets/icons/nail-polish-svgrepo-com.svg', 'Маникюр & Педикюр', 'Профессиональные услуги маникюра и педикюра'),
        ],
      ),
    );
  }

  Widget _buildServiceItem(BuildContext context, String iconPath, String title, String desc) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SvgPicture.asset(
        iconPath,
        width: 18,
        height: 18,
        colorFilter: ColorFilter.mode(
          context.colors.textPrimary,
          BlendMode.srcIn,
        ),
      ),
      SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: context.colors.textPrimary)), SizedBox(height: 2), Text(desc, style: TextStyle(fontSize: 12, color: context.colors.textMuted))])),
    ]);
  }

  Widget _buildDeliveryOption(BuildContext context, {required bool isSelected, required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(border: Border.all(color: isSelected ? context.colors.brand : context.colors.border, width: 2), borderRadius: BorderRadius.circular(14), color: isSelected ? context.colors.brandLight : context.colors.surface),
        child: Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: isSelected ? Colors.white : context.colors.surfaceAlt, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: context.colors.brand, size: 22)),
          SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.colors.textPrimary)), SizedBox(height: 4), Text(subtitle, style: TextStyle(fontSize: 13, color: context.colors.textMuted))])),
        ]),
      ),
    );
  }
}