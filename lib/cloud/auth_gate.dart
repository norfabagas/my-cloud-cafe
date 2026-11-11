import 'package:flutter/material.dart';
import 'account_panel.dart';
import 'cloud_controller.dart';

/// Removing this account's Navigator also removes its open game dialogs.
/// A valid session and the matching local account must be ready before play.
class AuthGate extends StatefulWidget {
  final CloudController controller;
  final WidgetBuilder gameBuilder;
  const AuthGate({
    super.key,
    required this.controller,
    required this.gameBuilder,
  });
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.controller.recheckSession();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final c = widget.controller;
      if (!c.initialized || c.switchingAccount) {
        return const Scaffold(
          body: SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text('Menyiapkan akun…'),
                ],
              ),
            ),
          ),
        );
      }
      if (!c.signedIn) {
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.local_cafe,
                        color: Color(0xFF436C59),
                        size: 44,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'MY CLOUD CAFÉ',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Card(
                        clipBehavior: Clip.antiAlias,
                        child: AccountPanel(controller: c),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }
      return Navigator(
        key: ValueKey('cafe-account-${c.userId}'),
        onGenerateRoute: (_) =>
            MaterialPageRoute<void>(builder: widget.gameBuilder),
      );
    },
  );
}
