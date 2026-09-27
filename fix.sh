#!/bin/bash

# 1. Исправить двойной импорт
sed -i '' '2d' lib/screens/checkout/widgets/checkout_button.dart

# 2. Исправить путь импорта
sed -i '' "s|import '../main_shell.dart';|import '../../screens/main_shell.dart';|" lib/screens/checkout/widgets/checkout_button.dart

# 3. Добавить импорт
for f in lib/screens/catalog/catalog_screen.dart lib/screens/profile/profile_screen.dart; do
    if ! grep -q "main_shell.dart" "$f"; then
        echo "import '../../screens/main_shell.dart';" | cat - "$f" > tmp && mv tmp "$f"
    fi
done

# 4. Добавить } перед классами
for f in \
  lib/screens/catalog/catalog_screen.dart \
  lib/screens/profile/profile_screen.dart \
  lib/widgets/app_header.dart \
  lib/screens/product/product_detail_screen.dart \
  lib/screens/profile/settings_screen.dart \
  lib/widgets/order_preview.dart \
  lib/screens/profile/order_detail_screen.dart \
  lib/screens/checkout/widgets/checkout_button.dart; do
    perl -i -pe 's/^(class _)/\}\n\n$1/' "$f"
    perl -i -pe 's/^(Widget _build)/\}\n\n$1/' "$f"
    perl -i -pe 's/^(Future.*_openPayment)/\}\n\n$1/' "$f"
done
