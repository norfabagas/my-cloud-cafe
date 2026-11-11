import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_web_cafe/game/engine.dart';
import 'package:my_web_cafe/game/state.dart';
import 'package:my_web_cafe/persistence/save_store.dart';
import 'package:my_web_cafe/ui/game_shell.dart';
import 'package:my_web_cafe/ui/cafe_scene.dart';

void main() {
  for (final size in [
    const Size(360, 740),
    const Size(768, 1000),
    const Size(1024, 600),
    const Size(1440, 900),
  ]) {
    final width = size.width;
    testWidgets('main views fit ${width.toInt()}px', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final store = SaveStore(await SharedPreferences.getInstance());
      final engine = GameEngine(
        CafeState(1700000000000),
        clock: () => 1700000000000,
      )..resume();
      await tester.pumpWidget(
        MaterialApp(
          home: GameShell(engine: engine, store: store),
        ),
      );
      expect(find.text('Kafe hari ini'), findsOneWidget);
      expect(tester.takeException(), isNull);
      for (final label in [
        'Menu',
        'Toko',
        'Tim',
        'Pelanggan',
        'Cerita',
        'Akun & data',
      ]) {
        await tester.ensureVisible(find.text(label).first);
        await tester.tap(find.text(label).first);
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.byType(CafeScene), findsOneWidget);
        expect(find.byType(Dialog), findsOneWidget);
        expect(tester.takeException(), isNull, reason: '$label at $width');
        await tester.tap(find.byTooltip('Tutup').first);
        await tester.pump(const Duration(milliseconds: 350));
      }
      await tester.pumpWidget(const SizedBox());
      engine.dispose();
    });
  }
}
