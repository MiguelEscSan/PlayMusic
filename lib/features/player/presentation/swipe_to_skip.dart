import 'package:flutter/material.dart';

/// Cambia de canción deslizando en horizontal, como en Spotify: el
/// contenido sigue al dedo y, al soltar, pasa a la siguiente (izquierda) o
/// a la anterior (derecha) si se superó la distancia o la velocidad mínima.
/// Si no, o si no hay canción en ese sentido, vuelve a su sitio.
///
/// Solo escucha gestos horizontales, así que los toques y los arrastres
/// verticales siguen llegando a quien esté por encima o por debajo.
class SwipeToSkip extends StatefulWidget {
  const SwipeToSkip({
    super.key,
    required this.child,
    required this.onNext,
    required this.onPrevious,
    this.canSkipNext = true,
    this.canSkipPrevious = true,
  });

  final Widget child;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final bool canSkipNext;
  final bool canSkipPrevious;

  @override
  State<SwipeToSkip> createState() => _SwipeToSkipState();
}

class _SwipeToSkipState extends State<SwipeToSkip>
    with SingleTickerProviderStateMixin {
  /// Fracción del ancho que hay que arrastrar para cambiar de canción.
  static const _distanceFraction = 0.3;

  /// Velocidad (px/s) a partir de la cual un gesto rápido basta.
  static const _flingVelocity = 700.0;

  /// Freno al arrastrar hacia un lado sin canción: se mueve, pero poco.
  static const _resistance = 0.25;

  late final AnimationController _offset = AnimationController.unbounded(
    vsync: this,
  );
  double _width = 1;
  bool _committing = false;

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  void _onStart(DragStartDetails details) {
    if (_committing) return;
    _offset.stop();
    _width = context.size?.width ?? 1;
  }

  void _onUpdate(DragUpdateDetails details) {
    if (_committing) return;
    final delta = details.primaryDelta ?? 0;
    final next = _offset.value + delta;
    final allowed = next < 0 ? widget.canSkipNext : widget.canSkipPrevious;
    _offset.value += allowed ? delta : delta * _resistance;
  }

  void _onEnd(DragEndDetails details) {
    if (_committing) return;
    final dx = _offset.value;
    final velocity = details.primaryVelocity ?? 0;

    final double direction;
    if (velocity.abs() >= _flingVelocity) {
      direction = velocity.sign;
    } else if (dx.abs() >= _width * _distanceFraction) {
      direction = dx.sign;
    } else {
      direction = 0;
    }

    if (direction < 0 && widget.canSkipNext) {
      _commit(-1);
    } else if (direction > 0 && widget.canSkipPrevious) {
      _commit(1);
    } else {
      _snapBack();
    }
  }

  void _snapBack() {
    if (_committing) return;
    _offset.animateTo(
      0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  /// Saca el contenido por el lado del gesto, cambia de canción y hace
  /// entrar la nueva por el lado contrario.
  Future<void> _commit(double direction) async {
    _committing = true;
    try {
      await _offset.animateTo(
        direction * _width,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
      );
      if (!mounted) return;
      direction < 0 ? widget.onNext() : widget.onPrevious();
      _offset.value = -direction * _width;
      await _offset.animateTo(
        0,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    } finally {
      _committing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: _onStart,
      onHorizontalDragUpdate: _onUpdate,
      onHorizontalDragEnd: _onEnd,
      onHorizontalDragCancel: _snapBack,
      child: AnimatedBuilder(
        animation: _offset,
        builder: (context, child) {
          final progress = (_offset.value.abs() / _width).clamp(0.0, 1.0);
          return Transform.translate(
            offset: Offset(_offset.value, 0),
            child: Opacity(opacity: 1 - progress * 0.6, child: child),
          );
        },
        child: widget.child,
      ),
    );
  }
}
