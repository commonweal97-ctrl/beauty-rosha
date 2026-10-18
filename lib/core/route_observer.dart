// lib/core/route_observer.dart
import 'package:flutter/material.dart';

/// Глобальный RouteObserver — нужен для RouteAware-экранов,
/// которые хотят реагировать на возврат (didPopNext).
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();
