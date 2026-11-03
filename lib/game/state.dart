import 'dart:convert';

import 'catalog.dart';

class Order {
  final int id;
  final String name, recipe;
  int deadline;
  Order(this.id, this.name, this.recipe, this.deadline);
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'recipe': recipe,
    'deadline': deadline,
  };
}

class Brew {
  final int orderId, startedAt, readyAt;
  Brew(this.orderId, this.startedAt, this.readyAt);
  Map<String, dynamic> toJson() => {
    'orderId': orderId,
    'startedAt': startedAt,
    'readyAt': readyAt,
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
  bool staff = false;
  String theme = 'sage';
  final Set<String> unlocked = {'espresso'}, machines = {'coffee'};
  final Set<int> stories = {}, claimedGoals = {};
  final List<Order> orders = [];
  final List<Brew> brews = [];
  final List<Decoration> decor = [
    Decoration('table', 2, 2),
    Decoration('table', 5, 3),
    Decoration('plant', 0, 4),
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
  int get capacity => decor.where((d) => d.kind == 'table').length.clamp(1, 6);

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
        values('brews').length > 2 ||
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
      s.orders.add(Order(id, o['name'], o['recipe'], number(o['deadline'])));
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
      s.brews.add(Brew(id, start, end));
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
    return s;
  }
}
