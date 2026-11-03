import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:my_web_cafe/cloud/cloud_controller.dart';
import 'package:my_web_cafe/cloud/cloud_service.dart';
import 'package:my_web_cafe/game/engine.dart';
import 'package:my_web_cafe/game/state.dart';
import 'package:my_web_cafe/persistence/save_store.dart';

String sessionFor(String id) {
  String part(Map<String, dynamic> value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final jwt =
      '${part({'alg': 'HS256'})}.${part({'sub': id, 'exp': 4102444800, 'role': 'authenticated'})}.test';
  return jsonEncode({
    'access_token': jwt,
    'token_type': 'bearer',
    'refresh_token': 'test-refresh',
    'expires_at': 4102444800,
    'user': {
      'id': id,
      'aud': 'authenticated',
      'email': '$id@example.invalid',
      'app_metadata': {},
      'user_metadata': {},
      'created_at': '2026-01-01T00:00:00Z',
    },
  });
}

class Dependency {
  late HttpServer server;
  bool offline = false;
  int revision = 3;
  CafeState saved = CafeState(1700000000000)..coins = 935;
  final requests = <String>[];
  final identities = <String>[];
  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final auth = request.headers.value('authorization')!;
      final payload = auth.split(' ').last.split('.')[1];
      identities.add(
        jsonDecode(
          utf8.decode(base64Url.decode(base64Url.normalize(payload))),
        )['sub'],
      );
      requests.add('${request.method} ${request.uri.path}');
      request.response.headers.contentType = ContentType.json;
      if (offline) {
        request.response.statusCode = 503;
        request.response.write(
          jsonEncode({'code': '503', 'message': 'dependency unavailable'}),
        );
      } else if (request.method == 'GET' &&
          request.uri.path == '/rest/v1/mcc_cafe_saves') {
        request.response.write(
          jsonEncode([
            {
              'state': jsonDecode(saved.encode()),
              'revision': revision,
              'updated_at': '2026-11-03T00:00:00Z',
            },
          ]),
        );
      } else if (request.method == 'POST' &&
          request.uri.path == '/rest/v1/rpc/cafe_save_compare_and_swap') {
        final body = jsonDecode(await utf8.decoder.bind(request).join());
        if (body['p_expected_revision'] != revision) {
          request.response.statusCode = 409;
          request.response.write(
            jsonEncode({'code': '40001', 'message': 'stale revision'}),
          );
        } else {
          expect(body.containsKey('p_owner_id'), isFalse);
          saved = CafeState.decode(jsonEncode(body['p_state']));
          revision++;
          request.response.write(
            jsonEncode([
              {'revision': revision, 'updated_at': '2026-11-03T00:00:00Z'},
            ]),
          );
        }
      } else {
        request.response.statusCode = 501;
        request.response.write('{}');
      }
      await request.response.close();
    });
  }

  SupabaseClient client() => SupabaseClient(
    'http://127.0.0.1:${server.port}',
    'test-public-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
}

Future<void> idle(CloudController c) async {
  final until = DateTime.now().add(const Duration(seconds: 5));
  while (c.busy && DateTime.now().isBefore(until)) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  expect(c.busy, isFalse);
}

void main() {
  late Dependency backend;
  late SupabaseClient client;
  setUp(() async {
    backend = Dependency();
    await backend.start();
    client = backend.client();
    await client.auth.setInitialSession(sessionFor('user-a'));
  });
  tearDown(() async {
    await client.dispose();
    await backend.server.close(force: true);
  });
  test(
    'HTTP save keeps the captured account JWT during an account switch',
    () async {
      final service = CloudService(client);
      final write = service.write(
        CafeState(1700000000000).encode(),
        ownerId: 'user-a',
        expectedRevision: 3,
      );
      await client.auth.setInitialSession(sessionFor('user-b'));
      expect(await write, 4);
      expect(backend.identities.single, 'user-a');
      expect(
        () => service.write(
          CafeState(1700000000000).encode(),
          ownerId: 'user-a',
          expectedRevision: 4,
        ),
        throwsStateError,
      );
    },
  );
  test(
    'offline retry and conflict resolution preserve local and guest progress',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = SaveStore(await SharedPreferences.getInstance());
      final engine = GameEngine(
        CafeState(1700000000000)..coins = 777,
        clock: () => 1700000000000,
      );
      final controller = CloudController(
        client: client,
        store: store,
        engine: engine,
      );
      addTearDown(controller.dispose);
      addTearDown(engine.dispose);
      await controller.initialize();
      await idle(controller);
      expect(engine.state.coins, 935);
      expect(store.cloudRevision, 3);
      engine.state.coins = 945;
      await store.save(engine.state);
      controller.markDirty();
      backend.offline = true;
      await controller.sync();
      expect(store.pendingCloud, isTrue);
      expect(engine.state.coins, 945);
      backend.offline = false;
      await controller.sync();
      expect(backend.saved.coins, 945);
      expect(store.cloudRevision, 4);
      expect(store.pendingCloud, isFalse);
      backend.saved.coins = 1200;
      backend.revision = 5;
      engine.state.coins = 950;
      await store.save(engine.state);
      await controller.sync();
      expect(controller.conflict, isTrue);
      expect(engine.state.coins, 950);
      await controller.resolveConflict(true);
      expect(controller.conflict, isFalse);
      expect(engine.state.coins, 1200);
      final guest = SaveStore(store.preferences);
      await guest.switchAccount(null);
      expect(guest.load(engine.now).coins, 777);
      expect(
        backend.requests,
        contains('POST /rest/v1/rpc/cafe_save_compare_and_swap'),
      );
    },
  );
}
