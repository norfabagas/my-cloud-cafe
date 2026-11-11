import 'dart:convert';
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
    now += GameEngine.walkMillis;
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
      game.place('plant', 7, 4, moving: game.state.decor.length - 1);
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

  test('latte requires espresso then milk, each timed, before payment', () {
    game.state.coins = 2000;
    game.state.xp = 100;
    game.unlockEquipment(equipment.firstWhere((e) => e.id == 'milk'));
    game.unlockRecipe(recipeById('latte'));
    game.toggleMenu('espresso');
    game.state.orders.clear();
    game.state.nextArrival = now;
    game.tick();
    now += GameEngine.walkMillis;
    final o = game.state.orders.single, balance = game.state.coins;
    expect(o.recipe, 'latte');
    game.prepare(o.id, 'milk');
    expect(game.state.brews, isEmpty);
    game.prepare(o.id, 'coffee');
    expect(game.brewFor(o.id)!.step, 0);
    game.prepare(o.id, 'milk');
    expect(game.brewFor(o.id)!.step, 0);
    now += 4000;
    game.serve(o.id);
    expect(game.state.coins, balance);
    game.prepare(o.id, 'milk');
    expect(game.brewFor(o.id)!.step, 1);
    now += 3999;
    game.serve(o.id);
    expect(game.state.served, 0);
    now++;
    game.serve(o.id);
    game.serve(o.id);
    expect(game.state.served, 1);
    expect(game.departures.single.order.id, o.id);
  });
  test('tool locks exclude simultaneous manual and staff jobs', () {
    game.state.nextArrival = now;
    game.tick();
    now += GameEngine.walkMillis;
    final ids = game.state.orders.map((o) => o.id).toList();
    expect(ids.length, 2);
    game.prepare(ids.first, 'coffee');
    game.prepare(ids.last, 'coffee');
    expect(game.state.brews.length, 1);
    expect(game.toolAvailable('coffee'), isFalse);
    game.hire();
    game.tick();
    expect(game.state.brews.length, 1);
    now += 5000;
    game.prepare(ids.last, 'coffee');
    expect(game.state.brews.length, 2);
  });
  test(
    'disabled menu prevents new orders and cannot remove the last recipe',
    () {
      game.toggleMenu('espresso');
      expect(game.state.disabledMenu, isEmpty);
      game.unlockEquipment(equipment.firstWhere((e) => e.id == 'tea'));
      game.unlockRecipe(recipeById('tea'));
      game.toggleMenu('espresso');
      final original = game.state.orders.first;
      game.state.nextArrival = now;
      game.tick();
      expect(game.state.orders.last.recipe, 'tea');
      expect(original.recipe, 'espresso');
    },
  );
  test('three staff share recipe rules, rest needs, and manual completion', () {
    game.state.coins = 2000;
    game.hire();
    game.hire();
    game.hire();
    final balance = game.state.coins;
    game.hire();
    expect(game.state.workers.length, 3);
    expect(game.state.coins, balance);
    game.setRole(0, 'barista');
    game.setRole(1, 'server');
    game.setRole(2, 'server');
    game.tick();
    expect(game.state.brews.length, 1);
    final id = game.state.orders.first.id;
    now += 5000;
    game.serve(id);
    game.tick();
    expect(game.state.served, 1);
    game.state.workers.first.energy = 0;
    game.restStaff(0);
    now += 9999;
    game.tick();
    expect(game.state.workers.first.energy, 0);
    now++;
    game.tick();
    expect(game.state.workers.first.energy, greaterThan(0));
    final restored = CafeState.decode(game.state.encode());
    expect(restored.workers.length, 3);
    expect(restored.workers.first.role, 'barista');
  });
  test('tools require tables; moving a table moves its supported tool', () {
    game.place('counter', 4, 4);
    game.moveTool('coffee', 4, 4);
    expect(game.state.toolPositions['coffee']!.x, 4);
    game.moveTool('coffee', 6, 4);
    expect(game.state.toolPositions['coffee']!.x, 4);
    game.place('counter', 6, 4, moving: game.state.decor.length - 1);
    expect(game.state.toolPositions['coffee']!.x, 6);
    final roundTrip = CafeState.decode(game.state.encode());
    expect(roundTrip.toolPositions['coffee']!.x, 6);
    final balance = game.state.coins;
    game.place('plant', 7, 5);
    expect(game.state.coins, balance);
  });
  test('customers are registered once, retain their look, and revisit', () {
    final first = game.state.customers.single;
    for (var i = 0; i < 24; i++) {
      game.state.orders.clear();
      game.departures.clear();
      game.state.nextArrival = now;
      game.tick();
      now += 12000;
    }
    expect(game.state.customers.length, 24);
    expect(game.state.customers.first.look, first.look);
    expect(first.visits, 2);
    final restored = CafeState.decode(game.state.encode());
    expect(restored.customers.first.visits, 2);
  });
  test('expiry removes partial recipes and frees the station', () {
    final o = game.state.orders.first;
    game.brew(o.id);
    now += 91000;
    game.tick();
    expect(game.brewFor(o.id), isNull);
    expect(game.state.served, 0);
    expect(game.toolAvailable('coffee'), isTrue);
    expect(game.departures.any((d) => d.order.id == o.id), isTrue);
  });
  test('legacy save upgrades chairs, profiles and pending recipes', () {
    game.brew(game.state.orders.first.id);
    final j = jsonDecode(game.state.encode()) as Map<String, dynamic>;
    for (final k in ['customers', 'workers', 'disabledMenu', 'toolPositions']) {
      j.remove(k);
    }
    (j['decor'] as List).removeWhere((d) => d['kind'] == 'chair');
    for (final o in j['orders']) {
      for (final k in ['customerId', 'arrivedAt', 'seatX', 'seatY']) {
        o.remove(k);
      }
    }
    for (final b in j['brews']) {
      b.remove('step');
    }
    final migrated = CafeState.decode(jsonEncode(j));
    expect(migrated.capacity, 2);
    expect(migrated.customers.single.name, 'Nara');
    expect(migrated.brews.length, 1);
    expect(CafeState.decode(migrated.encode()).encode(), migrated.encode());
  });
  test(
    'all recipe steps add up to their listed duration and stay under 30s',
    () {
      for (final r in recipes) {
        expect(r.steps.fold<int>(0, (n, s) => n + s.seconds), r.seconds);
        expect(r.seconds, lessThanOrEqualTo(30));
      }
    },
  );
}
