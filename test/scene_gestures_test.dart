import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_web_cafe/game/state.dart';
import 'package:my_web_cafe/ui/cafe_scene.dart';

void main() {
  testWidgets(
    'pinch zoom preserves rotation; long press moves furniture in transformed space',
    (tester) async {
      tester.view.physicalSize = const Size(900, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final s = CafeState(1000);
      (int?, String?, int, int)? drop;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CafeScene(
              state: s,
              editing: true,
              onMove: (i, t, x, y) => drop = (i, t, x, y),
            ),
          ),
        ),
      );
      final camera = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      final a = await tester.startGesture(const Offset(400, 300), pointer: 1),
          b = await tester.startGesture(const Offset(500, 300), pointer: 2);
      await tester.pump();
      await a.moveTo(const Offset(340, 300));
      await b.moveTo(const Offset(560, 300));
      await tester.pump();
      await a.up();
      await b.up();
      await tester.pump();
      final matrix = camera.transformationController!.value;
      expect(matrix.getMaxScaleOnAxis(), greaterThan(1));
      expect(matrix.entry(0, 1), 0);
      expect(matrix.entry(1, 0), 0);
      final rect = tester.getRect(find.byType(CafeScene)),
          scale = math.min(rect.width / 800, rect.height / 560);
      Offset point(double x, double y, double z) =>
          rect.topLeft +
          MatrixUtils.transformPoint(
            matrix,
            Offset(rect.width / 2, rect.height * .28) + iso(x, y, z) * scale,
          );
      final gesture = await tester.startGesture(point(.5, 4.5, 48), pointer: 3);
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveTo(point(4.5, 4.5, 13));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      expect(drop, (2, null, 4, 4));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  test('paths avoid furniture and preserve entrance-to-seat continuity', () {
    final s = CafeState(1000);
    for (final seat in s.seats) {
      final path = s.pathTo(seat.x, seat.y);
      expect(path.first, (7, 5));
      expect(path.last, (seat.x, seat.y));
      for (var i = 1; i < path.length; i++) {
        expect(
          (path[i].$1 - path[i - 1].$1).abs() +
              (path[i].$2 - path[i - 1].$2).abs(),
          1,
        );
      }
      for (final cell in path.take(path.length - 1)) {
        expect(s.decor.any((d) => d.x == cell.$1 && d.y == cell.$2), isFalse);
      }
    }
  });
}
