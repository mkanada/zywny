import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:zywny/tutorial/tour_store.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test('nada visto no começo; ver um passeio não marca o outro', () async {
    final store = TourStore();
    expect(await store.seen(TourId.library), isFalse);
    expect(await store.seen(TourId.score), isFalse);

    await store.markSeen(TourId.library);
    expect(await store.seen(TourId.library), isTrue);
    expect(await store.seen(TourId.score), isFalse);
  });

  test('sobrevive a uma instância nova (fica nas preferências)', () async {
    await TourStore().markSeen(TourId.score);
    expect(await TourStore().seen(TourId.score), isTrue);
  });

  test('uma versão mais velha do passeio não vale: ele reaparece', () async {
    // O que um app antigo gravou, antes de o passeio mudar e a versão subir.
    final older = TourId.library.version - 1;
    await SharedPreferencesAsync().setInt('tutorial_seen_library', older);
    expect(await TourStore().seen(TourId.library), isFalse);

    await TourStore().markSeen(TourId.library);
    expect(await TourStore().seen(TourId.library), isTrue);
  });
}
