import 'package:flutter/material.dart';
import 'package:rive/rive.dart' as rive;

class CatWidget extends StatefulWidget {
  final double size;
  final VoidCallback? onTap;

  const CatWidget({super.key, this.size = 200, this.onTap});

  @override
  State<CatWidget> createState() => _CatWidgetState();
}

class _CatWidgetState extends State<CatWidget> {
  rive.RiveWidgetController? _controller;
  rive.ViewModelInstanceTrigger? _tapTrigger;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _initRive();
  }

  Future<void> _initRive() async {
    try {
      final file = await rive.File.asset(
        'assets/rive/cat.riv',
        riveFactory: rive.Factory.rive,
      );
      if (file == null) {
        if (mounted) setState(() => _error = 'file null');
        return;
      }
      final controller = rive.RiveWidgetController(file);
      final vmi = controller.dataBind(rive.AutoBind());
      if (mounted) {
        setState(() {
          _controller = controller;
          _tapTrigger = vmi.trigger('tap');
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'err: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ДИАГНОСТИКА: если ошибка — показываем красный текст
    if (_error.isNotEmpty) {
      return Container(
        width: widget.size,
        height: widget.size,
        color: Colors.yellow,
        child: Center(
          child: Text(
            _error,
            style: const TextStyle(fontSize: 10, color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_controller == null) {
      // ДИАГНОСТИКА: если контроллер ещё не готов — показываем серый квадрат
      return Container(
        width: widget.size,
        height: widget.size,
        color: Colors.grey.withValues(alpha: 0.3),
        child: const Center(
          child: Text('loading', style: TextStyle(fontSize: 10)),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        _tapTrigger?.trigger();
        widget.onTap?.call();
      },
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: rive.RiveWidget(
          controller: _controller!,
          fit: rive.Fit.contain,
        ),
      ),
    );
  }
}
