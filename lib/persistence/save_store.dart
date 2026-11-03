import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../game/state.dart';

/// Cloud metadata travels with each account snapshot, so a restart cannot drop
/// its pending upload. Guest and account progress use separate namespaces.
class SaveStore {
  final SharedPreferences preferences;
  Future<void> _pending = Future.value();
  String? _ownerId;
  String? warning;

  SaveStore(this.preferences);

  String? get ownerId => _ownerId;
  bool get hasSave => _current != null;
  String? get savedRaw => _current?.raw;
  int get cloudRevision => _current?.revision ?? 0;
  bool get pendingCloud => _current?.pending ?? false;

  String _key(String? owner, {bool backup = false}) => owner == null
      ? 'cafe.${backup ? 'backup' : 'save'}.v1'
      : 'cafe.account.$owner.${backup ? 'backup' : 'save'}.v1';

  _StoredSave? _read(String key) {
    final value = preferences.getString(key);
    if (value == null) return null;
    final json = jsonDecode(value);
    if (json is Map<String, dynamic> && json['storageVersion'] == 1) {
      final revision = json['cloudRevision'];
      if (revision is! int || revision < 0 || json['pendingCloud'] is! bool) {
        throw const FormatException('Metadata sinkronisasi tidak valid.');
      }
      final raw = jsonEncode(json['state']);
      CafeState.decode(raw);
      return _StoredSave(raw, revision, json['pendingCloud'] as bool);
    }
    CafeState.decode(value);
    return _StoredSave(value, 0, false);
  }

  _StoredSave? get _current {
    for (final backup in [false, true]) {
      try {
        final record = _read(_key(_ownerId, backup: backup));
        if (record != null) return record;
      } catch (_) {
        // load() presents recovery information to the player.
      }
    }
    return null;
  }

  CafeState load(int now) {
    warning = null;
    for (final backup in [false, true]) {
      try {
        final record = _read(_key(_ownerId, backup: backup));
        if (record == null) continue;
        if (backup) warning = 'Progres dipulihkan dari cadangan terakhir.';
        return CafeState.decode(record.raw);
      } catch (_) {
        warning = 'Data tersimpan tidak terbaca. Cadangan diperiksa.';
      }
    }
    return CafeState(now);
  }

  Future<void> switchAccount(String? ownerId) async {
    if (ownerId != null &&
        !RegExp(r'^[a-zA-Z0-9_-]{1,100}$').hasMatch(ownerId)) {
      throw ArgumentError.value(ownerId, 'ownerId');
    }
    await _pending.catchError((_) {});
    _ownerId = ownerId;
    warning = null;
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    _pending = _pending.catchError((_) {}).then((_) => operation());
    return _pending;
  }

  Future<void> _write(String? owner, _StoredSave record) async {
    final key = _key(owner);
    final previous = preferences.getString(key);
    if (previous != null) {
      try {
        _read(key);
        if (!await preferences.setString(_key(owner, backup: true), previous)) {
          throw StateError('Cadangan gagal disimpan.');
        }
      } on FormatException {
        // Retain the last valid backup.
      } on TypeError {
        // Retain the last valid backup.
      }
    }
    final value = owner == null
        ? record.raw
        : jsonEncode({
            'storageVersion': 1,
            'state': jsonDecode(record.raw),
            'cloudRevision': record.revision,
            'pendingCloud': record.pending,
          });
    if (!await preferences.setString(key, value)) {
      throw StateError('Progres gagal disimpan.');
    }
  }

  Future<void> save(CafeState state) {
    final raw = state.encode();
    final owner = _ownerId; // Capture the namespace before queuing the write.
    return _enqueue(() async {
      _StoredSave? previous;
      try {
        previous = _read(_key(owner));
      } catch (_) {
        try {
          previous = _read(_key(owner, backup: true));
        } catch (_) {}
      }
      await _write(
        owner,
        _StoredSave(
          raw,
          previous?.revision ?? 0,
          owner != null &&
              ((previous?.pending ?? false) || previous?.raw != raw),
        ),
      );
    });
  }

  Future<void> replaceFromCloud(CafeState state, {required int revision}) {
    final owner = _ownerId;
    if (owner == null || revision < 1) {
      throw StateError('Akun atau revisi cloud tidak valid.');
    }
    final record = _StoredSave(state.encode(), revision, false);
    return _enqueue(() => _write(owner, record));
  }

  /// Acknowledge only the uploaded snapshot. Progress made while a request was
  /// in flight stays pending, with the newly acknowledged server revision.
  Future<void> acknowledgeCloud({
    required String ownerId,
    required int revision,
    required String uploadedRaw,
  }) => _enqueue(() async {
    final current = _read(_key(ownerId));
    if (current == null || revision < current.revision) return;
    await _write(
      ownerId,
      _StoredSave(current.raw, revision, current.raw != uploadedRaw),
    );
  });
}

class _StoredSave {
  final String raw;
  final int revision;
  final bool pending;
  const _StoredSave(this.raw, this.revision, this.pending);
}
