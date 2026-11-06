import 'dart:math';

import 'package:flutter/foundation.dart';

import 'catalog.dart';
import 'state.dart';

class Departure {
  final Order order;
  final int leftAt;
  Departure(this.order, this.leftAt);
}

class GameEngine extends ChangeNotifier {
  CafeState state;
  final int Function() clock;
  int offlineCoins = 0;
  String message = '';
  final List<Departure> departures = [];
  final Map<String, (double, double, int)> staffMotions = {};
  static const walkMillis = 2400;
  GameEngine(this.state, {int Function()? clock})
    : clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch);
  int get now => clock();
  static const names = [
    'Nara',
    'Dimas',
    'Sari',
    'Arga',
    'Lia',
    'Bima',
    'Dewi',
    'Rani',
    'Fajar',
    'Intan',
    'Bayu',
    'Citra',
    'Eka',
    'Putri',
    'Andi',
    'Wulan',
    'Rizal',
    'Nina',
    'Tara',
    'Yoga',
    'Kirana',
    'Reza',
    'Adit',
    'Maya',
  ];
  static const goalTargets = [5, 15, 30, 60];

  void resume() {
    departures.clear();
    staffMotions.clear();
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
    departures.removeWhere((d) => now - d.leftAt > walkMillis);
    for (final w in state.workers) {
      if (w.restUntil > 0 && w.restUntil <= now) {
        w.energy = 12;
        w.restUntil = 0;
        changed = true;
      }
    }
    final expired = state.orders
        .where(
          (o) =>
              o.deadline <= now &&
              !state.brews.any((b) => b.orderId == o.id && b.readyAt > now),
        )
        .toList();
    if (expired.isNotEmpty) {
      for (final o in expired) {
        _leave(o);
      }
      state.brews.removeWhere((b) => expired.any((o) => o.id == b.orderId));
      state.orders.removeWhere((o) => expired.contains(o));
      changed = true;
    }
    if (now >= state.nextArrival) {
      _arrive();
      changed = true;
      state.nextArrival = now + 12000;
    }
    if (state.staff && now >= state.nextStaff) {
      for (final w in state.workers) {
        if (w.energy <= 0 || w.restUntil > 0) continue;
        final motion = staffMotions[w.name];
        if (motion != null && now - motion.$3 < walkMillis) continue;
        for (final o in state.orders.toList()) {
          if (now < o.arrivedAt + walkMillis) continue;
          final b = brewFor(o.id);
          if (b != null && b.readyAt > now) continue;
          final step = nextStep(o.id);
          if (step == null && b != null && w.role != 'barista') {
            staffMotions[w.name] = (o.seatX + .5, o.seatY + .5, now);
            _serve(o.id);
            w.energy--;
            break;
          }
          if (step != null && w.role != 'server' && toolAvailable(step.tool)) {
            final p = state.toolPositions[step.tool]!;
            staffMotions[w.name] = (p.x + .5, p.y + 1.5, now);
            _prepare(o.id, step.tool);
            w.energy--;
            break;
          }
        }
      }
      state.nextStaff = now + 1000;
      changed = true;
    }
    if (changed || state.brews.isNotEmpty || state.orders.isNotEmpty) {
      notifyListeners();
    }
  }

  void _arrive() {
    final seats = state.seats
        .where(
          (d) =>
              state.pathTo(d.x, d.y).isNotEmpty &&
              !state.orders.any((o) => o.seatX == d.x && o.seatY == d.y) &&
              !departures.any(
                (o) => o.order.seatX == d.x && o.order.seatY == d.y,
              ) &&
              !state.toolPositions.values.any(
                (p) =>
                    (p.x - d.x).abs() + (p.y - d.y).abs() == 1 &&
                    state.decor.any(
                      (t) => t.kind == 'table' && t.x == p.x && t.y == p.y,
                    ),
              ),
        )
        .toList();
    if (seats.isEmpty) return;
    final menu = recipes
        .where(
          (r) =>
              state.unlocked.contains(r.id) &&
              !state.disabledMenu.contains(r.id) &&
              r.tools.every(state.machines.contains),
        )
        .toList();
    if (menu.isEmpty) return;
    final id = state.nextId++;
    final customerId = (id - 1) % names.length + 1;
    if (state.orders.any((o) => o.customerId == customerId)) return;
    var customer = state.customers.where((c) => c.id == customerId).firstOrNull;
    if (customer == null) {
      customer = Customer(
        customerId,
        names[customerId - 1],
        customerId * 31,
        now,
      );
      state.customers.add(customer);
    } else {
      customer.visits++;
    }
    state.orders.add(
      Order(
        id,
        customer.name,
        menu[(id - 1) % menu.length].id,
        now + 90000,
        customerId: customerId,
        arrivedAt: now,
        seatX: seats.first.x,
        seatY: seats.first.y,
      ),
    );
  }

  Brew? brewFor(int id) =>
      state.brews.where((b) => b.orderId == id).firstOrNull;
  RecipeStep? nextStep(int id) {
    final o = state.orders.where((o) => o.id == id).firstOrNull;
    if (o == null) return null;
    final steps = recipeById(o.recipe).steps, b = brewFor(id);
    final index = b == null ? 0 : b.step + 1;
    return index < steps.length ? steps[index] : null;
  }

  bool toolAvailable(String tool) =>
      state.machines.contains(tool) &&
      state.toolPositions.containsKey(tool) &&
      !state.brews.any(
        (b) =>
            b.readyAt > now &&
            recipeById(
                  state.orders.firstWhere((o) => o.id == b.orderId).recipe,
                ).steps[b.step].tool ==
                tool,
      );
  String brew(int id) => prepare(id, nextStep(id)?.tool ?? '');
  String prepare(int id, String tool) => _action(() => _prepare(id, tool));
  String _prepare(int id, String tool) {
    final o = state.orders.where((o) => o.id == id).firstOrNull;
    if (o == null) return 'Pesanan sudah selesai.';
    if (now < o.arrivedAt + walkMillis) return 'Pelanggan sedang menuju kursi.';
    final b = brewFor(id), step = nextStep(id);
    if (b != null && b.readyAt > now) return 'Bahan masih disiapkan.';
    if (step == null) return 'Siap disajikan.';
    if (step.tool != tool) {
      return 'Gunakan ${equipment.firstWhere((e) => e.id == step.tool).name} dahulu.';
    }
    if (!toolAvailable(tool)) return 'Alat belum tersedia atau sedang dipakai.';
    state.brews.removeWhere((b) => b.orderId == id);
    state.brews.add(
      Brew(id, now, now + step.seconds * 1000, b == null ? 0 : b.step + 1),
    );
    return '${step.ingredient} · ${step.seconds} detik';
  }

  String serve(int id) => _action(() => _serve(id));
  String _serve(int id) {
    final matches = state.brews.where((b) => b.orderId == id);
    if (matches.isEmpty ||
        matches.first.readyAt > now ||
        nextStep(id) != null) {
      return 'Pesanan belum siap.';
    }
    final orders = state.orders.where((o) => o.id == id);
    if (orders.isEmpty) return 'Pesanan sudah selesai.';
    final recipe = recipeById(orders.first.recipe);
    _leave(orders.first);
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
    if (!r.tools.every(state.machines.contains)) {
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
    final slots = [
      for (var x = 1; x <= 6; x++) Decoration(e.id, x, 0),
      ...state.decor
          .where((d) => ['table', 'counter'].contains(d.kind))
          .map((d) => Decoration(e.id, d.x, d.y)),
    ];
    final slot = slots
        .where(
          (d) =>
              !state.toolPositions.values.any((p) => p.x == d.x && p.y == d.y),
        )
        .firstOrNull;
    if (slot == null) return 'Beli meja kerja untuk alat ini dahulu.';
    state.coins -= e.cost;
    state.machines.add(e.id);
    state.toolPositions[e.id] = slot;
    return '${e.name} siap digunakan.';
  });
  String hire() => _action(() {
    if (state.workers.length >= 3) return 'Maksimal 3 staf.';
    final cost = 280 + state.workers.length * 100;
    if (state.coins < cost) return 'Butuh $cost koin untuk merekrut staf.';
    state.coins -= cost;
    state.workers.add(
      StaffMember(['Ayu', 'Raka', 'Mira'][state.workers.length]),
    );
    state.nextStaff = now;
    return '${state.workers.last.name} bergabung.';
  });
  String setRole(int i, String role) => _action(() {
    if (i < 0 ||
        i >= state.workers.length ||
        !['all', 'barista', 'server'].contains(role)) {
      return 'Pilih staf dan tugas.';
    }
    state.workers[i].role = role;
    return 'Tugas staf diperbarui.';
  });
  String restStaff(int i) => _action(() {
    if (i < 0 || i >= state.workers.length) return 'Pilih staf.';
    final w = state.workers[i];
    if (w.restUntil > now) return 'Staf sedang istirahat.';
    w.restUntil = now + 10000;
    return '${w.name} istirahat 10 detik.';
  });
  String toggleMenu(String id) => _action(() {
    if (!state.unlocked.contains(id)) return 'Pelajari resep dahulu.';
    if (state.disabledMenu.contains(id)) {
      state.disabledMenu.remove(id);
      return 'Menu tersedia.';
    }
    if (state.unlocked.difference(state.disabledMenu).length <= 1) {
      return 'Sisakan minimal satu menu.';
    }
    state.disabledMenu.add(id);
    return 'Menu disembunyikan. Pesanan yang sudah ada tetap dilayani.';
  });
  void _leave(Order o) => departures.add(Departure(o, now));
  String moveTool(String tool, int x, int y) => _action(() {
    if (!state.machines.contains(tool)) return 'Beli alat dahulu.';
    if (!toolAvailable(tool)) return 'Tunggu alat selesai bekerja.';
    if (x < 0 ||
        x > 7 ||
        y < 0 ||
        y > 5 ||
        (y == 0 && (x < 1 || x > 6)) ||
        (y > 0 &&
            !state.decor.any(
              (d) =>
                  ['table', 'counter'].contains(d.kind) && d.x == x && d.y == y,
            ))) {
      return 'Alat harus berada di atas meja.';
    }
    if (state.toolPositions.entries.any(
      (e) => e.key != tool && e.value.x == x && e.value.y == y,
    )) {
      return 'Meja sudah memiliki alat.';
    }
    if (state.orders.any(
      (o) =>
          (o.seatX - x).abs() + (o.seatY - y).abs() == 1 &&
          state.decor.any((d) => d.kind == 'table' && d.x == x && d.y == y),
    )) {
      return 'Meja sedang digunakan pelanggan.';
    }
    state.toolPositions[tool] = Decoration(tool, x, y);
    return 'Alat dipindahkan.';
  });
  String place(String kind, int x, int y, {int? moving}) => _action(() {
    if (state.orders.any((o) => now < o.arrivedAt + walkMillis) ||
        departures.any((d) => now - d.leftAt < walkMillis)) {
      return 'Tunggu pelanggan selesai berjalan.';
    }
    if (x < 0 || x > 7 || y < 1 || y > 5) return 'Pilih ubin di dalam kafe.';
    if (x == 7 && y == 5) return 'Pintu masuk harus tetap kosong.';
    if (state.decor.indexed.any(
      (d) => d.$1 != moving && d.$2.x == x && d.$2.y == y,
    )) {
      return 'Ubin ini sudah terisi.';
    }
    if (moving != null) {
      if (moving < 0 || moving >= state.decor.length) {
        return 'Pilih dekorasi dahulu.';
      }
      final d = state.decor[moving];
      if (state.orders.any(
            (o) =>
                (o.seatX == d.x && o.seatY == d.y) ||
                (d.kind == 'table' &&
                    (o.seatX - d.x).abs() + (o.seatY - d.y).abs() == 1),
          ) ||
          departures.any((o) => o.order.seatX == d.x && o.order.seatY == d.y)) {
        return 'Tunggu pelanggan meninggalkan meja.';
      }
      final tools = state.toolPositions.entries
          .where((e) => e.value.x == d.x && e.value.y == d.y)
          .toList();
      if (tools.any((e) => !toolAvailable(e.key))) {
        return 'Alat di meja masih bekerja.';
      }
      final layout = state.decor.indexed
          .map((e) => e.$1 == moving ? Decoration(d.kind, x, y) : e.$2)
          .toList();
      if (!_pathsClear(layout)) {
        return 'Sisakan jalan dari pintu ke setiap kursi.';
      }
      for (final e in tools) {
        e.value.x = x;
        e.value.y = y;
      }
      state.decor[moving].x = x;
      state.decor[moving].y = y;
      return 'Dekorasi dipindahkan.';
    }
    final f = furniture.firstWhere((f) => f.id == kind);
    if (state.coins < f.cost) return 'Koin belum cukup.';
    if (state.decor.length >= 40) return 'Semua ubin sudah terisi.';
    if (!_pathsClear([...state.decor, Decoration(kind, x, y)])) {
      return 'Sisakan jalan dari pintu ke setiap kursi.';
    }
    state.coins -= f.cost;
    state.decor.add(Decoration(kind, x, y));
    return '${f.name} ditempatkan.';
  });
  bool _pathsClear(List<Decoration> layout) => layout
      .where((d) => d.kind == 'chair')
      .every((d) => state.pathTo(d.x, d.y, layout: layout).isNotEmpty);
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
