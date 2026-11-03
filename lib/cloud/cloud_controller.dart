import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../game/engine.dart';
import '../game/state.dart';
import '../persistence/save_store.dart';
import 'cloud_service.dart';

class CloudController extends ChangeNotifier {
  final SupabaseClient? client;
  final SaveStore store;
  final GameEngine engine;
  final CloudService? _service;
  StreamSubscription<AuthState>? _authSubscription;
  Timer? _retry;
  Future<void> _accountQueue = Future.value();
  String? _requestedId, _userId, _email;
  bool _requested = false, _disposed = false;
  bool _authBusy = false, _syncBusy = false, _switchBusy = false;
  bool _newAccount = false;
  int _epoch = 0;
  CloudSnapshot? _conflicting;
  String _status = 'Progres tersimpan di perangkat ini.';

  CloudController({
    this.client,
    required this.store,
    required this.engine,
    CloudService? service,
  }) : _service = service ?? (client == null ? null : CloudService(client));

  bool get configured => client != null;
  bool get busy => _authBusy || _syncBusy || _switchBusy;
  String? get userEmail => _email;
  String get status => _status;
  bool get conflict => _conflicting != null;
  CloudSnapshot? get conflictingSnapshot => _conflicting;
  bool get switchingAccount => _switchBusy;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  bool _active(int epoch, String uid) =>
      !_disposed && epoch == _epoch && uid == _userId;

  Future<void> initialize() async {
    if (client == null || _retry != null) return;
    _authSubscription = client!.auth.onAuthStateChange.listen(
      (event) {
        unawaited(_scheduleAccount(event.session?.user));
      },
      onError: (Object error, StackTrace stack) {
        _status = 'Koneksi akun terputus. Progres lokal tetap tersimpan.';
        _notify();
      },
    );
    await _scheduleAccount(client!.auth.currentUser);
    if (_disposed) return;
    _retry = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(sync());
    });
  }

  Future<void> _scheduleAccount(User? user) {
    if (_disposed) return Future.value();
    if (_requested && _requestedId == user?.id) {
      _email = user?.email;
      return _accountQueue;
    }
    _requested = true;
    _requestedId = user?.id;
    final epoch = ++_epoch;
    _accountQueue = _accountQueue.catchError((_) {}).then((_) async {
      if (_disposed || epoch != _epoch) return;
      _switchBusy = true;
      _notify();
      try {
        if (store.ownerId == _userId) await store.save(engine.state);
        if (_disposed || epoch != _epoch) return;
        await store.switchAccount(user?.id);
        if (_disposed || epoch != _epoch) return;
        _userId = user?.id;
        _email = user?.email;
        _conflicting = null;
        _newAccount = !store.hasSave;
        engine.state = store.load(engine.now);
        engine.resume();
        await store.save(engine.state);
        _status = _userId == null
            ? 'Mode tamu. Progres tersimpan di perangkat ini.'
            : 'Progres lokal siap. Memeriksa cadangan cloud…';
      } catch (_) {
        _status = 'Progres lokal belum dapat dimuat. Coba masuk kembali.';
      } finally {
        if (!_disposed && epoch == _epoch) {
          _switchBusy = false;
          _notify();
          if (_userId != null) unawaited(sync());
        }
      }
    });
    return _accountQueue;
  }

  void markDirty() {
    if (_disposed || _switchBusy || _userId == null || conflict) return;
    if (store.pendingCloud) {
      _status = 'Perubahan tersimpan lokal. Menunggu sinkronisasi.';
      _notify();
    }
  }

  Future<void> signIn(String email, String password) => _authenticate(() async {
    await client!.auth
        .signInWithPassword(email: email.trim(), password: password)
        .timeout(const Duration(seconds: 15));
    await _scheduleAccount(client!.auth.currentUser);
  });

  Future<void> signUp(String email, String password) => _authenticate(() async {
    final result = await client!.auth
        .signUp(email: email.trim(), password: password)
        .timeout(const Duration(seconds: 15));
    if (result.session == null) {
      _status =
          'Periksa email untuk konfirmasi akun, lalu kembali ke sini dan masuk.';
    } else {
      await _scheduleAccount(result.user);
    }
  });

  Future<void> _authenticate(Future<void> Function() operation) async {
    if (client == null || busy) return;
    _authBusy = true;
    _notify();
    try {
      await operation();
    } on AuthException catch (error) {
      _status = error.code == 'email_not_confirmed'
          ? 'Konfirmasi email dahulu, lalu masuk kembali.'
          : error.code == 'over_email_send_rate_limit'
          ? 'Pengiriman email dibatasi. Tunggu sebentar sebelum mencoba lagi.'
          : 'Akun belum dapat diproses. Periksa email dan kata sandi.';
    } catch (_) {
      _status = 'Akun belum terhubung. Periksa koneksi lalu coba lagi.';
    } finally {
      _authBusy = false;
      _notify();
    }
  }

  Future<void> signOut() async {
    if (client == null || busy) return;
    _authBusy = true;
    _notify();
    try {
      await store.save(engine.state);
      await client!.auth.signOut(scope: SignOutScope.local);
      await _scheduleAccount(null);
    } catch (_) {
      _status = 'Belum dapat keluar. Progres lokal tetap tersimpan.';
    } finally {
      _authBusy = false;
      _notify();
    }
  }

  // A newly created account cache must not replace an existing remote game
  // just because its initial arrival/checkpoint was saved during login.
  bool _hasProgress(CafeState s) =>
      s.coins != 350 ||
      s.xp > 0 ||
      s.served > 0 ||
      s.staff ||
      s.unlocked.length > 1 ||
      s.machines.length > 1 ||
      s.stories.isNotEmpty ||
      s.claimedGoals.isNotEmpty ||
      s.decor.length != 3 ||
      s.theme != 'sage';

  Future<void> sync() async {
    final uid = _userId;
    if (_service == null ||
        uid == null ||
        _syncBusy ||
        _switchBusy ||
        conflict ||
        _disposed) {
      return;
    }
    final epoch = _epoch;
    _syncBusy = true;
    _notify();
    try {
      await store.save(engine.state);
      final remote = await _service.read(uid);
      if (!_active(epoch, uid)) return;
      if (remote != null) {
        final pending = store.pendingCloud;
        if (_newAccount && !_hasProgress(engine.state)) {
          await _applyRemote(remote, epoch, uid);
        } else if (pending && remote.revision != store.cloudRevision) {
          _setConflict(remote);
        } else if (!pending && remote.revision != store.cloudRevision) {
          await _applyRemote(remote, epoch, uid);
        } else if (pending) {
          await _upload(uid, epoch, remote.revision);
        } else {
          _status = 'Progres sudah tersinkron.';
        }
      } else {
        await _upload(uid, epoch, 0);
      }
      _newAccount = false;
    } on PostgrestException catch (error) {
      if (_active(epoch, uid)) {
        if (error.code == '40001') {
          await _refreshConflict(uid, epoch);
        } else {
          _status = 'Cloud belum tersedia. Progres lokal akan dicoba lagi.';
        }
      }
    } catch (_) {
      if (_active(epoch, uid)) {
        _status = 'Sedang offline. Progres lokal akan dicoba lagi.';
      }
    } finally {
      _syncBusy = false;
      _notify();
    }
  }

  void _setConflict(CloudSnapshot remote) {
    _conflicting = remote;
    _status =
        'Ada progres berbeda di perangkat lain. Pilih progres yang ingin dipakai.';
  }

  Future<void> _refreshConflict(String uid, int epoch) async {
    try {
      final latest = await _service!.read(uid);
      if (!_active(epoch, uid)) return;
      if (latest != null) {
        _setConflict(latest);
      } else {
        _status = 'Cadangan berubah. Coba sinkronkan kembali.';
      }
    } catch (_) {
      if (_active(epoch, uid)) {
        _status =
            'Cadangan berubah. Hubungkan internet sebelum memilih progres.';
      }
    }
  }

  Future<void> _upload(String uid, int epoch, int expectedRevision) async {
    if (!_active(epoch, uid)) return;
    final raw = store.savedRaw ?? engine.state.encode();
    final revision = await _service!.write(
      raw,
      ownerId: uid,
      expectedRevision: expectedRevision,
    );
    // Acknowledgements are scoped to their original account even if auth changes
    // while the HTTP response is in flight.
    await store.acknowledgeCloud(
      ownerId: uid,
      revision: revision,
      uploadedRaw: raw,
    );
    if (!_active(epoch, uid)) return;
    _conflicting = null;
    _status = store.pendingCloud
        ? 'Progres baru tersimpan lokal. Sinkronisasi berikutnya menyusul.'
        : 'Progres sudah tersinkron.';
  }

  Future<void> _applyRemote(CloudSnapshot remote, int epoch, String uid) async {
    if (!_active(epoch, uid)) return;
    await store.replaceFromCloud(remote.state, revision: remote.revision);
    if (!_active(epoch, uid)) return;
    engine.state = remote.state;
    engine.resume();
    await store.save(engine.state);
    _conflicting = null;
    _status =
        'Progres cloud dimuat. Perubahan berikutnya tetap disimpan lokal.';
  }

  Future<void> resolveConflict(bool useCloud) async {
    final uid = _userId;
    if (!conflict || uid == null || _service == null || busy || _disposed) {
      return;
    }
    final epoch = _epoch;
    _syncBusy = true;
    _notify();
    try {
      await store.save(engine.state);
      final latest = await _service.read(uid);
      if (!_active(epoch, uid)) return;
      if (useCloud) {
        if (latest == null) {
          _status =
              'Cadangan cloud tidak tersedia. Progres lokal tetap disimpan.';
          return;
        }
        await _applyRemote(latest, epoch, uid);
      } else {
        await _upload(uid, epoch, latest?.revision ?? 0);
      }
      _newAccount = false;
    } on PostgrestException catch (error) {
      if (_active(epoch, uid) && error.code == '40001') {
        await _refreshConflict(uid, epoch);
      } else if (_active(epoch, uid)) {
        _status = 'Pilihan belum tersimpan. Coba lagi saat terhubung.';
      }
    } catch (_) {
      if (_active(epoch, uid)) {
        _status = 'Sedang offline. Pilihan progres belum diterapkan.';
      }
    } finally {
      _syncBusy = false;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    _retry?.cancel();
    unawaited(_authSubscription?.cancel());
    super.dispose();
  }
}
