/// `retry` de los notifiers que cargan de un repositorio y lanzan su
/// `Failure` tipado: un fallo de la BD local no es transitorio, así que se
/// muestra con su botón de reintentar en vez de reintentarlo en segundo
/// plano (y dejar la pantalla cargando mientras tanto).
Duration? noAutomaticRetry(int retryCount, Object error) => null;
