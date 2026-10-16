import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../di/providers.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/song_tile.dart';
import 'search_controller.dart';
import 'search_history_providers.dart';
import 'search_suggestions_controller.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    // Paginación infinita: al acercarse al final se pide la siguiente página.
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 600) {
        ref.read(searchControllerProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// El usuario está escribiendo algo que aún no ha enviado.
  bool _editing = false;

  /// Busca [query] (enviada, reciente o sugerida) y la deja en el campo.
  void _submit(String query) {
    final q = query.trim();
    _text.text = q;
    _editing = false;
    ref.read(searchSuggestionsProvider.notifier).clear();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {});
    ref.read(searchControllerProvider.notifier).search(q);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchControllerProvider);
    final controller = ref.read(searchControllerProvider.notifier);
    final suggestions = ref.watch(searchSuggestionsProvider);
    final recents = ref.watch(recentSearchesProvider).value ?? const [];
    final typed = _text.text.trim();
    final showRecents = typed.isEmpty && recents.isNotEmpty;
    final showSuggestions =
        _editing && typed.isNotEmpty && suggestions.isNotEmpty;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          controller: _scroll,
          slivers: [
            SliverAppBar(
              floating: true,
              snap: true,
              toolbarHeight: 72,
              titleSpacing: 16,
              title: SearchBar(
                controller: _text,
                hintText: 'Canciones, artistas…',
                elevation: const WidgetStatePropertyAll(0),
                leading: const Icon(Icons.search_rounded),
                trailing: [
                  if (_text.text.isNotEmpty)
                    IconButton(
                      tooltip: 'Borrar',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _text.clear();
                        _editing = false;
                        ref.read(searchSuggestionsProvider.notifier).clear();
                        controller.search('');
                        setState(() {});
                      },
                    ),
                ],
                onChanged: (q) {
                  setState(() => _editing = true);
                  ref
                      .read(searchSuggestionsProvider.notifier)
                      .onQueryChanged(q);
                },
                onSubmitted: _submit,
              ),
            ),
            if (showRecents)
              ..._recentSlivers(context, recents)
            else if (showSuggestions)
              SliverList.builder(
                itemCount: suggestions.length,
                itemBuilder: (context, i) => ListTile(
                  leading: const Icon(Icons.search_rounded),
                  title: Text(suggestions[i]),
                  onTap: () => _submit(suggestions[i]),
                ),
              )
            else if (state.isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (state.error != null && state.results.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.wifi_off_rounded,
                  title: state.error!,
                  action: FilledButton.tonal(
                    onPressed: controller.retry,
                    child: const Text('Reintentar'),
                  ),
                ),
              )
            else if (state.query.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.library_music_rounded,
                  title: 'Busca cualquier canción',
                  message:
                      'Tócala para escucharla al instante o descárgala '
                      'para oírla sin conexión.',
                ),
              )
            else if (state.results.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'Sin resultados para "${state.query}"',
                ),
              )
            else ...[
              SliverList.builder(
                itemCount: state.results.length,
                itemBuilder: (context, i) => SongTile(
                  song: state.results[i],
                  onTap: () =>
                      ref.read(playWithRadioUseCaseProvider)(state.results, i),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: state.isLoadingMore
                        ? const CircularProgressIndicator()
                        : state.error != null
                        ? TextButton(
                            onPressed: controller.loadMore,
                            child: const Text('Cargar más'),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// "Búsquedas recientes": tocar repite la búsqueda; la X la quita.
  List<Widget> _recentSlivers(BuildContext context, List<String> recents) {
    final history = ref.read(recentSearchesProvider.notifier);
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Búsquedas recientes',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton(
                onPressed: history.clear,
                child: const Text('Borrar todo'),
              ),
            ],
          ),
        ),
      ),
      SliverList.builder(
        itemCount: recents.length,
        itemBuilder: (context, i) => ListTile(
          leading: const Icon(Icons.history_rounded),
          title: Text(recents[i]),
          trailing: IconButton(
            tooltip: 'Quitar',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => history.remove(recents[i]),
          ),
          onTap: () => _submit(recents[i]),
        ),
      ),
    ];
  }
}
