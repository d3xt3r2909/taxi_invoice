import 'package:app_taxi_invoice/firebase_options.dart';
import 'package:app_taxi_invoice/src/auth/app_auth_controller.dart';
import 'package:app_taxi_invoice/src/settings/app_settings_controller.dart';
import 'package:app_taxi_invoice/src/store/invoice_store_controller.dart';
import 'package:app_taxi_invoice/src/ui/home_screen.dart';
import 'package:flutter/material.dart';

final class AuthGate extends StatefulWidget {
  const AuthGate({
    required this.auth,
    required this.store,
    required this.settings,
    super.key,
  });

  final AppAuthController auth;
  final InvoiceStoreController store;
  final AppSettingsController settings;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

final class _AuthGateState extends State<AuthGate> {
  bool _loadingStore = false;
  String? _loadedUserId;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    widget.auth.addListener(_handleAuthChanged);
    _handleAuthChanged();
  }

  @override
  void dispose() {
    widget.auth.removeListener(_handleAuthChanged);
    super.dispose();
  }

  void _handleAuthChanged() {
    final user = widget.auth.user;
    if (user == null) {
      if (widget.store.isLoaded) {
        widget.store.reset();
      }
      _loadedUserId = null;
      _loadError = null;
      if (mounted) {
        setState(() {});
      }
      return;
    }
    if (_loadedUserId != user.uid && !_loadingStore) {
      _loadStoreFor(user.uid);
    }
  }

  Future<void> _loadStoreFor(String userId) async {
    setState(() {
      _loadingStore = true;
      _loadError = null;
    });
    try {
      widget.store.reset();
      await widget.store.load();
      _loadedUserId = userId;
    } catch (_) {
      _loadError = 'Podaci se nisu mogli učitati. Pokušajte ponovo.';
    } finally {
      if (mounted) {
        setState(() => _loadingStore = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.auth, widget.store]),
      builder: (context, _) {
        return switch (widget.auth.status) {
          AppAuthStatus.setupRequired => const FirebaseSetupRequiredScreen(),
          AppAuthStatus.signedOut ||
          AppAuthStatus.signingIn => LoginScreen(auth: widget.auth),
          AppAuthStatus.signedIn => _signedInContent(context),
        };
      },
    );
  }

  Widget _signedInContent(BuildContext context) {
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cloud sync')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _loadError!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    final userId = widget.auth.user?.uid;
                    if (userId != null) {
                      _loadStoreFor(userId);
                    }
                  },
                  child: const Text('Pokušaj ponovo'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: widget.auth.signOut,
                  child: const Text('Odjava'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_loadingStore || !widget.store.isLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return HomeScreen(
      store: widget.store,
      settings: widget.settings,
      auth: widget.auth,
    );
  }
}

final class FirebaseSetupRequiredScreen extends StatelessWidget {
  const FirebaseSetupRequiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Firebase nije podešen')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Dodajte Firebase vrijednosti preko --dart-define-from-file=android_config.json i pokrenite aplikaciju ponovo.',
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
          ),
          const SizedBox(height: 16),
          SelectableText(
            FirebaseConfigKeys.requiredDartDefines.join('\n'),
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

final class LoginScreen extends StatefulWidget {
  const LoginScreen({required this.auth, super.key});

  final AppAuthController auth;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

final class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _rememberMe = true;
  _LoginMethod? _activeMethod;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unesite email i lozinku.')));
      return;
    }
    setState(() => _activeMethod = _LoginMethod.email);
    await widget.auth.signIn(
      email: email,
      password: password,
      rememberMe: _rememberMe,
    );
    if (mounted) {
      setState(() => _activeMethod = null);
    }
  }

  Future<void> _submitGoogle() async {
    setState(() => _activeMethod = _LoginMethod.google);
    await widget.auth.signInWithGoogle(rememberMe: _rememberMe);
    if (mounted) {
      setState(() => _activeMethod = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final signingIn = widget.auth.status == AppAuthStatus.signingIn;
    return Scaffold(
      appBar: AppBar(title: const Text('Prijava')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Prijavite se Google računom ili email adresom koja je odobrena za aplikaciju.',
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: signingIn ? null : _submitGoogle,
                icon: _activeMethod == _LoginMethod.google
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const _GoogleMark(),
                label: const Text('Prijava Google računom'),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _rememberMe,
                onChanged: signingIn
                    ? null
                    : (value) {
                        setState(() => _rememberMe = value ?? true);
                      },
                title: const Text('Zapamti prijavu'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'ili',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 18),
              AutofillGroup(
                child: Column(
                  children: [
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _password,
                      obscureText: true,
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) {
                        if (!signingIn) {
                          _submit();
                        }
                      },
                      decoration: const InputDecoration(
                        labelText: 'Lozinka',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.auth.errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  widget.auth.errorMessage!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton(
                onPressed: signingIn ? null : _submit,
                child: _activeMethod == _LoginMethod.email
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Prijava emailom'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _LoginMethod { email, google }

final class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 18,
      child: Center(
        child: Text(
          'G',
          style: TextStyle(
            color: Color(0xFF4285F4),
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
