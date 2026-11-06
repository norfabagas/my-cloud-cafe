import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_web_cafe/cloud/auth_gate.dart';
import 'package:my_web_cafe/cloud/cloud_controller.dart';
import 'package:my_web_cafe/cloud/cloud_service.dart';
import 'package:my_web_cafe/game/engine.dart';
import 'package:my_web_cafe/game/state.dart';
import 'package:my_web_cafe/persistence/save_store.dart';

Map<String, dynamic> authSession(
  String id, {
  bool anonymous = false,
  int? expiresAt,
}) {
  final expiry =
      expiresAt ?? DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600;
  String part(Map<String, dynamic> value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return {
    'access_token':
        '${part({'alg': 'HS256'})}.${part({'sub': id, 'exp': expiry, 'role': 'authenticated', 'is_anonymous': anonymous})}.test',
    'token_type': 'bearer',
    'refresh_token': 'test-refresh',
    'expires_in': 3600,
    'user': {
      'id': id,
      'aud': 'authenticated',
      'email': '$id@example.invalid',
      'is_anonymous': anonymous,
      'app_metadata': {},
      'user_metadata': {},
      'created_at': '2026-01-01T00:00:00Z',
    },
  };
}

class MemoryCloud extends CloudService {
  final Map<String, CloudSnapshot> saves = {};
  MemoryCloud(super.client);
  @override
  Future<CloudSnapshot?> read(String ownerId) async => saves[ownerId];
  @override
  Future<int> write(
    String raw, {
    required String ownerId,
    required int expectedRevision,
  }) async {
    saves[ownerId] = CloudSnapshot(
      CafeState.decode(raw),
      expectedRevision + 1,
      DateTime.now(),
    );
    return expectedRevision + 1;
  }
}

Future<void> settled(CloudController c) async {
  await Future<void>.delayed(
    Duration.zero,
  ); // Deliver SDK auth stream events first.
  final deadline = DateTime.now().add(const Duration(seconds: 3));
  while (c.busy && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
  expect(c.busy, isFalse);
}

void main() {
  late HttpServer backend;
  late SupabaseClient client;
  late SaveStore store;
  late GameEngine engine;
  late CloudController c;
  late MemoryCloud cloud;
  String? launchedUrl;
  bool launchOk = true;
  setUp(() async {
    launchedUrl = null;
    launchOk = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/url_launcher'),
          (call) async {
            if (call.method == 'launch') {
              launchedUrl = (call.arguments as Map)['url'] as String;
            }
            return launchOk;
          },
        );
    HttpOverrides.global =
        null; // Exercise the real SDK against the local HTTP fixture.
    SharedPreferences.setMockInitialValues({});
    store = SaveStore(await SharedPreferences.getInstance());
    engine = GameEngine(CafeState(1700000000000), clock: () => 1700000000000);
    backend = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    backend.listen((r) async {
      r.response.headers.contentType = ContentType.json;
      if (r.uri.path.endsWith('/logout')) {
        r.response.statusCode = 204;
      } else {
        r.response.statusCode = 404;
        r.response.write('{}');
      }
      await r.response.close();
    });
    client = SupabaseClient(
      'http://127.0.0.1:${backend.port}',
      'test-public-key',
      authOptions: const AuthClientOptions(
        autoRefreshToken: false,
        authFlowType: AuthFlowType.implicit,
      ),
    );
    cloud = MemoryCloud(client);
    c = CloudController(
      client: client,
      store: store,
      engine: engine,
      service: cloud,
      authRedirectTo: 'https://my-cloud-cafe.netlify.app',
    );
  });
  tearDown(() async {
    c.dispose();
    engine.dispose();
    await client.dispose();
    await backend.close(force: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/url_launcher'),
          null,
        );
  });

  test(
    'Google OAuth launch uses the existing provider and cannot itself unlock gameplay',
    () async {
      await c.initialize();
      expect(c.signedIn, isFalse);
      expect(engine.state.orders, isEmpty);
      await c.signInWithGoogle();
      final url = Uri.parse(launchedUrl!);
      expect(url.path, '/auth/v1/authorize');
      expect(url.queryParameters['provider'], 'google');
      expect(
        url.queryParameters['redirect_to'],
        'https://my-cloud-cafe.netlify.app',
      );
      expect(c.signedIn, isFalse);
      await client.auth.setInitialSession(jsonEncode(authSession('user-a')));
      await settled(c);
      expect(c.signedIn, isTrue);
      expect(store.ownerId, 'user-a');
      expect(engine.state.orders, isNotEmpty);
      await c.signOut();
      await settled(c);
      expect(c.signedIn, isFalse);
    },
  );
  test('failed OAuth launch remains on the login gate', () async {
    await c.initialize();
    launchOk = false;
    await c.signInWithGoogle();
    expect(c.signedIn, isFalse);
    expect(c.status, contains('Periksa koneksi'));
  });
  test(
    'existing sessions restore the matching account; anonymous and expired sessions cannot play',
    () async {
      await client.auth.setInitialSession(jsonEncode(authSession('user-a')));
      await store.switchAccount('user-a');
      await store.save(CafeState(1700000000000)..coins = 875);
      await store.switchAccount(null);
      await store.save(CafeState(1700000000000)..coins = 777);
      await c.initialize();
      await settled(c);
      expect(c.signedIn, isTrue);
      expect(engine.state.coins, 875);
      await client.auth.setInitialSession(
        jsonEncode(authSession('anon-user', anonymous: true)),
      );
      await settled(c);
      expect(c.signedIn, isFalse);
      expect(store.ownerId, isNull);
      expect(engine.state.coins, 777);
      await client.auth.setInitialSession(
        jsonEncode(authSession('user-b', expiresAt: 1)),
      );
      await settled(c);
      expect(c.signedIn, isFalse);
      await client.auth.setInitialSession(jsonEncode(authSession('user-a')));
      await settled(c);
      expect(c.signedIn, isTrue);
      expect(engine.state.coins, 875);
    },
  );
  test(
    'session expiration closes access and same-user refresh restores it',
    () async {
      await client.auth.setInitialSession(
        jsonEncode(
          authSession(
            'user-a',
            expiresAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 2,
          ),
        ),
      );
      await c.initialize();
      await settled(c);
      expect(c.signedIn, isTrue);
      final expired = Completer<void>();
      void check() {
        if (!c.signedIn && !expired.isCompleted) expired.complete();
      }

      c.addListener(check);
      await expired.future.timeout(const Duration(seconds: 4));
      c.removeListener(check);
      expect(c.signedIn, isFalse);
      expect(c.status, contains('Sesi berakhir'));
      await client.auth.setInitialSession(jsonEncode(authSession('user-a')));
      await settled(c);
      expect(c.signedIn, isTrue);
    },
  );
  testWidgets(
    'auth gate removes the account navigator and its popup on logout',
    (tester) async {
      await tester.runAsync(() async {
        await c.initialize();
      });
      await tester.pumpWidget(
        MaterialApp(
          home: AuthGate(
            controller: c,
            gameBuilder: (context) => Scaffold(
              body: Column(
                children: [
                  const Text('Private cafe'),
                  TextButton(
                    onPressed: () => showDialog<void>(
                      useRootNavigator: false,
                      context: context,
                      builder: (_) =>
                          const AlertDialog(content: Text('Private popup')),
                    ),
                    child: const Text('Open popup'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.text('Masuk ke kafe'), findsOneWidget);
      expect(find.text('Private cafe'), findsNothing);
      await tester.runAsync(() async {
        await client.auth.setInitialSession(jsonEncode(authSession('user-a')));
        await settled(c);
      });
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Private cafe'), findsOneWidget);
      await tester.tap(find.text('Open popup'));
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Private popup'), findsOneWidget);
      await tester.runAsync(() async {
        await c.signOut();
        await settled(c);
      });
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Masuk ke kafe'), findsOneWidget);
      expect(find.text('Private popup'), findsNothing);
      expect(find.text('Private cafe'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final width in [360.0, 1440.0]) {
    testWidgets(
      'login fits ${width.toInt()}px and missing configuration never exposes the cafe',
      (tester) async {
        tester.view.physicalSize = Size(width, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final unavailable = CloudController(store: store, engine: engine);
        await unavailable.initialize();
        await tester.pumpWidget(
          MaterialApp(
            home: AuthGate(
              controller: unavailable,
              gameBuilder: (_) => const Text('Private cafe'),
            ),
          ),
        );
        expect(find.text('Private cafe'), findsNothing);
        expect(find.text('Masuk ke kafe'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        unavailable.dispose();
      },
    );
  }
}
