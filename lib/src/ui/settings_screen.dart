import 'package:app_taxi_invoice/src/auth/app_auth_controller.dart';
import 'package:app_taxi_invoice/src/auth/app_user_access_controller.dart';
import 'package:app_taxi_invoice/src/settings/app_settings_controller.dart';
import 'package:app_taxi_invoice/src/store/invoice_store_controller.dart';
import 'package:app_taxi_invoice/src/store/invoice_store_encryption.dart';
import 'package:app_taxi_invoice/src/ui/import_export_sheet.dart';
import 'package:app_taxi_invoice/src/ui/store_sync_status.dart';
import 'package:app_taxi_invoice/src/util/app_build_info.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

const _settingsHeaderAsset = 'assets/branding/home_header.png';

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
          return CustomScrollView(
            slivers: [
              const _SettingsSliverAppBar(),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                sliver: SliverList.list(
                  children: [
                    _SettingsSection(
                      icon: Icons.account_circle_outlined,
                      title: 'Nalog i sinhronizacija',
                      description:
                          'Brzi pregled prijave i stanja zajedničke baze računa.',
                      children: [
                        _SettingsInfoTile(
                          icon: Icons.mail_outline,
                          title: 'Prijavljen korisnik',
                          subtitle: auth.email ?? 'Nije prijavljen',
                        ),
                        _SyncStatusTile(store: store),
                        if (store.syncMessage != null)
                          _SettingsNote(text: store.syncMessage!),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              Navigator.of(
                                context,
                              ).popUntil((route) => route.isFirst);
                              await auth.signOut();
                            },
                            icon: const Icon(Icons.logout, size: 22),
                            label: const Text('Odjava'),
                          ),
                        ),
                      ],
                    ),
                    const _SettingsDivider(),
                    _SettingsSection(
                      icon: Icons.palette_outlined,
                      title: 'Izgled aplikacije',
                      description:
                          'Podesite temu, jednostavan prikaz i veličinu teksta.',
                      children: [
                        _SettingsControlBlock(
                          title: 'Tema',
                          description:
                              'Telefon prati postavke uređaja. Svijetlo i tamno drže '
                              'isti prikaz stalno uključen.',
                          child: _HorizontalSettingsControl(
                            child: SegmentedButton<ThemeMode>(
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
                          ),
                        ),
                        const _SettingsThinDivider(),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: settings.simpleMode,
                          onChanged: settings.setSimpleMode,
                          secondary: const Icon(Icons.touch_app_outlined),
                          title: const Text('Jednostavan prikaz'),
                          subtitle: const Text(
                            'Veći osnovni tekst i glavni put preko pomoćnika za račun.',
                          ),
                        ),
                        const _SettingsThinDivider(),
                        _SettingsControlBlock(
                          title: 'Veličina teksta',
                          description:
                              'Dodatno uvećanje preko sistemske veličine fonta. '
                              'Veće je oko +12%, a najveće oko +24%.',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _HorizontalSettingsControl(
                                child: SegmentedButton<int>(
                                  showSelectedIcon: false,
                                  segments: const <ButtonSegment<int>>[
                                    ButtonSegment<int>(
                                      value: 0,
                                      label: Text('Obično'),
                                    ),
                                    ButtonSegment<int>(
                                      value: 1,
                                      label: Text('Veće'),
                                    ),
                                    ButtonSegment<int>(
                                      value: 2,
                                      label: Text('Najveće'),
                                    ),
                                  ],
                                  selected: <int>{settings.textScaleStep},
                                  onSelectionChanged: (next) {
                                    if (next.isNotEmpty) {
                                      settings.setTextScaleStep(next.first);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(height: 14),
                              const _TextPreviewBox(),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const _SettingsDivider(),
                    _SettingsSection(
                      icon: Icons.picture_as_pdf_outlined,
                      title: 'PDF računi',
                      description: kIsWeb
                          ? 'Na webu se PDF dijeli ili preuzima iz pregleda računa.'
                          : 'Odaberite gdje će aplikacija čuvati PDF datoteke.',
                      children: [
                        if (kIsWeb)
                          const _SettingsNote(
                            text:
                                'Fiksni folder na disku nije podržan u web-pregledniku.',
                          )
                        else ...[
                          Text(
                            'Svaki put kad snimite račun, datoteka ide u ovaj folder '
                            'kao „Naručilac - broj_računa.pdf”. Ako ista datoteka već '
                            'postoji, aplikacija pita da li da je zamijeni.',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _SettingsInfoTile(
                            icon: Icons.folder_outlined,
                            title: 'Trenutni folder',
                            subtitle:
                                settings.pdfOutputDirectory ??
                                'Još nije odabran folder.',
                            selectableSubtitle: true,
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              FilledButton.icon(
                                onPressed: () async {
                                  final path = await FilePicker.platform
                                      .getDirectoryPath(
                                        dialogTitle:
                                            'Odaberite folder za PDF račune',
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
                                  onPressed: () =>
                                      settings.setPdfOutputDirectory(null),
                                  child: const Text('Ukloni folder'),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                    const _SettingsDivider(),
                    _SettingsSection(
                      icon: Icons.import_export,
                      title: 'Podaci i sigurnosna kopija',
                      description:
                          'Izvezite JSON kopiju ili uvezite podatke s drugog uređaja.',
                      children: [
                        Text(
                          'Kopija sadrži račune, naručioce usluga, gradove i imena '
                          'narudžbi. Uvoz „zamijeni sve” briše trenutne lokalne podatke.',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                showImportExportSheet(context, store),
                            icon: const Icon(Icons.import_export, size: 24),
                            label: const Text('Uvoz i izvoz podataka'),
                          ),
                        ),
                      ],
                    ),
                    const _SettingsDivider(),
                    _SettingsSection(
                      icon: Icons.info_outline,
                      title: 'O aplikaciji',
                      description:
                          'Verzija koja je trenutno otvorena na ovom uređaju.',
                      children: [
                        _SettingsInfoTile(
                          icon: Icons.new_releases_outlined,
                          title: 'Verzija aplikacije',
                          subtitle: AppBuildInfo.current.settingsSubtitle,
                          selectableSubtitle: true,
                        ),
                      ],
                    ),
                    if (showAdminTools) ...[
                      const _SettingsDivider(),
                      _AdminDatabaseSection(
                        store: store,
                        encryption: encryption!,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

final class _SettingsSliverAppBar extends StatelessWidget {
  const _SettingsSliverAppBar();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final topPadding = MediaQuery.paddingOf(context).top;
    final toolbarHeight = _settingsToolbarHeight(context);
    final collapsedHeight = topPadding + toolbarHeight;
    final expandedHeight =
        collapsedHeight + (size.width * 0.2).clamp(96.0, 156.0).toDouble();
    final scheme = Theme.of(context).colorScheme;
    return SliverAppBar(
      automaticallyImplyLeading: false,
      pinned: true,
      toolbarHeight: toolbarHeight,
      expandedHeight: expandedHeight,
      backgroundColor: scheme.surface,
      surfaceTintColor: scheme.surfaceTint,
      elevation: 0,
      scrolledUnderElevation: 2,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final rawProgress =
              (constraints.biggest.height - collapsedHeight) /
              (expandedHeight - collapsedHeight);
          final imageProgress = Curves.easeOut.transform(
            rawProgress.clamp(0.0, 1.0),
          );
          final onImage = Curves.easeOutCubic.transform(
            ((rawProgress - 0.12) / 0.88).clamp(0.0, 1.0),
          );
          final foregroundColor = Color.lerp(
            scheme.onSurface,
            Colors.white,
            onImage,
          )!;
          return Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: scheme.surface),
              Opacity(
                opacity: imageProgress,
                child: Semantics(
                  image: true,
                  label: 'Taxi Invoice',
                  child: Image.asset(
                    _settingsHeaderAsset,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                  ),
                ),
              ),
              Opacity(
                opacity: imageProgress,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x99000000),
                        Color(0x33000000),
                        Color(0x66000000),
                      ],
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  top: false,
                  bottom: false,
                  child: SizedBox(
                    width: double.infinity,
                    height: toolbarHeight,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
                      child: Row(
                        children: [
                          if (Navigator.of(context).canPop()) ...[
                            _SettingsBackButton(color: foregroundColor),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Text(
                              'Postavke',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: foregroundColor,
                                    fontWeight: FontWeight.w800,
                                    shadows: imageProgress > 0.2
                                        ? const [
                                            Shadow(
                                              blurRadius: 12,
                                              color: Color(0xAA000000),
                                            ),
                                          ]
                                        : null,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

double _settingsToolbarHeight(BuildContext context) {
  return MediaQuery.textScalerOf(context).scale(64).clamp(64.0, 88.0);
}

final class _SettingsBackButton extends StatelessWidget {
  const _SettingsBackButton({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: () => Navigator.of(context).maybePop(),
      icon: const Icon(Icons.arrow_back),
      style: IconButton.styleFrom(
        foregroundColor: color,
        backgroundColor: Colors.black.withValues(alpha: 0.24),
      ),
    );
  }
}

final class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.icon,
    required this.title,
    required this.description,
    required this.children,
  });

  final IconData icon;
  final String title;
  final String description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: scheme.primary, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }
}

final class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Divider(height: 1),
    );
  }
}

final class _SettingsThinDivider extends StatelessWidget {
  const _SettingsThinDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 14),
      child: Divider(height: 1),
    );
  }
}

final class _SettingsControlBlock extends StatelessWidget {
  const _SettingsControlBlock({
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: theme.textTheme.bodyLarge?.copyWith(height: 1.4),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

final class _HorizontalSettingsControl extends StatelessWidget {
  const _HorizontalSettingsControl({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: child,
      ),
    );
  }
}

final class _SettingsInfoTile extends StatelessWidget {
  const _SettingsInfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.selectableSubtitle = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selectableSubtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitleStyle = theme.textTheme.bodyMedium?.copyWith(height: 1.35);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: selectableSubtitle
          ? SelectableText(subtitle, style: subtitleStyle)
          : Text(subtitle, style: subtitleStyle),
    );
  }
}

final class _SyncStatusTile extends StatelessWidget {
  const _SyncStatusTile({required this.store});

  final InvoiceStoreController store;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = invoiceStoreSyncStatusColor(
      scheme,
      store.syncStatus,
      isSaving: store.isSaving,
    );
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: store.isSaving
          ? SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: accent),
            )
          : Icon(invoiceStoreSyncStatusIcon(store.syncStatus), color: accent),
      title: const Text('Status baze'),
      subtitle: Text(
        invoiceStoreSyncStatusLabel(store.syncStatus, isSaving: store.isSaving),
      ),
    );
  }
}

final class _SettingsNote extends StatelessWidget {
  const _SettingsNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.72,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(text, style: theme.textTheme.bodyMedium),
      ),
    );
  }
}

final class _TextPreviewBox extends StatelessWidget {
  const _TextPreviewBox();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.72,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          'Primjer: ovako će izgledati tekst u računima i na dugmadima.',
          style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
        ),
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
    return _SettingsSection(
      icon: Icons.admin_panel_settings_outlined,
      title: 'Administrator',
      description:
          'Ove opcije vidi samo administrator. Promjena šifre traži trenutnu '
          'šifru, a brisanje uklanja sve račune, naručioce i prijedloge iz baze.',
      children: [
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
