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

final class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.store,
    required this.settings,
    required this.auth,
    super.key,
  });

  final InvoiceStoreController store;
  final AppSettingsController settings;
  final AppAuthController auth;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

final class _HomeScreenState extends State<HomeScreen> {
  _InvoiceHomeFilter _filter = _InvoiceHomeFilter.all;

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
    final store = widget.store;
    if (!store.isLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final allInvoices = store.invoicesSortedByIssueDate;
    final list = _filterInvoices(allInvoices, _filter, DateTime.now());

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
                    settings: widget.settings,
                    store: widget.store,
                    auth: widget.auth,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _StoreStatusBanner(store: store),
          if (allInvoices.isNotEmpty)
            _InvoiceFilterBar(
              selected: _filter,
              onSelected: (filter) => setState(() => _filter = filter),
            ),
          Expanded(
            child: allInvoices.isEmpty
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
                : list.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _emptyFilterMessage(_filter),
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
                      return _InvoiceListItem(
                        invoice: inv,
                        onOpen: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => InvoiceDetailScreen(
                                store: store,
                                settings: widget.settings,
                                invoice: inv,
                              ),
                            ),
                          );
                        },
                        onPreviewPdf: () => _previewPdf(context, inv),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _InvoiceCreateActions(
        store: store,
        settings: widget.settings,
        onInvoiceCreated: () =>
            setState(() => _filter = _InvoiceHomeFilter.all),
      ),
    );
  }
}

enum _InvoiceHomeFilter { currentMonth, previousMonth, all }

List<StoredInvoice> _filterInvoices(
  List<StoredInvoice> invoices,
  _InvoiceHomeFilter filter,
  DateTime now,
) {
  return switch (filter) {
    _InvoiceHomeFilter.currentMonth =>
      invoices
          .where((invoice) => _isSameMonth(invoice.issueDate, now))
          .toList(),
    _InvoiceHomeFilter.previousMonth => invoices.where((invoice) {
      final previousMonth = DateTime(now.year, now.month - 1);
      return _isSameMonth(invoice.issueDate, previousMonth);
    }).toList(),
    _InvoiceHomeFilter.all => invoices,
  };
}

bool _isSameMonth(DateTime date, DateTime month) {
  return date.year == month.year && date.month == month.month;
}

String _emptyFilterMessage(_InvoiceHomeFilter filter) {
  return switch (filter) {
    _InvoiceHomeFilter.currentMonth =>
      'Nema računa za ovaj mjesec.\n\nPritisnite „Svi računi” za cijelu listu.',
    _InvoiceHomeFilter.previousMonth =>
      'Nema računa za prošli mjesec.\n\nPritisnite „Svi računi” za cijelu listu.',
    _InvoiceHomeFilter.all => 'Nema sačuvanih računa.',
  };
}

final class _InvoiceFilterBar extends StatelessWidget {
  const _InvoiceFilterBar({required this.selected, required this.onSelected});

  final _InvoiceHomeFilter selected;
  final ValueChanged<_InvoiceHomeFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final buttons = [
            _InvoiceFilterButton(
              selected: selected == _InvoiceHomeFilter.currentMonth,
              icon: Icons.today_outlined,
              label: 'Ovaj mjesec',
              onPressed: () => onSelected(_InvoiceHomeFilter.currentMonth),
            ),
            _InvoiceFilterButton(
              selected: selected == _InvoiceHomeFilter.previousMonth,
              icon: Icons.history_rounded,
              label: 'Prošli mjesec',
              onPressed: () => onSelected(_InvoiceHomeFilter.previousMonth),
            ),
            _InvoiceFilterButton(
              selected: selected == _InvoiceHomeFilter.all,
              icon: Icons.list_alt_rounded,
              label: 'Svi računi',
              onPressed: () => onSelected(_InvoiceHomeFilter.all),
            ),
          ];
          if (constraints.maxWidth < 560) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < buttons.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  buttons[i],
                ],
              ],
            );
          }
          return Row(
            children: [
              for (var i = 0; i < buttons.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: buttons[i]),
              ],
            ],
          );
        },
      ),
    );
  }
}

final class _InvoiceFilterButton extends StatelessWidget {
  const _InvoiceFilterButton({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final style = selected
        ? FilledButton.styleFrom(minimumSize: const Size.fromHeight(48))
        : OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48));
    return selected
        ? FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
            style: style,
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
            style: style,
          );
  }
}

final class _InvoiceListItem extends StatelessWidget {
  const _InvoiceListItem({
    required this.invoice,
    required this.onOpen,
    required this.onPreviewPdf,
  });

  final StoredInvoice invoice;
  final VoidCallback onOpen;
  final VoidCallback onPreviewPdf;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textScale = MediaQuery.textScalerOf(context).scale(17) / 17;
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.65)),
      ),
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final actions = _InvoiceListActions(onPreviewPdf: onPreviewPdf);
              if (constraints.maxWidth < 420 || textScale > 1.35) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _InvoiceListText(invoice: invoice),
                    const SizedBox(height: 12),
                    Align(alignment: Alignment.centerRight, child: actions),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: _InvoiceListText(invoice: invoice)),
                  const SizedBox(width: 12),
                  actions,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

final class _InvoiceListText extends StatelessWidget {
  const _InvoiceListText({required this.invoice});

  final StoredInvoice invoice;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          invoiceDocumentTitle(invoice),
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'Izdavanje: ${formatInvoiceDateMedium(invoice.issueDate)} '
          '· broj stavki: ${invoice.lines.length}',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.4),
        ),
      ],
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
            minimumSize: const Size(0, 44),
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
  const _InvoiceCreateActions({
    required this.store,
    required this.settings,
    required this.onInvoiceCreated,
  });

  final InvoiceStoreController store;
  final AppSettingsController settings;
  final VoidCallback onInvoiceCreated;

  Future<void> _openAssistant(BuildContext context) async {
    if (!store.canWrite) {
      showInvoiceStoreReadOnlyMessage(context, store);
      return;
    }
    final invoiceCount = store.snapshot.invoices.length;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            InvoiceChatWizardScreen(store: store, settings: settings),
      ),
    );
    if (context.mounted && store.snapshot.invoices.length > invoiceCount) {
      onInvoiceCreated();
    }
  }

  Future<void> _openEditor(BuildContext context) async {
    if (!store.canWrite) {
      showInvoiceStoreReadOnlyMessage(context, store);
      return;
    }
    final invoiceCount = store.snapshot.invoices.length;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InvoiceEditorScreen(store: store, settings: settings),
      ),
    );
    if (context.mounted && store.snapshot.invoices.length > invoiceCount) {
      onInvoiceCreated();
    }
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
                  label: Text(
                    settings.simpleMode ? 'Novi račun ručno' : 'Novi račun',
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                );
                if (settings.simpleMode || constraints.maxWidth < 420) {
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

final class _StoreStatusBanner extends StatelessWidget {
  const _StoreStatusBanner({required this.store});

  final InvoiceStoreController store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = Theme.of(context).colorScheme;
    final accent = invoiceStoreSyncStatusColor(
      scheme,
      store.syncStatus,
      isSaving: store.isSaving,
    );
    final message = store.isReadOnly
        ? store.readOnlyMessage
        : store.syncMessage ?? '';
    return Material(
      color: store.isReadOnly
          ? scheme.errorContainer
          : scheme.surfaceContainerHighest.withValues(alpha: 0.62),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (store.isSaving)
                SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: accent,
                  ),
                )
              else
                Icon(
                  invoiceStoreSyncStatusIcon(store.syncStatus),
                  color: accent,
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invoiceStoreSyncStatusLabel(
                        store.syncStatus,
                        isSaving: store.isSaving,
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: store.isReadOnly
                            ? scheme.onErrorContainer
                            : scheme.onSurface,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                    if (message.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        message,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: store.isReadOnly
                              ? scheme.onErrorContainer
                              : scheme.onSurfaceVariant,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
