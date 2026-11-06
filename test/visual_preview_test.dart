import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_web_cafe/game/engine.dart';
import 'package:my_web_cafe/game/state.dart';
import 'package:my_web_cafe/persistence/save_store.dart';
import 'package:my_web_cafe/ui/game_shell.dart';

void main() {
  testWidgets('visual review of the rendered café', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      final font = FontLoader('CafeSans')
        ..addFont(rootBundle.load('assets/fonts/Roboto-Regular.ttf'))
        ..addFont(rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
      final emoji = FontLoader('CafeEmoji')
        ..addFont(rootBundle.load('assets/fonts/CafeEmoji.ttf'));
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await font.load();
      await emoji.load();
      await icons.load();
    });
    SharedPreferences.setMockInitialValues({});
    final store = SaveStore(await SharedPreferences.getInstance());
    final game = GameEngine(
      CafeState(1700000000000),
      clock: () => 1700000000000,
    )..resume();
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            fontFamily: 'CafeSans',
            fontFamilyFallback: ['CafeEmoji'],
            colorScheme: ColorScheme.fromSeed(seedColor: sage),
            textTheme: ThemeData.light().textTheme.apply(
              fontFamily: 'CafeSans',
              bodyColor: ink,
              displayColor: ink,
            ),
          ),
          home: GameShell(engine: game, store: store),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final image =
          await (key.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('build/qa').create(recursive: true);
      await File(
        'build/qa/cafe-desktop.png',
      ).writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
    await tester.pumpWidget(const SizedBox());
    game.dispose();
  });
}
