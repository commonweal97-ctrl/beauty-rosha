// lib/screens/product/product_questions_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/app_logger.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/scroll_to_top_button.dart';
import '../auth/login_screen.dart';
import '../main_shell.dart';
import '../../core/app_colors.dart';

class ProductQuestionsScreen extends StatefulWidget {
  final int productId;
  final String productName;
  final int initialQuestionCount;

  const ProductQuestionsScreen({
    super.key,
    required this.productId,
    required this.productName,
    this.initialQuestionCount = 0,
  });

  @override
  State<ProductQuestionsScreen> createState() =>
      _ProductQuestionsScreenState();
}

class _ProductQuestionsScreenState extends State<ProductQuestionsScreen> {
  static const _logTag = 'ProductQuestionsScreen';

  List<Map<String, dynamic>> _questions = [];
  bool _isLoading = false;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadQuestions();
    _scrollController.addListener(_onScroll);
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              Theme.of(context).brightness == Brightness.dark
                  ? Brightness.light
                  : Brightness.dark,
          statusBarBrightness:
              Theme.of(context).brightness == Brightness.dark
                  ? Brightness.dark
                  : Brightness.light,
        ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadQuestions();
    }
  }

  String _formatUserName(String? fullName) {
    if (fullName == null || fullName.isEmpty) return 'Пользователь';

    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'Пользователь';

    return parts[0];
  }

  Future<void> _loadQuestions({bool refresh = false}) async {
    if (_isLoading) return;
    if (!_hasMore && !refresh) return;

    if (refresh) {
      _hasMore = true;
      _questions = [];
    }

    setState(() => _isLoading = true);

    final result = await ApiService.get(
      '/api/questions/product',
      queryParams: {'product_id': widget.productId.toString()},
    );

    if (!mounted) return;

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'loadQuestions failed: ${result.errorOrNull?.message}',
      );
      setState(() {
        _questions = [];
        _hasMore = false;
        _isLoading = false;
      });
      return;
    }

    final data = result.valueOrNull?['data'];
    if (data is! Map) {
      setState(() {
        _questions = [];
        _hasMore = false;
        _isLoading = false;
      });
      return;
    }

    final itemsRaw = data['questions'];
    final items = itemsRaw is List
        ? itemsRaw
            .whereType<Map>()
            .map((q) => Map<String, dynamic>.from(q))
            .toList()
        : <Map<String, dynamic>>[];

    setState(() {
      _questions = items;
      _hasMore = false;
      _isLoading = false;
    });
  }

  String _pluralQuestions(int n) {
    final m10 = n % 10, m100 = n % 100;
    if (m10 == 1 && m100 != 11) return 'вопрос';
    if ([2, 3, 4].contains(m10) && ![12, 13, 14].contains(m100)) {
      return 'вопроса';
    }
    return 'вопросов';
  }

  void _showAskQuestionDialog() {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      MainShell.push(context, const LoginScreen());
      return;
    }

    final TextEditingController controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (ctx) {
        /// 🔥 Берём viewInsets из внешнего MediaQuery, чтобы клавиатура
        /// корректно поднимала шторку и не перекрывала поле ввода.
        final viewInsets = MediaQuery.viewInsetsOf(context);

        return AnimatedPadding(
          duration: Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Задать вопрос',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 4),
                    Text(
                      widget.productName,
                      style: TextStyle(
                        fontSize: 14,
                        color: context.colors.textMuted,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: controller,
                      maxLines: 5,
                      minLines: 3,
                      autofocus: true,
                      textInputAction: TextInputAction.newline,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Введите вопрос';
                        }
                        if (value.trim().length < 10) {
                          return 'Вопрос должен быть не короче 10 символов';
                        }
                        return null;
                      },
                      decoration: InputDecoration(
                        hintText: 'Напишите ваш вопрос о товаре...',
                        hintStyle: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 15,
                        ),
                        filled: true,
                        fillColor: context.colors.surfaceAlt,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.all(16),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;

                        final result = await ApiService.post(
                          '/api/questions/ask',
                          {
                            'product_id': widget.productId,
                            'question': controller.text.trim(),
                          },
                        );

                        if (!ctx.mounted) return;

                        if (result.isFailure) {
                          AppLogger.warning(
                            _logTag,
                            'ask question failed: '
                                '${result.errorOrNull?.message}',
                          );
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text(
                                  result.errorOrNull?.userMessage ?? 'Ошибка',
                                ),
                                backgroundColor: ctx.colors.error,
                              ),
                            );
                          }
                          return;
                        }

                        Navigator.pop(ctx);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Вопрос отправлен!'),
                            backgroundColor: context.colors.success,
                          ),
                        );
                        _loadQuestions(refresh: true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.colors.brand,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Отправить',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final questionCount = _questions.isNotEmpty
        ? _questions.length
        : widget.initialQuestionCount;

    /// 🔥 AnnotatedRegion перебивает родительский экран и гарантирует,
    /// что иконки статус-бара будут тёмными на светлом фоне.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness:
            isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor:
            isDark ? Color(0xFF1E1E1E) : Colors.white,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: context.colors.background,
        body: Stack(
          children: [
            Positioned.fill(
              child: Column(
                children: [
                  SizedBox(height: topPadding + 100),
                  Expanded(
                    child: _isLoading && _questions.isEmpty
                        ? Center(
                            child: CircularProgressIndicator(
                              color: context.colors.brand,
                            ),
                          )
                        : _questions.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.question_answer_outlined,
                                      size: 64,
                                      color: Colors.grey[300],
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'Вопросов пока нет',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: context.colors.textMuted,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Будьте первым, кто задаст вопрос',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: context.colors.textDisabled,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.fromLTRB(
                                  0,
                                  20,
                                  0,
                                  100,
                                ),
                                itemCount:
                                    _questions.length + (_hasMore ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index >= _questions.length) {
                                    _loadQuestions();
                                    return Padding(
                                      padding: EdgeInsets.all(20),
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          color: context.colors.brand,
                                        ),
                                      ),
                                    );
                                  }

                                  final q = _questions[index];
                                  final hasAnswer = q['answer'] != null &&
                                      q['answer'].toString().isNotEmpty;
                                  final userName = _formatUserName(
                                    q['user_name']?.toString(),
                                  );

                                  return Container(
                                    margin: EdgeInsets.fromLTRB(
                                      16,
                                      0,
                                      16,
                                      8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: context.colors.surface,
                                      borderRadius:
                                          BorderRadius.circular(16),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                width: 32,
                                                height: 32,
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFF5F5F5,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                    8,
                                                  ),
                                                ),
                                                child: Icon(
                                                  Icons.person_outline,
                                                  size: 18,
                                                  color:
                                                      context.colors.textMuted,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .start,
                                                  children: [
                                                    Text(
                                                      userName,
                                                      style:
                                                          const TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Color(
                                                          0xFF1A1A1A,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                      height: 2,
                                                    ),
                                                    Text(
                                                      q['created_at'] ?? '',
                                                      style:
                                                          const TextStyle(
                                                        fontSize: 11,
                                                        color: Color(
                                                          0xFF999999,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                      height: 8,
                                                    ),
                                                    Text(
                                                      q['question'] ??
                                                          q['text'] ??
                                                          '',
                                                      style:
                                                          const TextStyle(
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: Color(
                                                          0xFF1A1A1A,
                                                        ),
                                                        height: 1.4,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (hasAnswer) ...[
                                            const SizedBox(height: 12),
                                            Container(
                                              width: double.infinity,
                                              padding:
                                                  const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: const Color(
                                                  0xFFF8F9FA,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                  12,
                                                ),
                                              ),
                                              child: Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment
                                                        .start,
                                                children: [
                                                  Container(
                                                    width: 32,
                                                    height: 32,
                                                    decoration:
                                                        BoxDecoration(
                                                      color: const Color(
                                                        0xFFDD1847,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius
                                                              .circular(6),
                                                      image:
                                                          const DecorationImage(
                                                        image: AssetImage(
                                                          'assets/images/logo.png',
                                                        ),
                                                        fit: BoxFit.cover,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        const Text(
                                                          'Б•Роща',
                                                          style: TextStyle(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w700,
                                                            color: Color(
                                                              0xFFDD1847,
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          height: 4,
                                                        ),
                                                        Text(
                                                          q['answer'] ?? '',
                                                          style:
                                                              const TextStyle(
                                                            fontSize: 14,
                                                            color: Color(
                                                              0xFF555555,
                                                            ),
                                                            height: 1.4,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
                child: Container(
                  color: context.colors.surface,
                  child: Padding(
                    padding: EdgeInsets.only(top: topPadding, bottom: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            SizedBox(width: 8),
                            IconButton(
                              icon: Icon(
                                Icons.arrow_back,
                                color: context.colors.error,
                                size: 22,
                              ),
                              onPressed: () => Navigator.pop(context),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 40,
                                minHeight: 40,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Вопросы о товаре',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: context.colors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 48),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '$questionCount '
                                '${_pluralQuestions(questionCount)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: context.colors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              GestureDetector(
                                onTap: _showAskQuestionDialog,
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.colors.brand,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.edit,
                                        size: 14,
                                        color: context.colors.surface,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Задать вопрос',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: context.colors.surface,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: bottomPadding + 20,
              right: 40,
              child:
                  ScrollToTopButton(scrollController: _scrollController),
            ),
          ],
        ),
      ),
    );
  }
}