import 'package:app_taxi_invoice/src/pdf/invoice_pdf_builder.dart';
import 'package:app_taxi_invoice/src/auth/app_auth_controller.dart';
import 'package:app_taxi_invoice/src/ui/invoice_color_scheme.dart';
import 'package:app_taxi_invoice/src/settings/app_settings_controller.dart';
import 'package:app_taxi_invoice/src/store/invoice_store_controller.dart';
import 'package:app_taxi_invoice/src/store/invoice_models.dart';
import 'package:app_taxi_invoice/src/ui/invoice_date_formats.dart';
import 'package:app_taxi_invoice/src/ui/invoice_detail_screen.dart';
import 'package:app_taxi_invoice/src/ui/invoice_chat_wizard_screen.dart';
import 'package:app_taxi_invoice/src/ui/invoice_editor_screen.dart';
import 'package:app_taxi_invoice/src/ui/service_recipients_list_screen.dart';
import 'package:app_taxi_invoice/src/ui/settings_screen.dart';
import 'package:app_taxi_invoice/src/ui/store_sync_status.dart';
import 'package:flutter/material.dart';

final class HomeScreen extends StatelessWidget {
  const HomeScreen({
    required this.store,
    required this.settings,
    required this.auth,
    super.key,
  });

  final InvoiceStoreController store;
  final AppSettingsController settings;
  final AppAuthController auth;

  Future<void> _previewPdf(BuildContext context, StoredInvoice invoice) async {
    final bytes = await buildInvoicePdfBytes(invoice);
    if (!context.mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PdfPreviewScreen(
          invoice: invoice,
          pdfBytes: bytes,
          initialSavedPdfPath: invoice.savedPdfPath,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!store.isLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final list = store.invoicesSortedByIssueDate;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Računi',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.groups_outlined, size: 26),
            tooltip: 'Naručioci usluga',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ServiceRecipientsListScreen(store: store),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings, size: 26),
            tooltip: 'Postavke',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SettingsScreen(
                    settings: settings,
                    store: store,
                    auth: auth,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (store.isReadOnly) _StoreReadOnlyBanner(store: store),
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Nema sačuvanih računa.\n\nNajlakše je početi preko '
                        'dugmeta „Pomoćnik za račun” dolje.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontSize: 18,
                          height: 1.5,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final inv = list[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 14),
                        clipBehavior: Clip.antiAlias,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: Theme.of(
                              context,
                            ).colorScheme.outline.withValues(alpha: 0.65),
                          ),
                        ),
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => InvoiceDetailScreen(
                                  store: store,
                                  settings: settings,
                                  invoice: inv,
                                ),
                              ),
                            );
                          },
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                            title: Text(
                              invoiceDocumentTitle(inv),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Izdavanje: '
                                '${formatInvoiceDateMedium(inv.issueDate)} '
                                '· broj stavki: ${inv.lines.length}',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyLarge?.copyWith(height: 1.4),
                              ),
                            ),
                            trailing: _InvoiceListActions(
                              onPreviewPdf: () => _previewPdf(context, inv),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _InvoiceCreateActions(
        store: store,
        settings: settings,
      ),
    );
  }
}

final class _InvoiceListActions extends StatelessWidget {
  const _InvoiceListActions({required this.onPreviewPdf});

  final VoidCallback onPreviewPdf;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilledButton.tonalIcon(
          onPressed: onPreviewPdf,
          icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
          label: const Text('PDF'),
          style: FilledButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
        ),
        const SizedBox(width: 4),
        Icon(Icons.chevron_right, size: 30, color: scheme.invoiceAccent),
      ],
    );
  }
}

final class _InvoiceCreateActions extends StatelessWidget {
  const _InvoiceCreateActions({required this.store, required this.settings});

  final InvoiceStoreController store;
  final AppSettingsController settings;

  void _openAssistant(BuildContext context) {
    if (!store.canWrite) {
      showInvoiceStoreReadOnlyMessage(context, store);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            InvoiceChatWizardScreen(store: store, settings: settings),
      ),
    );
  }

  void _openEditor(BuildContext context) {
    if (!store.canWrite) {
      showInvoiceStoreReadOnlyMessage(context, store);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InvoiceEditorScreen(store: store, settings: settings),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final border = BorderSide(color: Theme.of(context).colorScheme.outline);
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: DecoratedBox(
          decoration: BoxDecoration(border: Border(top: border)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final assistant = FilledButton.icon(
                  onPressed: () => _openAssistant(context),
                  icon: const Icon(Icons.chat_bubble_outline_rounded),
                  label: const Text('Pomoćnik za račun'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                );
                final editor = OutlinedButton.icon(
                  onPressed: () => _openEditor(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Novi račun'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                );
                if (constraints.maxWidth < 420) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [assistant, const SizedBox(height: 10), editor],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: assistant),
                    const SizedBox(width: 12),
                    Expanded(child: editor),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

final class _StoreReadOnlyBanner extends StatelessWidget {
  const _StoreReadOnlyBanner({required this.store});

  final InvoiceStoreController store;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.errorContainer,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(
            children: [
              Icon(Icons.cloud_off_outlined, color: scheme.onErrorContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  store.readOnlyMessage,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onErrorContainer,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
