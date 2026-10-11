import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/song_actions.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/song_tile.dart';
import 'search_controller.dart';

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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchControllerProvider);
    final controller = ref.read(searchControllerProvider.notifier);
    final actions = ref.read(songActionsProvider);

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
                        controller.search('');
                        setState(() {});
                      },
                    ),
                ],
                onChanged: (q) {
                  setState(() {});
                  controller.onQueryChanged(q);
                },
                onSubmitted: controller.search,
              ),
            ),
            if (state.isLoading)
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
                  onTap: () => actions.playQueue(state.results, i),
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
}
