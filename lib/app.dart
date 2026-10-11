import 'package:flutter/material.dart';

import 'features/home/home_shell.dart';

class SponifyApp extends StatelessWidget {
  const SponifyApp({super.key});

  static ThemeData _theme(Brightness brightness) => ThemeData(
    colorSchemeSeed: const Color(0xFF1DB954),
    brightness: brightness,
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Spoñify',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: const HomeShell(),
    );
  }
}
