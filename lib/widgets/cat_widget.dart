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
      if (file == null) return;
      final controller = rive.RiveWidgetController(file);
      final vmi = controller.dataBind(rive.AutoBind());
      if (mounted) {
        setState(() {
          _controller = controller;
          _tapTrigger = vmi.trigger('tap');
        });
      }
    } catch (_) {
      // ignore: avoid_print
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return SizedBox(width: widget.size, height: widget.size);
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
