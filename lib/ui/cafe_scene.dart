import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../game/catalog.dart';
import '../game/engine.dart';
import '../game/state.dart';

/// The fixed isometric camera scales and pans, but never rotates.
/// Foreground animation repaints independently of simulation and persistence.
class CafeScene extends StatefulWidget {
  final CafeState state;
  final GameEngine? engine;
  final bool editing;
  final int? selected, selectedOrder;
  final void Function(int, int)? onTile;
  final void Function(int)? onCustomer;
  final void Function(String)? onTool;
  final void Function(int?, String?, int, int)? onMove;
  const CafeScene({
    super.key,
    required this.state,
    this.engine,
    this.editing = false,
    this.selected,
    this.selectedOrder,
    this.onTile,
    this.onCustomer,
    this.onTool,
    this.onMove,
  });
  @override
  State<CafeScene> createState() => _CafeSceneState();
}

class _CafeSceneState extends State<CafeScene>
    with SingleTickerProviderStateMixin {
  late final frames = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 60),
  )..repeat();
  final watch = Stopwatch()..start();
  final transform = TransformationController();
  int? dragging;
  String? draggingTool;
  Offset? preview;
  Size size = Size.zero;
  int get now => widget.engine?.now ?? widget.state.lastSeen;
  @override
  void dispose() {
    frames.dispose();
    transform.dispose();
    watch.stop();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant CafeScene old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) {
      dragging = null;
      draggingTool = null;
      preview = null;
    }
  }

  Offset world(Offset p) {
    final scale = math.min(size.width / 800, size.height / 560);
    return (p - Offset(size.width / 2, size.height * .28)) / scale;
  }

  Offset tile(Offset p) {
    final v = world(p);
    return Offset(
      ((v.dx / 42 + (v.dy + 13) / 23) / 2).floorToDouble(),
      (((v.dy + 13) / 23 - v.dx / 42) / 2).floorToDouble(),
    );
  }

  String? toolAt(Offset p) {
    final v = world(p);
    return widget.state.toolPositions.entries
        .where(
          (e) => (iso(e.value.x + .5, e.value.y + .5, 67) - v).distance < 25,
        )
        .firstOrNull
        ?.key;
  }

  int? furnitureAt(Offset p) {
    final point = world(p);
    final hits = widget.state.decor.indexed
        .where(
          (e) =>
              (iso(e.$2.x + .5, e.$2.y + .5, e.$2.kind == 'chair' ? 32 : 48) -
                      point)
                  .distance <
              32,
        )
        .toList();
    hits.sort(
      (a, b) => (iso(a.$2.x + .5, a.$2.y + .5, 45) - point).distance.compareTo(
        (iso(b.$2.x + .5, b.$2.y + .5, 45) - point).distance,
      ),
    );
    return hits.firstOrNull?.$1;
  }

  void tap(Offset p) {
    if (widget.editing) {
      final tool = toolAt(p);
      if (tool != null) {
        widget.onTool?.call(tool);
        return;
      }
      final i = furnitureAt(p);
      if (i != null) {
        final d = widget.state.decor[i];
        widget.onTile?.call(d.x, d.y);
        return;
      }
      final t = tile(p);
      widget.onTile?.call(t.dx.toInt(), t.dy.toInt());
      return;
    }
    final tool = toolAt(p);
    if (tool != null) {
      widget.onTool?.call(tool);
      return;
    }
    final v = world(p),
        o = widget.state.orders
            .where(
              (o) => (iso(o.seatX + .5, o.seatY + .5, 65) - v).distance < 44,
            )
            .firstOrNull;
    if (o != null) widget.onCustomer?.call(o.id);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, b) {
      size = Size(b.maxWidth, b.maxHeight);
      return ClipRect(
        child: InteractiveViewer(
          key: const ValueKey('cafe-camera'),
          transformationController: transform,
          minScale: .7,
          maxScale: 2.8,
          boundaryMargin: const EdgeInsets.all(180),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => tap(d.localPosition),
            onLongPressStart: widget.editing
                ? (d) {
                    final t = tile(d.localPosition);
                    setState(() {
                      draggingTool = toolAt(d.localPosition);
                      dragging = draggingTool == null
                          ? (furnitureAt(d.localPosition) ??
                                widget.state.decor.indexWhere(
                                  (v) => v.x == t.dx && v.y == t.dy,
                                ))
                          : null;
                      if (dragging == -1) dragging = null;
                      preview = t;
                    });
                  }
                : null,
            onLongPressMoveUpdate: widget.editing
                ? (d) => setState(() => preview = tile(d.localPosition))
                : null,
            onLongPressEnd: widget.editing
                ? (d) {
                    if (preview != null &&
                        (dragging != null || draggingTool != null)) {
                      widget.onMove?.call(
                        dragging,
                        draggingTool,
                        preview!.dx.toInt(),
                        preview!.dy.toInt(),
                      );
                    }
                    setState(() {
                      dragging = null;
                      draggingTool = null;
                      preview = null;
                    });
                  }
                : null,
            child: Stack(
              fit: StackFit.expand,
              children: [
                RepaintBoundary(
                  child: CustomPaint(
                    painter: RoomPainter(widget.state, widget.editing),
                  ),
                ),
                RepaintBoundary(
                  child: CustomPaint(
                    painter: PeoplePainter(
                      widget.state,
                      widget.engine,
                      frames,
                      watch,
                      () => now,
                      widget.selectedOrder,
                      preview,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Offset iso(num x, num y, [num z = 0]) =>
    Offset((x - y) * 42, (x + y) * 23 - z.toDouble());

class RoomPainter extends CustomPainter {
  final CafeState s;
  final bool editing;
  final String fingerprint;
  RoomPainter(this.s, this.editing)
    : fingerprint =
          '${s.theme}|$editing|${s.decor.map((d) => '${d.kind}:${d.x}:${d.y}').join(';')}|${s.toolPositions.entries.map((e) => '${e.key}:${e.value.x}:${e.value.y}').join(';')}';
  static void setup(Canvas c, Size size) {
    c.translate(size.width / 2, size.height * .28);
    c.scale(math.min(size.width / 800, size.height / 560));
  }

  static void poly(
    Canvas c,
    List<Offset> points,
    Color color, {
    bool stroke = false,
  }) => c.drawPath(
    Path()..addPolygon(points, true),
    Paint()
      ..color = color
      ..style = stroke ? PaintingStyle.stroke : PaintingStyle.fill
      ..strokeWidth = 1,
  );
  static void box(
    Canvas c,
    double x,
    double y,
    double w,
    double d,
    double h,
    Color color, [
    double z = 13,
  ]) {
    final a = iso(x, y, z),
        b = iso(x + w, y, z),
        e = iso(x + w, y + d, z),
        f = iso(x, y + d, z),
        up = Offset(0, -h);
    poly(c, [b, e, e + up, b + up], Color.lerp(color, Colors.black, .22)!);
    poly(c, [e, f, f + up, e + up], Color.lerp(color, Colors.black, .12)!);
    poly(c, [a + up, b + up, e + up, f + up], color);
  }

  static void text(Canvas c, String value, Offset p, double size, Color color) {
    final t = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontFamily: 'CafeSans',
          fontSize: size,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    t.paint(c, p - Offset(t.width / 2, t.height / 2));
  }

  static void line(
    Canvas c,
    Offset a,
    Offset b,
    Color color, [
    double width = 2,
  ]) => c.drawLine(
    a,
    b,
    Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round,
  );
  @override
  void paint(Canvas c, Size size) {
    c.save();
    setup(c, size);
    const wood = Color(0xFFC3996A),
        floor = Color(0xFFEBDDC7),
        green = Color(0xFF496D5B);
    final wall = s.theme == 'terracotta'
        ? const Color(0xFFE1AF96)
        : s.theme == 'midnight'
        ? const Color(0xFF536F70)
        : const Color(0xFFB4CDBA);
    c.drawOval(
      Rect.fromCenter(center: const Offset(40, 240), width: 650, height: 190),
      Paint()
        ..color = const Color(0x1851654B)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
    box(c, 0, 0, 8, 6, 13, floor, 0);
    for (var x = 0; x < 8; x++) {
      for (var y = 0; y < 6; y++) {
        final p = [
          iso(x, y, 13),
          iso(x + 1, y, 13),
          iso(x + 1, y + 1, 13),
          iso(x, y + 1, 13),
        ];
        poly(c, p, (x + y).isEven ? const Color(0xFFF2E8D5) : floor);
        if (editing) poly(c, p, const Color(0xFF8DA48D), stroke: true);
      }
    }
    poly(c, [
      iso(0, 0, 13),
      iso(8, 0, 13),
      iso(8, 0, 135),
      iso(0, 0, 135),
    ], wall);
    poly(c, [
      iso(0, 0, 13),
      iso(0, 6, 13),
      iso(0, 6, 135),
      iso(0, 0, 135),
    ], Color.lerp(wall, green, .18)!);
    for (final x in [1.0, 3.0, 5.0]) {
      poly(c, [
        iso(x, 0, 66),
        iso(x + 1.4, 0, 66),
        iso(x + 1.4, 0, 120),
        iso(x, 0, 120),
      ], const Color(0xFFFFF5DA));
      poly(c, [
        iso(x + .08, 0, 70),
        iso(x + 1.32, 0, 70),
        iso(x + 1.32, 0, 116),
        iso(x + .08, 0, 116),
      ], const Color(0xFFC6E2DE));
      line(
        c,
        iso(x + .7, 0, 70),
        iso(x + .7, 0, 116),
        const Color(0xFFFFF5DA),
        4,
      );
      line(c, iso(x, 0, 94), iso(x + 1.4, 0, 94), const Color(0xFFFFF5DA), 4);
    }
    poly(c, [
      iso(0, 1, 70),
      iso(0, 3.4, 70),
      iso(0, 3.4, 116),
      iso(0, 1, 116),
    ], const Color(0xFF385449));
    text(c, 'MY CLOUD', iso(0, 2.2, 102), 11, const Color(0xFFFFF0CA));
    text(c, 'CAFÉ', iso(0, 2.2, 86), 15, const Color(0xFFFFF0CA));
    box(c, 1, 0, 6, .85, 33, wood);
    text(c, 'MASUK / KELUAR', iso(7.5, 5.6, 14), 8, green);
    final items = s.decor.toList()
      ..sort((a, b) => (a.x + a.y).compareTo(b.x + b.y));
    for (final d in items) {
      final x = d.x + .12, y = d.y + .12;
      switch (d.kind) {
        case 'table':
        case 'counter':
          box(c, x + .35, y + .35, .15, .15, 28, const Color(0xFF805F42));
          box(
            c,
            x,
            y,
            .84,
            .84,
            7,
            d.kind == 'counter' ? const Color(0xFF7D9B8D) : wood,
            41,
          );
        case 'chair':
          box(c, x + .1, y + .1, .56, .56, 18, green);
          box(c, x + .1, y + .62, .56, .1, 22, green, 29);
        case 'plant':
          box(c, x + .2, y + .2, .45, .45, 18, const Color(0xFFCF9B73));
          final p = iso(x + .4, y + .4, 43);
          for (var i = 0; i < 7; i++) {
            final a = i * math.pi * 2 / 7;
            c.drawOval(
              Rect.fromCenter(
                center: p + Offset(math.cos(a) * 11, math.sin(a) * 10),
                width: 18,
                height: 11,
              ),
              Paint()..color = i.isEven ? green : const Color(0xFF7BA16B),
            );
          }
        case 'lamp':
          final p = iso(x + .4, y + .4, 14);
          c.drawOval(
            Rect.fromCenter(center: p, width: 24, height: 12),
            Paint()..color = wood,
          );
          line(c, p, p - const Offset(0, 68), wood, 3);
          poly(c, [
            p + const Offset(-18, -54),
            p + const Offset(18, -54),
            p + const Offset(10, -77),
            p + const Offset(-10, -77),
          ], const Color(0xFFF6DA9D));
        case 'shelf':
          box(c, x, y, .8, .4, 54, wood);
          for (var i = 0; i < 5; i++) {
            box(
              c,
              x + i * .14,
              y + .38,
              .1,
              .13,
              24,
              [wall, green, const Color(0xFFDCAC79)][i % 3],
              23,
            );
          }
      }
    }
    for (final e in s.toolPositions.entries) {
      final d = e.value, x = d.x + .18, y = d.y + .18;
      final color = switch (e.key) {
        'coffee' => green,
        'milk' => const Color(0xFFCAD7D4),
        'tea' => const Color(0xFFDDBB72),
        'chocolate' => const Color(0xFF9B6B52),
        _ => const Color(0xFF78858C),
      };
      box(c, x, y, .65, .55, 23, color, 48);
      box(c, x + .08, y + .49, .48, .07, 10, const Color(0xFFD7DFD6), 50);
      text(
        c,
        switch (e.key) {
          'coffee' => 'ESP',
          'milk' => 'MILK',
          'tea' => 'TEA',
          'oven' => 'OVEN',
          'freezer' => 'ICE',
          _ => 'CHOCO',
        },
        iso(x + .3, y + .55, 68),
        7,
        const Color(0xFF263F36),
      );
    }
    c.restore();
  }

  @override
  bool shouldRepaint(covariant RoomPainter old) =>
      fingerprint != old.fingerprint;
}

class PeoplePainter extends CustomPainter {
  final CafeState s;
  final GameEngine? engine;
  final Stopwatch watch;
  final int Function() clock;
  final int? selected;
  final Offset? preview;
  final Map<int, List<Offset>> routes;
  PeoplePainter(
    this.s,
    this.engine,
    Listenable frames,
    this.watch,
    this.clock,
    this.selected,
    this.preview,
  ) : routes = {
        for (final o in [
          ...s.orders,
          ...?(engine?.departures.map((d) => d.order)),
        ])
          o.id: cafeRoute(s, Offset(o.seatX + .5, o.seatY + .5)),
      },
      super(repaint: frames);
  static const shirts = [
    Color(0xFFD39264),
    Color(0xFF7899AF),
    Color(0xFFB87E8D),
    Color(0xFF9AA66B),
    Color(0xFF9B87B1),
    Color(0xFF6DA49E),
  ];
  static void person(
    Canvas c,
    Offset p,
    int look,
    double phase, {
    bool walking = false,
    bool staff = false,
  }) {
    final skin = [
          const Color(0xFFEBC39F),
          const Color(0xFFBD8C64),
          const Color(0xFF8F6249),
        ][look % 3],
        hair = [
          const Color(0xFF4B3930),
          const Color(0xFF795439),
          const Color(0xFF292F32),
        ][(look ~/ 3) % 3];
    c.drawOval(
      Rect.fromCenter(center: p + const Offset(0, 2), width: 23, height: 10),
      Paint()..color = const Color(0x1F243D30),
    );
    final stride = walking ? math.sin(phase) * 5 : 0.0,
        bob = walking
            ? math.sin(phase * 2).abs() * 2
            : math.sin(phase * .3) * .7;
    p = p - Offset(0, bob);
    RoomPainter.line(
      c,
      p + Offset(-5, stride),
      p + const Offset(-4, -15),
      const Color(0xFF42504A),
      5,
    );
    RoomPainter.line(
      c,
      p + Offset(5, -stride),
      p + const Offset(4, -15),
      const Color(0xFF42504A),
      5,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: p - const Offset(0, 25), width: 24, height: 27),
        const Radius.circular(7),
      ),
      Paint()..color = shirts[look % shirts.length],
    );
    if (staff) {
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: p - const Offset(0, 24),
            width: 15,
            height: 21,
          ),
          const Radius.circular(3),
        ),
        Paint()..color = const Color(0xFF315B4B),
      );
    }
    RoomPainter.line(
      c,
      p + Offset(-13, -31),
      p + Offset(-15, -17 - stride),
      skin,
      4,
    );
    RoomPainter.line(
      c,
      p + Offset(13, -31),
      p + Offset(15, -17 + stride),
      skin,
      4,
    );
    c.drawCircle(p - const Offset(0, 46), 11, Paint()..color = hair);
    c.drawCircle(p - const Offset(0, 43), 9, Paint()..color = skin);
    c.drawArc(
      Rect.fromCircle(center: p - const Offset(0, 47), radius: 11),
      math.pi,
      math.pi,
      true,
      Paint()..color = hair,
    );
    if (look.isEven) {
      c.drawCircle(p + const Offset(-8, -49), 5, Paint()..color = hair);
    }
    for (final x in [-3.0, 3.0]) {
      c.drawCircle(
        p + Offset(x, -43),
        1,
        Paint()..color = const Color(0xFF3B3932),
      );
    }
    if (look % 4 == 0) {
      for (final x in [-4.0, 4.0]) {
        c.drawCircle(
          p + Offset(x, -43),
          4,
          Paint()
            ..color = hair
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }
    }
  }

  @override
  void paint(Canvas c, Size size) {
    c.save();
    RoomPainter.setup(c, size);
    final now = clock(), phase = watch.elapsedMilliseconds / 110;
    for (final w in s.workers.indexed) {
      final home = Offset(3 + w.$1 * 1.3, 1.5),
          motion = engine?.staffMotions[w.$2.name];
      final elapsed = motion == null
          ? 1.0
          : ((now - motion.$3) / GameEngine.walkMillis).clamp(0.0, 1.0);
      final position = motion == null
          ? home
          : Offset.lerp(
              home,
              Offset(motion.$1, motion.$2),
              1 - (elapsed * 2 - 1).abs(),
            )!;
      person(
        c,
        iso(position.dx, position.dy, 13),
        w.$1 + 1,
        phase,
        staff: true,
        walking: elapsed < 1,
      );
      RoomPainter.text(
        c,
        w.$2.name,
        iso(position.dx, position.dy, 78),
        9,
        const Color(0xFF315B4B),
      );
    }
    final all = [
      ...s.orders.map((o) => (o, false, o.arrivedAt)),
      ...?(engine?.departures.map((d) => (d.order, true, d.leftAt))),
    ];
    all.sort(
      (a, b) => (a.$1.seatX + a.$1.seatY).compareTo(b.$1.seatX + b.$1.seatY),
    );
    for (final item in all) {
      final o = item.$1,
          t = ((now - item.$3) / GameEngine.walkMillis).clamp(0.0, 1.0),
          route = routes[o.id]!,
          progress = item.$2 ? 1 - t : t,
          scaled = progress * (route.length - 1);
      final i = scaled.floor().clamp(0, route.length - 2),
          position = Offset.lerp(
            route[i],
            route[i + 1],
            (scaled - i).clamp(0, 1),
          )!;
      final p = iso(position.dx, position.dy, 13),
          customer = s.customers.where((v) => v.id == o.customerId).firstOrNull;
      person(c, p, customer?.look ?? o.id, phase, walking: t < 1);
      if (!item.$2 && t >= 1) {
        final b = engine?.brewFor(o.id),
            ready =
                b != null && b.readyAt <= now && engine?.nextStep(o.id) == null;
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: p - const Offset(0, 84),
              width: 94,
              height: 34,
            ),
            const Radius.circular(10),
          ),
          Paint()
            ..color = o.id == selected
                ? const Color(0xFFFFE1A0)
                : const Color(0xFFFFFDF5),
        );
        RoomPainter.text(
          c,
          o.name,
          p - const Offset(0, 90),
          10,
          const Color(0xFF315B4B),
        );
        RoomPainter.text(
          c,
          ready ? 'Siap • Sajikan' : recipeById(o.recipe).name,
          p - const Offset(0, 77),
          8,
          const Color(0xFF526E5B),
        );
        if (b != null && b.readyAt > now) {
          final v = ((now - b.startedAt) / (b.readyAt - b.startedAt)).clamp(
            0.0,
            1.0,
          );
          c.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(p.dx - 34, p.dy - 65, 68 * v, 3),
              const Radius.circular(2),
            ),
            Paint()..color = const Color(0xFF5A8D69),
          );
        }
      }
    }
    for (final b in s.brews.where((b) => b.readyAt > now)) {
      final o = s.orders.where((o) => o.id == b.orderId).firstOrNull;
      if (o == null) continue;
      final tool = recipeById(o.recipe).steps[b.step].tool,
          p = s.toolPositions[tool];
      if (p == null) continue;
      for (var i = 0; i < 3; i++) {
        final t = ((watch.elapsedMilliseconds / 1100) + i / 3) % 1,
            pos =
                iso(p.x + .5, p.y + .5, 83) +
                Offset(math.sin(t * 5 + i) * 4, -t * 21);
        c.drawCircle(
          pos,
          2 + t * 2,
          Paint()..color = Colors.white.withValues(alpha: (1 - t) * .7),
        );
      }
    }
    if (preview != null) {
      final p = preview!;
      RoomPainter.poly(c, [
        iso(p.dx, p.dy, 15),
        iso(p.dx + 1, p.dy, 15),
        iso(p.dx + 1, p.dy + 1, 15),
        iso(p.dx, p.dy + 1, 15),
      ], const Color(0x99E6BC67));
    }
    c.restore();
  }

  @override
  bool shouldRepaint(covariant PeoplePainter old) => true;
}

List<Offset> cafeRoute(CafeState s, Offset destination) {
  const entrance = (7, 5);
  final target = (destination.dx.floor(), destination.dy.floor());
  final blocked = s.decor
      .where((d) => !(d.x == target.$1 && d.y == target.$2))
      .map((d) => (d.x, d.y))
      .toSet();
  final queue = [entrance], parents = <(int, int), (int, int)?>{entrance: null};
  for (var i = 0; i < queue.length; i++) {
    final p = queue[i];
    if (p == target) break;
    for (final d in [(0, -1), (-1, 0), (1, 0), (0, 1)]) {
      final n = (p.$1 + d.$1, p.$2 + d.$2);
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
  if (!parents.containsKey(target)) {
    return [const Offset(7.5, 5.5), destination];
  }
  final result = <Offset>[];
  (int, int)? at = target;
  while (at != null) {
    result.add(Offset(at.$1 + .5, at.$2 + .5));
    at = parents[at];
  }
  return result.length > 1
      ? result.reversed.toList()
      : [const Offset(8, 6), destination];
}
