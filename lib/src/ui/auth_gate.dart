import 'package:app_taxi_invoice/firebase_options.dart';
import 'package:app_taxi_invoice/src/auth/app_auth_controller.dart';
import 'package:app_taxi_invoice/src/auth/app_user_access_controller.dart';
import 'package:app_taxi_invoice/src/settings/app_settings_controller.dart';
import 'package:app_taxi_invoice/src/store/invoice_store_controller.dart';
import 'package:app_taxi_invoice/src/store/invoice_store_encryption.dart';
import 'package:app_taxi_invoice/src/ui/home_screen.dart';
import 'package:flutter/material.dart';

const _loginHeroAsset = 'assets/branding/login_hero.png';
const _loginPanelBackgroundAsset = 'assets/branding/login_background_panel.png';

final class AuthGate extends StatefulWidget {
  const AuthGate({
    required this.auth,
    required this.store,
    required this.settings,
    this.userAccess,
    this.encryption,
    super.key,
  });

  final AppAuthController auth;
  final InvoiceStoreController store;
  final AppSettingsController settings;
  final AppUserAccessController? userAccess;
  final InvoiceStoreEncryptionController? encryption;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

final class _AuthGateState extends State<AuthGate> {
  bool _loadingStore = false;
  bool _checkingEncryption = false;
  String? _loadedUserId;
  String? _encryptionUserId;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    widget.auth.addListener(_handleAuthChanged);
    widget.encryption?.addListener(_handleEncryptionChanged);
    _handleAuthChanged();
  }

  @override
  void dispose() {
    widget.auth.removeListener(_handleAuthChanged);
    widget.encryption?.removeListener(_handleEncryptionChanged);
    super.dispose();
  }

  void _handleAuthChanged() {
    final user = widget.auth.user;
    if (user == null) {
      widget.encryption?.lockInMemory();
      if (widget.store.isLoaded) {
        widget.store.reset();
      }
      widget.userAccess?.reset();
      _loadedUserId = null;
      _encryptionUserId = null;
      _loadError = null;
      if (mounted) {
        setState(() {});
      }
      return;
    }
    widget.userAccess?.loadForUser(user.uid);
    final encryption = widget.encryption;
    if (encryption != null) {
      if (_encryptionUserId != user.uid && !_checkingEncryption) {
        _inspectEncryptionFor(user.uid);
      }
      if (encryption.isUnlocked &&
          _loadedUserId != user.uid &&
          !_loadingStore) {
        _loadStoreFor(user.uid);
      }
      return;
    }
    if (_loadedUserId != user.uid && !_loadingStore) {
      _loadStoreFor(user.uid);
    }
  }

  void _handleEncryptionChanged() {
    final user = widget.auth.user;
    if (user == null) {
      return;
    }
    if (widget.encryption?.isUnlocked == true &&
        _loadedUserId != user.uid &&
        !_loadingStore) {
      _loadStoreFor(user.uid);
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _inspectEncryptionFor(String userId) async {
    setState(() {
      _checkingEncryption = true;
      _encryptionUserId = userId;
      _loadedUserId = null;
      _loadError = null;
    });
    if (widget.store.isLoaded) {
      widget.store.reset();
    }
    try {
      await widget.encryption?.inspectForUser(userId);
    } catch (_) {
      _loadError = 'Šifra baze se nije mogla provjeriti. Pokušajte ponovo.';
    } finally {
      if (mounted) {
        setState(() => _checkingEncryption = false);
      }
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
    final encryption = widget.encryption;
    if (encryption != null && !encryption.isUnlocked) {
      if (_checkingEncryption) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return DatabasePasswordScreen(
        encryption: encryption,
        onSignOut: widget.auth.signOut,
      );
    }

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
      userAccess: widget.userAccess,
      encryption: widget.encryption,
    );
  }
}

final class DatabasePasswordScreen extends StatefulWidget {
  const DatabasePasswordScreen({
    required this.encryption,
    required this.onSignOut,
    super.key,
  });

  final InvoiceStoreEncryptionController encryption;
  final Future<void> Function() onSignOut;

  @override
  State<DatabasePasswordScreen> createState() => _DatabasePasswordScreenState();
}

final class _DatabasePasswordScreenState extends State<DatabasePasswordScreen> {
  final _password = TextEditingController();
  final _repeatPassword = TextEditingController();
  bool _remember = true;

  @override
  void dispose() {
    _password.dispose();
    _repeatPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final setup = widget.encryption.requiresSetup;
    final password = _password.text;
    if (setup && password.trim() != _repeatPassword.text.trim()) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Šifre nisu iste.')));
      return;
    }
    if (setup) {
      final confirmed = await _confirmDatabasePasswordSetup();
      if (!mounted || !confirmed) {
        return;
      }
      await widget.encryption.setup(
        passphrase: password,
        rememberOnDevice: _remember,
      );
    } else {
      await widget.encryption.unlock(
        passphrase: password,
        rememberOnDevice: _remember,
      );
    }
  }

  Future<bool> _confirmDatabasePasswordSetup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Potvrditi šifru baze?'),
          content: const Text(
            'Ova šifra zaključava zajedničku bazu računa.\n\n'
            'Svi odobreni korisnici moraju znati istu šifru. Ako se šifra '
            'zaboravi, podaci u bazi se ne mogu otvoriti.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Vrati se'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Postavi ovu šifru'),
            ),
          ],
        );
      },
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final encryption = widget.encryption;
    final setup = encryption.requiresSetup;
    final checking = encryption.status == InvoiceStoreEncryptionStatus.checking;
    final progress = encryption.progress;
    final progressPercent = progress == null
        ? null
        : (progress * 100).clamp(0, 100).round();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(setup ? 'Postavite šifru baze' : 'Otključajte bazu'),
        actions: [
          TextButton(onPressed: widget.onSignOut, child: const Text('Odjava')),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 48,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 18),
              Text(
                setup
                    ? 'Postavite zajedničku šifru baze. Svi odobreni korisnici moraju koristiti istu šifru.'
                    : 'Unesite zajedničku šifru baze za prikaz računa.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _password,
                enabled: !checking,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) {
                  if (!setup && !checking) {
                    _submit();
                  }
                },
                decoration: const InputDecoration(
                  labelText: 'Šifra baze',
                  border: OutlineInputBorder(),
                ),
              ),
              if (setup) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _repeatPassword,
                  enabled: !checking,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) {
                    if (!checking) {
                      _submit();
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: 'Ponovite šifru baze',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _remember,
                onChanged: checking
                    ? null
                    : (value) {
                        setState(() => _remember = value ?? true);
                      },
                title: const Text('Zapamti šifru na ovom uređaju'),
                subtitle: const Text(
                  'Sljedeće otvaranje baze biće brže na ovom telefonu ili računaru.',
                ),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              if (encryption.message != null) ...[
                const SizedBox(height: 8),
                Text(
                  encryption.message!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (checking) ...[
                const SizedBox(height: 12),
                Text(
                  setup
                      ? 'Šifru spremamo i šifrujemo bazu. Sačekajte nekoliko sekundi.'
                      : 'Otključavam bazu. Aplikacija ostaje dostupna dok provjera traje.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 8),
                Text(
                  progressPercent == null
                      ? 'Pripremam...'
                      : '$progressPercent%',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton(
                onPressed: checking ? null : _submit,
                child: checking
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 12),
                          Text(setup ? 'Šifrujem...' : 'Otključavam...'),
                        ],
                      )
                    : Text(setup ? 'Postavi šifru' : 'Otključaj'),
              ),
            ],
          ),
        ),
      ),
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
    final signingIn = widget.auth.status == AppAuthStatus.signingIn;
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final form = _loginForm(context, signingIn);
          if (constraints.maxWidth >= 760) {
            return Row(
              children: [
                const Expanded(flex: 6, child: _LoginHeroPanel()),
                Expanded(
                  flex: 4,
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(36),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: form,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                children: [
                  _LoginHeroImage(
                    height: (constraints.maxWidth * 0.72)
                        .clamp(230.0, 340.0)
                        .toDouble(),
                  ),
                  const SizedBox(height: 18),
                  form,
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _loginForm(BuildContext context, bool signingIn) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
    );
  }
}

enum _LoginMethod { email, google }

final class _LoginHeroPanel extends StatelessWidget {
  const _LoginHeroPanel();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      image: true,
      label: 'Taxi Invoice',
      child: ColoredBox(
        color: scheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: DecoratedBox(
              decoration: BoxDecoration(color: scheme.surfaceContainerHighest),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    _loginPanelBackgroundAsset,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    color: Colors.black.withAlpha(80),
                    colorBlendMode: BlendMode.darken,
                  ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: Image.asset(
                          _loginHeroAsset,
                          fit: BoxFit.contain,
                          alignment: Alignment.center,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _LoginHeroImage extends StatelessWidget {
  const _LoginHeroImage({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        image: true,
        label: 'Taxi Invoice',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            width: double.infinity,
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  _loginPanelBackgroundAsset,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  color: Colors.black.withAlpha(64),
                  colorBlendMode: BlendMode.darken,
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      _loginHeroAsset,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
