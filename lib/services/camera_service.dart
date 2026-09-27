// lib/services/camera_service.dart
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class CameraService {
  final ImagePicker _picker;

  CameraService({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  /// Проверяет, доступна ли камера.
  /// На симуляторе iOS камера недоступна — isCameraAvailable вернёт false.
  Future<bool> get isCameraAvailable async {
    // На симуляторе iOS камеры нет физически
    if (Platform.isIOS) {
      try {
        // Проверяем, является ли устройство симулятором
        final result = await Process.run('uname', ['-m']);
        // На симуляторе архитектура x86_64, на реальном — arm64
        if (result.stdout.toString().trim() == 'x86_64') {
          return false;
        }
      } catch (_) {}
    }
    
    // Для реальных устройств и Android — камера доступна
    return true;
  }

  Future<FileWithMeta?> pickImage(
    ImageSource source, {
    int imageQuality = 80,
    double maxWidth = 1920,
  }) async {
    try {
      final xFile = await _picker.pickImage(
        source: source,
        imageQuality: imageQuality,
        maxWidth: maxWidth,
      );

      if (xFile == null) return null;

      final file = File(xFile.path);
      if (!await file.exists()) {
        throw CameraException(
          code: CameraErrorCode.fileNotFound,
          message: 'Файл изображения не найден',
        );
      }

      final sizeInBytes = await file.length();

      return FileWithMeta(
        file: file,
        name: xFile.name,
        sizeInBytes: sizeInBytes,
      );
    } catch (e) {
      throw CameraException(
        code: CameraErrorCode.unknown,
        message: 'Не удалось получить изображение',
        originalError: e,
      );
    }
  }
}

class FileWithMeta {
  final File file;
  final String name;
  final int sizeInBytes;

  const FileWithMeta({
    required this.file,
    required this.name,
    required this.sizeInBytes,
  });

  static const maxSizeBytes = 10 * 1024 * 1024;
  bool get isTooLarge => sizeInBytes > maxSizeBytes;
}

class CameraException implements Exception {
  final CameraErrorCode code;
  final String message;
  final Object? originalError;

  const CameraException({
    required this.code,
    required this.message,
    this.originalError,
  });

  String get userFriendlyMessage {
    switch (code) {
      case CameraErrorCode.unavailable:
        return 'Камера недоступна на этом устройстве';
      case CameraErrorCode.permissionDenied:
        return 'Нет доступа к камере. Разрешите доступ в настройках';
      case CameraErrorCode.fileNotFound:
        return 'Не удалось прочитать файл';
      case CameraErrorCode.tooLarge:
        return 'Файл слишком большой. Максимальный размер: 10 МБ';
      case CameraErrorCode.unknown:
        return 'Произошла ошибка. Попробуйте ещё раз';
    }
  }
}

enum CameraErrorCode {
  unavailable,
  permissionDenied,
  fileNotFound,
  tooLarge,
  unknown,
}