/// Raíz de composición: todos los providers de infraestructura (DAOs,
/// repositorios, servicios) y de casos de uso. Vive fuera de `core` y de
/// `features` para que ninguna capa interna dependa del cableado.
library;

export 'data_providers.dart';
export 'service_providers.dart';
export 'use_case_providers.dart';
