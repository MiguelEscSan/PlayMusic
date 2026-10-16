import 'package:flutter/material.dart';

import '../../core/error/failure.dart';

/// Error al cargar una pantalla o sección, con botón para reintentar.
///
/// Si [error] es un [Failure] muestra su mensaje como detalle; cualquier
/// otro error se queda con el texto genérico.
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.error,
    this.title = 'No se pudo cargar',
    this.onRetry,
  });

  final Object error;
  final String title;

  /// Normalmente invalida el provider que falló.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detail = switch (error) {
      Failure(:final message) => message,
      _ => null,
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (detail != null) ...[
              const SizedBox(height: 8),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
