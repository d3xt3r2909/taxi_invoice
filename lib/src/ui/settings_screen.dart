import 'package:app_taxi_invoice/src/settings/app_settings_controller.dart';
import 'package:app_taxi_invoice/src/store/invoice_store_controller.dart';
import 'package:app_taxi_invoice/src/ui/import_export_sheet.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Prikaz i izmjena tamnog/svijetlog moda, teksta i uvoza/izvoza podataka.
final class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    required this.settings,
    required this.store,
    super.key,
  });

  final AppSettingsController settings;
  final InvoiceStoreController store;

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
        listenable: settings,
        builder: (context, _) {
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
              const SizedBox(height: 28),
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
