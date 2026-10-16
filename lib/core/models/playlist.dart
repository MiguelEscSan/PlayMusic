import 'package:sponify/core/data/models/playlist_model.dart';

export 'package:sponify/core/data/models/playlist_model.dart'
    show PlaylistModel;

/// Alias transitorio de [PlaylistModel] para que los consumidores existentes
/// sigan compilando sin cambios. Se elimina en el slice 2b, cuando todos
/// pasen a depender de la entidad de dominio o del DTO directamente.
typedef Playlist = PlaylistModel;
