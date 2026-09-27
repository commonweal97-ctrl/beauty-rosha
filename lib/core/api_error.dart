// lib/core/api_error.dart
//
// Типизированные ошибки API. Заменяют разрозненные
// {'success': false, 'message': '...'} на строгую модель.

/// Базовая ошибка API.
sealed class ApiError implements Exception {
  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  const ApiError(this.message, {this.cause, this.stackTrace});

  /// Пользовательское сообщение (можно показывать в UI).
  String get userMessage;

  /// Критична ли ошибка (блокирует ли работу приложения).
  bool get isBlocking => false;

  /// Можно ли повторить запрос.
  bool get isRetryable => false;

  @override
  String toString() => '$runtimeType: $message';
}

/// Ошибка сети (нет соединения, DNS, connection refused).
class NetworkError extends ApiError {
  @override
  final bool isBlocking;

  const NetworkError(
    super.message, {
    this.isBlocking = false,
    super.cause,
    super.stackTrace,
  });

  @override
  String get userMessage => 'Нет соединения с интернетом';

  @override
  bool get isRetryable => true;
}

/// Таймаут запроса.
class TimeoutError extends ApiError {
  const TimeoutError(
    super.message, {
    super.cause,
    super.stackTrace,
  });

  @override
  String get userMessage => 'Превышено время ожидания';

  @override
  bool get isBlocking => true;

  @override
  bool get isRetryable => true;
}

/// Сервер ответил, но с ошибкой (5xx).
class ServerError extends ApiError {
  final int? statusCode;

  const ServerError(
    super.message, {
    this.statusCode,
    super.cause,
    super.stackTrace,
  });

  @override
  String get userMessage => 'Ошибка на сервере';

  @override
  bool get isRetryable => statusCode == null || statusCode! >= 500;
}

/// Сервер вернул успешный HTTP-код, но тело невалидное (не JSON).
class ParseError extends ApiError {
  const ParseError(
    super.message, {
    super.cause,
    super.stackTrace,
  });

  @override
  String get userMessage => 'Ошибка обработки данных';

  @override
  bool get isRetryable => false;
}

/// Бизнес-ошибка: сервер вернул `success: false` с сообщением.
class BusinessError extends ApiError {
  final Map<String, dynamic> payload;

  const BusinessError(
    super.message, {
    this.payload = const {},
    super.cause,
    super.stackTrace,
  });

  @override
  String get userMessage => message.isNotEmpty ? message : 'Что-то пошло не так';

  @override
  bool get isRetryable => false;
}

/// Неизвестная ошибка.
class UnknownError extends ApiError {
  const UnknownError(
    super.message, {
    super.cause,
    super.stackTrace,
  });

  @override
  String get userMessage => 'Что-то пошло не так';

  @override
  bool get isRetryable => false;
}