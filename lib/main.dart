import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cloud/cloud_controller.dart';
import 'cloud/account_panel.dart';
import 'game/engine.dart';
import 'persistence/save_store.dart';
import 'ui/game_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  final store = SaveStore(preferences);
  final engine = GameEngine(store.load(DateTime.now().millisecondsSinceEpoch));
  SupabaseClient? client;
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_ANON_KEY');
  if (url.isNotEmpty && key.isNotEmpty) {
    try {
      await Supabase.initialize(url: url, anonKey: key);
      client = Supabase.instance.client;
    } catch (_) {
      // A failed optional cloud connection must never prevent local play.
    }
  }
  final cloud = CloudController(client: client, store: store, engine: engine);
  await cloud.initialize();
  engine.resume();
  try {
    await store.save(engine.state);
  } catch (_) {
    store.warning =
        'Progres belum tersimpan. Salin cadangan melalui Akun & data.';
  }
  runApp(CafeApp(engine: engine, store: store, cloud: cloud));
}

class CafeApp extends StatelessWidget {
  final GameEngine engine;
  final SaveStore store;
  final CloudController cloud;
  const CafeApp({
    super.key,
    required this.engine,
    required this.store,
    required this.cloud,
  });
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'My Cloud Café',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'CafeSans',
      fontFamilyFallback: const ['CafeEmoji'],
      scaffoldBackgroundColor: cream,
      colorScheme: ColorScheme.fromSeed(
        seedColor: sage,
        surface: const Color(0xFFFFFDF8),
      ),
      textTheme: ThemeData.light().textTheme.apply(
        fontFamily: 'CafeSans',
        fontFamilyFallback: const ['CafeEmoji'],
        bodyColor: ink,
        displayColor: ink,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: sage,
          foregroundColor: Colors.white,
          minimumSize: const Size(44, 46),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: sage,
          minimumSize: const Size(44, 44),
          side: const BorderSide(color: Color(0xFFCED8C7)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
      ),
      snackBarTheme: const SnackBarThemeData(backgroundColor: ink),
      navigationBarTheme: const NavigationBarThemeData(
        indicatorColor: Color(0xFFDDE8D8),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
        ),
      ),
    ),
    home: GameShell(
      engine: engine,
      store: store,
      accountPanel: AccountPanel(controller: cloud),
      onSaved: cloud.markDirty,
    ),
  );
}
