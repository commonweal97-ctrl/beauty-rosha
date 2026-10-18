// lib/core/navigation.dart
import 'package:flutter/material.dart';

/// Глобальный ключ навигации.
///
/// Вынесен отдельно от `main.dart`, чтобы сервисы (например, `PushService`)
/// могли получать `BuildContext` (для доступа к `Provider`) без циклического
/// импорта `main.dart`.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
