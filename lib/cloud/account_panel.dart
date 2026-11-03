import 'package:flutter/material.dart';

import 'cloud_controller.dart';

class AccountPanel extends StatefulWidget {
  final CloudController controller;
  const AccountPanel({super.key, required this.controller});

  @override
  State<AccountPanel> createState() => _AccountPanelState();
}

class _AccountPanelState extends State<AccountPanel> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    final controller = widget.controller;
    if (_register) {
      await controller.signUp(_email.text, _password.text);
    } else {
      await controller.signIn(_email.text, _password.text);
    }
    _password.clear();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final c = widget.controller;
      final signedIn = c.userEmail != null;
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Akun & cadangan',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              signedIn
                  ? c.userEmail!
                  : 'Main tanpa akun tetap bisa. Masuk untuk menyimpan progres antarperangkat.',
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
                'Sinkronisasi belum tersedia. Progres tetap tersimpan di perangkat ini.',
              )
            else if (signedIn) ...[
              const Text(
                'Cadangan otomatis diperiksa setiap 30 detik saat game terbuka. Progres tamu disimpan terpisah di perangkat ini.',
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
                    onPressed: c.busy ? null : c.signOut,
                    child: const Text('Keluar ke mode tamu'),
                  ),
                ],
              ),
            ] else
              AutofillGroup(
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _email,
                        enabled: !c.busy,
                        decoration: const InputDecoration(labelText: 'Email'),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.email],
                        validator: (value) =>
                            value != null &&
                                RegExp(
                                  r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                ).hasMatch(value.trim())
                            ? null
                            : 'Masukkan email yang valid.',
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _password,
                        enabled: !c.busy,
                        decoration: const InputDecoration(
                          labelText: 'Kata sandi',
                        ),
                        obscureText: true,
                        autocorrect: false,
                        enableSuggestions: false,
                        autofillHints: [
                          _register
                              ? AutofillHints.newPassword
                              : AutofillHints.password,
                        ],
                        onFieldSubmitted: (_) {
                          if (!c.busy) _submit();
                        },
                        validator: (value) => value == null || value.isEmpty
                            ? 'Masukkan kata sandi.'
                            : _register && value.length < 8
                            ? 'Gunakan setidaknya 8 karakter.'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: c.busy ? null : _submit,
                        child: Text(_register ? 'Buat akun' : 'Masuk'),
                      ),
                      TextButton(
                        onPressed: c.busy
                            ? null
                            : () => setState(() {
                                _register = !_register;
                              }),
                        child: Text(
                          _register
                              ? 'Sudah punya akun? Masuk'
                              : 'Belum punya akun? Daftar',
                        ),
                      ),
                      if (_register)
                        const Text(
                          'Setelah mendaftar, konfirmasi email lalu kembali ke game ini untuk masuk.',
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}
