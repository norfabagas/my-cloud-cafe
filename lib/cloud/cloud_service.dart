import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../game/state.dart';

class CloudSnapshot {
  final CafeState state;
  final int revision;
  final DateTime updatedAt;

  CloudSnapshot(this.state, this.revision, this.updatedAt);

  factory CloudSnapshot.fromJson(Map<String, dynamic> json) {
    final revision = json['revision'];
    if (revision is! int || revision < 1) {
      throw const FormatException('Revisi cloud tidak valid.');
    }
    return CloudSnapshot(
      CafeState.decode(jsonEncode(json['state'])),
      revision,
      DateTime.parse(json['updated_at'] as String),
    );
  }
}

class CloudService {
  final SupabaseClient client;
  CloudService(this.client);

  String _tokenFor(String ownerId) {
    final session = client.auth.currentSession;
    if (session == null || session.user.id != ownerId) {
      throw StateError('Akun berubah sebelum sinkronisasi.');
    }
    return session.accessToken;
  }

  Future<CloudSnapshot?> read(String ownerId) async {
    final token = _tokenFor(ownerId);
    final row = await client
        .from('mcc_cafe_saves')
        .select('state,revision,updated_at')
        .eq('owner_id', ownerId)
        .setHeader('Authorization', 'Bearer $token')
        .maybeSingle()
        .timeout(const Duration(seconds: 12));
    return row == null ? null : CloudSnapshot.fromJson(row);
  }

  Future<int> write(
    String raw, {
    required String ownerId,
    required int expectedRevision,
  }) async {
    CafeState.decode(raw);
    // Freeze the request identity. AuthHttpClient preserves explicit headers,
    // so switching accounts cannot send this snapshot with the new user's JWT.
    final token = _tokenFor(ownerId);
    final rows = await client
        .rpc(
          'cafe_save_compare_and_swap',
          params: {
            'p_state': jsonDecode(raw),
            'p_expected_revision': expectedRevision,
          },
        )
        .setHeader('Authorization', 'Bearer $token')
        .timeout(const Duration(seconds: 12));
    if (rows is! List || rows.length != 1) {
      throw const FormatException('Balasan sinkronisasi tidak valid.');
    }
    final revision = rows.single['revision'];
    if (revision is! int || revision != expectedRevision + 1) {
      throw const FormatException('Revisi sinkronisasi tidak sesuai.');
    }
    return revision;
  }
}
