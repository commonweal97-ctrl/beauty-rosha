class ProductPriceDisplay {
  final double primaryPrice;
  final double? secondaryPrice;
  final bool strikethroughSecondary;
  final bool isSale;
  final bool showCardIcon;
  final double? discountAmount;

  const ProductPriceDisplay({
    required this.primaryPrice,
    this.secondaryPrice,
    required this.strikethroughSecondary,
    required this.isSale,
    required this.showCardIcon,
    this.discountAmount,
  });

  factory ProductPriceDisplay.resolve({
    required double regularPrice,
    double? cardPrice,
    double? salePrice,
    required bool hasActiveCard,
  }) {
    final hasValidSale =
        salePrice != null && salePrice > 0 && salePrice < regularPrice;
    if (hasValidSale) {
      return ProductPriceDisplay(
        primaryPrice: salePrice,
        secondaryPrice: regularPrice,
        strikethroughSecondary: true,
        isSale: true,
        showCardIcon: false,
        discountAmount: regularPrice - salePrice,
      );
    }

    final resolvedCardPrice =
        (cardPrice != null && cardPrice > 0) ? cardPrice : regularPrice;
    final hasDistinctCardPrice = resolvedCardPrice < regularPrice;

    return ProductPriceDisplay(
      primaryPrice: resolvedCardPrice,
      secondaryPrice: hasDistinctCardPrice ? regularPrice : null,
      strikethroughSecondary: hasDistinctCardPrice && hasActiveCard,
      isSale: false,
      showCardIcon: hasDistinctCardPrice,
      discountAmount: hasDistinctCardPrice && hasActiveCard
          ? regularPrice - resolvedCardPrice
          : null,
    );
  }
}
