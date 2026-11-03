import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_web_cafe/game/state.dart';
import 'package:my_web_cafe/persistence/save_store.dart';

void main() {
  late SharedPreferences preferences;
  late SaveStore store;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    store = SaveStore(preferences);
  });
  test(
    'guest and account snapshots remain isolated across queued writes',
    () async {
      final guest = CafeState(1000)..coins = 500;
      final pending = store.save(guest);
      await store.switchAccount('user-a');
      await pending;
      expect(store.load(1000).coins, 350);
      await store.save(CafeState(1000)..coins = 900);
      await store.switchAccount('user-b');
      expect(store.load(1000).coins, 350);
      await store.switchAccount('user-a');
      expect(store.load(1000).coins, 900);
      await store.switchAccount(null);
      expect(store.load(1000).coins, 500);
    },
  );
  test('a corrupted primary recovers the last valid save', () async {
    await store.save(CafeState(1000)..coins = 400);
    await store.save(CafeState(2000)..coins = 600);
    await preferences.setString('cafe.save.v1', '{broken');
    expect(store.load(3000).coins, 400);
    expect(store.warning, contains('cadangan'));
  });
  test('pending upload and revision survive a restart', () async {
    await store.switchAccount('user-a');
    await store.replaceFromCloud(CafeState(1000), revision: 4);
    final changed = store.load(1000)..coins = 600;
    await store.save(changed);
    final restarted = SaveStore(preferences);
    await restarted.switchAccount('user-a');
    expect(restarted.pendingCloud, isTrue);
    expect(restarted.cloudRevision, 4);
    expect(restarted.load(1000).coins, 600);
  });
  test(
    'acknowledging an older upload preserves newer local progress',
    () async {
      await store.switchAccount('user-a');
      final initial = CafeState(1000);
      await store.save(initial);
      final submitted = initial.encode();
      await store.save(CafeState(1000)..coins = 800);
      await store.acknowledgeCloud(
        ownerId: 'user-a',
        revision: 1,
        uploadedRaw: submitted,
      );
      expect(store.pendingCloud, isTrue);
      expect(store.cloudRevision, 1);
      expect(store.load(1000).coins, 800);
    },
  );
}
