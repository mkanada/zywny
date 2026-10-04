/// Chaves de `shared_preferences` do que o app guarda por biblioteca e por
/// música (docs/plano/B00). Remover uma biblioteca não apaga nenhuma delas
/// (D-BIB-REMOVER): reinstalar recupera o progresso.
String progressKeyFor(String libraryId) => 'lib_progress_$libraryId';

String pieceSettingsKeyFor(String libraryId, String pieceId) =>
    'piece_settings_${libraryId}_$pieceId';

String trailKeyFor(String libraryId, String pieceId) =>
    'trail_${libraryId}_$pieceId';
