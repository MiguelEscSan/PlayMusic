import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/domain/entities/song.dart';

/// Carrusel para cambiar de canción deslizando, como en Spotify: la
/// canción actual sigue al dedo y por el borde asoma la vecina (la
/// siguiente al ir a la izquierda, la anterior al ir a la derecha). Al
/// soltar, si se superó la distancia o la velocidad mínima, la vecina se
/// queda en el centro y se avisa con [onNext] u [onPrevious]; si no, todo
/// vuelve a su sitio. Sin vecina en ese sentido, solo cede un poco.
///
/// Solo escucha gestos horizontales: los toques y los arrastres
/// verticales siguen llegando a quien esté por encima o por debajo.
class SwipeToSkip extends StatefulWidget {
  const SwipeToSkip({
    super.key,
    required this.current,
    required this.itemBuilder,
    required this.onNext,
    required this.onPrevious,
    this.next,
    this.previous,
  });

  final Song current;
  final Song? next;
  final Song? previous;

  /// Pinta una canción; se usa para la actual y para las vecinas.
  final Widget Function(BuildContext context, Song song) itemBuilder;

  final VoidCallback onNext;
  final VoidCallback onPrevious;

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

  /// Cuánto se espera a que el reproductor confirme el cambio antes de
  /// volver a mostrar la canción que diga él.
  static const _pendingTimeout = Duration(seconds: 2);

  late final AnimationController _offset = AnimationController.unbounded(
    vsync: this,
  );
  double _width = 1;
  bool _committing = false;

  /// Canción a la que se acaba de deslizar mientras el reproductor aún no
  /// la ha cargado; se muestra en el centro para que no parpadee la vieja.
  Song? _pending;
  Timer? _pendingTimer;

  bool get _busy => _committing || _pending != null;

  @override
  void didUpdateWidget(SwipeToSkip oldWidget) {
    super.didUpdateWidget(oldWidget);
    final pending = _pending;
    if (pending != null &&
        (widget.current.id == pending.id ||
            widget.current.id != oldWidget.current.id)) {
      _clearPending();
    }
  }

  @override
  void dispose() {
    _pendingTimer?.cancel();
    _offset.dispose();
    super.dispose();
  }

  void _clearPending() {
    _pendingTimer?.cancel();
    _pendingTimer = null;
    _pending = null;
  }

  void _onStart(DragStartDetails details) {
    if (_busy) return;
    _offset.stop();
  }

  void _onUpdate(DragUpdateDetails details) {
    if (_busy) return;
    final delta = details.primaryDelta ?? 0;
    final next = _offset.value + delta;
    final neighbour = next < 0 ? widget.next : widget.previous;
    _offset.value += neighbour != null ? delta : delta * _resistance;
  }

  void _onEnd(DragEndDetails details) {
    if (_busy) return;
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

    final next = widget.next;
    final previous = widget.previous;
    if (direction < 0 && next != null) {
      _commit(-1, next, widget.onNext);
    } else if (direction > 0 && previous != null) {
      _commit(1, previous, widget.onPrevious);
    } else {
      _snapBack();
    }
  }

  void _snapBack() {
    if (_busy) return;
    _offset.animateTo(
      0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  /// Termina de deslizar hasta que la vecina queda en el centro, la deja
  /// ahí mientras el reproductor cambia de canción y entonces avisa.
  Future<void> _commit(double direction, Song target, VoidCallback skip) async {
    _committing = true;
    try {
      await _offset.animateTo(
        direction * _width,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      );
      if (!mounted) return;
      setState(() {
        _pending = target;
        _pendingTimer = Timer(_pendingTimeout, () {
          if (mounted) setState(_clearPending);
        });
      });
      _offset.value = 0;
      skip();
    } finally {
      _committing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _width = constraints.maxWidth.isFinite ? constraints.maxWidth : 1;
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragStart: _onStart,
          onHorizontalDragUpdate: _onUpdate,
          onHorizontalDragEnd: _onEnd,
          onHorizontalDragCancel: _snapBack,
          child: ClipRect(
            child: AnimatedBuilder(
              animation: _offset,
              builder: (context, _) => _buildCarousel(context),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCarousel(BuildContext context) {
    final dx = _offset.value;
    final center = _pending ?? widget.current;
    final neighbour = _pending != null
        ? null
        : dx < 0
        ? widget.next
        : dx > 0
        ? widget.previous
        : null;

    return Stack(
      children: [
        Transform.translate(
          offset: Offset(dx, 0),
          child: SizedBox(
            width: double.infinity,
            child: KeyedSubtree(
              key: ValueKey('current-${center.id}'),
              child: widget.itemBuilder(context, center),
            ),
          ),
        ),
        if (neighbour != null)
          Positioned.fill(
            child: Transform.translate(
              offset: Offset(dx < 0 ? dx + _width : dx - _width, 0),
              child: KeyedSubtree(
                key: ValueKey('neighbour-${neighbour.id}'),
                child: widget.itemBuilder(context, neighbour),
              ),
            ),
          ),
      ],
    );
  }
}
