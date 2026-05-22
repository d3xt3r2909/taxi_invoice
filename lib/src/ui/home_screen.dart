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
import 'package:flutter/rendering.dart' show ScrollDirection;

const _homeHeaderAsset = 'assets/branding/home_header.png';
const _assistantFabAsset = 'assets/branding/assistant_fab.png';

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
  String? _selectedRecipientFilter;
  bool _assistantFabExpanded = true;

  Future<void> _previewPdf(BuildContext context, StoredInvoice invoice) async {
    final bytes = await buildInvoicePdfBytes(invoice);
    if (!context.mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PdfPreviewScreen(
          store: widget.store,
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
      recipientName: invoice.recipientName,
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

  void _openServiceRecipients() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ServiceRecipientsListScreen(store: widget.store),
      ),
    );
  }

  void _openSettings() {
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
  }

  Future<void> _openAssistant({InvoiceChatDraft? draft}) async {
    final invoiceCount = widget.store.invoicesSortedByIssueDate.length;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => InvoiceChatWizardScreen(
          store: widget.store,
          settings: widget.settings,
          draft: draft,
        ),
      ),
    );
    if (mounted) {
      if (widget.store.invoicesSortedByIssueDate.length > invoiceCount) {
        setState(() => _selectedRecipientFilter = null);
      } else {
        setState(() {});
      }
    }
  }

  Future<void> _openManualInvoice() async {
    final store = widget.store;
    if (!store.canWrite) {
      showInvoiceStoreReadOnlyMessage(context, store);
      return;
    }
    final invoiceCount = store.invoicesSortedByIssueDate.length;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            InvoiceEditorScreen(store: store, settings: widget.settings),
      ),
    );
    if (mounted && store.invoicesSortedByIssueDate.length > invoiceCount) {
      setState(() => _selectedRecipientFilter = null);
    }
  }

  bool _handleUserScroll(UserScrollNotification notification) {
    final shouldExpand = switch (notification.direction) {
      ScrollDirection.forward => true,
      ScrollDirection.reverse => false,
      _ =>
        notification.metrics.pixels <= notification.metrics.minScrollExtent + 8
            ? true
            : _assistantFabExpanded,
    };
    if (_assistantFabExpanded != shouldExpand) {
      setState(() => _assistantFabExpanded = shouldExpand);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    if (!store.isLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final allInvoices = _sortInvoicesByCreatedDate(
      store.invoicesSortedByIssueDate,
    );
    final recipientFilters = _recipientFiltersForInvoices(allInvoices);
    final activeRecipientFilter =
        _selectedRecipientFilter != null &&
            recipientFilters.contains(_selectedRecipientFilter)
        ? _selectedRecipientFilter
        : null;
    final list = _filterInvoicesByRecipient(allInvoices, activeRecipientFilter);
    final helpDrafts = store.helpRequestedInvoiceChatDrafts;

    return Scaffold(
      body: NotificationListener<UserScrollNotification>(
        onNotification: _handleUserScroll,
        child: CustomScrollView(
          slivers: [
            _HomeSliverAppBar(
              onOpenManualInvoice: _openManualInvoice,
              onOpenRecipients: _openServiceRecipients,
              onOpenSettings: _openSettings,
            ),
            SliverToBoxAdapter(child: _StoreStatusBanner(store: store)),
            if (helpDrafts.isNotEmpty)
              SliverToBoxAdapter(
                child: _HelpRequestedDraftsSection(
                  drafts: helpDrafts,
                  onOpenDraft: (draft) => _openAssistant(draft: draft),
                  onDeleteDraft: _deleteHelpDraft,
                ),
              ),
            if (allInvoices.isNotEmpty)
              SliverToBoxAdapter(
                child: _InvoiceFilterBar(
                  recipients: recipientFilters,
                  selectedRecipient: activeRecipientFilter,
                  onSelected: (recipient) =>
                      setState(() => _selectedRecipientFilter = recipient),
                ),
              ),
            if (allInvoices.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _HomeEmptyState(
                  message:
                      'Nema sačuvanih računa.\n\nNajlakše je početi preko '
                      'dugmeta „Pomoćnik za račun” dolje.',
                ),
              )
            else if (list.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _HomeEmptyState(
                  message: _emptyFilterMessage(activeRecipientFilter),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                sliver: SliverList.builder(
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
      ),
      floatingActionButton: _AssistantFloatingActionButton(
        expanded: _assistantFabExpanded,
        onPressed: _openAssistant,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Future<void> _deleteHelpDraft(InvoiceChatDraft draft) async {
    if (!widget.store.canWrite) {
      showInvoiceStoreReadOnlyMessage(context, widget.store);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Obrisati nacrt?'),
        content: Text(
          'Nacrt „${_draftTitle(draft)}” će nestati iz pomoći. '
          'Sačuvani računi se neće mijenjati.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Odustani'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Obriši'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) {
      return;
    }
    try {
      await widget.store.deleteInvoiceChatDraft(draft.id);
    } catch (e) {
      if (mounted) {
        showInvoiceStoreMutationError(context, e);
      }
      return;
    }
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nacrt je obrisan.')));
    }
  }
}

final class _AssistantFloatingActionButton extends StatelessWidget {
  const _AssistantFloatingActionButton({
    required this.expanded,
    required this.onPressed,
  });

  final bool expanded;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxExpandedWidth = (MediaQuery.sizeOf(context).width - 32)
        .clamp(64.0, 224.0)
        .toDouble();
    return Tooltip(
      message: 'Pomoćnik za račun',
      child: Semantics(
        button: true,
        label: 'Pomoćnik za račun',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: expanded ? maxExpandedWidth : 64,
          height: 64,
          child: Material(
            color: scheme.primaryContainer,
            elevation: 6,
            shadowColor: Colors.black.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(32),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(32),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 64,
                          height: 64,
                          child: Center(child: _AssistantFabAvatar(size: 58)),
                        ),
                        Expanded(
                          child: ClipRect(
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 140),
                              opacity: expanded ? 1 : 0,
                              child: Padding(
                                padding: const EdgeInsets.only(
                                  left: 8,
                                  right: 20,
                                ),
                                child: Text(
                                  'Pomoćnik za račun',
                                  maxLines: 1,
                                  overflow: TextOverflow.fade,
                                  softWrap: false,
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(
                                        color: scheme.onPrimaryContainer,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox.shrink(
                    key: ValueKey(
                      expanded
                          ? 'assistant-fab-expanded'
                          : 'assistant-fab-collapsed',
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

final class _AssistantFabAvatar extends StatelessWidget {
  const _AssistantFabAvatar({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Image.asset(
        _assistantFabAsset,
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}

final class _HelpRequestedDraftsSection extends StatelessWidget {
  const _HelpRequestedDraftsSection({
    required this.drafts,
    required this.onOpenDraft,
    required this.onDeleteDraft,
  });

  final List<InvoiceChatDraft> drafts;
  final ValueChanged<InvoiceChatDraft> onOpenDraft;
  final ValueChanged<InvoiceChatDraft> onDeleteDraft;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.tertiaryContainer.withValues(alpha: 0.58),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.tertiary.withValues(alpha: 0.34)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.support_agent, color: scheme.onTertiaryContainer),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pomoć potrebna',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.onTertiaryContainer,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (final draft in drafts) ...[
                _HelpRequestedDraftTile(
                  draft: draft,
                  onTap: () => onOpenDraft(draft),
                  onDelete: () => onDeleteDraft(draft),
                ),
                if (draft != drafts.last) const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

final class _HelpRequestedDraftTile extends StatelessWidget {
  const _HelpRequestedDraftTile({
    required this.draft,
    required this.onTap,
    required this.onDelete,
  });

  final InvoiceChatDraft draft;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _draftTitle(draft),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_draftStepLabel(draft.step)} · '
                      'Ažurirano ${formatInvoiceDateMedium(draft.updatedAt)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Obriši nacrt',
              ),
              const SizedBox(width: 4),
              FilledButton.tonalIcon(
                onPressed: onTap,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Otvori'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 42),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _HomeSliverAppBar extends StatelessWidget {
  const _HomeSliverAppBar({
    required this.onOpenManualInvoice,
    required this.onOpenRecipients,
    required this.onOpenSettings,
  });

  final VoidCallback onOpenManualInvoice;
  final VoidCallback onOpenRecipients;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final topPadding = MediaQuery.paddingOf(context).top;
    final toolbarHeight = _homeToolbarHeight(context);
    final collapsedHeight = topPadding + toolbarHeight;
    final expandedHeight =
        collapsedHeight + (size.width * 0.24).clamp(112.0, 188.0).toDouble();
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
          final currentHeight = constraints.biggest.height;
          final rawProgress =
              (currentHeight - collapsedHeight) /
              (expandedHeight - collapsedHeight);
          final progress = rawProgress.clamp(0.0, 1.0);
          final imageProgress = Curves.easeOut.transform(progress);
          final onImage = Curves.easeOutCubic.transform(
            ((progress - 0.12) / 0.88).clamp(0.0, 1.0),
          );
          final foregroundColor = Color.lerp(
            scheme.onSurface,
            Colors.white,
            onImage,
          )!;
          final buttonBackground = Color.lerp(
            scheme.surfaceContainerHighest.withValues(alpha: 0.86),
            Colors.black.withValues(alpha: 0.34),
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
                    _homeHeaderAsset,
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
                      padding: const EdgeInsets.fromLTRB(18, 8, 12, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Računi',
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
                          const SizedBox(width: 12),
                          _HomeHeaderAction(
                            tooltip: 'Napredno: novi račun ručno',
                            icon: Icons.edit_document,
                            foregroundColor: foregroundColor,
                            backgroundColor: buttonBackground,
                            onPressed: onOpenManualInvoice,
                          ),
                          const SizedBox(width: 4),
                          _HomeHeaderAction(
                            tooltip: 'Naručioci usluga',
                            icon: Icons.groups_outlined,
                            foregroundColor: foregroundColor,
                            backgroundColor: buttonBackground,
                            onPressed: onOpenRecipients,
                          ),
                          const SizedBox(width: 4),
                          _HomeHeaderAction(
                            tooltip: 'Postavke',
                            icon: Icons.settings,
                            foregroundColor: foregroundColor,
                            backgroundColor: buttonBackground,
                            onPressed: onOpenSettings,
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

double _homeToolbarHeight(BuildContext context) {
  return MediaQuery.textScalerOf(context).scale(64).clamp(64.0, 88.0);
}

final class _HomeHeaderAction extends StatelessWidget {
  const _HomeHeaderAction({
    required this.tooltip,
    required this.icon,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final Color foregroundColor;
  final Color backgroundColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 26),
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
      ),
    );
  }
}

final class _HomeEmptyState extends StatelessWidget {
  const _HomeEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontSize: 18, height: 1.5),
        ),
      ),
    );
  }
}

List<String> _recipientFiltersForInvoices(List<StoredInvoice> invoices) {
  final recipients = <String>{};
  for (final invoice in invoices) {
    final recipient = invoice.recipientName.trim();
    if (recipient.isNotEmpty) {
      recipients.add(recipient);
    }
  }
  return recipients.toList()..sort(_compareText);
}

List<StoredInvoice> _sortInvoicesByCreatedDate(List<StoredInvoice> invoices) {
  final sorted = List<StoredInvoice>.from(invoices);
  sorted.sort((a, b) {
    final created = b.createdAt.compareTo(a.createdAt);
    if (created != 0) {
      return created;
    }
    final issued = b.issueDate.compareTo(a.issueDate);
    if (issued != 0) {
      return issued;
    }
    return b.id.compareTo(a.id);
  });
  return sorted;
}

List<StoredInvoice> _filterInvoicesByRecipient(
  List<StoredInvoice> invoices,
  String? recipient,
) {
  final selected = recipient?.trim();
  if (selected == null || selected.isEmpty) {
    return invoices;
  }
  return invoices
      .where((invoice) => invoice.recipientName.trim() == selected)
      .toList();
}

int _compareText(String a, String b) {
  return a.toLowerCase().compareTo(b.toLowerCase());
}

String _emptyFilterMessage(String? recipient) {
  final selected = recipient?.trim();
  if (selected == null || selected.isEmpty) {
    return 'Nema sačuvanih računa.';
  }
  return 'Nema računa za „$selected”.\n\nPritisnite „Svi” za cijelu listu.';
}

String _draftTitle(InvoiceChatDraft draft) {
  final recipient = draft.recipientName.trim();
  if (recipient.isNotEmpty) {
    return recipient;
  }
  final number = draft.invoiceNumber.trim();
  if (number.isNotEmpty) {
    return 'Nacrt računa $number';
  }
  return 'Nedovršen račun';
}

String _draftStepLabel(String step) {
  return switch (step) {
    'recipient' => 'Naručilac',
    'invoiceNumber' => 'Broj računa',
    'issueDate' => 'Datum računa',
    'lineDate' => 'Datum vožnje',
    'route' => 'Relacija',
    'orderName' => 'Narudžba / ime',
    'amount' => 'Iznos',
    'moreLines' => 'Stavke',
    'summary' => 'Potvrda',
    _ => 'Nacrt',
  };
}

final class _InvoiceFilterBar extends StatelessWidget {
  const _InvoiceFilterBar({
    required this.recipients,
    required this.selectedRecipient,
    required this.onSelected,
  });

  final List<String> recipients;
  final String? selectedRecipient;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _InvoiceFilterButton(
              selected: selectedRecipient == null,
              label: 'Svi',
              onPressed: () => onSelected(null),
            ),
            for (final recipient in recipients) ...[
              const SizedBox(width: 8),
              _InvoiceFilterButton(
                selected: selectedRecipient == recipient,
                label: recipient,
                onPressed: () => onSelected(recipient),
              ),
            ],
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
        top: false,
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
