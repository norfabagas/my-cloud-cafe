import 'dart:convert';

import 'catalog.dart';

class Order {
  final int id;
  final String name, recipe;
  int deadline;
  final int customerId, arrivedAt, seatX, seatY;
  Order(
    this.id,
    this.name,
    this.recipe,
    this.deadline, {
    this.customerId = 0,
    this.arrivedAt = 0,
    this.seatX = 2,
    this.seatY = 3,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'recipe': recipe,
    'deadline': deadline,
    'customerId': customerId,
    'arrivedAt': arrivedAt,
    'seatX': seatX,
    'seatY': seatY,
  };
}

class Brew {
  final int orderId, startedAt, readyAt, step;
  Brew(this.orderId, this.startedAt, this.readyAt, [this.step = 0]);
  Map<String, dynamic> toJson() => {
    'orderId': orderId,
    'startedAt': startedAt,
    'readyAt': readyAt,
    'step': step,
  };
}

class Customer {
  final int id, look, firstSeen;
  final String name;
  int visits;
  Customer(this.id, this.name, this.look, this.firstSeen, {this.visits = 1});
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'look': look,
    'firstSeen': firstSeen,
    'visits': visits,
  };
}

class StaffMember {
  final String name;
  String role;
  int energy, restUntil;
  StaffMember(
    this.name, {
    this.role = 'all',
    this.energy = 12,
    this.restUntil = 0,
  });
  Map<String, dynamic> toJson() => {
    'name': name,
    'role': role,
    'energy': energy,
    'restUntil': restUntil,
  };
}

class Decoration {
  final String kind;
  int x, y;
  Decoration(this.kind, this.x, this.y);
  Map<String, dynamic> toJson() => {'kind': kind, 'x': x, 'y': y};
}

class CafeState {
  static const schemaVersion = 1;
  int coins = 350, xp = 0, served = 0, earned = 0, nextId = 1;
  int lastSeen, nextArrival, nextStaff;
  final List<StaffMember> workers = [];
  bool get staff => workers.isNotEmpty;
  set staff(bool value) {
    if (value && workers.isEmpty) workers.add(StaffMember('Ayu'));
    if (!value) workers.clear();
  }

  String theme = 'sage';
  final Set<String> unlocked = {'espresso'}, machines = {'coffee'};
  final Set<int> stories = {}, claimedGoals = {};
  final List<Order> orders = [];
  final List<Brew> brews = [];
  final List<Customer> customers = [];
  final Set<String> disabledMenu = {};
  // Tools sit on the built-in back counter (y=0), or on purchased work tables.
  final Map<String, Decoration> toolPositions = {
    'coffee': Decoration('coffee', 1, 0),
  };
  final List<Decoration> decor = [
    Decoration('table', 2, 2),
    Decoration('table', 5, 3),
    Decoration('plant', 0, 4),
    Decoration('chair', 2, 3),
    Decoration('chair', 5, 4),
  ];

  CafeState(int now)
    : lastSeen = now,
      nextArrival = now,
      nextStaff = now + 15000;
  int get level => 1 + xp ~/ 100;
  int get charm => decor.fold(
    0,
    (n, d) => n + furniture.firstWhere((f) => f.id == d.kind).charm,
  );
  List<Decoration> get seats => decor
      .where(
        (d) =>
            d.kind == 'chair' &&
            decor.any(
              (t) =>
                  t.kind == 'table' &&
                  (d.x - t.x).abs() + (d.y - t.y).abs() == 1,
            ),
      )
      .take(6)
      .toList();
  int get capacity => seats.length;

  List<(int, int)> pathTo(int x, int y, {List<Decoration>? layout}) {
    final target = (x, y), entrance = (7, 5), items = layout ?? decor;
    final blocked = items
        .where((d) => (d.x, d.y) != target)
        .map((d) => (d.x, d.y))
        .toSet();
    final queue = [entrance],
        parents = <(int, int), (int, int)?>{entrance: null};
    for (var i = 0; i < queue.length; i++) {
      final p = queue[i];
      if (p == target) break;
      for (final delta in [(0, -1), (-1, 0), (1, 0), (0, 1)]) {
        final n = (p.$1 + delta.$1, p.$2 + delta.$2);
        if (n.$1 < 0 ||
            n.$1 > 7 ||
            n.$2 < 1 ||
            n.$2 > 5 ||
            blocked.contains(n) ||
            parents.containsKey(n)) {
          continue;
        }
        parents[n] = p;
        queue.add(n);
      }
    }
    if (!parents.containsKey(target)) return [];
    final result = <(int, int)>[];
    (int, int)? at = target;
    while (at != null) {
      result.add(at);
      at = parents[at];
    }
    return result.reversed.toList();
  }

  String encode() => jsonEncode({
    'version': schemaVersion,
    'coins': coins,
    'xp': xp,
    'served': served,
    'earned': earned,
    'nextId': nextId,
    'lastSeen': lastSeen,
    'nextArrival': nextArrival,
    'nextStaff': nextStaff,
    'staff': staff,
    'workers': workers.map((w) => w.toJson()).toList(),
    'customers': customers.map((c) => c.toJson()).toList(),
    'disabledMenu': disabledMenu.toList(),
    'toolPositions': toolPositions.map((k, v) => MapEntry(k, v.toJson())),
    'theme': theme,
    'unlocked': unlocked.toList(),
    'machines': machines.toList(),
    'stories': stories.toList(),
    'claimedGoals': claimedGoals.toList(),
    'orders': orders.map((o) => o.toJson()).toList(),
    'brews': brews.map((b) => b.toJson()).toList(),
    'decor': decor.map((d) => d.toJson()).toList(),
  });

  static CafeState decode(String raw) {
    if (raw.length > 100000) {
      throw const FormatException('Cadangan terlalu besar.');
    }
    final j = jsonDecode(raw);
    if (j is! Map<String, dynamic> || j['version'] != schemaVersion) {
      throw const FormatException('Versi cadangan tidak didukung.');
    }
    int number(dynamic v, [int max = 9000000000000000]) {
      if (v is! int || v < 0 || v > max) {
        throw const FormatException('Angka pada cadangan tidak valid.');
      }
      return v;
    }

    List values(String key) {
      if (j[key] is! List) throw FormatException('Data $key tidak valid.');
      return j[key] as List;
    }

    Set<String> ids(String key, Set<String> allowed) {
      final v = values(key);
      if (v.any((e) => e is! String || !allowed.contains(e))) {
        throw FormatException('Data $key tidak dikenal.');
      }
      return v.cast<String>().toSet();
    }

    final s = CafeState(number(j['lastSeen']));
    s.coins = number(j['coins']);
    s.xp = number(j['xp'], 100000000);
    s.served = number(j['served']);
    s.earned = number(j['earned']);
    s.nextId = number(j['nextId']);
    s.nextArrival = number(j['nextArrival']);
    s.nextStaff = number(j['nextStaff']);
    if (j['staff'] is! bool ||
        !['sage', 'terracotta', 'midnight'].contains(j['theme'])) {
      throw const FormatException('Pengaturan tidak valid.');
    }
    s.staff = j['staff'];
    s.theme = j['theme'];
    s.unlocked
      ..clear()
      ..addAll(ids('unlocked', recipes.map((r) => r.id).toSet()));
    s.machines
      ..clear()
      ..addAll(ids('machines', equipment.map((e) => e.id).toSet()));
    if (!s.unlocked.contains('espresso') ||
        !s.machines.contains('coffee') ||
        recipes.any(
          (r) => s.unlocked.contains(r.id) && !s.machines.contains(r.equipment),
        )) {
      throw const FormatException('Resep dan peralatan tidak sesuai.');
    }
    for (final i in values('stories')) {
      s.stories.add(number(i, chapters.length - 1));
    }
    for (final i in values('claimedGoals')) {
      s.claimedGoals.add(number(i, 3));
    }
    if (values('orders').length > 6 ||
        values('brews').length > 6 ||
        values('decor').length > 48) {
      throw const FormatException('Kapasitas cadangan tidak valid.');
    }
    final used = <int>{};
    for (final o in values('orders')) {
      final id = number(o['id']);
      if (!used.add(id) ||
          id >= s.nextId ||
          !s.unlocked.contains(o['recipe']) ||
          o['name'] is! String ||
          (o['name'] as String).length > 30) {
        throw const FormatException('Pesanan tidak valid.');
      }
      s.orders.add(
        Order(
          id,
          o['name'],
          o['recipe'],
          number(o['deadline']),
          customerId: number(o['customerId'] ?? 0),
          arrivedAt: number(o['arrivedAt'] ?? 0),
          seatX: number(o['seatX'] ?? (s.orders.isEmpty ? 2 : 5), 7),
          seatY: number(o['seatY'] ?? (s.orders.isEmpty ? 3 : 4), 5),
        ),
      );
    }
    final brewing = <int>{};
    for (final b in values('brews')) {
      final id = number(b['orderId']),
          start = number(b['startedAt']),
          end = number(b['readyAt']);
      if (!used.contains(id) ||
          !brewing.add(id) ||
          end < start ||
          end - start > 60000) {
        throw const FormatException('Seduhan tidak valid.');
      }
      final order = s.orders.firstWhere((o) => o.id == id);
      final step = number(
        b['step'] ?? (recipeById(order.recipe).steps.length - 1),
        recipeById(order.recipe).steps.length - 1,
      );
      s.brews.add(Brew(id, start, end, step));
    }
    s.decor.clear();
    final cells = <String>{};
    for (final d in values('decor')) {
      final x = number(d['x'], 7), y = number(d['y'], 5);
      if (y == 0 ||
          !cells.add('$x,$y') ||
          !furniture.any((f) => f.id == d['kind'])) {
        throw const FormatException('Dekorasi tidak valid.');
      }
      s.decor.add(Decoration(d['kind'], x, y));
    }
    if (!s.decor.any((d) => d.kind == 'table')) {
      throw const FormatException('Kafe membutuhkan meja.');
    }
    if (j['workers'] != null) {
      final rows = values('workers');
      if (rows.length > 3) throw const FormatException('Tim terlalu besar.');
      s.workers.clear();
      for (final w in rows) {
        if (!['Ayu', 'Raka', 'Mira'].contains(w['name']) ||
            s.workers.any((m) => m.name == w['name']) ||
            !['all', 'barista', 'server'].contains(w['role'])) {
          throw const FormatException('Staf tidak valid.');
        }
        s.workers.add(
          StaffMember(
            w['name'],
            role: w['role'],
            energy: number(w['energy'], 12),
            restUntil: number(w['restUntil']),
          ),
        );
      }
    }
    if (j['customers'] != null) {
      for (final c in values('customers')) {
        if (s.customers.length >= 48 ||
            c['id'] == 0 ||
            c['name'] is! String ||
            (c['name'] as String).isEmpty ||
            (c['name'] as String).length > 30 ||
            s.customers.any((v) => v.id == c['id'])) {
          throw const FormatException('Pelanggan tidak valid.');
        }
        s.customers.add(
          Customer(
            number(c['id'], 48),
            c['name'],
            number(c['look'], 100000),
            number(c['firstSeen']),
            visits: number(c['visits']),
          ),
        );
      }
    }
    if (j['disabledMenu'] != null) {
      s.disabledMenu.addAll(ids('disabledMenu', s.unlocked));
    }
    if (s.unlocked.difference(s.disabledMenu).isEmpty) {
      throw const FormatException('Menu harus tersedia.');
    }
    if (j['toolPositions'] != null) {
      if (j['toolPositions'] is! Map) {
        throw const FormatException('Posisi alat tidak valid.');
      }
      s.toolPositions.clear();
      final positions = <String>{};
      for (final entry in (j['toolPositions'] as Map).entries) {
        if (!s.machines.contains(entry.key)) {
          throw const FormatException('Alat tidak dikenal.');
        }
        final x = number(entry.value['x'], 7), y = number(entry.value['y'], 5);
        if ((y == 0 && (x < 1 || x > 6)) ||
            (y != 0 &&
                !s.decor.any(
                  (d) =>
                      d.x == x &&
                      d.y == y &&
                      ['table', 'counter'].contains(d.kind),
                )) ||
            !positions.add('$x,$y')) {
          throw const FormatException('Alat membutuhkan meja kosong.');
        }
        s.toolPositions[entry.key] = Decoration(entry.key, x, y);
      }
      if (s.toolPositions.length != s.machines.length) {
        throw const FormatException('Posisi alat belum lengkap.');
      }
      if (recipes
          .where((r) => s.unlocked.contains(r.id))
          .any((r) => !r.tools.every(s.machines.contains))) {
        throw const FormatException('Alat resep belum lengkap.');
      }
    } else {
      for (final recipe in recipes.where((r) => s.unlocked.contains(r.id))) {
        s.machines.addAll(recipe.tools);
      }
      for (final entry in s.machines.indexed) {
        s.toolPositions[entry.$2] = Decoration(entry.$2, entry.$1 + 1, 0);
      }
      // Old saves had chairs drawn as part of the table, rather than separate items.
      for (final table in s.decor.where((d) => d.kind == 'table').toList()) {
        for (final delta in [(0, 1), (1, 0), (0, -1), (-1, 0)]) {
          final x = table.x + delta.$1, y = table.y + delta.$2;
          if (x >= 0 &&
              x < 8 &&
              y > 0 &&
              y < 6 &&
              !s.decor.any((d) => d.x == x && d.y == y)) {
            s.decor.add(Decoration('chair', x, y));
            break;
          }
        }
      }
    }
    if (j['customers'] == null) {
      for (final entry in s.orders.indexed.toList()) {
        final o = entry.$2,
            id = entry.$1 + 1,
            seat = s.seats.isEmpty
                ? Decoration('chair', 2, 3)
                : s.seats[entry.$1 % s.seats.length];
        s.customers.add(Customer(id, o.name, id * 31, s.lastSeen));
        s.orders[entry.$1] = Order(
          o.id,
          o.name,
          o.recipe,
          o.deadline,
          customerId: id,
          seatX: seat.x,
          seatY: seat.y,
        );
      }
    }
    if (s.orders.any(
      (o) =>
          o.customerId < 1 ||
          !s.customers.any((c) => c.id == o.customerId && c.name == o.name),
    )) {
      throw const FormatException('Identitas pelanggan tidak valid.');
    }
    return s;
  }
}
