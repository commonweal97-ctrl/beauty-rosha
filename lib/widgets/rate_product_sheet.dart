// lib/widgets/rate_product_sheet.dart
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';

import '../core/app_logger.dart';
import '../core/result.dart';
import '../services/api_service.dart';
import '../services/camera_service.dart';
import '../core/app_colors.dart';

class RateProductSheet extends StatefulWidget {
  final Map<String, dynamic> item;
  final VoidCallback onRated;

  const RateProductSheet({
    super.key,
    required this.item,
    required this.onRated,
  });

  static Future<bool?> show(
    BuildContext context,
    Map<String, dynamic> item,
    VoidCallback onRated,
  ) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => RateProductSheet(item: item, onRated: onRated),
    );
  }

  @override
  State<RateProductSheet> createState() => _RateProductSheetState();
}

class _RateProductSheetState extends State<RateProductSheet> {
  static const _logTag = 'RateProductSheet';

  int _rating = 5;
  final _prosController = TextEditingController();
  final _consController = TextEditingController();
  final _textController = TextEditingController();
  bool _isSending = false;

  final ImagePicker _picker = ImagePicker();
  final List<File> _photos = [];
  File? _video;
  final CameraService _cameraService = CameraService();

  bool get _isEdit => widget.item['is_edit'] == true;

  @override
  void initState() {
    super.initState();

    if (_isEdit) {
      _rating = (widget.item['existing_rating'] ?? 5) as int;
      _prosController.text = widget.item['existing_pros'] ?? '';
      _consController.text = widget.item['existing_cons'] ?? '';
      _textController.text = widget.item['existing_text'] ?? '';
    } else {
      if (_getCommentBonus() == 0 &&
          _getPhotoBonus() == 0 &&
          _getVideoBonus() == 0) {
        _loadBonuses();
      }
    }

    _prosController.addListener(() {
      if (mounted) setState(() {});
    });
    _consController.addListener(() {
      if (mounted) setState(() {});
    });
    _textController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadBonuses() async {
    final productId = widget.item['id'];
    if (productId == null) return;

    final result = await ApiService.get(
      '/api/products/bonuses',
      queryParams: {'product_id': productId},
      forceRefresh: true,
    );

    if (!mounted) return;

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'loadBonuses failed: ${result.errorOrNull?.message}',
      );
      return;
    }

    final data = result.valueOrNull?['data'];
    if (data is! Map) return;

    setState(() {
      widget.item['max_bonus'] = data['max_bonus'] ?? 0;
      widget.item['comment_bonus'] = data['comment_bonus'] ?? 0;
      widget.item['photo_bonus'] = data['photo_bonus'] ?? 0;
      widget.item['video_bonus'] = data['video_bonus'] ?? 0;
    });
  }

  @override
  void dispose() {
    _prosController.dispose();
    _consController.dispose();
    _textController.dispose();
    super.dispose();
  }

  String _imageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    return 'https://xn--80abvyjk6cts.xn--p1ai/$url';
  }

  int _parseBonus(dynamic bonus) {
    if (bonus == null) return 0;
    if (bonus is int) return bonus;
    if (bonus is String) return int.tryParse(bonus) ?? 0;
    return 0;
  }

  int _getCommentBonus() => _parseBonus(widget.item['comment_bonus']);
  int _getPhotoBonus() => _parseBonus(widget.item['photo_bonus']);
  int _getVideoBonus() => _parseBonus(widget.item['video_bonus']);

  int get _totalTextLength =>
      _prosController.text.length +
      _consController.text.length +
      _textController.text.length;

  bool get _hasMinText => _totalTextLength >= 40;

  int get _charsRemaining => 40 - _totalTextLength;

  bool get _canAddPhotos => _hasMinText;
  bool get _canAddVideo => _hasMinText && _photos.isNotEmpty;

  Future<void> _pickVideo() async {
    if (!_canAddVideo) return;
    final video = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 2),
    );
    if (video != null) {
      setState(() => _video = File(video.path));
    }
  }

  Future<void> _pickPhotos() async {
    if (!_canAddPhotos || _photos.length >= 5) return;
    final file = await _cameraService.pickImage(ImageSource.gallery);
    if (file != null) {
      setState(() => _photos.add(file.file));
    }
  }

  Future<void> _submit() async {
    setState(() => _isSending = true);

    try {
      final fields = <String, String>{
        'product_id': widget.item['id'].toString(),
        'rating': _rating.toString(),
        'pros': _prosController.text,
        'cons': _consController.text,
        'text': _textController.text,
      };

      if (_isEdit && widget.item['review_id'] != null) {
        fields['review_id'] = widget.item['review_id'].toString();
      }

      final photoPaths = _photos.map((f) => f.path).toList();
      final videoPath = _video?.path;

      final Result<Map<String, dynamic>> result;
      if (photoPaths.isNotEmpty || videoPath != null) {
        result = await ApiService.uploadMultipleFiles(
          '/api/reviews/save',
          filePaths: photoPaths,
          additionalFields: fields,
          videoPath: videoPath,
        );
      } else {
        result = await ApiService.post('/api/reviews/save', fields);
      }

      if (result.isFailure) {
        AppLogger.warning(
          _logTag,
          'submit failed: ${result.errorOrNull?.message}',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result.errorOrNull?.userMessage ?? 'Ошибка отправки',
              ),
              backgroundColor: const Color(0xFFC62828),
            ),
          );
        }
        return;
      }

      final response = result.valueOrNull ?? const {};
      final data = response['data'];
      final bonusEarned =
          (data is Map ? data['bonus_earned'] : null) ?? 0;
      final message = (response['message'] as String?) ?? '';

      widget.onRated();

      if (!mounted) return;

      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEdit
                ? (message.isNotEmpty
                    ? message
                    : 'Отзыв отправлен на модерацию')
                : (bonusEarned > 0
                    ? 'Спасибо за отзыв! Начислено: $bonusEarned бонусов 🎁'
                    : 'Спасибо за отзыв! Отправлен на модерацию.'),
          ),
          backgroundColor: context.colors.brand,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e, st) {
      AppLogger.error(_logTag, 'submit unexpected error', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ошибка соединения'),
            backgroundColor: Color(0xFFC62828),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final item = widget.item;

    final existingPhotos = (_isEdit && item['existing_photos'] is List)
        ? List<String>.from(item['existing_photos'])
        : <String>[];
    final existingVideo = (_isEdit && item['existing_video'] is String)
        ? item['existing_video'] as String
        : null;

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.colors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
              decoration: BoxDecoration(
                color: context.colors.surface,
                border: Border(
                  bottom: BorderSide(color: context.colors.border),
                ),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(
                      imageUrl: _imageUrl(item['main_image'] as String?),
                      width: 52,
                      height: 70,
                      fit: BoxFit.cover,
                      placeholder: (_, _) =>
                          Container(color: context.colors.surfaceAlt),
                      errorWidget: (_, _, _) =>
                          Container(color: context.colors.surfaceAlt),
                    ),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['brand'] ?? 'Без бренда',
                          style: TextStyle(
                            fontSize: 14,
                            color: context.colors.textMuted,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          item['name'] ?? '',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: context.colors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          _isEdit
                              ? 'Редактирование отзыва'
                              : 'Получен: ${(item['order_date'] ?? '').toString().length >= 10 ? item['order_date'].toString().substring(0, 10) : 'Офлайн-покупка'}',
                          style: TextStyle(
                            fontSize: 13,
                            color: context.colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(20, 24, 20, 24),
                children: [
                  Center(
                    child: Text(
                      _isEdit ? 'Измените ваш отзыв' : 'Ваша оценка',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textPrimary,
                      ),
                    ),
                  ),
                  SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      5,
                      (i) => GestureDetector(
                        onTap: () => setState(() => _rating = i + 1),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            Icons.star,
                            size: 48,
                            color: i < _rating
                                ? context.colors.warning
                                : context.colors.border,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  Center(
                    child: Text(
                      [
                        'Всё очень плохо',
                        'Плюсов почти нет',
                        'Могло быть и лучше',
                        'Хороший товар',
                        'Всё здорово',
                      ][_rating - 1],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: context.colors.textPrimary,
                      ),
                    ),
                  ),
                  SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Что понравилось',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: context.colors.textPrimary,
                          ),
                        ),
                      ),
                      if (_getCommentBonus() > 0)
                        _buildBonusBadge(
                          bonus: _getCommentBonus(),
                          isActive: _hasMinText,
                        ),
                    ],
                  ),
                  if (_getCommentBonus() > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      _hasMinText
                          ? 'Бонус активирован! 🎉'
                          : 'Осталось $_charsRemaining символов для бонуса',
                      style: TextStyle(
                        fontSize: 12,
                        color: _hasMinText
                            ? const Color(0xFF2e7d32)
                            : context.colors.textMuted,
                        fontWeight:
                            _hasMinText ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                  SizedBox(height: 8),
                  _buildTextField(
                    _prosController,
                    'Что понравилось',
                    maxLines: 3,
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Что не так',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 8),
                  _buildTextField(_consController, 'Что не так', maxLines: 3),
                  SizedBox(height: 20),
                  Text(
                    'Комментарий',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildTextField(
                    _textController,
                    'Комментарий',
                    maxLines: 4,
                  ),
                  _buildCharCounter(_textController),
                  const SizedBox(height: 28),
                  _buildMediaSection(
                    title: 'Загрузите до 5 фото',
                    icon: Icons.photo_library,
                    isVideo: false,
                    onTap: _pickPhotos,
                    bonus: _getPhotoBonus(),
                    isActive: _canAddPhotos,
                    hasFiles: _photos.isNotEmpty || existingPhotos.isNotEmpty,
                    existingPhotos: existingPhotos,
                  ),
                  if (!_hasMinText) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        'Напишите минимум 40 символов, чтобы прикрепить фото',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.colors.textMuted,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  _buildMediaSection(
                    title: 'Загрузите видео до 2 минут',
                    icon: Icons.videocam,
                    isVideo: true,
                    onTap: _pickVideo,
                    bonus: _getVideoBonus(),
                    isActive: _canAddVideo,
                    hasFiles: _video != null || existingVideo != null,
                    existingVideo: existingVideo,
                  ),
                  if (_isEdit) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        'После редактирования отзыв снова уйдет на модерацию',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[700],
                        ),
                      ),
                    ),
                  ],
                  SizedBox(height: 16),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                bottomPadding > 0 ? bottomPadding + 8 : 16,
              ),
              decoration: BoxDecoration(
                color: context.colors.surface,
                border: Border(top: BorderSide(color: context.colors.border)),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: _isSending
                      ? null
                      : LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [context.colors.brand, context.colors.brandDark],
                        ),
                  color: _isSending ? context.colors.textDisabled : null,
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: _isSending ? null : _submit,
                    borderRadius: BorderRadius.circular(14),
                    splashColor: Colors.white.withValues(alpha: 0.2),
                    highlightColor: Colors.white.withValues(alpha: 0.1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      child: Center(
                        child: _isSending
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  _isEdit
                                      ? 'Сохранить изменения'
                                      : 'Отправить на проверку',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBonusBadge({required int bonus, required bool isActive}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? context.colors.brandLight : context.colors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? context.colors.brand.withValues(alpha: 0.3)
              : context.colors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/icons/bonus-logo.svg',
            width: 14,
            height: 14,
            placeholderBuilder: (context) =>
                Text('🎁', style: TextStyle(fontSize: 12)),
          ),
          SizedBox(width: 4),
          Text(
            '+$bonus бонусов',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isActive
                  ? context.colors.brand
                  : context.colors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaSection({
    required String title,
    required IconData icon,
    required bool isVideo,
    required VoidCallback onTap,
    required int bonus,
    required bool isActive,
    required bool hasFiles,
    List<String>? existingPhotos,
    String? existingVideo,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textPrimary,
                ),
              ),
            ),
            if (bonus > 0)
              _buildBonusBadge(bonus: bonus, isActive: hasFiles),
          ],
        ),
        SizedBox(height: 14),
        GestureDetector(
          onTap: isActive ? onTap : null,
          child: Opacity(
            opacity: isActive ? 1.0 : 0.5,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: isActive
                    ? context.colors.surfaceAlt
                    : context.colors.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: hasFiles
                      ? context.colors.brand
                      : (isActive
                          ? context.colors.border
                          : context.colors.border),
                ),
              ),
              child: Column(
                children: [
                  if (hasFiles)
                    Column(
                      children: [
                        if (isVideo)
                          Container(
                            width: double.infinity,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.play_circle,
                                size: 48,
                                color: context.colors.brand,
                              ),
                            ),
                          )
                        else
                          SizedBox(
                            height: 120,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              shrinkWrap: true,
                              itemCount: (existingPhotos?.length ?? 0) +
                                  _photos.length +
                                  (_photos.length < 5 ? 1 : 0),
                              itemBuilder: (context, index) {
                                final totalExisting =
                                    existingPhotos?.length ?? 0;

                                if (index < totalExisting) {
                                  return Container(
                                    width: 80,
                                    height: 120,
                                    margin: const EdgeInsets.only(left: 8),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      image: DecorationImage(
                                        image: CachedNetworkImageProvider(
                                          _imageUrl(existingPhotos![index]),
                                        ),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  );
                                }

                                final newIndex = index - totalExisting;
                                if (newIndex >= _photos.length) {
                                  return GestureDetector(
                                    onTap: onTap,
                                    child: Container(
                                      width: 80,
                                      height: 120,
                                      margin:
                                          EdgeInsets.only(left: 8),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: context.colors.border,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: Center(
                                        child: Icon(
                                          Icons.add,
                                          color: context.colors.textMuted,
                                        ),
                                      ),
                                    ),
                                  );
                                }

                                return Container(
                                  width: 80,
                                  height: 120,
                                  margin: const EdgeInsets.only(left: 8),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    image: DecorationImage(
                                      image: FileImage(_photos[newIndex]),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        SizedBox(height: 12),
                        Text(
                          _isEdit
                              ? 'Нажмите, чтобы добавить ещё'
                              : 'Нажмите, чтобы изменить',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: context.colors.textPrimary,
                          ),
                        ),
                      ],
                    )
                  else ...[
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: context.colors.surfaceAlt,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        size: 28,
                        color: isActive
                            ? context.colors.textMuted
                            : context.colors.textDisabled,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      isActive ? 'Нажмите, чтобы загрузить' : 'Недоступно',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isActive
                            ? context.colors.textPrimary
                            : context.colors.textMuted,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      isActive
                          ? 'или перетащите файл сюда'
                          : 'Сначала напишите текст',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.colors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    int maxLines = 2,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.border, width: 1),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        onChanged: (_) => setState(() {}),
        style: TextStyle(fontSize: 16, color: context.colors.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: context.colors.textDisabled),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildCharCounter(TextEditingController controller) {
    return Padding(
      padding: EdgeInsets.only(top: 6),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          '${controller.text.length} / 500',
          style: TextStyle(fontSize: 12, color: context.colors.textMuted),
        ),
      ),
    );
  }
}