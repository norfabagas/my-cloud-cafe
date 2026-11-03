import 'dart:math';

import 'package:flutter/foundation.dart';

import 'catalog.dart';
import 'state.dart';

class GameEngine extends ChangeNotifier {
  CafeState state;
  final int Function() clock;
  int offlineCoins = 0;
  String message = '';
  GameEngine(this.state, {int Function()? clock})
    : clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch);
  int get now => clock();
  static const names = ['Nara', 'Dimas', 'Sari', 'Arga', 'Lia', 'Bima'];
  static const goalTargets = [5, 15, 30, 60];

  void resume() {
    final elapsed = max(0, now - state.lastSeen);
    // Offline production is a deliberate local design, capped at eight hours.
    if (state.staff && elapsed >= 60000) {
      final minutes = min(elapsed ~/ 60000, 480);
      final average =
          recipes
              .where((r) => state.unlocked.contains(r.id))
              .map((r) => r.price)
              .reduce((a, b) => a + b) ~/
          state.unlocked.length;
      offlineCoins = minutes * average ~/ 3;
      state.coins += offlineCoins;
      state.earned += offlineCoins;
    }
    for (final o in state.orders) {
      o.deadline = now + 90000;
    }
    state.lastSeen = now;
    state.nextArrival = now + 3000;
    state.nextStaff = now + 15000;
    if (state.orders.isEmpty) _arrive();
    notifyListeners();
  }

  void tick() {
    var changed = false;
    final expired = state.orders
        .where(
          (o) =>
              o.deadline <= now && !state.brews.any((b) => b.orderId == o.id),
        )
        .toList();
    if (expired.isNotEmpty) {
      state.orders.removeWhere((o) => expired.contains(o));
      changed = true;
    }
    if (now >= state.nextArrival) {
      if (state.orders.length < state.capacity) {
        _arrive();
        changed = true;
      }
      state.nextArrival = now + 12000;
    }
    if (state.staff && now >= state.nextStaff) {
      for (final b in state.brews.where((b) => b.readyAt <= now).toList()) {
        _serve(b.orderId);
      }
      final waiting = state.orders.where(
        (o) => !state.brews.any((b) => b.orderId == o.id),
      );
      if (waiting.isNotEmpty && state.brews.length < 2) _brew(waiting.first.id);
      state.nextStaff = now + 5000;
      changed = true;
    }
    if (changed || state.brews.isNotEmpty || state.orders.isNotEmpty) {
      notifyListeners();
    }
  }

  void _arrive() {
    final menu = recipes.where((r) => state.unlocked.contains(r.id)).toList();
    final id = state.nextId++;
    state.orders.add(
      Order(
        id,
        names[(id - 1) % names.length],
        menu[(id - 1) % menu.length].id,
        now + 90000,
      ),
    );
  }

  String brew(int id) => _action(() => _brew(id));
  String _brew(int id) {
    if (!state.orders.any((o) => o.id == id)) return 'Pesanan sudah selesai.';
    if (state.brews.any((b) => b.orderId == id)) {
      return 'Pesanan ini sedang disiapkan.';
    }
    if (state.brews.length >= 2) {
      return 'Dua pesanan sedang disiapkan. Tunggu sebentar.';
    }
    final recipe = recipeById(
      state.orders.firstWhere((o) => o.id == id).recipe,
    );
    state.brews.add(Brew(id, now, now + recipe.seconds * 1000));
    return '${recipe.name} sedang disiapkan.';
  }

  String serve(int id) => _action(() => _serve(id));
  String _serve(int id) {
    final matches = state.brews.where((b) => b.orderId == id);
    if (matches.isEmpty || matches.first.readyAt > now) {
      return 'Pesanan belum siap.';
    }
    final orders = state.orders.where((o) => o.id == id);
    if (orders.isEmpty) return 'Pesanan sudah selesai.';
    final recipe = recipeById(orders.first.recipe);
    final tip = min(state.charm ~/ 3, 20);
    state.coins += recipe.price + tip;
    state.earned += recipe.price + tip;
    state.xp += 20;
    state.served++;
    state.brews.removeWhere((b) => b.orderId == id);
    state.orders.removeWhere((o) => o.id == id);
    return '+${recipe.price + tip} koin · Terima kasih!';
  }

  String unlockRecipe(Recipe r) => _action(() {
    if (state.unlocked.contains(r.id)) return 'Resep sudah tersedia.';
    if (state.level < r.level) return 'Tersedia pada level ${r.level}.';
    if (!state.machines.contains(r.equipment)) {
      return 'Siapkan ${equipment.firstWhere((e) => e.id == r.equipment).name} dahulu.';
    }
    if (state.coins < r.cost) return 'Koin belum cukup.';
    state.coins -= r.cost;
    state.unlocked.add(r.id);
    return '${r.name} masuk menu.';
  });
  String unlockEquipment(Equipment e) => _action(() {
    if (state.machines.contains(e.id)) return 'Peralatan sudah tersedia.';
    if (state.level < e.level) return 'Tersedia pada level ${e.level}.';
    if (state.coins < e.cost) return 'Koin belum cukup.';
    state.coins -= e.cost;
    state.machines.add(e.id);
    return '${e.name} siap digunakan.';
  });
  String hire() => _action(() {
    if (state.staff) return 'Ayu sudah bergabung.';
    if (state.coins < 280) return 'Butuh 280 koin untuk merekrut Ayu.';
    state.coins -= 280;
    state.staff = true;
    state.nextStaff = now;
    return 'Ayu bergabung. Ia akan menyiapkan dan menyajikan pesanan.';
  });
  String place(String kind, int x, int y, {int? moving}) => _action(() {
    if (x < 0 || x > 7 || y < 1 || y > 5) return 'Pilih ubin di dalam kafe.';
    if (state.decor.indexed.any(
      (d) => d.$1 != moving && d.$2.x == x && d.$2.y == y,
    )) {
      return 'Ubin ini sudah terisi.';
    }
    if (moving != null) {
      if (moving < 0 || moving >= state.decor.length) {
        return 'Pilih dekorasi dahulu.';
      }
      state.decor[moving].x = x;
      state.decor[moving].y = y;
      return 'Dekorasi dipindahkan.';
    }
    final f = furniture.firstWhere((f) => f.id == kind);
    if (state.coins < f.cost) return 'Koin belum cukup.';
    if (state.decor.length >= 40) return 'Semua ubin sudah terisi.';
    state.coins -= f.cost;
    state.decor.add(Decoration(kind, x, y));
    return '${f.name} ditempatkan.';
  });
  String story(int index) => _action(() {
    if (index < 0 ||
        index >= chapters.length ||
        state.stories.contains(index)) {
      return 'Cerita sudah selesai.';
    }
    final c = chapters[index];
    if (state.served < c.requiredServed) {
      return 'Layani ${c.requiredServed} pesanan untuk melanjutkan.';
    }
    state.stories.add(index);
    state.coins += c.reward;
    return c.response;
  });
  String claimGoal(int index) => _action(() {
    if (index < 0 ||
        index >= goalTargets.length ||
        state.claimedGoals.contains(index) ||
        state.served < goalTargets[index]) {
      return 'Target belum bisa diklaim.';
    }
    state.claimedGoals.add(index);
    state.coins += (index + 1) * 75;
    return '+${(index + 1) * 75} koin dari target.';
  });
  void setTheme(String value) {
    state.theme = value;
    notifyListeners();
  }

  String _action(String Function() fn) {
    message = fn();
    notifyListeners();
    return message;
  }
}
