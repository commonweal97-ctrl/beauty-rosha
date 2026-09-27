// lib/core/result.dart
//
// Тип Result<T> — явное представление результата операции,
// который может завершиться успехом или ошибкой.
//
// Зачем: убирает разбросанные try/catch по всему коду, делает
// обработку ошибок явной и типобезопасной.

import 'api_error.dart';

/// Результат операции: либо [Success], либо [Failure].
sealed class Result<T> {
  const Result();

  /// Успех с данными.
  const factory Result.success(T value) = Success<T>;

  /// Ошибка с типизированной причиной.
  const factory Result.failure(ApiError error) = Failure<T>;

  /// Удобные хелперы.
  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  T? get valueOrNull => this is Success<T> ? (this as Success<T>).value : null;
  ApiError? get errorOrNull =>
      this is Failure<T> ? (this as Failure<T>).error : null;

  /// Преобразовать значение, сохранив ошибку.
  Result<R> map<R>(R Function(T value) mapper) {
    return switch (this) {
      Success<T>(value: final v) => Result.success(mapper(v)),
      Failure<T>(error: final e) => Result.failure(e),
    };
  }

  /// Выполнить действие при успехе (для side effects).
  Result<T> onSuccess(void Function(T value) action) {
    if (this is Success<T>) action((this as Success<T>).value);
    return this;
  }

  /// Выполнить действие при ошибке (для side effects).
  Result<T> onFailure(void Function(ApiError error) action) {
    if (this is Failure<T>) action((this as Failure<T>).error);
    return this;
  }
}

final class Success<T> extends Result<T> {
  final T value;
  const Success(this.value);
}

final class Failure<T> extends Result<T> {
  final ApiError error;
  const Failure(this.error);
}