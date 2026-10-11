import 'package:flutter/material.dart';

import '../downloads/presentation/downloads_screen.dart';
import '../player/presentation/mini_player.dart';
import '../playlists/presentation/playlists_screen.dart';
import '../search/presentation/search_screen.dart';

/// Estructura principal: 3 pestañas + mini-reproductor fijo abajo.
/// En pantallas anchas (tablet, horizontal) la navegación pasa a un
/// NavigationRail lateral.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  /// Cada pestaña tiene su propio Navigator: abrir una playlist no tapa
  /// la barra de navegación ni el mini-reproductor.
  final _navigatorKeys = List.generate(3, (_) => GlobalKey<NavigatorState>());

  static const _destinations = [
    (Icons.search_rounded, Icons.search_rounded, 'Buscar'),
    (Icons.queue_music_outlined, Icons.queue_music_rounded, 'Playlists'),
    (
      Icons.download_for_offline_outlined,
      Icons.download_for_offline_rounded,
      'Descargas',
    ),
  ];

  Widget _root(int i) => switch (i) {
    0 => const SearchScreen(),
    1 => const PlaylistsScreen(),
    _ => const DownloadsScreen(),
  };

  void _select(int i) {
    if (i == _tab) {
      // Tocar la pestaña activa vuelve a su pantalla principal.
      _navigatorKeys[i].currentState?.popUntil((r) => r.isFirst);
    } else {
      setState(() => _tab = i);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;

    final pages = IndexedStack(
      index: _tab,
      children: [
        for (var i = 0; i < 3; i++)
          Navigator(
            key: _navigatorKeys[i],
            onGenerateRoute: (_) =>
                MaterialPageRoute<void>(builder: (_) => _root(i)),
          ),
      ],
    );

    return PopScope(
      // El botón atrás de Android cierra primero las pantallas de la pestaña.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final nav = _navigatorKeys[_tab].currentState;
        if (nav != null && nav.canPop()) {
          nav.pop();
        } else if (_tab != 0) {
          setState(() => _tab = 0);
        } else {
          Navigator.of(context).maybePop();
        }
      },
      child: Scaffold(
        body: wide
            ? Row(
                children: [
                  NavigationRail(
                    selectedIndex: _tab,
                    onDestinationSelected: _select,
                    labelType: NavigationRailLabelType.all,
                    destinations: [
                      for (final (icon, selected, label) in _destinations)
                        NavigationRailDestination(
                          icon: Icon(icon),
                          selectedIcon: Icon(selected),
                          label: Text(label),
                        ),
                    ],
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(child: pages),
                        const MiniPlayer(),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  Expanded(child: pages),
                  const MiniPlayer(),
                ],
              ),
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: _tab,
                onDestinationSelected: _select,
                destinations: [
                  for (final (icon, selected, label) in _destinations)
                    NavigationDestination(
                      icon: Icon(icon),
                      selectedIcon: Icon(selected),
                      label: label,
                    ),
                ],
              ),
      ),
    );
  }
}
