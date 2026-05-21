import 'package:app_taxi_invoice/src/auth/app_auth_controller.dart';
import 'package:app_taxi_invoice/src/auth/app_user_access_controller.dart';
import 'package:app_taxi_invoice/src/settings/app_settings_controller.dart';
import 'package:app_taxi_invoice/src/store/invoice_store_controller.dart';
import 'package:app_taxi_invoice/src/store/invoice_store_encryption.dart';
import 'package:app_taxi_invoice/src/ui/import_export_sheet.dart';
import 'package:app_taxi_invoice/src/ui/store_sync_status.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Prikaz i izmjena tamnog/svijetlog moda, teksta i uvoza/izvoza podataka.
final class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    required this.settings,
    required this.store,
    required this.auth,
    this.userAccess,
    this.encryption,
    super.key,
  });

  final AppSettingsController settings;
  final InvoiceStoreController store;
  final AppAuthController auth;
  final AppUserAccessController? userAccess;
  final InvoiceStoreEncryptionController? encryption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Postavke',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          settings,
          store,
          auth,
          ?userAccess,
          ?encryption,
        ]),
        builder: (context, _) {
          final showAdminTools =
              userAccess?.isAdmin == true && encryption != null;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Text(
                'Izgled',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Telefon = ista tema kao u postavkama uređaja. Svijetlo / tamno '
                'drže prikaz uvijek jasan danju ili noću.',
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.4),
              ),
              const SizedBox(height: 16),
              SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: const <ButtonSegment<ThemeMode>>[
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.system,
                    label: Text('Telefon'),
                  ),
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.light,
                    label: Text('Svijetlo'),
                  ),
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.dark,
                    label: Text('Tamno'),
                  ),
                ],
                selected: <ThemeMode>{settings.themeMode},
                onSelectionChanged: (next) {
                  if (next.isNotEmpty) {
                    settings.setThemeMode(next.first);
                  }
                },
              ),
              const SizedBox(height: 18),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                value: settings.simpleMode,
                onChanged: settings.setSimpleMode,
                secondary: const Icon(Icons.touch_app_outlined),
                title: const Text('Jednostavan prikaz'),
                subtitle: const Text(
                  'Veći osnovni tekst i glavni put preko pomoćnika za račun.',
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Veličina teksta u aplikaciji',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Dva koraka veća od standarda. Pomnoži se s onim što ste '
                'postavili u sistemu (pristupačnost – veliki font).',
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
              ),
              const SizedBox(height: 8),
              Text(
                'Obično · Bez dodatnog · Veće ≈ +12% · Najveće ≈ +24%',
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.35),
              ),
              const SizedBox(height: 16),
              SegmentedButton<int>(
                showSelectedIcon: false,
                segments: const <ButtonSegment<int>>[
                  ButtonSegment<int>(value: 0, label: Text('Obično')),
                  ButtonSegment<int>(value: 1, label: Text('Veće')),
                  ButtonSegment<int>(value: 2, label: Text('Najveće')),
                ],
                selected: <int>{settings.textScaleStep},
                onSelectionChanged: (next) {
                  if (next.isNotEmpty) {
                    settings.setTextScaleStep(next.first);
                  }
                },
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Primjer: ovako će izgledati tekst u računima i na dugmadima '
                    's trenutnim izborom.',
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Folder za PDF račune',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              if (kIsWeb)
                Text(
                  'U web-pregledniku PDF se dijeli iz pregleda. Fiksni folder '
                  'na disku nije podržan.',
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
                )
              else ...[
                Text(
                  'Jednom odaberite folder. Svaki put kad snimite račun '
                  '(„Sačuvaj i generiši PDF”), datoteka ide tamo kao '
                  '„Naručilac - broj_računa.pdf” (npr. „ITX - 6_26.pdf”). '
                  'Ako ista datoteka već postoji, aplikacija pita da li da je zamijeni.',
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
                ),
                const SizedBox(height: 12),
                SelectableText(
                  settings.pdfOutputDirectory ?? 'Još nije odabran folder.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: settings.pdfOutputDirectory != null
                        ? FontWeight.w500
                        : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () async {
                        final path = await FilePicker.platform.getDirectoryPath(
                          dialogTitle: 'Odaberite folder za PDF račune',
                        );
                        if (path != null) {
                          await settings.setPdfOutputDirectory(path);
                        }
                      },
                      icon: const Icon(Icons.folder_open, size: 22),
                      label: const Text('Odaberi folder'),
                    ),
                    if (settings.pdfOutputDirectory != null)
                      OutlinedButton(
                        onPressed: () => settings.setPdfOutputDirectory(null),
                        child: const Text('Ukloni folder'),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 32),
              Text(
                'Cloud sync',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Prijavljen korisnik: ${auth.email ?? 'nije prijavljen'}',
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
              ),
              const SizedBox(height: 6),
              Text(
                'Status: ${invoiceStoreSyncStatusLabel(store.syncStatus, isSaving: store.isSaving)}',
                style: theme.textTheme.bodyLarge?.copyWith(
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (store.syncMessage != null) ...[
                const SizedBox(height: 6),
                Text(
                  store.syncMessage!,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
              ],
              if (showAdminTools) ...[
                const SizedBox(height: 28),
                _AdminDatabaseSection(store: store, encryption: encryption!),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                  await auth.signOut();
                },
                icon: const Icon(Icons.logout, size: 22),
                label: const Text('Odjava'),
              ),
              const SizedBox(height: 32),
              Text(
                'Podaci (JSON)',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Napravite rezervnu kopiju svih računa, naručilaca, gradova i '
                'imen narudžbi, ili uvezite datoteku s drugog uređaja. Oprez: '
                'uvoz „zamijeni sve” briše sve lokalne podatke.',
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => showImportExportSheet(context, store),
                  icon: const Icon(Icons.import_export, size: 24),
                  label: const Text('Uvoz i izvoz podataka'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

final class _AdminDatabaseSection extends StatelessWidget {
  const _AdminDatabaseSection({required this.store, required this.encryption});

  final InvoiceStoreController store;
  final InvoiceStoreEncryptionController encryption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final changingPassword =
        encryption.status == InvoiceStoreEncryptionStatus.checking;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Administrator',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Ove opcije vidi samo administrator. Promjena šifre traži trenutnu '
          'šifru, a brisanje uklanja sve račune, naručioce i prijedloge iz baze.',
          style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: changingPassword
              ? null
              : () async {
                  final changed = await showDialog<bool>(
                    context: context,
                    builder: (_) =>
                        _ChangeDatabasePasswordDialog(encryption: encryption),
                  );
                  if (!context.mounted || changed != true) {
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Šifra baze je promijenjena.'),
                    ),
                  );
                },
          icon: const Icon(Icons.password_rounded, size: 22),
          label: const Text('Promijeni šifru baze'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: store.canWrite && !store.isSaving
              ? () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (_) => const _ConfirmClearDatabaseDialog(),
                  );
                  if (!context.mounted || confirmed != true) {
                    return;
                  }
                  try {
                    await store.clearAllData();
                    if (!context.mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Svi podaci iz baze su obrisani.'),
                      ),
                    );
                  } on InvoiceStoreMutationException catch (e) {
                    if (!context.mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(e.message)));
                  }
                }
              : null,
          icon: Icon(
            Icons.delete_forever_outlined,
            size: 22,
            color: store.canWrite ? theme.colorScheme.error : null,
          ),
          label: Text(
            store.isSaving ? 'Baza se čuva...' : 'Obriši sve podatke',
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: store.canWrite ? theme.colorScheme.error : null,
            side: store.canWrite
                ? BorderSide(color: theme.colorScheme.error)
                : null,
          ),
        ),
      ],
    );
  }
}

final class _ChangeDatabasePasswordDialog extends StatefulWidget {
  const _ChangeDatabasePasswordDialog({required this.encryption});

  final InvoiceStoreEncryptionController encryption;

  @override
  State<_ChangeDatabasePasswordDialog> createState() =>
      _ChangeDatabasePasswordDialogState();
}

final class _ChangeDatabasePasswordDialogState
    extends State<_ChangeDatabasePasswordDialog> {
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _repeatPassword = TextEditingController();
  bool _rememberOnDevice = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _currentPassword.dispose();
    _newPassword.dispose();
    _repeatPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final next = _newPassword.text.trim();
    if (next != _repeatPassword.text.trim()) {
      setState(() => _error = 'Nova šifra i ponovljena šifra nisu iste.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    var completed = false;
    try {
      await widget.encryption.changePassphrase(
        currentPassphrase: _currentPassword.text,
        newPassphrase: next,
        rememberOnDevice: _rememberOnDevice,
      );
      if (mounted) {
        completed = true;
        Navigator.of(context).pop(true);
      }
    } on InvoiceStoreEncryptionException catch (e) {
      if (mounted) {
        setState(() => _error = e.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Šifra baze nije promijenjena.');
      }
    } finally {
      if (mounted && !completed) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.encryption,
      builder: (context, _) {
        final progress = widget.encryption.progress;
        final progressPercent = progress == null
            ? null
            : (progress * 100).clamp(0, 100).round();
        final busy =
            _submitting ||
            widget.encryption.status == InvoiceStoreEncryptionStatus.checking;
        final theme = Theme.of(context);
        return AlertDialog(
          title: const Text('Promijeni šifru baze'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _currentPassword,
                  enabled: !busy,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Trenutna šifra',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _newPassword,
                  enabled: !busy,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Nova šifra',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _repeatPassword,
                  enabled: !busy,
                  obscureText: true,
                  onSubmitted: (_) {
                    if (!busy) {
                      _submit();
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: 'Ponovite novu šifru',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: _rememberOnDevice,
                  onChanged: busy
                      ? null
                      : (value) {
                          setState(() => _rememberOnDevice = value ?? true);
                        },
                  title: const Text('Zapamti novu šifru na ovom uređaju'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (busy) ...[
                  const SizedBox(height: 12),
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 8),
                  Text(
                    progressPercent == null
                        ? 'Mijenjam šifru...'
                        : '$progressPercent%',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.of(context).pop(false),
              child: const Text('Odustani'),
            ),
            FilledButton(
              onPressed: busy ? null : _submit,
              child: const Text('Promijeni'),
            ),
          ],
        );
      },
    );
  }
}

final class _ConfirmClearDatabaseDialog extends StatefulWidget {
  const _ConfirmClearDatabaseDialog();

  @override
  State<_ConfirmClearDatabaseDialog> createState() =>
      _ConfirmClearDatabaseDialogState();
}

final class _ConfirmClearDatabaseDialogState
    extends State<_ConfirmClearDatabaseDialog> {
  final _confirmation = TextEditingController();

  @override
  void dispose() {
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final confirmed = _confirmation.text.trim().toUpperCase() == 'OBRISI';
    return AlertDialog(
      title: const Text('Obrisati sve podatke?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Ovo briše sve račune, naručioce usluga, gradove i prijedloge. '
            'Šifra baze ostaje ista.',
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _confirmation,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Upišite OBRISI za potvrdu',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Odustani'),
        ),
        FilledButton(
          onPressed: confirmed ? () => Navigator.of(context).pop(true) : null,
          child: const Text('Obriši sve'),
        ),
      ],
    );
  }
}
