import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/state.dart';

class CafeScene extends StatelessWidget {
  final CafeState state;
  final bool editing;
  final int? selected;
  final void Function(int x, int y)? onTile;
  const CafeScene({
    super.key,
    required this.state,
    this.editing = false,
    this.selected,
    this.onTile,
  });
  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 1.65,
    child: LayoutBuilder(
      builder: (context, bounds) => Semantics(
        label:
            'Denah kafe dengan ${state.capacity} meja dan ${state.orders.length} pelanggan',
        child: GestureDetector(
          onTapUp: onTile == null
              ? null
              : (tap) {
                  final scale = math.min(
                    bounds.maxWidth / 800,
                    bounds.maxHeight / 470,
                  );
                  final dx =
                      (tap.localPosition.dx - bounds.maxWidth / 2) / scale;
                  final dy =
                      (tap.localPosition.dy - bounds.maxHeight * .32) / scale;
                  final correctedX = (dx / 42 + (dy + 13) / 23) / 2;
                  final y = ((dy + 13) / 23 - dx / 42) / 2;
                  onTile!(correctedX.floor(), y.floor());
                },
          child: RepaintBoundary(
            child: CustomPaint(
              size: Size(bounds.maxWidth, bounds.maxHeight),
              painter: _CafePainter(state, editing, selected),
            ),
          ),
        ),
      ),
    ),
  );
}

class _CafePainter extends CustomPainter {
  final CafeState s;
  final bool editing;
  final int? selected;
  final String fingerprint;
  _CafePainter(this.s, this.editing, this.selected)
    : fingerprint =
          '${s.theme}|${s.staff}|${s.orders.length}|${s.machines.join(',')}|${s.decor.map((d) => '${d.kind}:${d.x}:${d.y}').join(';')}|$editing|$selected';
  static const wood = Color(0xFFBC8256), edge = Color(0xFF845E44);
  Offset iso(num x, num y, [num z = 0]) =>
      Offset((x - y) * 42, (x + y) * 23 - z.toDouble());
  void poly(Canvas c, List<Offset> p, Color color, {bool stroke = false}) {
    final path = Path()..addPolygon(p, true);
    c.drawPath(
      path,
      Paint()
        ..color = color
        ..style = stroke ? PaintingStyle.stroke : PaintingStyle.fill
        ..strokeWidth = 1,
    );
  }

  void box(
    Canvas c,
    double x,
    double y,
    double w,
    double d,
    double h,
    Color top,
    Color front,
    Color side, [
    double z = 0,
  ]) {
    final a = iso(x, y, z),
        b = iso(x + w, y, z),
        e = iso(x + w, y + d, z),
        f = iso(x, y + d, z);
    final up = Offset(0, -h);
    poly(c, [b, e, e + up, b + up], side);
    poly(c, [e, f, f + up, e + up], front);
    poly(c, [a + up, b + up, e + up, f + up], top);
  }

  void line(Canvas c, Offset a, Offset b, Color color, [double width = 2]) =>
      c.drawLine(
        a,
        b,
        Paint()
          ..color = color
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );
  void text(
    Canvas c,
    String value,
    Offset p,
    double size,
    Color color, {
    FontWeight weight = FontWeight.w700,
  }) {
    final t = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontFamily: 'CafeSans',
          fontSize: size,
          color: color,
          fontWeight: weight,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    t.paint(c, p - Offset(t.width / 2, t.height / 2));
  }

  @override
  void paint(Canvas c, Size size) {
    final scale = math.min(size.width / 800, size.height / 470);
    c.save();
    c.translate(size.width / 2, size.height * .32);
    c.scale(scale);
    final wall = s.theme == 'terracotta'
        ? const Color(0xFFE5B3A0)
        : s.theme == 'midnight'
        ? const Color(0xFF58716E)
        : const Color(0xFFB8CFC3);
    final wallSide = Color.lerp(wall, const Color(0xFF375B50), .16)!;
    c.drawOval(
      Rect.fromCenter(center: const Offset(35, 200), width: 650, height: 195),
      Paint()
        ..color = const Color(0xFF4C6755).withValues(alpha: .10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
    box(
      c,
      0,
      0,
      8,
      6,
      13,
      const Color(0xFFEADFC9),
      const Color(0xFFC4AF8D),
      const Color(0xFFB29A7E),
    );
    for (var x = 0; x < 8; x++) {
      for (var y = 0; y < 6; y++) {
        final color = (x + y).isEven
            ? const Color(0xFFF0E6D5)
            : const Color(0xFFE5D8BF);
        poly(c, [
          iso(x, y, 13),
          iso(x + 1, y, 13),
          iso(x + 1, y + 1, 13),
          iso(x, y + 1, 13),
        ], color);
        if (editing && y > 0) {
          poly(
            c,
            [
              iso(x, y, 13),
              iso(x + 1, y, 13),
              iso(x + 1, y + 1, 13),
              iso(x, y + 1, 13),
            ],
            const Color(0xFF829B86),
            stroke: true,
          );
        }
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
    ], wallSide);
    line(c, iso(0, 0, 16), iso(8, 0, 16), const Color(0xFF6C8876), 5);
    line(c, iso(0, 0, 16), iso(0, 6, 16), const Color(0xFF6C8876), 5);
    // Window panes, sunshine and the back-wall menu are drawn locally.
    for (final x in [1.0, 3.0, 5.0]) {
      poly(c, [
        iso(x, 0, 61),
        iso(x + 1.45, 0, 61),
        iso(x + 1.45, 0, 119),
        iso(x, 0, 119),
      ], const Color(0xFFF8F1D7));
      poly(c, [
        iso(x + .09, 0, 65),
        iso(x + 1.36, 0, 65),
        iso(x + 1.36, 0, 115),
        iso(x + .09, 0, 115),
      ], const Color(0xFFC6E1DD));
      line(
        c,
        iso(x + .72, 0, 64),
        iso(x + .72, 0, 117),
        const Color(0xFFF8F1D7),
        4,
      );
      line(c, iso(x, 0, 90), iso(x + 1.45, 0, 90), const Color(0xFFF8F1D7), 4);
      box(
        c,
        x,
        -.02,
        1.45,
        .25,
        5,
        const Color(0xFFF8F1D7),
        const Color(0xFFCEBDA1),
        const Color(0xFFCEBDA1),
        60,
      );
    }
    poly(c, [
      iso(0, 1, 70),
      iso(0, 2.8, 70),
      iso(0, 2.8, 115),
      iso(0, 1, 115),
    ], const Color(0xFF88674C));
    poly(c, [
      iso(0, 1.08, 74),
      iso(0, 2.72, 74),
      iso(0, 2.72, 111),
      iso(0, 1.08, 111),
    ], const Color(0xFF314C43));
    text(c, 'COFFEE', iso(0, 1.9, 99), 12, const Color(0xFFE8DDC1));
    text(c, '& good company', iso(0, 1.9, 84), 7, const Color(0xFFE8DDC1));
    box(
      c,
      1,
      .4,
      5.8,
      .7,
      35,
      const Color(0xFFCCAA82),
      const Color(0xFF996D4B),
      const Color(0xFF7D583E),
      13,
    );
    for (var x = 1.0; x < 6.5; x += 1.1) {
      line(c, iso(x, 1.1, 16), iso(x, 1.1, 45), const Color(0xFFBC926B), 1);
    }
    box(
      c,
      1.3,
      .45,
      1.15,
      .55,
      26,
      const Color(0xFF66817A),
      const Color(0xFF3E5F57),
      const Color(0xFF294A43),
      48,
    );
    box(
      c,
      1.42,
      .91,
      .8,
      .1,
      12,
      const Color(0xFFD4DBD4),
      const Color(0xFFABB8AC),
      const Color(0xFF94A79C),
      54,
    );
    for (final x in [1.6, 1.95]) {
      c.drawCircle(
        iso(x, 1.04, 65),
        3,
        Paint()..color = const Color(0xFFE4CE9C),
      );
    }
    if (s.machines.contains('tea')) {
      box(
        c,
        3,
        .52,
        .5,
        .4,
        23,
        const Color(0xFFD9BA77),
        const Color(0xFFCCAA62),
        const Color(0xFFB89346),
        48,
      );
    }
    if (s.machines.contains('milk')) {
      box(
        c,
        4,
        .52,
        .4,
        .4,
        20,
        const Color(0xFFD9E2DB),
        const Color(0xFFA6B7AF),
        const Color(0xFF809D8E),
        48,
      );
    }
    if (s.machines.contains('oven')) {
      box(
        c,
        5,
        .47,
        .9,
        .5,
        25,
        const Color(0xFF646F6A),
        const Color(0xFF333F38),
        const Color(0xFF505E55),
        48,
      );
    }
    for (var i = 0; i < 3; i++) {
      c.drawOval(
        Rect.fromCenter(center: iso(3.5 + i * .3, .8, 50), width: 8, height: 5),
        Paint()..color = const Color(0xFFFFFBF0),
      );
    }
    _person(c, 3.6, 1.45, const Color(0xFFD18C73), true);
    if (s.staff) _person(c, 5.9, 1.6, const Color(0xFF6988A3), true);
    final items = s.decor.indexed.toList()
      ..sort((a, b) => (a.$2.x + a.$2.y).compareTo(b.$2.x + b.$2.y));
    var customer = 0;
    for (final item in items) {
      final d = item.$2, x = d.x + .15, y = d.y + .15;
      if (selected == item.$1) {
        poly(c, [
          iso(d.x, d.y, 14),
          iso(d.x + 1, d.y, 14),
          iso(d.x + 1, d.y + 1, 14),
          iso(d.x, d.y + 1, 14),
        ], const Color(0xFFEDD18B));
      }
      switch (d.kind) {
        case 'table':
          box(c, x + .25, y + .3, .12, .12, 22, edge, edge, edge, 13);
          box(c, x, y, .85, .75, 7, wood, const Color(0xFF9B6B49), edge, 35);
          box(
            c,
            x + .15,
            y + .85,
            .45,
            .35,
            17,
            const Color(0xFF6C8C76),
            const Color(0xFF496D56),
            const Color(0xFF3C5E49),
            13,
          );
          box(
            c,
            x + .15,
            y + 1.12,
            .45,
            .1,
            18,
            const Color(0xFF6C8C76),
            const Color(0xFF496D56),
            const Color(0xFF3C5E49),
            25,
          );
          if (customer < s.orders.length) {
            _person(
              c,
              x + 1,
              y + .2,
              [
                const Color(0xFFE1AA58),
                const Color(0xFF8A9CB4),
                const Color(0xFFC47F7B),
              ][customer % 3],
              false,
            );
            c.drawOval(
              Rect.fromCenter(
                center: iso(x + .4, y + .35, 44),
                width: 12,
                height: 7,
              ),
              Paint()..color = const Color(0xFFF9F4E8),
            );
            c.drawCircle(
              iso(x + .4, y + .35, 46),
              3,
              Paint()..color = const Color(0xFF7E583D),
            );
            customer++;
          }
        case 'plant':
          box(
            c,
            x + .2,
            y + .2,
            .45,
            .45,
            17,
            const Color(0xFFD8B290),
            const Color(0xFFB7805C),
            const Color(0xFFA46C4B),
            13,
          );
          final p = iso(x + .4, y + .4, 36);
          for (var i = 0; i < 7; i++) {
            final a = i * math.pi * 2 / 7;
            c.drawOval(
              Rect.fromCenter(
                center: p + Offset(math.cos(a) * 11, math.sin(a) * 10 - 9),
                width: 17,
                height: 9,
              ),
              Paint()
                ..color = i.isEven
                    ? const Color(0xFF507D55)
                    : const Color(0xFF729662),
            );
          }
        case 'lamp':
          final p = iso(x + .4, y + .4, 14);
          c.drawOval(
            Rect.fromCenter(center: p, width: 23, height: 12),
            Paint()..color = edge,
          );
          line(c, p, p - const Offset(0, 62), edge, 3);
          poly(c, [
            p + const Offset(-17, -55),
            p + const Offset(17, -55),
            p + const Offset(10, -75),
            p + const Offset(-10, -75),
          ], const Color(0xFFF0D39E));
        case 'shelf':
          box(c, x, y, .8, .35, 52, wood, edge, const Color(0xFF75543D), 13);
          for (var i = 0; i < 5; i++) {
            box(
              c,
              x + i * .14,
              y + .34,
              .1,
              .12,
              22,
              [wall, const Color(0xFFDEA17E), const Color(0xFFE1CB95)][i % 3],
              const Color(0xFFCEA77A),
              wall,
              21,
            );
          }
      }
    }
    c.restore();
  }

  void _person(Canvas c, double x, double y, Color shirt, bool apron) {
    final p = iso(x, y, 13);
    c.drawOval(
      Rect.fromCenter(center: p + const Offset(0, 2), width: 21, height: 9),
      Paint()..color = Colors.black.withValues(alpha: .12),
    );
    line(
      c,
      p + const Offset(-4, 0),
      p + const Offset(-4, -16),
      const Color(0xFF444E49),
      4,
    );
    line(
      c,
      p + const Offset(4, 0),
      p + const Offset(4, -16),
      const Color(0xFF444E49),
      4,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: p - const Offset(0, 24), width: 22, height: 26),
        const Radius.circular(6),
      ),
      Paint()..color = shirt,
    );
    if (apron) {
      c.drawRect(
        Rect.fromCenter(center: p - const Offset(0, 23), width: 13, height: 20),
        Paint()..color = const Color(0xFF38594F),
      );
    }
    c.drawCircle(
      p - const Offset(0, 44),
      10,
      Paint()..color = const Color(0xFF513E33),
    );
    c.drawCircle(
      p - const Offset(0, 41),
      8,
      Paint()..color = const Color(0xFFE4B390),
    );
    c.drawArc(
      Rect.fromCircle(center: p - const Offset(0, 44), radius: 10),
      math.pi,
      math.pi,
      true,
      Paint()..color = const Color(0xFF513E33),
    );
  }

  @override
  bool shouldRepaint(covariant _CafePainter oldDelegate) =>
      oldDelegate.fingerprint != fingerprint;
}
