# Koda 🎵 - Flutter Audio Architecture PoC

> **⚠️ Disclaimer Legal:** Este proyecto ha sido creado con fines estrictamente educativos y como una prueba de concepto (Proof of Concept) de arquitectura de software avanzada en Flutter. No está diseñado para su distribución comercial, no fomenta la piratería y utiliza APIs públicas y librerías de terceros (como `youtube_explode_dart`) únicamente como fuente de datos masiva para probar el estrés y la viabilidad de la arquitectura. **No se proveen binarios compilados (APK/AAB).**

Koda es una aplicación de reproducción de audio híbrida (Streaming + Offline) construida para demostrar la implementación de **Clean Architecture**, **gestión de estado reactiva** y **manejo complejo de audio en segundo plano** en Flutter.

## 🚀 Sobre el Proyecto

El objetivo principal de este proyecto es resolver problemas arquitectónicos comunes en aplicaciones multimedia complejas, tales como:
- Mantener sincronizada la interfaz de usuario con un motor de audio en segundo plano.
- Gestionar una fuente de verdad única entre una base de datos local (SQLite) y un estado reactivo (Riverpod).
- Interceptar y resolver dinámicamente el origen de un archivo multimedia (decidir en milisegundos si reproducir desde caché local o pedir una URL temporal por streaming).

## 🛠️ Stack Tecnológico

- **Framework:** Flutter / Dart
- **Gestión de Estado:** Riverpod (`flutter_riverpod`)
- **Arquitectura:** Clean Architecture estructurada por funcionalidades (*Feature-first*)
- **Base de Datos:** SQLite (`sqflite`)
- **Motor de Audio:** `just_audio` + `audio_service` (OS Media Controls)
- **Networking & Descargas:** `dio` (Chunked downloads)

## 🏗️ Arquitectura y Diseño

El proyecto sigue un enfoque **Feature-first** con separación de capas internas para garantizar la escalabilidad y la testabilidad:

```text
lib/
├── core/             # Base de datos, clientes HTTP, utilidades y modelos de dominio compartidos.
├── features/         # Módulos independientes (Home, Player, Playlists, Downloads, Search).
│   └── [feature]/
│       ├── domain/   # Entidades puras y Casos de Uso.
│       ├── data/     # Repositorios, DAOs y Data Sources (APIs).
│       └── presentation/ # Widgets tontos y Notifiers (Riverpod).
└── shared/           #
