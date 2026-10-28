// lib/screens/checkout/payment_webview_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../../services/app_review_service.dart';
import '../../widgets/network_error_banner.dart';
import '../../core/app_colors.dart';
import '../../widgets/common/cancel_payment_dialog.dart';

class PaymentWebViewScreen extends StatefulWidget {
  final String paymentUrl;
  final int orderId;
  final String? authToken;
  final String baseUrl;

  const PaymentWebViewScreen({
    super.key,
    required this.paymentUrl,
    required this.orderId,
    this.authToken,
    this.baseUrl = 'https://xn--80abvyjk6cts.xn--p1ai',
  });

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  InAppWebViewController? _controller;
  ChromeSafariBrowser? _safariBrowser;
  bool _isLoading = true;
  bool _paymentCompleted = false;
  bool _isOpeningBankApp = false;
  bool _waitingForBankReturn = false;
  bool _useSafariBrowser = false;
  bool _safariOpened = false;
  bool _disposed = false;
  bool _networkErrorShown = false;
  Timer? _statusCheckTimer;
  int _statusCheckAttempts = 0;
  static const int _maxStatusChecks = 15;
  static const Duration _statusCheckInterval = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();

    if (widget.paymentUrl.contains('podeli') ||
        widget.paymentUrl.contains('yandex-pay')) {
      _useSafariBrowser = true;
      _startStatusCheck(); // Запускаем polling статуса
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && !_disposed) _openInSafari();
      });
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _statusCheckTimer?.cancel();
    // 🔥 Уничтожаем нативный WKWebView (иначе recreating_view на iOS)
    final c = _controller;
    _controller = null;
    c?.dispose();
    // _safeCloseBrowser() не вызываем — Safari-шторка уже закрыта
    super.dispose();
  }

  bool _isBankDeepLink(String url) {
    if (url.contains('qr.nspk.ru')) return true;
    if (url.contains('sbp.nspk.ru')) return true;

    final bankSchemes = [
      'sberbank://',
      'sbp://',
      'tbanksbp://',
      'tinkoffbank://',
      'openbank://',
      'vtb://',
      'alfa://',
      'raiffeisen://',
      'gazprombank://',
      'psb://',
      'rshb://',
      'mirpay://',
    ];

    for (final scheme in bankSchemes) {
      if (url.startsWith(scheme)) return true;
    }

    if (url.contains('://') && url.toLowerCase().contains('bank')) {
      final scheme = url.split('://').first;
      if (scheme != 'http' && scheme != 'https') return true;
    }

    return false;
  }

  /// 🔥 Вызывает наш попап NetworkErrorBanner
  void _showNetworkError() {
    if (_networkErrorShown || _disposed || !mounted) return;
    _networkErrorShown = true;

    NetworkErrorBanner.show(
      context,
      isBlocking: true,
      onRetry: () {
        _networkErrorShown = false;
        // Перезагружаем страницу оплаты
        if (_controller != null) {
          _controller!.loadUrl(
            urlRequest: URLRequest(url: WebUri(widget.paymentUrl)),
          );
        }
      },
    );

    // Сбрасываем флаг после закрытия
    Future.delayed(const Duration(seconds: 2), () {
      _networkErrorShown = false;
    });
  }

  Future<void> _openInSafari() async {
    if (_safariOpened || _disposed) return;
    _safariOpened = true;

    try {
      _safariBrowser = ChromeSafariBrowser();

      await _safariBrowser!.open(
        url: WebUri(widget.paymentUrl),
        settings: ChromeSafariBrowserSettings(
          toolbarBackgroundColor: Colors.white,
          preferredBarTintColor: context.colors.brand,
          preferredControlTintColor: context.colors.brand,
        ),
      );

      _safariOpened = false;
      await _checkOrderStatus();

      // 🔥 После закрытия Safari НЕ закрываем экран.
      // Polling (в _checkStatus) сам проверит статус и перекинет на ThankYouScreen,
      // если оплата прошла.
    } catch (e) {
      debugPrint('❌ Safari open error: $e');
      _safariOpened = false;
      if (mounted && !_disposed) {
        setState(() => _useSafariBrowser = false);
      }
    }
  }

  Future<void> _openExternalApp(String url) async {
    if (_isOpeningBankApp) return;
    _isOpeningBankApp = true;
    _waitingForBankReturn = true;
    _startStatusCheck();

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
    } finally {
      _isOpeningBankApp = false;
    }
  }

  void _startStatusCheck() {
    _statusCheckAttempts = 0;
    _statusCheckTimer?.cancel();
    _statusCheckTimer = Timer.periodic(_statusCheckInterval, (_) {
      _checkOrderStatus();
    });
    _checkOrderStatus();
  }

  void _stopStatusCheck() {
    _statusCheckTimer?.cancel();
    _statusCheckTimer = null;
    if (mounted && !_disposed) ScaffoldMessenger.of(context).clearSnackBars();
  }

  Future<void> _checkOrderStatus() async {
    if (_paymentCompleted || _disposed) {
      _stopStatusCheck();
      return;
    }
    if (_statusCheckAttempts >= _maxStatusChecks) {
      _stopStatusCheck();
      return;
    }
    _statusCheckAttempts++;

    try {
      // 🔥 Используем правильный endpoint для проверки статуса Яндекс Сплита
      final isYandexPay = widget.paymentUrl.contains('yandex-pay');
      final endpoint = isYandexPay
          ? '/api/payment/yandex-pay-check-status'
          : '/api/orders/status';

      final uri = Uri.parse('${widget.baseUrl}$endpoint').replace(
        queryParameters: {
          'order_id': widget.orderId.toString(),
          'token': widget.authToken ?? '',
        },
      );
      // 🔥 Передаем remember_token в заголовке Cookie для авторизации
      final headers = <String, String>{'Accept': 'application/json'};
      if (widget.authToken != null && widget.authToken!.isNotEmpty) {
        headers['Cookie'] = 'remember_token=${widget.authToken}';
      }

      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Наш API yandex-pay-check-status возвращает {"success": true, "status": "paid"}
        // а /api/orders/status может возвращать payment_status
        final paymentStatus = data['status'] ?? data['payment_status'] ?? '';
        final orderStatus = data['order_status'] ?? '';

        if (paymentStatus == 'paid' ||
            paymentStatus == 'completed' ||
            orderStatus == 'processing' ||
            orderStatus == 'completed') {
          _onPaymentConfirmed();
          return;
        }
        if (paymentStatus == 'failed' ||
            paymentStatus == 'cancelled' ||
            orderStatus == 'cancelled') {
          _onPaymentFailed();
          return;
        }
      }
    } catch (e) {
      // Используем print, чтобы лог точно появился в терминале
    }
  }

  void _onPaymentConfirmed() {
    if (_paymentCompleted || _disposed) return;
    _paymentCompleted = true;
    _waitingForBankReturn = false;
    _stopStatusCheck();

    try {} catch (_) {}

    _showReviewIfNeeded();

    if (mounted && !_disposed) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !_disposed) Navigator.of(context).pop(true);
      });
    }
  }

  void _onPaymentFailed() {
    if (_paymentCompleted || _disposed) return;
    _paymentCompleted = true;
    _waitingForBankReturn = false;
    _stopStatusCheck();

    try {} catch (_) {}

    if (mounted && !_disposed) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted && !_disposed) Navigator.of(context).pop(false);
      });
    }
  }

  Future<void> _showReviewIfNeeded() async {
    try {
      final shouldShow = await AppReviewService.shouldShowAfterOrder();
      if (shouldShow) {
        await AppReviewService.showReviewDialog();
      }
    } catch (_) {}
  }

  void _checkPaymentSuccess(String url) {
    if (_paymentCompleted) return;
    final isSuccess =
        url.contains('/thank-you') && url.contains('paid=1') ||
        url.contains('pay.modulbank.ru/success') ||
        url.contains('transaction_id=') && url.contains('success') ||
        url.contains('/profile/orders') && url.contains('paid=') ||
        url.contains('podeli-success') && url.contains('order_id=');
    if (isSuccess) {
      _paymentCompleted = true;
      _stopStatusCheck();

      _showReviewIfNeeded();

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && !_disposed) Navigator.of(context).pop(true);
      });
    }
  }

  void _showCancelDialog() {
    if (_disposed || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) =>
          CancelPaymentDialog(isWaitingForBank: _waitingForBankReturn),
    ).then((result) {
      if (!mounted) return;
      if (result == true) {
        // Пользователь нажал "Выйти"
        _stopStatusCheck();
        Navigator.pop(context, false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          if (!_paymentCompleted) _showCancelDialog();
        }
      },
      child: Scaffold(
        backgroundColor: context.colors.surfaceAlt,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(
            _waitingForBankReturn ? 'Оплата в банке...' : 'Оплата',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: context.colors.textPrimary,
            ),
          ),
          leading: IconButton(
            icon: Icon(Icons.close, color: context.colors.textPrimary),
            onPressed: () {
              if (!_paymentCompleted) _showCancelDialog();
            },
          ),
          backgroundColor: context.colors.surface,
          elevation: 0,
        ),
        body: Stack(
          children: [
            if (_useSafariBrowser || widget.paymentUrl.contains('yandex-pay'))
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: context.colors.brand,
                      strokeWidth: 3,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Открываем страницу оплаты...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Если окно не открылось, нажмите кнопку ниже',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.colors.textMuted,
                      ),
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _openInSafari,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.colors.brand,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Открыть страницу оплаты',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(widget.paymentUrl)),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  useShouldOverrideUrlLoading: true,
                  useOnDownloadStart: true,
                  supportZoom: false,
                  transparentBackground: true,
                  useHybridComposition: true,
                  javaScriptCanOpenWindowsAutomatically: false,
                  mediaPlaybackRequiresUserGesture: false,
                  allowsInlineMediaPlayback: true,
                ),
                onWebViewCreated: (controller) {
                  _controller = controller;
                },
                onLoadStart: (controller, url) {
                  if (!_isOpeningBankApp) setState(() => _isLoading = true);
                },
                onLoadStop: (controller, url) {
                  if (!_isOpeningBankApp) setState(() => _isLoading = false);
                  _checkPaymentSuccess(url?.toString() ?? '');
                },
                shouldOverrideUrlLoading: (controller, navigationAction) async {
                  final url = navigationAction.request.url?.toString() ?? '';
                  debugPrint('🌐 NAVIGATION REQUEST: $url');
                  _checkPaymentSuccess(url);
                  if (_isBankDeepLink(url) && !_isOpeningBankApp) {
                    _openExternalApp(url);
                    return NavigationActionPolicy.CANCEL;
                  }
                  return NavigationActionPolicy.ALLOW;
                },
                onReceivedError: (controller, request, error) {
                  // 🔥 Показываем наш попап при ошибке DNS
                  if (error.type == WebResourceErrorType.HOST_LOOKUP) {
                    _showNetworkError();
                  }
                },
                onReceivedServerTrustAuthRequest:
                    (controller, challenge) async {
                      return ServerTrustAuthResponse(
                        action: ServerTrustAuthResponseAction.PROCEED,
                      );
                    },
              ),
            if (_isLoading && !_useSafariBrowser && !_isOpeningBankApp)
              Center(
                child: CircularProgressIndicator(
                  color: context.colors.brand,
                  strokeWidth: 3,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
