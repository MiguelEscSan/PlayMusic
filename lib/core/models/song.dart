import 'package:sponify/core/data/models/song_model.dart';

export 'package:sponify/core/data/models/song_model.dart'
    show SongModel, SongSource;

/// Alias transitorio de [SongModel] para que los consumidores existentes
/// sigan compilando sin cambios. Se elimina en el slice 2b, cuando todos
/// pasen a depender de la entidad de dominio o del DTO directamente.
typedef Song = SongModel;
