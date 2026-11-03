import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_cafe/game/catalog.dart';
import 'package:my_web_cafe/game/engine.dart';
import 'package:my_web_cafe/game/state.dart';

void main() {
  late int now;
  late GameEngine game;
  setUp(() {
    now = 1700000000000;
    game = GameEngine(CafeState(now), clock: () => now);
    game.resume();
  });
  test('brewing cannot pay early or pay twice', () {
    final id = game.state.orders.first.id;
    final balance = game.state.coins;
    game.brew(id);
    game.brew(id);
    expect(game.state.brews.length, 1);
    game.serve(id);
    expect(game.state.coins, balance);
    now += 5000;
    game.serve(id);
    final paid = game.state.coins;
    expect(paid, greaterThan(balance));
    expect(game.state.served, 1);
    game.serve(id);
    expect(game.state.coins, paid);
  });
  test('equipment and level gates are enforced without charging', () {
    final balance = game.state.coins;
    game.unlockRecipe(recipes.firstWhere((r) => r.id == 'latte'));
    expect(game.state.coins, balance);
    expect(game.state.unlocked, isNot(contains('latte')));
    game.state.xp = 100;
    game.unlockRecipe(recipes.firstWhere((r) => r.id == 'latte'));
    expect(game.state.coins, balance);
    game.unlockEquipment(equipment.firstWhere((e) => e.id == 'milk'));
    game.unlockRecipe(recipes.firstWhere((r) => r.id == 'latte'));
    expect(game.state.unlocked, contains('latte'));
    expect(game.state.coins, balance - 180 - 110);
  });
  test('offline rewards are capped, require staff and cannot be replayed', () {
    now += const Duration(days: 2).inMilliseconds;
    game.resume();
    expect(game.state.coins, 350);
    game.hire();
    final balance = game.state.coins;
    now += const Duration(days: 2).inMilliseconds;
    game.resume();
    expect(game.offlineCoins, 480 * 24 ~/ 3);
    expect(game.state.coins, balance + game.offlineCoins);
    final paid = game.state.coins;
    game.resume();
    expect(game.state.coins, paid);
    now -= const Duration(days: 3).inMilliseconds;
    game.resume();
    expect(game.state.coins, paid);
  });
  test(
    'furniture cannot overlap, leave the room or charge on rejected placement',
    () {
      final balance = game.state.coins;
      game.place('plant', 2, 2);
      game.place('plant', -1, 3);
      game.place('plant', 2, 0);
      expect(game.state.coins, balance);
      game.place('plant', 4, 4);
      expect(game.state.coins, balance - 45);
      game.place('plant', 7, 5, moving: 3);
      expect(game.state.coins, balance - 45);
      expect(game.state.decor.last.x, 7);
    },
  );
  test('story and milestone rewards are granted once', () {
    game.state.served = 10;
    final balance = game.state.coins;
    game.story(0);
    game.story(0);
    game.claimGoal(0);
    game.claimGoal(0);
    expect(game.state.coins, balance + 50 + 75);
    game.story(3);
    expect(game.state.stories, isNot(contains(3)));
  });
  test(
    'returning visitors get a fresh patience window and retain brewed orders',
    () {
      final id = game.state.orders.first.id;
      game.brew(id);
      now += const Duration(hours: 2).inMilliseconds;
      game.resume();
      game.tick();
      expect(game.state.orders.first.id, id);
      game.serve(id);
      expect(game.state.served, 1);
    },
  );
  test('barista automatically completes orders', () {
    game.hire();
    game.tick();
    expect(game.state.brews, isNotEmpty);
    now += 6000;
    game.tick();
    expect(game.state.served, 1);
  });
  test('save round trip retains pending jobs and refuses newer schemas', () {
    game.brew(game.state.orders.first.id);
    final decoded = CafeState.decode(game.state.encode());
    expect(decoded.encode(), game.state.encode());
    expect(
      () => CafeState.decode(
        game.state.encode().replaceFirst('"version":1', '"version":99'),
      ),
      throwsFormatException,
    );
    expect(() => CafeState.decode('{}'), throwsFormatException);
  });
}
