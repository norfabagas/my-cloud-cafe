import 'package:flutter/material.dart';
import 'cloud_controller.dart';

class AccountPanel extends StatelessWidget {
  final CloudController controller;
  const AccountPanel({super.key, required this.controller});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final c = controller, signedIn = c.signedIn;
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              signedIn ? 'Akun & cadangan' : 'Masuk ke kafe',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              signedIn
                  ? c.userEmail ?? 'Akun terhubung'
                  : 'Masuk dengan akun Google untuk bermain dan menyimpan progres antarperangkat.',
            ),
            const SizedBox(height: 16),
            Semantics(liveRegion: true, child: Text(c.status)),
            if (c.busy) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            const SizedBox(height: 20),
            if (!c.configured)
              const Text(
                'Login belum tersedia. Muat ulang atau coba kembali nanti.',
              )
            else if (!signedIn) ...[
              FilledButton.icon(
                key: const ValueKey('google-login'),
                onPressed: c.busy ? null : c.signInWithGoogle,
                icon: const Icon(Icons.login),
                label: const Text('Masuk dengan Google'),
              ),
              const SizedBox(height: 12),
              const Text(
                'Kamu akan kembali ke kafe setelah login. Tidak perlu membuat kata sandi baru.',
                style: TextStyle(fontSize: 12),
              ),
            ] else ...[
              const Text(
                'Cadangan otomatis diperiksa setiap 30 detik saat game terbuka. Progres tersimpan terpisah untuk setiap akun.',
              ),
              const SizedBox(height: 16),
              if (c.conflict) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Pilih progres',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Gunakan cloud akan mengganti progres lokal akun ini. Simpan lokal akan mengganti cadangan cloud. Pilihan baru diterapkan saat terhubung.',
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Perangkat ini: level ${c.engine.state.level}, ${c.engine.state.coins} koin, ${c.engine.state.served} pesanan.',
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Cloud: level ${c.conflictingSnapshot!.state.level}, ${c.conflictingSnapshot!.state.coins} koin, ${c.conflictingSnapshot!.state.served} pesanan.',
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Cloud terakhir: ${c.conflictingSnapshot!.updatedAt.toLocal().toIso8601String().substring(0, 16).replaceFirst('T', ' ')}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton(
                              onPressed: c.busy
                                  ? null
                                  : () => c.resolveConflict(false),
                              child: const Text('Simpan progres lokal'),
                            ),
                            OutlinedButton(
                              onPressed: c.busy
                                  ? null
                                  : () => c.resolveConflict(true),
                              child: const Text('Gunakan progres cloud'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: c.busy || c.conflict ? null : c.sync,
                    icon: const Icon(Icons.sync),
                    label: const Text('Sinkronkan sekarang'),
                  ),
                  OutlinedButton(
                    onPressed: c.authenticating || c.switchingAccount
                        ? null
                        : c.signOut,
                    child: const Text('Keluar'),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    },
  );
}
