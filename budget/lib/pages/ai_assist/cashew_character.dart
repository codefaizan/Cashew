import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Cashew mascot — static avatar for chat, or idle bob/blink for empty state.
class CashewCharacter extends StatefulWidget {
  final double size;
  final bool animated;

  const CashewCharacter({
    super.key,
    this.size = 32,
    this.animated = false,
  });

  static const assetPath = 'assets/icons/fun/cashew-character.png';

  @override
  State<CashewCharacter> createState() => _CashewCharacterState();
}

class _CashewCharacterState extends State<CashewCharacter>
    with TickerProviderStateMixin {
  AnimationController? _idleController;
  AnimationController? _blinkController;

  @override
  void initState() {
    super.initState();
    if (widget.animated) _startAnimations();
  }

  @override
  void didUpdateWidget(CashewCharacter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animated && !oldWidget.animated) {
      _startAnimations();
    } else if (!widget.animated && oldWidget.animated) {
      _stopAnimations();
    }
  }

  void _startAnimations() {
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();

    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
    _scheduleBlink();
  }

  void _stopAnimations() {
    _idleController?.dispose();
    _blinkController?.dispose();
    _idleController = null;
    _blinkController = null;
  }

  Future<void> _scheduleBlink() async {
    while (mounted && widget.animated && _blinkController != null) {
      final delayMs = 2800 + math.Random().nextInt(2200);
      await Future.delayed(Duration(milliseconds: delayMs));
      if (!mounted || _blinkController == null || !widget.animated) return;
      await _blinkController!.forward();
      if (!mounted || _blinkController == null) return;
      await _blinkController!.reverse();
    }
  }

  @override
  void dispose() {
    _stopAnimations();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      CashewCharacter.assetPath,
      width: widget.size,
      height: widget.size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );

    if (!widget.animated ||
        _idleController == null ||
        _blinkController == null) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: image,
      );
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_idleController!, _blinkController!]),
      builder: (context, child) {
        final t = _idleController!.value * 2 * math.pi;
        final bob = math.sin(t) * (widget.size * 0.035);
        final sway = math.sin(t * 0.85) * 0.035; // ~2°
        final blink = _blinkController!.value;

        return Transform.translate(
          offset: Offset(0, bob),
          child: Transform.rotate(
            angle: sway,
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  child!,
                  // Soft lids that cover the pupils during a blink.
                  // Fractions tuned to cashew-character.png face.
                  // Eye centers ~ (0.370, 0.425) and (0.503, 0.404) of the PNG.
                  _EyeLid(
                    size: widget.size,
                    centerX: 0.370,
                    centerY: 0.425,
                    blink: blink,
                  ),
                  _EyeLid(
                    size: widget.size,
                    centerX: 0.503,
                    centerY: 0.404,
                    blink: blink,
                  ),
                ],
              ),
            ),
          ),
        );
      },
      child: image,
    );
  }
}

class _EyeLid extends StatelessWidget {
  final double size;
  final double centerX;
  final double centerY;
  final double blink;

  const _EyeLid({
    required this.size,
    required this.centerX,
    required this.centerY,
    required this.blink,
  });

  @override
  Widget build(BuildContext context) {
    if (blink <= 0.01) return const SizedBox.shrink();

    final eyeSize = size * 0.10;
    return Positioned(
      left: size * centerX - eyeSize / 2,
      top: size * centerY - eyeSize / 2,
      child: Transform.scale(
        scaleY: blink.clamp(0.0, 1.0),
        child: Container(
          width: eyeSize,
          height: eyeSize,
          decoration: BoxDecoration(
            color: const Color(0xFFF3D9A8),
            borderRadius: BorderRadius.circular(eyeSize),
          ),
        ),
      ),
    );
  }
}
