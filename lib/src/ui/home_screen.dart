import 'package:app_taxi_invoice/src/pdf/invoice_pdf_builder.dart';
import 'package:app_taxi_invoice/src/auth/app_auth_controller.dart';
import 'package:app_taxi_invoice/src/auth/app_user_access_controller.dart';
import 'package:app_taxi_invoice/src/ui/invoice_color_scheme.dart';
import 'package:app_taxi_invoice/src/settings/app_settings_controller.dart';
import 'package:app_taxi_invoice/src/store/invoice_store_controller.dart';
import 'package:app_taxi_invoice/src/store/invoice_store_encryption.dart';
import 'package:app_taxi_invoice/src/store/invoice_models.dart';
import 'package:app_taxi_invoice/src/ui/invoice_date_formats.dart';
import 'package:app_taxi_invoice/src/ui/invoice_detail_screen.dart';
import 'package:app_taxi_invoice/src/ui/invoice_chat_wizard_screen.dart';
import 'package:app_taxi_invoice/src/ui/invoice_editor_screen.dart';
import 'package:app_taxi_invoice/src/ui/invoice_number.dart';
import 'package:app_taxi_invoice/src/ui/service_recipients_list_screen.dart';
import 'package:app_taxi_invoice/src/ui/settings_screen.dart';
import 'package:app_taxi_invoice/src/ui/store_sync_status.dart';
import 'package:flutter/material.dart';

final class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.store,
    required this.settings,
    required this.auth,
    this.userAccess,
    this.encryption,
    super.key,
  });

  final InvoiceStoreController store;
  final AppSettingsController settings;
  final AppAuthController auth;
  final AppUserAccessController? userAccess;
  final InvoiceStoreEncryptionController? encryption;

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

  Future<void> _saveInvoiceOnline(
    BuildContext context,
    StoredInvoice invoice,
  ) async {
    final store = widget.store;
    if (!store.canWrite) {
      showInvoiceStoreReadOnlyMessage(context, store);
      return;
    }
    final canSaveDuplicate = await confirmDuplicateInvoiceNumberIfNeeded(
      context: context,
      store: store,
      invoiceNumber: invoice.invoiceNumber,
      existingInvoiceId: invoice.id,
      onlineOnly: true,
    );
    if (!context.mounted || !canSaveDuplicate) {
      return;
    }
    try {
      await store.publishLocalOnlyInvoice(invoice.id);
    } catch (e) {
      if (context.mounted) {
        showInvoiceStoreMutationError(context, e);
      }
      return;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Račun je sačuvan online.')));
    }
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
                    userAccess: widget.userAccess,
                    encryption: widget.encryption,
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
                        storedOnline: store.isInvoiceStoredOnline(inv.id),
                        canSaveOnline: store.canWrite,
                        onSaveOnline: () => _saveInvoiceOnline(context, inv),
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _InvoiceFilterButton(
              selected: selected == _InvoiceHomeFilter.currentMonth,
              label: 'Ovaj mjesec',
              onPressed: () => onSelected(_InvoiceHomeFilter.currentMonth),
            ),
            const SizedBox(width: 8),
            _InvoiceFilterButton(
              selected: selected == _InvoiceHomeFilter.previousMonth,
              label: 'Prošli mjesec',
              onPressed: () => onSelected(_InvoiceHomeFilter.previousMonth),
            ),
            const SizedBox(width: 8),
            _InvoiceFilterButton(
              selected: selected == _InvoiceHomeFilter.all,
              label: 'Svi računi',
              onPressed: () => onSelected(_InvoiceHomeFilter.all),
            ),
          ],
        ),
      ),
    );
  }
}

final class _InvoiceFilterButton extends StatelessWidget {
  const _InvoiceFilterButton({
    required this.selected,
    required this.label,
    required this.onPressed,
  });

  final bool selected;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onPressed(),
      label: Text(label),
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      labelStyle: theme.textTheme.labelLarge?.copyWith(
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      side: BorderSide(color: theme.colorScheme.outlineVariant),
    );
  }
}

final class _InvoiceListItem extends StatelessWidget {
  const _InvoiceListItem({
    required this.invoice,
    required this.onOpen,
    required this.onPreviewPdf,
    required this.storedOnline,
    required this.canSaveOnline,
    required this.onSaveOnline,
  });

  final StoredInvoice invoice;
  final VoidCallback onOpen;
  final VoidCallback onPreviewPdf;
  final bool storedOnline;
  final bool canSaveOnline;
  final VoidCallback onSaveOnline;

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
              final actions = _InvoiceListActions(
                onPreviewPdf: onPreviewPdf,
                storedOnline: storedOnline,
                canSaveOnline: canSaveOnline,
                onSaveOnline: onSaveOnline,
              );
              if (constraints.maxWidth < 420 || textScale > 1.35) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _InvoiceListText(
                      invoice: invoice,
                      storedOnline: storedOnline,
                    ),
                    const SizedBox(height: 12),
                    Align(alignment: Alignment.centerRight, child: actions),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: _InvoiceListText(
                      invoice: invoice,
                      storedOnline: storedOnline,
                    ),
                  ),
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
  const _InvoiceListText({required this.invoice, required this.storedOnline});

  final StoredInvoice invoice;
  final bool storedOnline;

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
        if (!storedOnline) ...[
          const SizedBox(height: 8),
          const _OfflineInvoiceBadge(),
        ],
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

final class _OfflineInvoiceBadge extends StatelessWidget {
  const _OfflineInvoiceBadge();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.error.withValues(alpha: 0.38)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 16,
              color: scheme.onErrorContainer,
            ),
            const SizedBox(width: 6),
            Text(
              'Nije online',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: scheme.onErrorContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _InvoiceListActions extends StatelessWidget {
  const _InvoiceListActions({
    required this.onPreviewPdf,
    required this.storedOnline,
    required this.canSaveOnline,
    required this.onSaveOnline,
  });

  final VoidCallback onPreviewPdf;
  final bool storedOnline;
  final bool canSaveOnline;
  final VoidCallback onSaveOnline;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!storedOnline) ...[
          OutlinedButton.icon(
            onPressed: canSaveOnline ? onSaveOnline : null,
            icon: const Icon(Icons.cloud_upload_outlined, size: 18),
            label: const Text('Online'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 44),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
          const SizedBox(width: 6),
        ],
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
    final invoiceCount = store.invoicesSortedByIssueDate.length;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            InvoiceChatWizardScreen(store: store, settings: settings),
      ),
    );
    if (context.mounted &&
        store.invoicesSortedByIssueDate.length > invoiceCount) {
      onInvoiceCreated();
    }
  }

  Future<void> _openEditor(BuildContext context) async {
    if (!store.canWrite) {
      showInvoiceStoreReadOnlyMessage(context, store);
      return;
    }
    final invoiceCount = store.invoicesSortedByIssueDate.length;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InvoiceEditorScreen(store: store, settings: settings),
      ),
    );
    if (context.mounted &&
        store.invoicesSortedByIssueDate.length > invoiceCount) {
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
